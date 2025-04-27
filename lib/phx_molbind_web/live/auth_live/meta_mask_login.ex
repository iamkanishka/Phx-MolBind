# lib/my_app_web/live/meta_mask_login_live.ex

defmodule PhxMolbindWeb.Auth.MetaMaskLogin do
  use PhxMolbindWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, status: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-xl mb-4">🐺 MetaMask Login</h1>

      <button id="metamask-login" class="bg-indigo-600 text-white px-4 py-2 rounded">
        Connect MetaMask
      </button>

      <p class="mt-4">{@status}</p>
    </div>

    <script>
      window.addEventListener("phx:page-loading-stop", async () => {
        const btn = document.getElementById("metamask-login");
        if (!btn) return;

        btn.onclick = async () => {
          const provider = window.ethereum;
          if (!provider) {
            alert("MetaMask not found");
            return;
          }

          try {
            const [address] = await provider.request({ method: 'eth_requestAccounts' });
            const nonceRes = await fetch(`/api/nonce?address=${address}`);
            const { nonce } = await nonceRes.json();

            const signature = await provider.request({
              method: 'personal_sign',
              params:  [address, nonce],
            });

            const authRes = await fetch(`/api/auth/metamask`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ address, signature }),
              credentials: 'include' // ⬅️ Important for session-based login
            });

            const result = await authRes.json();

            if (result.status === "authenticated") {
              window.location.reload(); // or redirect to dashboard
            } else {
              alert("Auth failed");
            }
          } catch (err) {
            console.error(err);
            alert("Something went wrong");
          }
        };
      });
    </script>
    """
  end
end
