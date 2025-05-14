defmodule PhxMolbindWeb.ComponentsLive.MainLayout do
  use PhxMolbindWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex" id="defaultlayout" phx-hook="ThemeProvider">
      <.live_component
        sidebar_open={false}
        module={PhxMolbindWeb.ComponentsLive.Sidebar.Sidebar}
        page_name="kansihka"
        id={:sidebar}
      />
      <div class="relative flex flex-1 flex-col lg:ml-72.5">
        <.live_component
          sidebar_open={true}
          module={PhxMolbindWeb.ComponentsLive.Header}
          id={:header}
        />
        <main class="px-4 py-20 sm:px-6 lg:px-8">
          <div class="mx-auto">
            <.flash_group flash={@flash} /> {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>
    """
  end
end
