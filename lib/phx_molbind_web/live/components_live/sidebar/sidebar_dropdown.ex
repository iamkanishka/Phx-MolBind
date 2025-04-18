defmodule PhxMolbindWeb.ComponentsLive.Sidebar.SidebarDropdown do
use PhxMolbindWeb, :live_component


  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 px-4 py-2">
      <%= for item <- @items do %>

      <% end %>
    </div>
    """
  end

end
