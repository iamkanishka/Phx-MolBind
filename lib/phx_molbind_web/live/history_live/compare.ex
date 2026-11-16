defmodule PhxMolbindWeb.HistoryLive.Compare do
  @moduledoc """
  Side-by-side comparison of two of the user's saved runs
  (`/history/compare?a=ID&b=ID`). Everything shown is derived from the stored
  records by `PhxMolbind.Molecules.Comparison`; nothing is re-run.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Molecules.{Comparison, Molecules}

  @impl true
  def mount(params, _session, socket) do
    user_id = socket.assigns.current_user.id

    with {a_id, ""} <- Integer.parse(to_string(params["a"])),
         {b_id, ""} <- Integer.parse(to_string(params["b"])),
         true <- a_id != b_id,
         %{} = a <- Molecules.get_history_entry(user_id, a_id),
         %{} = b <- Molecules.get_history_entry(user_id, b_id) do
      {:ok,
       socket
       |> assign(:page_title, "Compare runs")
       |> assign(:a, a)
       |> assign(:b, b)
       |> assign(:result, Comparison.compare(a, b))}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Pick two different runs from your history to compare.")
         |> push_navigate(to: ~p"/history")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <.link
        navigate={~p"/history"}
        class="text-sm text-accent dark:text-accent-light hover:underline"
      >
        ← All runs
      </.link>

      <h2 class="mt-3 font-medium text-black dark:text-white">
        Run {@a.id} vs run {@b.id}
      </h2>

      <section class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2" aria-label="Starting molecules">
        <div
          :for={{label, run} <- [{"Run #{@a.id}", @a}, {"Run #{@b.id}", @b}]}
          class="rounded-lg border border-stroke bg-white p-4 dark:border-strokedark dark:bg-[#181818]"
        >
          <p class="text-sm font-medium text-black dark:text-white">{label}</p>
          <canvas
            id={"cmp-start-#{run.id}"}
            phx-hook="renderSMILESmol"
            data-smiles={run.smiles}
            width="240"
            height="180"
            data-width="240"
            data-height="180"
            role="img"
            aria-label={"Starting molecule of #{label}: #{run.smiles}"}
            class="mx-auto mt-2 max-w-full rounded border border-stroke bg-white dark:border-strokedark"
          >
          </canvas>
          <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{run.smiles}</p>
          <p class="mt-1 text-xs text-body dark:text-bodydark">
            Saved {Calendar.strftime(run.inserted_at, "%Y-%m-%d %H:%M")} UTC ·
            <.link
              navigate={~p"/history/#{run.id}"}
              class="text-accent dark:text-accent-light underline"
            >
              open run
            </.link>
          </p>
        </div>
      </section>

      <p class="mt-3 text-sm text-black dark:text-white">
        {if @result.starting_molecule.differs?,
          do: "The two runs started from different molecules.",
          else: "Both runs started from the same SMILES string."}
      </p>

      <section class="mt-6" aria-labelledby="params-heading">
        <h3 id="params-heading" class="font-medium text-black dark:text-white">Parameters</h3>
        <div class="mt-2 overflow-x-auto rounded-lg border border-stroke dark:border-strokedark">
          <table class="w-full min-w-[28rem] text-left text-sm">
            <caption class="sr-only">Parameters of each run; changed values are marked.</caption>
            <thead class="bg-gray-2 dark:bg-white/5">
              <tr>
                <th scope="col" class="p-3">Parameter</th>
                <th scope="col" class="p-3">Run {@a.id}</th>
                <th scope="col" class="p-3">Run {@b.id}</th>
                <th scope="col" class="p-3">Difference</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @result.parameters}
                class={[
                  "border-t border-stroke dark:border-strokedark",
                  row.differs? && "bg-primary/5"
                ]}
              >
                <th scope="row" class="p-3 font-medium">{row.label}</th>
                <td class="p-3">{row.a}</td>
                <td class="p-3">{row.b}</td>
                <td class="p-3">{if row.differs?, do: "Changed", else: "Same"}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="mt-6" aria-labelledby="results-heading">
        <h3 id="results-heading" class="font-medium text-black dark:text-white">Results</h3>
        <p
          :if={!@result.scores_comparable?}
          class="mt-2 rounded-md bg-gray-2 p-3 text-sm text-black dark:bg-white/5 dark:text-white"
          role="note"
        >
          These runs optimised different properties or in different directions, so their scores are not directly comparable. Each run's own best and mean are shown for reference only.
        </p>
        <div class="mt-2 overflow-x-auto rounded-lg border border-stroke dark:border-strokedark">
          <table class="w-full min-w-[28rem] text-left text-sm">
            <caption class="sr-only">Candidate counts and score statistics for each run.</caption>
            <thead class="bg-gray-2 dark:bg-white/5">
              <tr>
                <th scope="col" class="p-3">Measure</th>
                <th scope="col" class="p-3">Run {@a.id}</th>
                <th scope="col" class="p-3">Run {@b.id}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={
                  {label, key} <- [
                    {"Candidates returned", :returned},
                    {"Candidates with a score", :scored},
                    {"Best score", :best},
                    {"Mean score", :mean}
                  ]
                }
                class="border-t border-stroke dark:border-strokedark"
              >
                <th scope="row" class="p-3 font-medium">{label}</th>
                <td class="p-3 font-mono">{fmt(@result.stats.a[key])}</td>
                <td class="p-3 font-mono">{fmt(@result.stats.b[key])}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="mt-2 text-xs text-body dark:text-bodydark">
          Scores are values reported by the MolMIM service for each run's property (model output, not experimental measurements). "Best" follows each run's own objective: {objective(
            @a
          )} for run {@a.id}, {objective(@b)} for run {@b.id}.
        </p>
      </section>

      <section class="mt-6" aria-labelledby="shared-heading">
        <h3 id="shared-heading" class="font-medium text-black dark:text-white">
          Candidates found by both runs ({length(@result.shared_candidates)})
        </h3>
        <p :if={@result.shared_candidates == []} class="mt-2 text-sm text-body dark:text-bodydark">
          No candidate SMILES strings appear in both runs.
        </p>
        <ul class="mt-2 space-y-1 font-mono text-xs text-black dark:text-white">
          <li :for={smiles <- @result.shared_candidates} class="break-all">{smiles}</li>
        </ul>
        <p class="mt-2 text-xs text-body dark:text-bodydark">
          Matching is by exact SMILES text. Different spellings of the same molecule are not detected.
        </p>
      </section>
    </div>
    """
  end

  defp fmt(nil), do: "n/a"
  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 4)

  defp objective(%{minimize: true}), do: "lowest"
  defp objective(_), do: "highest"
end
