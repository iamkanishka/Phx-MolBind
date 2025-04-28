defmodule PhxMolbindWeb.DashboardLive.Dashboard do
  use PhxMolbindWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
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
    """
  end

  @impl true
  @spec mount(any(), any(), map()) :: {:ok, map()}
  def  mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign_CTA_card_list()}
  end

  def assign_CTA_card_list(socket) do
    socket
    |> assign(:cta_card_list, [
      %{title: "Molecule Bank", subtitle: "get access to more molecules", icon: "atom"},
      %{title: "Generate Molecule", subtitle: "get access to more molecules", icon: "network"},
      %{
        title: "Search Compounds",
        subtitle: "get access to more molecules",
        icon: "search"
      },
      %{
        title: "Collaborative Research",
        subtitle: "get access to more molecules",
        icon: "message-circle"
      }
    ])
  end
end
