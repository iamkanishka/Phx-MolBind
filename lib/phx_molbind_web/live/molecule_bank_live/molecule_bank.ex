defmodule PhxMolbindWeb.MoleculeBankLive.MoleculeBank do
  @moduledoc """
  Molecule Bank (`/molecule-bank`): browse the built-in reference catalog.

  Filters, sort and view mode live in the URL (`?q=&category=&sort=&view=`),
  so back/forward and shared links work. Entries come from
  `PhxMolbind.Catalog`; formula and stereocentre counts are computed from the
  SMILES, the listed molecular weight is a reference value, and none are
  experimental measurements.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Catalog

  @views ~w(grid table)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Molecule Bank")
     |> assign(:categories, Catalog.categories())
     |> assign(:expand_molecule, false)
     |> assign(:selected_smiles, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = params |> Map.get("q", "") |> to_string() |> String.slice(0, 100)
    category = if params["category"] in Catalog.categories(), do: params["category"], else: ""
    sort = if params["sort"] in Catalog.sorts(), do: params["sort"], else: "name"
    view = if params["view"] in @views, do: params["view"], else: "grid"

    {:noreply,
     socket
     # Closing the modal patches back here, so the enlarge state resets too.
     |> assign(:expand_molecule, false)
     |> assign(:selected_smiles, nil)
     |> assign(:q, q)
     |> assign(:category, category)
     |> assign(:sort, sort)
     |> assign(:view, view)
     |> assign(:molecules, Catalog.list(q: q, category: category, sort: sort))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl">
      <form
        phx-change="search_molecule"
        phx-submit="search_molecule"
        role="search"
        class="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-4"
      >
        <div class="sm:col-span-2">
          <label for="bank-q" class="text-sm text-body dark:text-bodydark">
            Search name, formula, category or SMILES
          </label>
          <input
            id="bank-q"
            type="search"
            name="search_query"
            value={@q}
            phx-debounce="300"
            autocomplete="off"
            class="mt-1 w-full rounded-lg border border-stroke bg-white px-4 py-2 focus:border-primary focus:ring-primary dark:border-strokedark dark:bg-[#181818] dark:text-white"
          />
        </div>
        <div>
          <label for="bank-category" class="text-sm text-body dark:text-bodydark">Category</label>
          <select
            id="bank-category"
            name="category"
            class="mt-1 w-full rounded-lg border border-stroke bg-white px-3 py-2 dark:border-strokedark dark:bg-[#181818] dark:text-white"
          >
            <option value="">All categories</option>
            <option :for={c <- @categories} value={c} selected={@category == c}>{c}</option>
          </select>
        </div>
        <div>
          <label for="bank-sort" class="text-sm text-body dark:text-bodydark">Sort</label>
          <select
            id="bank-sort"
            name="sort"
            class="mt-1 w-full rounded-lg border border-stroke bg-white px-3 py-2 dark:border-strokedark dark:bg-[#181818] dark:text-white"
          >
            <option value="name" selected={@sort == "name"}>Name (A–Z)</option>
            <option value="weight_asc" selected={@sort == "weight_asc"}>Weight, low to high</option>
            <option value="weight_desc" selected={@sort == "weight_desc"}>Weight, high to low</option>
          </select>
        </div>
      </form>

      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p class="text-sm text-body dark:text-bodydark" aria-live="polite">
          {length(@molecules)} {if length(@molecules) == 1, do: "molecule", else: "molecules"}
        </p>
        <nav class="flex gap-2 text-sm" aria-label="View mode">
          <.link
            :for={v <- ["grid", "table"]}
            patch={bank_path(@q, @category, @sort, v)}
            aria-current={if @view == v, do: "true"}
            class={[
              "rounded-lg border px-3 py-1",
              if(@view == v,
                do: "border-primary bg-primary/10 text-accent dark:text-accent-light",
                else: "border-stroke dark:border-strokedark"
              )
            ]}
          >
            {String.capitalize(v)}
          </.link>
        </nav>
      </div>

      <div
        :if={@molecules == []}
        class="rounded-lg border border-dashed border-stroke p-6 text-sm text-body dark:border-strokedark dark:text-bodydark"
      >
        <p class="font-medium text-black dark:text-white">No molecules match these filters.</p>
        <.link
          patch={~p"/molecule-bank"}
          class="mt-2 inline-block text-accent dark:text-accent-light hover:underline"
        >
          Clear filters
        </.link>
      </div>

      <ul
        :if={@view == "grid" and @molecules != []}
        class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3"
      >
        <li
          :for={m <- @molecules}
          id={"molecule-#{m.id}"}
          class="rounded-lg border border-stroke bg-white p-4 dark:border-strokedark dark:bg-[#181818]"
        >
          <div class="flex items-baseline justify-between gap-2">
            <h2 class="font-medium text-black dark:text-white">{m.name}</h2>
            <span class="font-mono text-xs text-body dark:text-bodydark">{m.formula}</span>
          </div>
          <canvas
            id={"bank-canvas-#{m.id}"}
            phx-hook="renderSMILESmol"
            data-smiles={m.smiles}
            width="240"
            height="180"
            data-width="240"
            data-height="180"
            role="img"
            aria-label={"Structure of #{m.name}"}
            class="mx-auto mt-2 max-w-full rounded border border-stroke bg-white dark:border-strokedark"
          >
          </canvas>
          <dl class="mt-3 grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
            <dt class="text-body dark:text-bodydark">Weight</dt>
            <dd class="text-black dark:text-white">{m.molecular_weight} g/mol</dd>
            <dt class="text-body dark:text-bodydark">Category</dt>
            <dd class="text-black dark:text-white">{m.category}</dd>
            <dt class="text-body dark:text-bodydark">Stereochemistry</dt>
            <dd class="text-black dark:text-white">{Catalog.stereo_summary(m)}</dd>
          </dl>
          <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{m.smiles}</p>
          <.actions m={m} />
        </li>
      </ul>

      <div
        :if={@view == "table" and @molecules != []}
        class="overflow-x-auto rounded-lg border border-stroke dark:border-strokedark"
      >
        <table class="w-full min-w-[48rem] text-left text-sm">
          <caption class="sr-only">Reference molecules</caption>
          <thead class="bg-gray-2 dark:bg-white/5">
            <tr>
              <th scope="col" class="p-3">Name</th>
              <th scope="col" class="p-3">Structure</th>
              <th scope="col" class="p-3">Formula</th>
              <th scope="col" class="p-3">Weight (g/mol)</th>
              <th scope="col" class="p-3">Category</th>
              <th scope="col" class="p-3">Stereochemistry</th>
              <th scope="col" class="p-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={m <- @molecules}
              id={"molecule-row-#{m.id}"}
              class="border-t border-stroke dark:border-strokedark"
            >
              <th scope="row" class="p-3 font-medium">{m.name}</th>
              <td class="p-3">
                <canvas
                  id={"bank-row-canvas-#{m.id}"}
                  phx-hook="renderSMILESmol"
                  data-smiles={m.smiles}
                  width="140"
                  height="100"
                  data-width="140"
                  data-height="100"
                  role="img"
                  aria-label={"Structure of #{m.name}"}
                  class="rounded border border-stroke bg-white dark:border-strokedark"
                >
                </canvas>
              </td>
              <td class="p-3 font-mono">{m.formula}</td>
              <td class="p-3 font-mono">{m.molecular_weight}</td>
              <td class="p-3">{m.category}</td>
              <td class="p-3">{Catalog.stereo_summary(m)}</td>
              <td class="p-3"><.actions m={m} /></td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="mt-4 text-xs text-body dark:text-bodydark">
        Reference list curated for MolBind. {Catalog.audit_note()}
      </p>
    </div>

    <%= if @expand_molecule and @selected_smiles != nil do %>
      <.modal id="molecule-modal" show on_cancel={JS.patch(bank_path(@q, @category, @sort, @view))}>
        <.live_component
          module={PhxMolbindWeb.ComponentsLive.MoleculeRender.ThreedmoleculeRender}
          id="threed_selected_smiles-canvas"
          smiles_structure={@selected_smiles}
        />
      </.modal>
    <% end %>
    """
  end

  attr :m, :map, required: true

  defp actions(assigns) do
    ~H"""
    <div class="mt-3 flex flex-wrap gap-2 text-sm">
      <button
        type="button"
        phx-click="enlarge_molecule"
        phx-value-smiles={@m.smiles}
        aria-label={"Open larger 3D view of #{@m.name}"}
        class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
      >
        3D view
      </button>
      <button
        id={"bank-copy-#{@m.id}"}
        type="button"
        phx-hook="CopyButton"
        data-copy={@m.smiles}
        class="rounded border border-stroke px-2 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
      >
        Copy SMILES
      </button>
      <.link
        navigate={~p"/model?#{%{smiles: @m.smiles}}"}
        class="rounded border border-primary px-2 py-1 text-accent dark:text-accent-light hover:bg-primary/10"
      >
        Use as starting molecule
      </.link>
    </div>
    """
  end

  @impl true
  def handle_event("search_molecule", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         bank_path(
           Map.get(params, "search_query", ""),
           Map.get(params, "category", ""),
           Map.get(params, "sort", "name"),
           socket.assigns.view
         )
     )}
  end

  def handle_event("enlarge_molecule", %{"smiles" => smiles}, socket) do
    # Only catalog structures can be opened; the client-supplied SMILES is
    # checked against the catalog rather than trusted.
    case Catalog.get_by_smiles(smiles) do
      nil ->
        {:noreply, socket}

      %{smiles: smiles} ->
        {:noreply, assign(socket, expand_molecule: true, selected_smiles: smiles)}
    end
  end

  defp bank_path(q, category, sort, view) do
    params =
      [{"q", q}, {"category", category}, {"sort", sort}, {"view", view}]
      |> Enum.reject(fn {key, value} ->
        value in [nil, ""] or (key == "sort" and value == "name") or
          (key == "view" and value == "grid")
      end)

    if params == [], do: ~p"/molecule-bank", else: ~p"/molecule-bank?#{params}"
  end
end
