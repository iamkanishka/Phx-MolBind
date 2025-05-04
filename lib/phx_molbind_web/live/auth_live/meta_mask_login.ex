defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts.Accounts

  @impl true

  def render(assigns) do
    ~H"""
    <div id="metamask-login" phx-hook="MetaMaskLogin">
      <button class="btn">Login with MetaMask</button>
      <%= if @eth_address do %>
        <p>Logged in as: {@eth_address}</p>
      <% else %>
        <p>Please log in to access your account.</p>
      <% end %>
    </div>
    """
  end

  @impl true

  def mount(_params, _session, socket) do
    {:ok, assign(socket, eth_address: nil)}
  end

  @impl true
  def handle_event(
        "metamask_login",
        %{"address" => address},
        socket
      ) do
    IO.inspect(address, label: "Received address")

    {:ok, user} =
      case Accounts.get_user_by_address(address) do
        nil -> Accounts.create_user(%{address: address, last_login_at: DateTime.utc_now()})
        user -> Accounts.update_user(user, %{last_login_at: DateTime.utc_now()})
      end

      IO.inspect(user, label: "User after login")

    {:noreply, socket |> assign(:eth_address, address)}
  end
end
