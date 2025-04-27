defmodule PhxMolbindWeb.ComponentsLive.Sidebar.Sidebar do
  use PhxMolbindWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <aside class={
      "fixed left-0 top-0 z-[9999] flex h-screen w-72.5 flex-col overflow-y-hidden bg-black duration-300 ease-linear dark:bg-[#000000] lg:translate-x-0" <>
      if @sidebar_open, do: "translate-x-0", else: "-translate-x-full"

    }>
      <div class="flex items-center justify-between gap-2 px-6 py-5.5 lg:py-6.5">
        <.link navigate="/">
          <div class="flex flex-row items-center justify-center space-x-2">
            <div class="ml-2 rounded-lg bg-[#3c4fe0] p-1">
              <img width="32" height="32" src="/images/dna.svg" alt="Logo" />
            </div>

            <p class="text-xl font-semibold text-white">ProteinBind</p>
          </div>
        </.link>

        <button phx-click="toggle_sidebar" aria-controls="sidebar" class="block lg:hidden">
          <.icon name="hero-chevron-left" />
        </button>
      </div>

      <div class="no-scrollbar flex flex-col overflow-y-auto duration-300 ease-linear">
        <nav class="mt-5 px-4 py-4 lg:mt-9 lg:px-6">
          <%= for {group, _group_index} <- Enum.with_index(@menu_groups) do %>
            <div>
              <%= if group.name != "" do %>
                <h3 class="mb-4 ml-4 text-sm font-semibold text-bodydark2">
                  {group.name}
                </h3>
              <% end %>

              <ul class="mb-6 flex flex-col gap-2">
                <%= for {menu_item, menu_index} <- Enum.with_index(group.menu_items) do %>
                  <.live_component
                    module={PhxMolbindWeb.ComponentsLive.Sidebar.SidebarItem}
                    item={menu_item}
                    page_name={@page_name}
                    set_page_name="set_page_name"
                    id={"sidebar_item_#{menu_item.label}"}
                  />
                <% end %>
              </ul>
            </div>
          <% end %>
        </nav>
      </div>
    </aside>
    """
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:sidebar_open, true)
     |> assign(:menu_groups, [
       %{
         name: "",
         menu_items: [
           %{icon: "layout-grid", label: "Dashboard", route: "/"},
           %{icon: "atom", label: "Molecules Bank", route: "/molecule-bank"},
           %{icon: "network", label: "Model", route: "/model"},
           %{icon: "microscope", label: "Research", route: "/research"},
           %{icon: "message-square-text", label: "Messages", route: "/message"}
         ]
       },
       %{
         name: "OTHERS",
         menu_items: [
           %{icon: "settings", label: "Settings", route: "/settings"}
         ]
       }
     ])}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end
end
