defmodule PhxMolbindWeb.ComponentsLive.MoleculeRender.TwoDMoleculeRender do
  use PhxMolbindWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-row justify-center items start">
      <canvas
        id={@id}
        phx-hook="renderSMILESmolZoomer"
        data-smiles={@smiles_structure}
        width="400"
        height="400"
      >
      </canvas>
    </div>
    """
  end

  @spec update(maybe_improper_list() | map(), any()) :: {:ok, any()}
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
