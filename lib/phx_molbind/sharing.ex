defmodule PhxMolbind.Sharing do
  @moduledoc """
  Read-only share links for runs and collections.

  Security model
  --------------
    * A link is a 256-bit random secret in the URL. Only its SHA-256 hash is
      stored, so a database leak cannot be turned into working links, and the
      secret is shown to its creator exactly once.
    * Creating, listing and revoking are scoped to the owning user. Links to
      someone else's run or collection cannot be created; guessing ids gets
      `{:error, :not_found}`.
    * `resolve/1` answers `{:error, :not_found}` for unknown, malformed,
      revoked, expired and orphaned links alike, so a visitor cannot tell
      which case it was.
    * The public payload is built from an explicit whitelist. It never
      contains the owner's address or name, user ids, other runs, review
      statuses, or source-run references.
  """
  import Ecto.Query, only: [from: 2]

  alias PhxMolbind.{Collections, Repo}
  alias PhxMolbind.Molecules.Molecules
  alias PhxMolbind.Sharing.ShareLink

  @token_bytes 32
  @expiry_choices %{"never" => nil, "1" => 1, "7" => 7, "30" => 30}

  @doc "Expiry options offered in the UI: `[{label, value}]`."
  def expiry_options, do: [{"7 days", "7"}, {"30 days", "30"}, {"1 day", "1"}, {"Never", "never"}]

  @doc """
  Creates a link to one of the user's own targets. Returns
  `{:ok, link, token}` — the only time the token is available.
  """
  def create_link(user_id, kind, target_id, expiry \\ "7")

  def create_link(user_id, kind, target_id, expiry) when kind in ["run", "collection"] do
    with true <- Map.has_key?(@expiry_choices, expiry) || {:error, :invalid_expiry},
         true <- owns_target?(user_id, kind, target_id) || {:error, :not_found} do
      token = :crypto.strong_rand_bytes(@token_bytes) |> Base.url_encode64(padding: false)

      expires_at =
        case Map.fetch!(@expiry_choices, expiry) do
          nil -> nil
          days -> DateTime.add(DateTime.utc_now(), days * 86_400, :second)
        end

      link =
        Repo.insert!(%ShareLink{
          user_id: user_id,
          kind: kind,
          target_id: target_id,
          token_hash: hash(token),
          expires_at: expires_at
        })

      {:ok, link, token}
    end
  end

  def create_link(_user_id, _kind, _target_id, _expiry), do: {:error, :not_found}

  @doc "The user's links for one target, newest first (active and inactive)."
  def list_links(user_id, kind, target_id) do
    Repo.all(
      from l in ShareLink,
        where: l.user_id == ^user_id and l.kind == ^kind and l.target_id == ^target_id,
        order_by: [desc: l.inserted_at, desc: l.id]
    )
  end

  @doc "Revokes one of the user's links. Idempotent for already-revoked links."
  def revoke_link(user_id, link_id) do
    case Repo.get_by(ShareLink, id: link_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      %ShareLink{revoked_at: nil} = link ->
        link |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update()

      link ->
        {:ok, link}
    end
  end

  @doc "Number of active links for a target (used for the visibility indicator)."
  def active_count(user_id, kind, target_id) do
    user_id |> list_links(kind, target_id) |> Enum.count(&ShareLink.active?/1)
  end

  @doc """
  Looks a token up and returns the public, whitelisted payload.

  `{:ok, %{kind: "run" | "collection", title: ..., ...}}` or
  `{:error, :not_found}`.
  """
  def resolve(token) when is_binary(token) and byte_size(token) in 20..100 do
    with %ShareLink{} = link <- Repo.get_by(ShareLink, token_hash: hash(token)),
         true <- ShareLink.active?(link),
         {:ok, payload} <- public_payload(link) do
      {:ok, payload}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve(_), do: {:error, :not_found}

  ## Internals

  defp hash(token), do: :crypto.hash(:sha256, token) |> Base.url_encode64(padding: false)

  defp owns_target?(user_id, "run", id), do: not is_nil(Molecules.get_history_entry(user_id, id))

  defp owns_target?(user_id, "collection", id),
    do: not is_nil(Collections.get_collection(user_id, id))

  defp public_payload(%ShareLink{kind: "run", target_id: id, user_id: owner}) do
    case Molecules.get_history_entry(owner, id) do
      nil ->
        :error

      run ->
        {:ok,
         %{
           kind: "run",
           title: "Generation run",
           starting_smiles: run.smiles,
           parameters: [
             {"Algorithm", run.algorithm},
             {"Property", run.property_name},
             {"Objective", if(run.minimize, do: "Minimise", else: "Maximise")},
             {"Molecules requested", run.num_molecules},
             {"Minimum similarity", run.min_similarity},
             {"Particles", run.particles},
             {"Iterations", run.iterations}
           ],
           property_name: run.property_name,
           candidates:
             for(c <- Molecules.candidates(run), do: %{structure: c.structure, score: c.score}),
           created_on: Date.to_iso8601(NaiveDateTime.to_date(run.inserted_at))
         }}
    end
  end

  defp public_payload(%ShareLink{kind: "collection", target_id: id, user_id: owner}) do
    case Collections.get_collection(owner, id) do
      nil ->
        :error

      collection ->
        {:ok,
         %{
           kind: "collection",
           title: collection.name,
           items:
             for i <- Collections.list_items(owner, collection.id) do
               %{smiles: i.smiles, score: i.score, property_name: i.property_name}
             end
         }}
    end
  end
end
