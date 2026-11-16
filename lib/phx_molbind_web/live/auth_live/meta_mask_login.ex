defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Accounts
  alias PhxMolbind.EthAuth.Auth

  @address_format ~r/^0x[0-9a-fA-F]{40}$/

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative flex min-h-screen items-center justify-center overflow-hidden bg-boxdark-2 p-4">
      <!-- Faint molecular-bond backdrop, echoing the mark above the card -->
      <svg
        class="pointer-events-none absolute inset-0 h-full w-full opacity-[0.07]"
        viewBox="0 0 800 800"
        preserveAspectRatio="xMidYMid slice"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <g stroke="#F6A345" stroke-width="1.5">
          <line x1="60" y1="120" x2="180" y2="80" /> <line x1="180" y1="80" x2="280" y2="160" />
          <line x1="280" y1="160" x2="420" y2="120" />
          <line x1="640" y1="90" x2="720" y2="180" /> <line x1="720" y1="180" x2="680" y2="300" />
          <line x1="120" y1="520" x2="220" y2="460" /> <line x1="220" y1="460" x2="340" y2="540" />
          <line x1="580" y1="560" x2="700" y2="520" /> <line x1="700" y1="520" x2="760" y2="620" />
          <line x1="380" y1="680" x2="460" y2="740" />
        </g>
        <g fill="#E4572E">
          <circle cx="60" cy="120" r="6" /> <circle cx="180" cy="80" r="6" />
          <circle cx="280" cy="160" r="6" /> <circle cx="420" cy="120" r="6" />
          <circle cx="640" cy="90" r="6" /> <circle cx="720" cy="180" r="6" />
          <circle cx="680" cy="300" r="6" /> <circle cx="120" cy="520" r="6" />
          <circle cx="220" cy="460" r="6" /> <circle cx="340" cy="540" r="6" />
          <circle cx="580" cy="560" r="6" /> <circle cx="700" cy="520" r="6" />
          <circle cx="760" cy="620" r="6" /> <circle cx="380" cy="680" r="6" />
          <circle cx="460" cy="740" r="6" />
        </g>
      </svg>

      <div class="relative w-full max-w-md rounded-2xl border border-white/10 bg-boxdark p-10 shadow-2xl">
        <div class="text-center">
          <img
            src={~p"/images/logo.png"}
            alt="Phoenix Molecule Research"
            class="mx-auto mb-6 h-20 w-20"
          />

          <h1 class="font-display text-3xl font-semibold text-white">
            Phoenix
          </h1>
          <p class="mb-3 text-sm font-medium uppercase tracking-[0.2em] text-secondary">
            Molecule Research
          </p>

          <p class="mx-auto max-w-xs text-sm text-bodydark1">
            Sign in with your wallet to generate molecules, search compounds, and pick up your saved history.
          </p>
        </div>

        <div class="mt-8" id="metamask-login" phx-hook="MetaMaskLogin">
          <button
            id="loginButton"
            type="button"
            class="group relative flex w-full items-center justify-center gap-3 rounded-xl border border-transparent bg-gradient-to-r from-primary to-secondary px-4 py-4 text-base font-semibold text-white shadow-lg transition-all duration-200 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 focus:ring-offset-boxdark disabled:cursor-not-allowed disabled:opacity-60"
          >
            <.icon name="hero-wallet" class="size-5" />
            <span data-label="idle">Connect Wallet</span>
          </button>

          <p
            id="wallet-status"
            data-status
            phx-update="ignore"
            role="status"
            aria-live="polite"
            class="mt-4 min-h-5 text-center text-sm text-bodydark1"
          >
          </p>

          <div
            id="wallet-install"
            data-install
            phx-update="ignore"
            class="mt-4 hidden rounded-lg border border-white/10 bg-boxdark-2 p-4 text-sm text-bodydark1"
          >
            <p class="font-medium text-white">No wallet detected</p>
            <p class="mt-1">
              Install the MetaMask browser extension, then reload this page.
            </p>
            <div class="mt-3 flex flex-wrap gap-3">
              <a
                href="https://metamask.io/download/"
                target="_blank"
                rel="noopener noreferrer"
                class="rounded-lg border border-white/20 px-3 py-1.5 text-white hover:bg-white/10"
              >
                Get MetaMask ↗
              </a>
              <a
                data-mobile-link
                href="#"
                class="hidden rounded-lg border border-white/20 px-3 py-1.5 text-white hover:bg-white/10"
              >
                Open in the MetaMask app
              </a>
            </div>
          </div>

          <p class="mt-4 text-center text-xs text-bodydark2">
            Requires an Ethereum wallet such as MetaMask. You'll sign a message to prove wallet ownership — this never triggers a transaction, costs gas, or depends on which network you are connected to.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, eth_address: nil)}
  end

  # Step 1: client connected their wallet and is asking to sign in with
  # `address`. Issue a fresh nonce and hand back the exact message the
  # wallet should sign — never trust a bare address as proof of identity.
  @impl true
  def handle_event("request_nonce", %{"address" => address}, socket) do
    if address =~ @address_format do
      message = Auth.generate_and_store_nonce(address)
      {:reply, %{message: message}, socket}
    else
      {:reply, %{error: "Invalid wallet address."}, socket}
    end
  end

  # Step 2: client signed the message and sends back the signature. Verify
  # it actually recovers to the claimed address before trusting anything.
  @impl true
  def handle_event("verify_signature", %{"address" => address, "signature" => signature}, socket) do
    case Auth.verify_signature(address, signature) do
      {:ok, %{address: verified_address}} ->
        case Accounts.find_or_create_user_by_address(verified_address) do
          {:ok, user} ->
            ticket = Auth.create_login_ticket(user.id)
            # Full-page redirect, not push_navigate: the target is a plain
            # controller action that needs to run the Plug session pipeline to
            # actually establish the session cookie.
            {:noreply, redirect(socket, to: ~p"/auth/session/#{ticket}")}

          {:error, _changeset} ->
            {:noreply,
             login_failed(socket, "error", "Your account could not be loaded. Please try again.")}
        end

      {:error, "Sign-in request expired"} ->
        {:noreply,
         login_failed(
           socket,
           "expired",
           "That sign-in request expired. Click Try again to get a fresh one."
         )}

      {:error, _reason} ->
        {:noreply,
         login_failed(
           socket,
           "invalid",
           "The signature could not be verified for that address. Please try again."
         )}
    end
  end

  # The wallet was disconnected client-side (accountsChanged with no
  # accounts). This only resets local UI state — it does not end an
  # already-established app session; use the sign-out button for that.
  def handle_event("wallet_disconnected", _params, socket) do
    {:noreply, assign(socket, :eth_address, nil)}
  end

  defp login_failed(socket, reason, message) do
    socket
    |> push_event("login_failed", %{reason: reason, message: message})
    |> assign(:eth_address, nil)
  end
end
