export default {
  mounted() {
    this.el.addEventListener("click", async () => {
      if (!window.ethereum) {
        alert("Please install MetaMask.");
        return;
      }

      try {
        await ethereum.request({ method: "eth_requestAccounts" });
        const accounts = await ethereum.request({ method: "eth_accounts" });
        const address = accounts[0];
        console.log(address);

        const message = `Login to MyApp at ${Date.now()}`;
        console.log(message);

        // const signature = await ethereum.request({
        //   method: "personal_sign",
        //   params: [message, address],
        // });

        function toHex(message) {
          return (
            "0x" +
            Array.from(new TextEncoder().encode(message))
              .map((b) => b.toString(16).padStart(2, "0"))
              .join("")
          );
        }
        // Convert message to hex
        const hexMessage = toHex(message);
        console.log("Hex Message:", hexMessage);

        try {
          const signature = await ethereum.request({
            method: "personal_sign",
            params: [hexMessage, address],
            // params: [address, message],
          });
          console.log("Signature:", signature);
        } catch (err) {
          console.error("Error during personal_sign:", err);
        }

        this.pushEvent("metamask_login", {
          message: message,
          signature: signature,
          address: address,
        });
      } catch (err) {
        console.error("MetaMask login failed:", err);
      }
    });
  },
};
