defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts.Accounts

  @impl true

  def render(assigns) do
    ~H"""
    <div class="bg-white min-h-screen flex items-center justify-center p-2 font-['Inter'] bg-science-pattern">
      <div class="max-w-md w-full space-y-8 bg-white/10 backdrop-blur-sm rounded-2xl p-10 shadow-2xl border border-white/20">
        <div class="text-center">
          <!-- Logo  -->
          <div class="flex justify-center my-8">
            <img src="../images/logo.png" alt="MetaMask Logo" class="h-24 w-24" />
          </div>

    <!-- App Logo/Name -->
          <h1 class="text-3xl font-bold text-black mb-1">Phoenix</h1>

          <h1 class="text-3xl font-bold text-black mb-2">Molecule Research</h1>

          <p class="text-gray-300">Secure, decentralized access to pharmaceutical research</p>
        </div>

    <!-- Login Button -->
        <div class="mt-8" id="metamask-login" phx-hook="MetaMaskLogin">
          <button
            id="loginButton"
            class="group relative w-full flex justify-center items-center py-4 px-4 border border-transparent text-lg font-medium rounded-xl text-white bg-gradient-to-r from-blue-600 to-teal-500 hover:from-blue-700 hover:to-teal-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-200 shadow-lg hover:shadow-xl"
          >
            <span class="mx-2">
              <img
                src="https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg"
                class="h-8 w-8 text-blue-300 group-hover:text-blue-200"
              />
            </span>
            Connect with MetaMask
          </button>
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
