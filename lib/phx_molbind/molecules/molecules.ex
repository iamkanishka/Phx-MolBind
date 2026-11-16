defmodule PhxMolbind.Molecules.Molecules do
  @moduledoc """
  The Molecules context: runs molecule-generation requests against the
  NVIDIA BioNeMo MolMIM API and persists the resulting optimization runs.
  """

  alias PhxMolbind.Repo
  alias PhxMolbind.Molecules.Molecule
  import Ecto.Query, only: [from: 2]

  @molmim_url "https://health.api.nvidia.com/v1/biology/nvidia/molmim/generate"
  @receive_timeout 120_000

  @doc """
  Validation limits for `generate_molecules/1` parameters, taken from NVIDIA's
  MolMIM documentation (docs.nvidia.com/nim/bionemo/molmim). NVIDIA's local-NIM
  docs cap `min_similarity` at 0.7 while the hosted API reference states 0-1;
  we accept 0-1 and surface the API's own error if it rejects a value.
  """
  def limits do
    %{
      num_molecules: 1..100,
      particles: 2..1000,
      iterations: 1..1000,
      min_similarity: {0.0, 1.0},
      algorithms: ~w(CMA-ES none),
      properties: ~w(QED plogP)
    }
  end

  @doc """
  Classifies a `generate_molecules/1` error into `{kind, user_message}`.
  Never includes raw response bodies or stack traces in the message.
  """
  @spec describe_error(term()) :: {atom(), String.t()}
  def describe_error(:missing_nvidia_api_key),
    do:
      {:missing_key,
       "Molecule generation is not configured: the NVIDIA_API_KEY is missing on the server."}

  def describe_error({:unexpected_status, status, _body}) when status in [401, 403],
    do: {:auth, "The generation service rejected the server's API key (HTTP #{status})."}

  def describe_error({:unexpected_status, 422, _body}),
    do:
      {:invalid_input,
       "The generation service could not process this input (HTTP 422). Check the SMILES string and parameters."}

  def describe_error({:unexpected_status, 429, _body}),
    do:
      {:rate_limited,
       "The generation service is rate limiting requests (HTTP 429). Wait a moment and retry."}

  def describe_error({:unexpected_status, status, _body}) when status >= 500,
    do:
      {:service_error,
       "The generation service had an internal error (HTTP #{status}). Retry shortly."}

  def describe_error({:unexpected_status, status, _body}),
    do:
      {:service_error, "The generation service returned an unexpected response (HTTP #{status})."}

  def describe_error(%{__exception__: true, reason: :timeout}),
    do:
      {:timeout,
       "The generation service did not respond in time. Try fewer molecules, particles or iterations."}

  def describe_error(%{__exception__: true}),
    do: {:network, "Could not reach the generation service. Check connectivity and retry."}

  def describe_error(_other),
    do: {:failed, "Molecule generation failed. The service response could not be understood."}

  @doc "Returns a user's past optimization runs, most recent first."
  def get_history_for_user(user_id) do
    Repo.all(
      from mo in Molecule,
        where: mo.user_id == ^user_id,
        order_by: [desc: mo.inserted_at]
    )
  end

  @doc """
  Returns the `limit` most recent runs for `user_id`, newest first.
  Use this instead of `get_history_for_user/1` for UI lists.
  """
  def recent_history_for_user(user_id, limit \\ 20) when is_integer(limit) and limit > 0 do
    Repo.all(
      from mo in Molecule,
        where: mo.user_id == ^user_id,
        order_by: [desc: mo.inserted_at, desc: mo.id],
        limit: ^limit
    )
  end

  @doc """
  Summary statistics for the dashboard, scoped to `user_id`.

    * `runs` — saved generation runs. Only successful runs are persisted, so
      failed, cancelled and in-flight requests are never counted.
    * `runs_this_week` — saved runs created in the last 7 days.
    * `molecules` — candidate molecules stored across those runs.
  """
  def dashboard_summary(user_id) do
    week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -7 * 24 * 3600, :second)

    Repo.one(
      from mo in Molecule,
        where: mo.user_id == ^user_id,
        select: %{
          runs: count(mo.id),
          runs_this_week:
            count(
              fragment(
                "CASE WHEN ? >= ? THEN 1 END",
                mo.inserted_at,
                type(^week_ago, :naive_datetime)
              )
            ),
          molecules:
            coalesce(
              sum(
                fragment(
                  "CASE WHEN jsonb_typeof(? -> 'molecules') = 'array' THEN jsonb_array_length(? -> 'molecules') ELSE 0 END",
                  mo.generated_molecules,
                  mo.generated_molecules
                )
              ),
              0
            )
        }
    )
  end

  @doc """
  Fetches one run belonging to `user_id`. Returns nil for runs that do not
  exist *or belong to someone else* — ownership is enforced here, never
  trusted from client-supplied ids.
  """
  def get_history_entry(user_id, id) do
    Repo.get_by(Molecule, id: id, user_id: user_id)
  end

  @doc """
  Paginated, filterable list of a user's saved runs.

  Options: `:search` (substring of the starting SMILES, case-insensitive),
  `:sort` (`:newest` | `:oldest` | `:most_candidates`), `:page` (1-based) and
  `:per_page` (max 100). Returns `%{entries: [...], total: n, page: p, pages: n}`.
  """
  def list_history(user_id, opts \\ []) do
    per_page = opts |> Keyword.get(:per_page, 12) |> max(1) |> min(100)
    search = opts |> Keyword.get(:search, "") |> to_string() |> String.trim()

    base =
      from mo in Molecule, where: mo.user_id == ^user_id

    base =
      if search == "" do
        base
      else
        pattern = "%" <> escape_like(search) <> "%"
        from mo in base, where: ilike(mo.smiles, ^pattern)
      end

    total = Repo.aggregate(base, :count, :id)
    pages = max(div(total + per_page - 1, per_page), 1)
    page = opts |> Keyword.get(:page, 1) |> max(1) |> min(pages)

    ordered =
      case Keyword.get(opts, :sort, :newest) do
        :oldest -> from mo in base, order_by: [asc: mo.inserted_at, asc: mo.id]
        :most_candidates -> from mo in base, order_by: [desc: mo.num_molecules, desc: mo.id]
        _ -> from mo in base, order_by: [desc: mo.inserted_at, desc: mo.id]
      end

    entries =
      Repo.all(from mo in ordered, limit: ^per_page, offset: ^((page - 1) * per_page))

    %{entries: entries, total: total, page: page, pages: pages}
  end

  defp escape_like(value), do: String.replace(value, ["\\", "%", "_"], &("\\" <> &1))

  @doc "Deletes one of the user's runs. Saved collection items keep their SMILES."
  def delete_history_entry(user_id, id) do
    case get_history_entry(user_id, id) do
      nil -> {:error, :not_found}
      entry -> Repo.delete(entry)
    end
  end

  @doc "Candidates stored on a run as `[%{index, structure, score}]`."
  def candidates(%Molecule{generated_molecules: generated}) do
    generated
    |> Map.get("molecules", [])
    |> Enum.with_index()
    |> Enum.flat_map(fn {m, index} ->
      structure = Map.get(m, "structure") || Map.get(m, :structure)
      score = Map.get(m, "score") || Map.get(m, :score)
      if is_binary(structure), do: [%{index: index, structure: structure, score: score}], else: []
    end)
  end

  @doc """
  CSV of a run's candidates (stable headers, RFC 4180). `score` is the value
  the generation service reported for `score_property` — a model output.
  """
  def run_to_csv(%Molecule{} = run) do
    rows =
      for c <- candidates(run) do
        [
          c.index + 1,
          c.structure,
          if(is_number(c.score), do: {:raw, to_string(c.score)}),
          run.property_name,
          run.smiles
        ]
      end

    [~w(candidate smiles score score_property parent_smiles) | rows]
    |> Enum.map_join("\r\n", &PhxMolbind.Collections.csv_row/1)
    |> Kernel.<>("\r\n")
  end

  @doc "Persists a generated-molecule run for `user_id`."
  def create_history(attrs, user_id) do
    # Lineage is never trusted from the caller: it is re-verified here, so a
    # forged or stale parent reference is dropped rather than recorded.
    {parent_id, parent_index} =
      case verified_parent(user_id, Map.get(attrs, :parent_run_id), Map.get(attrs, :smiles)) do
        {:ok, %{run_id: id, index: index}} -> {id, index}
        :none -> {nil, nil}
      end

    attrs =
      attrs
      |> Map.put(:user_id, user_id)
      |> Map.put(:parent_run_id, parent_id)
      |> Map.put(:parent_candidate_index, parent_index)

    %Molecule{} |> Molecule.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Verifies that `smiles` is exactly one of the candidates of run `from_run_id`
  and that the run belongs to `user_id`. Returns `{:ok, %{run_id, index}}` or
  `:none`. This is the only way a parent link is ever recorded: ancestry is
  not inferred from similar-looking SMILES afterwards.
  """
  def verified_parent(user_id, from_run_id, smiles) when is_binary(smiles) do
    with id when is_integer(id) <- to_int(from_run_id),
         %Molecule{} = parent <- get_history_entry(user_id, id),
         %{index: index} <- Enum.find(candidates(parent), &(&1.structure == smiles)) do
      {:ok, %{run_id: parent.id, index: index}}
    else
      _ -> :none
    end
  end

  def verified_parent(_user_id, _from_run_id, _smiles), do: :none

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_int(_), do: nil

  @doc """
  Calls the NVIDIA MolMIM API to generate candidate molecules for `payload`.
  Returns `{:ok, [%{structure: smiles, score: score}, ...]}`.
  """
  @spec generate_molecules(map()) :: {:ok, list()} | {:error, term()}
  def generate_molecules(payload) do
    # Generation can take far longer than Finch's 15s default.
    do_generate(payload, receive_timeout: @receive_timeout)
  end

  defp do_generate(payload, request_opts) do
    with {:ok, api_key} <- fetch_api_key() do
      headers = [
        {"Authorization", "Bearer " <> api_key},
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ]

      :post
      |> Finch.build(@molmim_url, headers, Jason.encode!(payload))
      |> Finch.request(PhxMolbind.Finch, request_opts)
      |> handle_response()
    end
  end

  defp handle_response({:ok, %Finch.Response{status: 200, body: body}}) do
    with {:ok, %{"molecules" => molecules_str}} <- Jason.decode(body),
         {:ok, molecules_list} <- Jason.decode(molecules_str) do
      {:ok,
       Enum.map(molecules_list, fn %{"sample" => smi, "score" => score} ->
         %{structure: smi, score: score}
       end)}
    else
      error -> {:error, error}
    end
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}) do
    {:error, {:unexpected_status, status, body}}
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp fetch_api_key do
    case Application.get_env(:phx_molbind, :nvidia_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_nvidia_api_key}
    end
  end
end
