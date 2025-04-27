defmodule PhxMolbindWeb.ComponentsLive.Sidebar.SidebarDropdown do
  use PhxMolbindWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <ul class="mb-5.5 mt-4 flex flex-col gap-2.5 pl-6">
      <%= for {child_item, _child_item_index} <- Enum.with_index(@item) do %>
        <li>
          <.link
            navigate={child_item.route}
            class={

              "group relative flex items-center gap-2.5 rounded-md px-4 font-medium text-bodydark2 duration-300 ease-in-out hover:text-white" <>
              if @current_path == child_item.route, do: "text-white", else: ""

          }
          >
            {child_item.label}
          </.link>
        </li>
      <% end %>
    </ul>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end
end
