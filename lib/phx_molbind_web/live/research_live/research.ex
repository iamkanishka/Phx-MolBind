defmodule PhxMolbindWeb.ResearchLive.Research do
  @moduledoc """
  PubChem compound lookup (`/research`).

  Suggestions and lookups run asynchronously. Each request gets a sequence
  number and a response is applied only if it is still the latest, so a slow
  answer for an older query can never replace newer results.

  Values are shown exactly as PubChem reports them. XLogP, TPSA, complexity
  and the other descriptors are PubChem *computed* properties, not
  experimental measurements, and the page says so.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbindWeb.ResearchLive.CompoundSearch

  @properties [
    {"MolecularFormula", "Molecular formula", nil},
    {"MolecularWeight", "Molecular weight", "g/mol"},
    {"InChIKey", "InChIKey", nil},
    {"IUPACName", "IUPAC name", nil},
    {"XLogP", "XLogP", nil},
    {"ExactMass", "Exact mass", "g/mol"},
    {"MonoisotopicMass", "Monoisotopic mass", "g/mol"},
    {"TPSA", "Topological polar surface area", "Å²"},
    {"Complexity", "Complexity", nil},
    {"Charge", "Charge", nil},
    {"HBondDonorCount", "Hydrogen bond donors", nil},
    {"HBondAcceptorCount", "Hydrogen bond acceptors", nil},
    {"RotatableBondCount", "Rotatable bonds", nil},
    {"HeavyAtomCount", "Heavy atoms", nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Research")
     |> assign(:compound_name, "")
     |> assign(:compound_data, nil)
     |> assign(:smiles, nil)
     |> assign(:record_url, nil)
     |> assign(:loading, false)
     |> assign(:show_dropdown, false)
     |> assign(:suggestions, [])
     |> assign(:seq, 0)
     |> assign(:error, nil)
     |> assign(:properties, @properties)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <div class="mb-6 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <h2 class="text-title-md2 font-semibold text-black dark:text-white">Compound search</h2>

        <div
          id="compound-search"
          phx-hook="SuggestNav"
          phx-click-away="hide_dropdown"
          class="relative w-full md:w-96"
        >
          <form phx-change="update_compound" phx-submit="search_submit" role="search">
            <label for="compound-name" class="sr-only">Compound name</label>
            <input
              id="compound-name"
              type="text"
              name="compound_name"
              value={@compound_name}
              phx-debounce="400"
              phx-focus="show_dropdown"
              role="combobox"
              aria-autocomplete="list"
              aria-expanded={to_string(@show_dropdown and @suggestions != [])}
              aria-controls="compound-suggestions"
              class="w-full rounded-lg border border-stroke bg-white p-3 pr-10 text-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary dark:border-strokedark dark:bg-boxdark"
              placeholder="Enter a compound name"
              autocomplete="off"
            />
          </form>
          <span class="pointer-events-none absolute inset-y-0 right-3 flex items-center">
            <.icon
              name={if @loading, do: "hero-arrow-path", else: "hero-magnifying-glass"}
              class={
                if @loading,
                  do: "size-5 text-body animate-spin motion-reduce:animate-none",
                  else: "size-5 text-body"
              }
            />
          </span>

          <ul
            :if={@show_dropdown and @suggestions != []}
            id="compound-suggestions"
            role="listbox"
            aria-label="Compound suggestions"
            class="absolute z-10 mt-1 max-h-72 w-full overflow-y-auto rounded-lg border border-stroke bg-white shadow-lg dark:border-strokedark dark:bg-boxdark"
          >
            <li
              :for={{compound, i} <- Enum.with_index(@suggestions)}
              id={"suggestion-#{i}"}
              role="option"
              phx-click="select_compound"
              phx-value-name={compound}
              class="cursor-pointer px-4 py-2 hover:bg-gray-2 aria-selected:bg-primary/10 dark:hover:bg-white/5"
            >
              {compound}
            </li>
          </ul>
        </div>
      </div>

      <div role="status" aria-live="polite">
        <p :if={@loading} class="text-sm text-body dark:text-bodydark">Searching PubChem…</p>
        <p :if={@error} class="mt-2 font-medium text-red-600 dark:text-red-400" role="alert">
          {@error}
        </p>
      </div>

      <p
        :if={is_nil(@compound_data) and is_nil(@error) and not @loading}
        class="rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        Search PubChem by compound name (for example “caffeine”). Pick a suggestion or press Enter to look it up.
      </p>

      <div :if={@compound_data} class="mt-6 grid grid-cols-1 gap-6 md:grid-cols-3">
        <section
          class="space-y-4 rounded-lg bg-white p-6 shadow-md dark:bg-[#181818] md:col-span-1"
          aria-labelledby="structure-heading"
        >
          <h3 id="structure-heading" class="text-lg font-semibold text-black dark:text-white">
            Structure
          </h3>
          <.structure_viewer
            :if={@smiles}
            id="research-viewer"
            canvas_id="smiles-canvas-research"
            smiles={@smiles}
            size={260}
            export={false}
            label={"structure of " <> @compound_name}
          />
          <p :if={is_nil(@smiles)} class="text-sm text-body dark:text-bodydark">
            PubChem did not return a SMILES string for this compound, so no structure can be drawn.
          </p>

          <div :if={@smiles} class="space-y-1">
            <p class="text-sm font-medium text-black dark:text-white">SMILES</p>
            <p class="break-all font-mono text-xs text-black dark:text-white">{@smiles}</p>
          </div>

          <div class="flex flex-wrap gap-2 text-sm">
            <button
              :if={@smiles}
              id="copy-research-smiles"
              type="button"
              phx-hook="CopyButton"
              data-copy={@smiles}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Copy SMILES
            </button>
            <button
              :if={@compound_data["InChIKey"]}
              id="copy-research-inchikey"
              type="button"
              phx-hook="CopyButton"
              data-copy={@compound_data["InChIKey"]}
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              Copy InChIKey
            </button>
            <.link
              :if={@smiles}
              navigate={~p"/model?#{%{smiles: @smiles}}"}
              class="rounded border border-primary px-2 py-1 text-accent dark:text-accent-light hover:bg-primary/10"
            >
              Use as starting molecule
            </.link>
            <a
              :if={@record_url}
              href={@record_url}
              target="_blank"
              rel="noopener noreferrer"
              class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
            >
              PubChem record ↗
            </a>
          </div>
        </section>

        <section
          class="rounded-lg bg-white p-6 shadow-md dark:bg-[#181818] md:col-span-2"
          aria-labelledby="properties-heading"
        >
          <h3 id="properties-heading" class="mb-4 text-lg font-semibold text-black dark:text-white">
            Properties
          </h3>
          <dl class="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <div :for={{key, label, unit} <- @properties}>
              <dt class="text-sm font-medium text-black dark:text-white">{label}</dt>
              <dd class="break-words text-sm text-body dark:text-bodydark">
                <%= case @compound_data[key] do %>
                  <% nil -> %>
                    <span class="italic">Not available</span>
                  <% value -> %>
                    {value}{if unit, do: " " <> unit}
                <% end %>
              </dd>
            </div>
          </dl>
          <p class="mt-5 text-xs text-body dark:text-bodydark">
            Source: PubChem (NCBI). Descriptors such as XLogP, TPSA and complexity are values computed by PubChem, not experimental measurements.
          </p>
        </section>
      </div>
    </div>
    """
  end

  ## Events

  @impl true
  def handle_event("update_compound", %{"compound_name" => name}, socket) do
    seq = socket.assigns.seq + 1
    socket = assign(socket, compound_name: name, seq: seq, show_dropdown: true)

    if String.length(String.trim(name)) < 2 do
      {:noreply, assign(socket, :suggestions, [])}
    else
      {:noreply, start_async(socket, {:suggest, seq}, fn -> CompoundSearch.suggest(name) end)}
    end
  end

  def handle_event("search_submit", %{"compound_name" => name}, socket),
    do: {:noreply, search(socket, name)}

  def handle_event("select_compound", %{"name" => name}, socket),
    do: {:noreply, search(socket, name)}

  def handle_event("show_dropdown", _params, socket),
    do: {:noreply, assign(socket, :show_dropdown, true)}

  def handle_event("hide_dropdown", _params, socket),
    do: {:noreply, assign(socket, :show_dropdown, false)}

  ## Async results (stale responses are dropped by sequence number)

  @impl true
  def handle_async({:suggest, seq}, {:ok, suggestions}, %{assigns: %{seq: seq}} = socket),
    do: {:noreply, assign(socket, :suggestions, suggestions)}

  def handle_async({:lookup, seq}, {:ok, {:ok, data}}, %{assigns: %{seq: seq}} = socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign_compound(data)}
  end

  def handle_async({:lookup, seq}, {:ok, {:error, message}}, %{assigns: %{seq: seq}} = socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, message)
     |> assign_compound(nil)}
  end

  def handle_async({:lookup, seq}, {:exit, _reason}, %{assigns: %{seq: seq}} = socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, "The search failed unexpectedly. Please retry.")}
  end

  # Anything else is a response for a request that has since been superseded.
  def handle_async(_name, _result, socket), do: {:noreply, socket}

  ## Helpers

  defp search(socket, name) do
    name = String.trim(name)
    seq = socket.assigns.seq + 1

    if name == "" do
      assign(socket, error: "Enter a compound name to search.", compound_name: "", seq: seq)
    else
      socket
      |> assign(
        compound_name: name,
        suggestions: [],
        show_dropdown: false,
        loading: true,
        error: nil,
        seq: seq
      )
      |> start_async({:lookup, seq}, fn -> CompoundSearch.lookup(name) end)
    end
  end

  defp assign_compound(socket, nil) do
    socket |> assign(:compound_data, nil) |> assign(:smiles, nil) |> assign(:record_url, nil)
  end

  defp assign_compound(socket, data) do
    socket
    |> assign(:compound_data, data)
    |> assign(:smiles, CompoundSearch.smiles(data))
    |> assign(:record_url, CompoundSearch.record_url(data))
  end
end
