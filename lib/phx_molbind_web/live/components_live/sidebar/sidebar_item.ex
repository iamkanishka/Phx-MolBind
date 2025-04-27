defmodule PhxMolbindWeb.ComponentsLive.Sidebar.SidebarItem do
  use PhxMolbindWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@item.route}
        phx-click={@set_page_name}
        phx-value-page_name={String.downcase(@item.label)}
        class={  "group relative flex items-center gap-2.5 rounded-md px-4 py-2 text-bodydark1 duration-300 ease-in-out hover:bg-graydark dark:hover:bg-[#1e1e1e]" <>
            if @page_name == String.downcase(@item.label), do: "bg-graydark dark:bg-[#1e1e1e]", else: ""}
      >
        <.icon name={"hero-#{@item.icon}"} class="size-5" /> <span>{@item.label}</span>
      </.link>

      <%= if Map.has_key?(@item, :children) and @item.children != [] do %>
        <div class={   "translate transform overflow-hidden" <> if  @page_name == String.downcase(@item.label), do: "hidden", else: ""  }>
          <.live_component
            module={PhxMolbindWeb.ComponentsLive.Sidebar.SidebarDropdown}
            id={:sidebar_dropdown}
          />
        </div>
      <% end %>
    </li>
    """
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end
end
