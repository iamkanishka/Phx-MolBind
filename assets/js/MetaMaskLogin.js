export default {
  mounted() {
    // Handle login button click
    this.el.addEventListener("click", async () => {
      if (!window.ethereum) {
        alert("Please install MetaMask.");
        return;
      }

      try {
        const accounts = await ethereum.request({ method: "eth_requestAccounts" });
        const address = accounts[0];

        this.pushEvent("metamask_login", { address });
      } catch (err) {
        console.error("MetaMask login failed:", err);
      }
    });

    // Handle account change in MetaMask
    ethereum?.on("accountsChanged", (accounts) => {
      if (accounts.length > 0) {
        this.pushEvent("metamask_login", { address: accounts[0] });
      } else {
        // If the user disconnected all accounts
        this.pushEvent("metamask_logout", {});
      }
    });
  },

  destroyed() {
    // Clean up listener when hook is removed
    window.ethereum?.removeAllListeners("accountsChanged");
  },
};
