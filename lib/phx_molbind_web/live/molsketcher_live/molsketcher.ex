defmodule PhxMolbindWeb.MolsketcherLive.Molsketcher do
  use PhxMolbindWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <canvas id="sketcher" width="500" height="300" id="chem-sketcher" phx-hook="Molsketcher"></canvas>
    <div class="text-center mt-4">
      <button phx-click="get_molecule" phx-value-format="mol" class="btn">Export as MOL</button>
      <button phx-click="get_molecule" phx-value-format="smiles" class="btn">Export as SMILES</button>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("theme:init", %{"theme" => theme}, socket) do
    # You can update assign or store the theme as needed.
    IO.inspect(theme, label: "theme check ")
    {:noreply, assign(socket, :theme, theme)}
  end

  def handle_event("get_molecule", %{"format" => format}, socket) do
    # Trigger JS event to get molecule from sketcher
    {:noreply, push_event(socket, "get_molecule", format)}
  end

  def handle_event("molecule_data", %{"format" => format, "data" => data}, socket) do
    IO.inspect({format, data}, label: "Received molecule")
    # Optionally store or use in assigns
    {:noreply, assign(socket, :molecule, %{format: format, data: data})}
  end
end
