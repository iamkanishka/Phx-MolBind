// Wallet sign-in. The protocol is unchanged (request_nonce -> personal_sign
// -> verify_signature); this hook only drives the UI states:
//   idle -> connecting -> signing -> verifying -> (redirect)
//   any step can end in an inline, retryable error. No alert() dialogs.
const MESSAGES = {
  4001: "You declined the request in your wallet. Click Try again when you're ready.",
  "-32002": "Your wallet already has a pending request. Open it to continue.",
};

export default {
  mounted() {
    this.button = this.el.querySelector("#loginButton");
    this.label = this.button.querySelector("[data-label]");
    this.status = this.el.querySelector("[data-status]");
    this.install = this.el.querySelector("[data-install]");
    this.address = null;
    this.step = "idle";

    this.onClick = () => this.login();
    this.button.addEventListener("click", this.onClick);

    // Server rejected sign-in (bad signature, expired nonce, ...).
    this.handleEvent("login_failed", ({ message }) => this.fail(message));

    // Switching or disconnecting the wallet mid-flow invalidates it. This
    // only resets local UI state; it never ends an established app session.
    this.accountsChangedHandler = (accounts) => {
      if (this.step === "idle") return;
      if (accounts.length === 0) this.pushEvent("wallet_disconnected", {});
      this.fail(
        accounts.length === 0
          ? "Your wallet was disconnected. Connect it again to continue."
          : "You switched accounts in your wallet. Try again with the account you want to use."
      );
    };
    window.ethereum?.on?.("accountsChanged", this.accountsChangedHandler);
  },

  destroyed() {
    this.button?.removeEventListener("click", this.onClick);
    window.ethereum?.removeListener?.("accountsChanged", this.accountsChangedHandler);
  },

  async login() {
    if (this.step !== "idle" && this.step !== "failed") return;

    if (!window.ethereum) {
      this.showInstallGuidance();
      return;
    }
    this.install.classList.add("hidden");

    this.setStep("connecting", "Connecting…", "Approve the connection in your wallet.");

    let address;
    try {
      const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
      address = accounts && accounts[0];
      if (!address) throw new Error("no account returned");
    } catch (err) {
      return this.fail(this.explain(err, "Could not connect to your wallet."));
    }
    this.address = address;

    // Step 1: ask the server for a nonce. Never send a bare address as proof.
    this.setStep("signing", "Confirm in wallet…", "Sign the message in your wallet. This is free and sends no transaction.");
    this.pushEvent("request_nonce", { address }, async (reply) => {
      if (!reply || reply.error || !reply.message) {
        return this.fail((reply && reply.error) || "The server could not start sign-in. Please try again.");
      }
      try {
        // Step 2: prove control of the address by signing the nonce.
        const signature = await window.ethereum.request({
          method: "personal_sign",
          params: [reply.message, address],
        });
        // Step 3: the server verifies and redirects to establish the session.
        this.setStep("verifying", "Verifying…", "Checking your signature…");
        this.pushEvent("verify_signature", { address, signature });
      } catch (err) {
        this.fail(this.explain(err, "Signing failed. Please try again."));
      }
    });
  },

  explain(err, fallback) {
    const code = err && err.code !== undefined ? String(err.code) : "";
    return MESSAGES[code] || fallback;
  },

  showInstallGuidance() {
    this.setStep("idle", "Connect Wallet", "");
    this.install.classList.remove("hidden");
    // On phones there is usually no extension; offer the MetaMask app's
    // in-app browser, which injects window.ethereum for this page.
    const mobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
    const link = this.install.querySelector("[data-mobile-link]");
    if (mobile && link) {
      link.href = `https://metamask.app.link/dapp/${location.host}${location.pathname}`;
      link.classList.remove("hidden");
    }
    this.status.textContent = "No wallet detected in this browser.";
  },

  fail(message) {
    this.setStep("failed", "Try again", message, true);
  },

  setStep(step, labelText, statusText, isError = false) {
    this.step = step;
    const busy = step === "connecting" || step === "signing" || step === "verifying";
    this.button.disabled = busy;
    this.button.setAttribute("aria-busy", busy ? "true" : "false");
    this.label.textContent = labelText;
    this.status.textContent = statusText;
    this.status.classList.toggle("text-red-400", isError);
    this.status.classList.toggle("text-bodydark1", !isError);
  },
};
