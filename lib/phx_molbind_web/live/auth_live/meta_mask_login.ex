defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view
  alias PhxMolbindWeb.AuthLive.Ethauth

  @impl true

  def render(assigns) do
    ~H"""
    <div id="metamask-login" phx-hook="MetaMaskLogin">
      <button class="btn">Login with MetaMask</button>
    </div>
    """
  end

  @impl true

  def mount(_params, _session, socket) do
    {:ok, assign(socket, eth_address: nil)}
  end

  def handle_event(
        "metamask_login",
        %{"message" => msg, "signature" => sig, "address" => address},
        socket
      ) do
        IO.inspect(msg, label: "Received message")
        IO.inspect(sig, label: "Received signature")
        IO.inspect(address, label: "Received address")
    # Log the received parameters for debugging
    # Verify the signature using the Ethauth module
    if Ethauth.verify_signature(msg, sig, address) do
      {:noreply,
       socket
       |> put_flash(:info, "Logged in as #{address}")
       |> assign(:eth_address, address)}
    else
      {:noreply, put_flash(socket, :error, "Signature verification failed")}
    end
  end
end
