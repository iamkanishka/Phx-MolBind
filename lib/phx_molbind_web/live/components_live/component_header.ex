defmodule PhxMolbindWeb.ComponentsLive.ComponentHeader do
  use PhxMolbindWeb, :live_component

  def render(assigns) do
    ~H"""
    """
  end

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
