defmodule PhxMolbindWeb.ComponentsLive.MolculeBank do
  use PhxMolbindWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex h-screen items-center justify-center bg-white dark:bg-black">
      <div class="h-16 w-16 animate-spin rounded-full border-4 border-solid border-primary border-t-transparent">
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
