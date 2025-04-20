defmodule PhxMolbindWeb.ComponentsLive.MoleculeStructure do

  use PhxMolbindWeb, :live_component

  alias PhxMolbindWeb.ComponentsLive.MoleculeStructure

  def render(assigns) do
    ~H"""
    <div class="molecule-structure">
      <h2 class="text-lg font-semibold">Molecule Structure</h2>
      <div id="molecule-structure" phx-hook="MoleculeStructure" phx-update="ignore"></div>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

end
