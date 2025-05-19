defmodule PhxMolbindWeb.DashboardLive.Dashboard do
  use PhxMolbindWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={PhxMolbindWeb.ComponentsLive.MainLayout} id={:main_layout}>
      <div class="grid grid-cols-1 gap-4 md:grid-cols-2 md:gap-6 lg:grid-cols-4 2xl:gap-7.5">
        <%= for card <- @cta_card_list do %>
          <.live_component
            module={PhxMolbindWeb.ComponentsLive.DashboardLive.CTACard}
            title={card.title}
            subtitle={card.subtitle}
            icon={card.icon}
            id={"cta_card_#{card.title}"}
          />
        <% end %>
      </div>
    </.live_component>
    """
  end

  @impl true
  @spec mount(any(), any(), map()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign_CTA_card_list()}
  end

  def assign_CTA_card_list(socket) do
    socket
    |> assign(:cta_card_list, [
      %{title: "Molecule Bank", subtitle: "Get access to generated molecules", icon: "atom"},
      %{title: "Generate Molecule", subtitle: "Genearte  more molecules", icon: "network"},
      %{
        title: "Search Compounds",
        subtitle: "Explore generated compounds",
        icon: "search"
      },
      %{
        title: "Collaborative Research",
        subtitle: "get access to more molecules",
        icon: "message-circle"
      }
    ])
  end

  @impl true
  def handle_event("theme:init", %{"theme" => theme}, socket) do
    # You can update assign or store the theme as needed.
    IO.inspect(theme, label: "theme check ")
    {:noreply, assign(socket, :theme, theme)}
  end
end
