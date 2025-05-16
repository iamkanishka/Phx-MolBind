defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts.Accounts

  @impl true

  def render(assigns) do
    ~H"""
    <%!-- <div id="metamask-login" phx-hook="MetaMaskLogin">
      <button class="btn">Login with MetaMask</button>
      <%= if @eth_address do %>
        <p>Logged in as: {@eth_address}</p>
      <% else %>
        <p>Please log in to access your account.</p>
      <% end %>
    </div> --%>
    <%!-- <div class="bg-gradient-to-br from-blue-900 to-teal-800 min-h-screen flex items-center justify-center p-4 font-['Inter'] bg-science-pattern"> --%>

    <div class="bg-white min-h-screen flex items-center justify-center p-4 font-['Inter'] bg-science-pattern">
      <div class="max-w-md w-full space-y-8 bg-white/10 backdrop-blur-sm rounded-2xl p-10 shadow-2xl border border-white/20">
        <div class="text-center">
          <!-- App Logo/Name -->
          <h1 class="text-4xl font-bold text-white mb-2">PharmaChain Research</h1>

          <p class="text-blue-200">Secure, decentralized access to pharmaceutical research</p>

    <!-- MetaMask Fox Image from external URL -->
          <div class="flex justify-center my-8">
            <img
              src="https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg"
              alt="MetaMask Logo"
              class="h-24 w-24"
            />
          </div>
        </div>

    <!-- Login Button -->
        <div class="mt-8" id="metamask-login" phx-hook="MetaMaskLogin">
          <button
            id="loginButton"
            class="group relative w-full flex justify-center items-center py-4 px-4 border border-transparent text-lg font-medium rounded-xl text-white bg-gradient-to-r from-blue-600 to-teal-500 hover:from-blue-700 hover:to-teal-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-200 shadow-lg hover:shadow-xl"
          >
            <span class="absolute left-0 inset-y-0 flex items-center pl-3">
              <img
                src="https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg"
                class="h-8 w-8 text-blue-300 group-hover:text-blue-200"
              />
            </span>
            Login with MetaMask
          </button>

            <%= if @eth_address do %>
        <p>Logged in as: {@eth_address}</p>
      <% else %>
        <p>Please log in to access your account.</p>
      <% end %>
        </div>
      </div>
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
