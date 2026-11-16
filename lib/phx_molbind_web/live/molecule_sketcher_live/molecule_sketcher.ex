defmodule PhxMolbindWeb.MolsketcherLive.Molsketcher do
  @moduledoc """
  Molecular sketcher (`/sketcher`) built on the ChemDoodle sketcher canvas.

  Export results come from the editor itself (`getMolecule()`), so they
  reflect what the user actually drew. SMILES produced by the editor are not
  independently validated here; nothing is sent to other pages automatically.
  """
  use PhxMolbindWeb, :live_view

  @formats %{"mol" => "MOL file", "smiles" => "SMILES"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sketcher")
     |> assign(:molecule, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl">
      <div class="rounded-lg border border-stroke bg-white p-4 shadow-default dark:border-strokedark dark:bg-[#181818]">
        <div class="max-w-full overflow-x-auto">
          <canvas
            id="sketcher"
            width="500"
            height="300"
            phx-hook="Molsketcher"
            phx-update="ignore"
            role="application"
            aria-label="Molecule drawing canvas. Pointer input is required to draw; use the export buttons below to read the drawn structure as MOL or SMILES text."
          >
          </canvas>
        </div>

        <div class="mt-4 flex flex-wrap gap-3">
          <button
            type="button"
            phx-click="get_molecule"
            phx-value-format="mol"
            class="rounded-lg border border-stroke px-4 py-2 hover:bg-gray-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:hover:bg-white/5"
          >
            Export as MOL
          </button>
          <button
            type="button"
            phx-click="get_molecule"
            phx-value-format="smiles"
            class="rounded-lg border border-stroke px-4 py-2 hover:bg-gray-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary dark:border-strokedark dark:hover:bg-white/5"
          >
            Export as SMILES
          </button>
        </div>

        <div role="status" aria-live="polite" class="mt-4">
          <p :if={@error} class="text-sm font-medium text-red-600 dark:text-red-400" role="alert">
            {@error}
          </p>

          <div :if={@molecule}>
            <label for="sketch-export" class="text-sm font-medium text-black dark:text-white">
              {Map.fetch!(formats(), @molecule.format)} from the canvas
            </label>
            <textarea
              id="sketch-export"
              readonly
              rows={if @molecule.format == "mol", do: 10, else: 3}
              class="mt-2 w-full break-all rounded-md border border-stroke bg-transparent p-2 font-mono text-xs dark:border-strokedark"
            >{@molecule.data}</textarea>
            <div class="mt-2 flex gap-2 text-sm">
              <button
                id="copy-sketch-export"
                type="button"
                phx-hook="CopyButton"
                data-copy={@molecule.data}
                class="rounded border border-stroke px-3 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Copy
              </button>
              <.link
                :if={@molecule.format == "smiles"}
                navigate={~p"/model?#{%{smiles: @molecule.data}}"}
                class="rounded border border-stroke px-3 py-1 hover:bg-gray-2 dark:border-strokedark dark:hover:bg-white/5"
              >
                Use in generator
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp formats, do: @formats

  @impl true
  def handle_event("get_molecule", %{"format" => format}, socket)
      when is_map_key(@formats, format) do
    {:noreply, socket |> assign(:error, nil) |> push_event("get_molecule", %{format: format})}
  end

  def handle_event("get_molecule", _params, socket) do
    {:noreply, assign(socket, :error, "Unsupported export format.")}
  end

  def handle_event("molecule_data", %{"format" => format, "data" => data}, socket)
      when is_map_key(@formats, format) and is_binary(data) do
    {:noreply, socket |> assign(:error, nil) |> assign(:molecule, %{format: format, data: data})}
  end

  def handle_event("molecule_error", %{"message" => message}, socket) when is_binary(message) do
    {:noreply, socket |> assign(:molecule, nil) |> assign(:error, message)}
  end
end
