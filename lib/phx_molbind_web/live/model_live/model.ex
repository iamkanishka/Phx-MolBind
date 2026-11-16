defmodule PhxMolbindWeb.ModelLive.Model do
  @moduledoc """
  Molecule generation workspace (`/model`).

  Lifecycle: `:idle -> :running -> :completed | :failed | :cancelled`.
  The request to the generation service runs in `start_async/3` so the
  LiveView stays responsive (elapsed timer, cancel button). Cancelling stops
  *waiting* for the result; the request already sent to the NVIDIA service may
  still complete on their side, and the UI says so.

  Scores shown on candidates are the values reported by the MolMIM service for
  the selected optimisation property. They are model outputs, not experimental
  measurements, and the UI labels them accordingly.
  """
  use PhxMolbindWeb, :live_view
  alias PhxMolbind.Molecules.Molecules

  @defaults %{
    "smiles" => "",
    "num_molecules" => "10",
    "min_similarity" => "0.7",
    "particles" => "30",
    "iterations" => "10",
    "property_name" => "QED",
    "algorithm" => "CMA-ES",
    "minimize" => "false"
  }

  # Preliminary character check only. This is NOT chemical validation: the
  # generation service is the authority and answers 422 for unparsable input.
  @smiles_chars ~r/\A[A-Za-z0-9@+\-\[\]\(\)=#$:\/\\%.*]+\z/
  @max_smiles_length 500

  @impl true
  def mount(params, _session, socket) do
    # Handoff from other pages (e.g. the sketcher) arrives as ?smiles=...
    # It only pre-fills the field; it is validated like typed input on submit.
    initial = prefill(params)

    {:ok,
     socket
     |> assign(:page_title, "Generate")
     |> assign(:status, :idle)
     |> assign(:started_at, nil)
     |> assign(:elapsed, 0)
     |> assign(:error, nil)
     |> assign(:notice, nil)
     |> assign(:history, Molecules.recent_history_for_user(socket.assigns.current_user.id))
     |> assign(:candidates, [])
     |> assign(:source, nil)
     |> assign(:sort, :score_desc)
     |> assign(:selected, MapSet.new())
     |> assign(:params, initial)
     |> assign(:from_run_id, params["from_run"])
     |> assign_lineage(initial["smiles"])
     |> assign_form(initial, %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <section class="xl:col-span-2" aria-labelledby="generator-heading">
        <div class="rounded-lg border border-stroke bg-white shadow-default dark:border-strokedark dark:bg-[#181818]">
          <div class="border-b border-stroke px-6 py-4 dark:border-strokedark">
            <h2 id="generator-heading" class="font-medium text-black dark:text-white">
              SMILES to Molecule Generator
            </h2>
          </div>

          <.simple_form for={@form} id="molecule-form" phx-change="validate" phx-submit="submit">
            <div class="flex flex-col gap-5 p-2 sm:p-4">
              <div>
                <.input
                  type="text"
                  field={@form[:smiles]}
                  label="Starting molecule (SMILES)"
                  placeholder="e.g. CN1C=NC2=C1C(=O)N(C(=O)N2C)C"
                  autocomplete="off"
                  spellcheck="false"
                  phx-debounce="400"
                />
                <p class="mt-1 text-xs text-body dark:text-bodydark">
                  Quick checks happen here; the generation service performs the authoritative SMILES validation.
                </p>
                <p
                  :if={@lineage_parent}
                  id="lineage-note"
                  class="mt-1 text-xs text-black dark:text-white"
                >
                  Lineage: this run will be recorded as derived from candidate {@lineage_parent.index +
                    1} of
                  <.link
                    navigate={~p"/history/#{@lineage_parent.run_id}"}
                    class="text-accent underline dark:text-accent-light"
                  >
                    run {@lineage_parent.run_id}
                  </.link>
                  . Change the SMILES and the link is dropped.
                </p>
                <div :if={@form[:smiles].value not in [nil, ""]} class="mt-3">
                  <canvas
                    id="input-preview"
                    phx-hook="renderSMILESmol"
                    data-smiles={@form[:smiles].value}
                    width="240"
                    height="180"
                    data-width="240"
                    data-height="180"
                    role="img"
                    aria-label={"Structure preview of " <> to_string(@form[:smiles].value)}
                    class="rounded border border-stroke bg-white dark:border-strokedark"
                  >
                  </canvas>
                </div>
              </div>

              <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <.input
                  type="select"
                  field={@form[:algorithm]}
                  label="Algorithm"
                  options={[
                    {"CMA-ES (guided optimisation)", "CMA-ES"},
                    {"none (random sampling)", "none"}
                  ]}
                />
                <.input
                  type="select"
                  field={@form[:property_name]}
                  label="Property to optimise"
                  options={[{"QED", "QED"}, {"plogP", "plogP"}]}
                />
              </div>

              <div class="grid grid-cols-1 gap-5 sm:grid-cols-3">
                <.input
                  type="number"
                  field={@form[:num_molecules]}
                  label="Number of molecules (1–100)"
                  min="1"
                  max="100"
                  step="1"
                  phx-debounce="300"
                />
                <.input
                  type="number"
                  field={@form[:particles]}
                  label="Particles (2–1000)"
                  min="2"
                  max="1000"
                  step="1"
                  phx-debounce="300"
                />
                <.input
                  type="number"
                  field={@form[:iterations]}
                  label="Iterations (1–1000)"
                  min="1"
                  max="1000"
                  step="1"
                  phx-debounce="300"
                />
              </div>

              <div>
                <.input
                  type="range"
                  field={@form[:min_similarity]}
                  label={"Minimum similarity: " <> to_string(@form[:min_similarity].value)}
                  min="0"
                  max="1"
                  step="0.05"
                  aria-describedby="similarity-help"
                />
                <p id="similarity-help" class="mt-1 text-xs text-body dark:text-bodydark">
                  Minimum similarity of each candidate to the starting molecule. NVIDIA's local-NIM docs cap this at 0.7; if the service rejects a higher value you will see its error.
                </p>
              </div>

              <.input
                type="checkbox"
                field={@form[:minimize]}
                label="Minimise the property instead of maximising"
              />

              <p
                class="rounded-md bg-gray-2 p-3 text-sm text-black dark:bg-white/5 dark:text-white"
                aria-live="polite"
              >
                Summary: {@params["algorithm"]} on {@params["property_name"]}, {if @params["minimize"] ==
                                                                                     "true",
                                                                                   do: "minimising",
                                                                                   else: "maximising"}; up to {@params[
                  "num_molecules"
                ]} molecules, similarity ≥ {@params["min_similarity"]}, {@params["particles"]} particles × {@params[
                  "iterations"
                ]} iterations.
              </p>

              <div class="flex flex-wrap items-center gap-3">
                <button
                  type="submit"
                  disabled={@status == :running}
                  class="flex min-w-40 justify-center rounded-lg bg-accent px-5 py-3 font-medium text-white hover:bg-accent-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {if @status == :running, do: "Generating…", else: "Generate molecules"}
                </button>
                <button
                  :if={@status == :running}
                  type="button"
                  phx-click="cancel"
                  class="rounded-lg border border-stroke px-5 py-3 font-medium text-black hover:bg-gray-2 dark:border-strokedark dark:text-white dark:hover:bg-white/5"
                >
                  Stop waiting
                </button>
                <button
                  type="button"
                  phx-click="reset"
                  disabled={@status == :running}
                  class="rounded-lg px-3 py-3 text-sm text-body underline hover:text-black disabled:opacity-50 dark:text-bodydark dark:hover:text-white"
                >
                  Reset to defaults
                </button>
              </div>

              <div role="status" aria-live="polite" class="min-h-6 text-sm">
                <p :if={@status == :running} class="text-black dark:text-white">
                  <.icon
                    name="hero-arrow-path"
                    class="mr-1 size-4 animate-spin motion-reduce:animate-none"
                  />
                  Waiting for the generation service… {@elapsed}s elapsed. The service does not report progress, so none is shown.
                </p>
                <p :if={@notice} class="text-black dark:text-white">{@notice}</p>
                <p :if={@error} class="font-medium text-red-600 dark:text-red-400" role="alert">
                  {@error}
                </p>
              </div>
            </div>
          </.simple_form>
        </div>
      </section>

      <aside aria-labelledby="history-heading">
        <div class="rounded-lg border border-stroke bg-white p-4 shadow-default dark:border-strokedark dark:bg-[#181818]">
          <h2 id="history-heading" class="font-medium text-black dark:text-white">
            Recent runs
          </h2>

          <p :if={@history == []} class="mt-4 text-sm text-body dark:text-bodydark">
            No runs yet. Enter a SMILES string and generate candidates; your runs will appear here.
          </p>

          <ul class="mt-4 max-h-96 divide-y divide-stroke overflow-y-auto dark:divide-strokedark">
            <li :for={entry <- @history} class="py-3">
              <p class="break-all font-mono text-xs text-black dark:text-white">{entry.smiles}</p>
              <p class="mt-1 text-xs text-body dark:text-bodydark">
                {entry.num_molecules} requested · {entry.property_name} · {Calendar.strftime(
                  entry.inserted_at,
                  "%Y-%m-%d %H:%M"
                )}
              </p>
              <button
                type="button"
                class="mt-2 text-sm text-accent dark:text-accent-light hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
                phx-click="view_molecules"
                phx-value-id={entry.id}
              >
                View molecules
              </button>
            </li>
          </ul>
        </div>
      </aside>
    </div>

    <section :if={@candidates != []} class="mt-8" aria-labelledby="results-heading">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id="results-heading" class="font-medium text-black dark:text-white">
          Candidates ({length(@candidates)})
        </h2>
        <div class="flex items-center gap-3 text-sm">
          <label for="sort-select" class="text-body dark:text-bodydark">Sort</label>
          <select
            id="sort-select"
            phx-change="sort"
            name="sort"
            class="rounded-md border border-stroke bg-white px-2 py-1 dark:border-strokedark dark:bg-boxdark"
          >
            <option value="score_desc" selected={@sort == :score_desc}>Score, high to low</option>
            <option value="score_asc" selected={@sort == :score_asc}>Score, low to high</option>
            <option value="original" selected={@sort == :original}>Service order</option>
          </select>
          <button
            :if={MapSet.size(@selected) > 0}
            type="button"
            phx-click="clear_selection"
            class="text-accent dark:text-accent-light hover:underline"
          >
            Clear selection ({MapSet.size(@selected)})
          </button>
        </div>
      </div>

      <p :if={@source} class="mt-2 text-xs text-body dark:text-bodydark">
        Scores are the {@source.property} values reported by the MolMIM service (a model output, not an experimental measurement).
        Parent molecule: <span class="break-all font-mono">{@source.smiles}</span>
      </p>

      <ul class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <li
          :for={c <- sorted(@candidates, @sort)}
          id={"candidate-#{c.index}"}
          class="rounded-lg border border-stroke bg-white p-3 dark:border-strokedark dark:bg-[#181818]"
        >
          <div class="flex items-center justify-between text-sm">
            <span class="font-medium text-black dark:text-white">Candidate {c.index + 1}</span>
            <label class="flex items-center gap-2 text-body dark:text-bodydark">
              <input
                type="checkbox"
                phx-click="toggle_select"
                phx-value-index={c.index}
                checked={MapSet.member?(@selected, c.index)}
              /> Compare
            </label>
          </div>
          <.structure_viewer
            id={"cand-viewer-#{c.index}"}
            canvas_id={"smiles-canvas-model-#{c.index}"}
            smiles={c.structure}
            size={260}
            export={false}
            label={"candidate #{c.index + 1}: #{c.structure}"}
          />
          <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{c.structure}</p>
          <p class="mt-1 text-sm text-black dark:text-white">
            Score: <span class="font-mono">{format_score(c.score)}</span>
          </p>
          <div class="mt-3 flex flex-wrap gap-2 text-sm">
            <button
              id={"copy-#{c.index}"}
              type="button"
              phx-hook="CopyButton"
              data-copy={c.structure}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Copy SMILES
            </button>
            <button
              id={"png-#{c.index}"}
              type="button"
              phx-hook="DownloadCanvas"
              data-canvas-id={"smiles-canvas-model-#{c.index}"}
              data-filename={"molbind-candidate-#{c.index + 1}.png"}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Download PNG
            </button>
          </div>
        </li>
      </ul>
    </section>

    <section :if={MapSet.size(@selected) >= 2} class="mt-8" aria-labelledby="compare-heading">
      <h2 id="compare-heading" class="font-medium text-black dark:text-white">Comparison</h2>
      <div class="mt-3 overflow-x-auto rounded-lg border border-stroke dark:border-strokedark">
        <table class="w-full min-w-[32rem] text-left text-sm">
          <thead class="bg-gray-2 dark:bg-white/5">
            <tr>
              <th scope="col" class="p-3">Candidate</th>
              <th scope="col" class="p-3">Structure</th>
              <th scope="col" class="p-3">SMILES</th>
              <th scope="col" class="p-3">Score</th>
              <th scope="col" class="p-3">Δ vs best selected</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={c <- compared(@candidates, @selected)}
              class="border-t border-stroke dark:border-strokedark"
            >
              <th scope="row" class="p-3">No. {c.index + 1}</th>
              <td class="p-3">
                <canvas
                  id={"cmp-canvas-#{c.index}"}
                  phx-hook="renderSMILESmol"
                  data-smiles={c.structure}
                  width="180"
                  height="140"
                  data-width="180"
                  data-height="140"
                  role="img"
                  aria-label={"Structure of candidate #{c.index + 1}"}
                  class="rounded border border-stroke bg-white dark:border-strokedark"
                >
                </canvas>
              </td>
              <td class="break-all p-3 font-mono text-xs">{c.structure}</td>
              <td class="p-3 font-mono">{format_score(c.score)}</td>
              <td class="p-3 font-mono">{score_delta(c, compared(@candidates, @selected))}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p :if={@source} class="mt-2 text-xs text-body dark:text-bodydark">
        Generated from <span class="break-all font-mono">{@source.smiles}</span>
        with {@source.algorithm}, {@source.property}.
      </p>
    </section>
    """
  end

  # Prefill from query params (sketcher, research, history "re-run").
  # Only known keys are taken, values are length-limited strings, and
  # everything is validated exactly like typed input on submit.
  @prefill_keys ~w(smiles num_molecules min_similarity particles iterations property_name algorithm minimize)

  defp prefill(params) when is_map(params) do
    Enum.reduce(@prefill_keys, @defaults, fn key, acc ->
      case Map.get(params, key) do
        value when is_binary(value) and byte_size(value) <= @max_smiles_length ->
          Map.put(acc, key, String.trim(value))

        _ ->
          acc
      end
    end)
  end

  defp prefill(_), do: @defaults

  ## Events

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params = Map.merge(@defaults, params)

    errors =
      case parse_form(params) do
        {:ok, _parsed} -> %{}
        {:error, errors} -> errors
      end

    # While typing, only complain about fields the user has actually filled in.
    errors = Map.reject(errors, fn {field, _} -> Map.get(params, field) in [nil, ""] end)

    {:noreply,
     socket
     |> assign(:params, params)
     |> assign_lineage(params["smiles"])
     |> assign_form(params, errors)}
  end

  def handle_event("submit", _params, %{assigns: %{status: :running}} = socket),
    do: {:noreply, socket}

  def handle_event("submit", %{"form" => params}, socket) do
    params = Map.merge(@defaults, params)

    case parse_form(params) do
      {:ok, parsed} ->
        payload = %{
          "algorithm" => parsed.algorithm,
          "num_molecules" => parsed.num_molecules,
          "property_name" => parsed.property_name,
          "minimize" => parsed.minimize,
          "min_similarity" => parsed.min_similarity,
          "particles" => parsed.particles,
          "iterations" => parsed.iterations,
          "smi" => parsed.smiles
        }

        Process.send_after(self(), :tick, 1_000)

        {:noreply,
         socket
         |> assign(:params, params)
         |> assign_form(params, %{})
         |> assign(:status, :running)
         |> assign(:started_at, System.monotonic_time(:second))
         |> assign(:elapsed, 0)
         |> assign(:error, nil)
         |> assign(:notice, nil)
         |> assign(:pending, parsed)
         |> start_async(:generate, fn -> Molecules.generate_molecules(payload) end)}

      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:params, params)
         |> assign_form(params, errors)
         |> assign(:error, "Please fix the highlighted fields.")}
    end
  end

  def handle_event("cancel", _params, %{assigns: %{status: :running}} = socket) do
    {:noreply,
     socket
     |> cancel_async(:generate)
     |> assign(:status, :cancelled)
     |> assign(
       :notice,
       "Stopped waiting. The request was already sent, so the NVIDIA service may still finish it and count it against your quota; its result is discarded."
     )}
  end

  def handle_event("cancel", _params, socket), do: {:noreply, socket}

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:params, @defaults)
     |> assign(:error, nil)
     |> assign_form(@defaults, %{})}
  end

  def handle_event("sort", %{"sort" => sort}, socket)
      when sort in ~w(score_desc score_asc original),
      do: {:noreply, assign(socket, :sort, String.to_existing_atom(sort))}

  def handle_event("toggle_select", %{"index" => index}, socket) do
    with {i, ""} <- Integer.parse(index),
         true <- Enum.any?(socket.assigns.candidates, &(&1.index == i)) do
      selected =
        if MapSet.member?(socket.assigns.selected, i),
          do: MapSet.delete(socket.assigns.selected, i),
          else: MapSet.put(socket.assigns.selected, i)

      {:noreply, assign(socket, :selected, selected)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("clear_selection", _params, socket),
    do: {:noreply, assign(socket, :selected, MapSet.new())}

  def handle_event("view_molecules", %{"id" => id}, socket) do
    with {int_id, ""} <- Integer.parse(id),
         %{} = entry <- Molecules.get_history_entry(socket.assigns.current_user.id, int_id) do
      {:noreply,
       socket
       |> assign(:candidates, entry_candidates(entry))
       |> assign(:selected, MapSet.new())
       |> assign(:notice, nil)
       |> assign(:source, %{
         smiles: entry.smiles,
         property: entry.property_name,
         algorithm: entry.algorithm
       })}
    else
      _ -> {:noreply, put_flash(socket, :error, "That run could not be found.")}
    end
  end

  ## Async + timer

  @impl true
  def handle_async(:generate, {:ok, {:ok, molecules}}, socket) do
    parsed = socket.assigns.pending
    user_id = socket.assigns.current_user.id

    attrs = %{
      algorithm: parsed.algorithm,
      num_molecules: parsed.num_molecules,
      property_name: parsed.property_name,
      minimize: parsed.minimize,
      min_similarity: parsed.min_similarity,
      particles: parsed.particles,
      iterations: parsed.iterations,
      smiles: parsed.smiles,
      parent_run_id: socket.assigns.from_run_id,
      generated_molecules: %{"molecules" => molecules}
    }

    {socket, notice} =
      case Molecules.create_history(attrs, user_id) do
        {:ok, _entry} ->
          {socket, nil}

        {:error, _changeset} ->
          {socket, "Candidates were generated but the run could not be saved to your history."}
      end

    {:noreply,
     socket
     |> assign(:status, :completed)
     |> assign(:error, nil)
     |> assign(
       :notice,
       notice || if(molecules == [], do: "The service returned no candidates for this input.")
     )
     |> assign(:candidates, Enum.with_index(molecules, &to_candidate/2))
     |> assign(:selected, MapSet.new())
     |> assign(:source, %{
       smiles: parsed.smiles,
       property: parsed.property_name,
       algorithm: parsed.algorithm
     })
     |> assign(:history, Molecules.recent_history_for_user(user_id))}
  end

  def handle_async(:generate, {:ok, {:error, reason}}, socket) do
    {_kind, message} = Molecules.describe_error(reason)
    {:noreply, socket |> assign(:status, :failed) |> assign(:error, message)}
  end

  # Raised by cancel_async/2; the "cancel" handler already updated the UI.
  def handle_async(:generate, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:generate, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:status, :failed)
     |> assign(:error, "Molecule generation failed unexpectedly. Please retry.")}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{status: :running, started_at: started}} = socket) do
    Process.send_after(self(), :tick, 1_000)
    {:noreply, assign(socket, :elapsed, System.monotonic_time(:second) - started)}
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  ## Helpers

  # Lineage is only shown (and later recorded) while the typed SMILES is
  # exactly a candidate of a run the user owns; editing the structure drops it.
  defp assign_lineage(socket, smiles) do
    parent =
      case PhxMolbind.Molecules.Molecules.verified_parent(
             socket.assigns.current_user.id,
             socket.assigns.from_run_id,
             smiles |> to_string() |> String.trim()
           ) do
        {:ok, parent} -> parent
        :none -> nil
      end

    assign(socket, :lineage_parent, parent)
  end

  defp assign_form(socket, params, errors) do
    form_errors = for {field, msg} <- errors, do: {String.to_atom(field), {msg, []}}
    assign(socket, :form, to_form(params, as: :form, errors: form_errors))
  end

  # Returns {:ok, parsed} or {:error, %{"field" => message}}. Raw params are
  # user-controlled strings, so they are parsed explicitly (never to_integer!).
  defp parse_form(params) do
    limits = Molecules.limits()

    checks = [
      {"smiles", check_smiles(params["smiles"])},
      {"num_molecules",
       check_int(params["num_molecules"], limits.num_molecules, "Number of molecules")},
      {"particles", check_int(params["particles"], limits.particles, "Particles")},
      {"iterations", check_int(params["iterations"], limits.iterations, "Iterations")},
      {"min_similarity",
       check_float(params["min_similarity"], limits.min_similarity, "Minimum similarity")},
      {"algorithm", check_member(params["algorithm"], limits.algorithms, "Algorithm")},
      {"property_name", check_member(params["property_name"], limits.properties, "Property")}
    ]

    errors = for {field, {:error, msg}} <- checks, into: %{}, do: {field, msg}

    if errors == %{} do
      values = Map.new(checks, fn {field, {:ok, value}} -> {field, value} end)

      {:ok,
       %{
         smiles: values["smiles"],
         num_molecules: values["num_molecules"],
         particles: values["particles"],
         iterations: values["iterations"],
         min_similarity: values["min_similarity"],
         algorithm: values["algorithm"],
         property_name: values["property_name"],
         minimize: params["minimize"] in ["true", "on"]
       }}
    else
      {:error, errors}
    end
  end

  defp check_smiles(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" ->
        {:error, "Enter a SMILES string."}

      byte_size(value) > @max_smiles_length ->
        {:error, "SMILES is longer than #{@max_smiles_length} characters."}

      not Regex.match?(@smiles_chars, value) ->
        {:error, "Contains characters that cannot appear in a SMILES string."}

      true ->
        {:ok, value}
    end
  end

  defp check_smiles(_), do: {:error, "Enter a SMILES string."}

  defp check_int(value, range, label) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} ->
        if int >= range.first and int <= range.last,
          do: {:ok, int},
          else: {:error, "#{label} must be between #{range.first} and #{range.last}."}

      _ ->
        {:error, "#{label} must be a whole number."}
    end
  end

  defp check_int(_, _range, label), do: {:error, "#{label} is required."}

  defp check_float(value, {min, max}, label) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {float, ""} when float >= min and float <= max -> {:ok, float}
      {_float, ""} -> {:error, "#{label} must be between #{min} and #{max}."}
      _ -> {:error, "#{label} must be a number."}
    end
  end

  defp check_float(_, _limits, label), do: {:error, "#{label} is required."}

  defp check_member(value, allowed, label) do
    if value in allowed,
      do: {:ok, value},
      else: {:error, "#{label} must be one of: #{Enum.join(allowed, ", ")}."}
  end

  defp to_candidate(molecule, index) do
    %{
      index: index,
      structure: fetch_field(molecule, :structure),
      score: fetch_field(molecule, :score)
    }
  end

  # History rows come back from the database with string keys; fresh results
  # have atom keys.
  defp fetch_field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp entry_candidates(entry) do
    entry.generated_molecules
    |> Map.get("molecules", [])
    |> Enum.with_index(&to_candidate/2)
    |> Enum.filter(&is_binary(&1.structure))
  end

  defp sorted(candidates, :original), do: candidates

  defp sorted(candidates, :score_desc),
    do: Enum.sort_by(candidates, &(&1.score || -1.0e18), :desc)

  defp sorted(candidates, :score_asc),
    do: Enum.sort_by(candidates, &(&1.score || 1.0e18), :asc)

  defp compared(candidates, selected),
    do: Enum.filter(candidates, &MapSet.member?(selected, &1.index))

  defp format_score(score) when is_number(score),
    do: :erlang.float_to_binary(score * 1.0, decimals: 4)

  defp format_score(_), do: "not reported"

  defp score_delta(%{score: score}, compared) when is_number(score) do
    best =
      compared |> Enum.map(& &1.score) |> Enum.filter(&is_number/1) |> Enum.max(fn -> nil end)

    if best, do: :erlang.float_to_binary((score - best) * 1.0, decimals: 4), else: "n/a"
  end

  defp score_delta(_candidate, _compared), do: "n/a"
end
