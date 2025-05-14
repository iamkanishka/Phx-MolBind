defmodule PhxMolbindWeb.ComponentsLive.MoleculeRender.ThreedmoleculeRender do
  use PhxMolbindWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-row justify-center items start w-[300px] h-[300px]">
      <canvas
        id="transformBallAndStick"
        phx-hook="ThreeDrenderSmilemol"
        data-smiles={@smiles_structure}
        width="300"
        height="300"
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
