import { ethers } from 'ethers';

export default {
    mounted() {
      // Initialize with wallet check
      this.checkWalletConnection();

      // Event listeners
      this.handleEvent("phx:fetchProfile", () => this.fetchProfile());
      
      // MetaMask event listeners
      if (window.ethereum) {
        window.ethereum.on('accountsChanged', (accounts) => {
          this.handleAccountsChanged(accounts);
        });
        
        window.ethereum.on('chainChanged', () => {
          window.location.reload();
        });
      }
    },

    async checkWalletConnection() {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
          this.pushEventTo("#profile-container", "wallet_connected", {address: accounts[0]});
        }
      } catch (error) {
        this.pushEventTo("#profile-container", "wallet_error", {error: error.message});
      }
    },

    async connectWallet() {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        this.pushEventTo("#profile-container", "wallet_connected", {address: accounts[0]});
      } catch (error) {
        this.pushEventTo("#profile-container", "wallet_error", {error: error.message});
      }
    },

    async fetchProfile() {
      const address = this.el.dataset.currentAddress;
      if (!address) return;

      try {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const contract = new ethers.Contract(
          this.el.dataset.contractAddress,
          JSON.parse(this.el.dataset.contractAbi),
          provider
        );

        const profile = await contract.getProfileByAddress(address);
        
        this.pushEventTo("#profile-container", "profile_loaded", {
          firstName: profile[0],
          lastName: profile[1],
          email: profile[2],
          bio: profile[3],
          photo: profile[4],
          address: {
            street: profile[5][0],
            city: profile[5][1],
            state: profile[5][2],
            country: profile[5][3],
            postalCode: profile[5][4]
          }
        });
      } catch (error) {
        this.pushEventTo("#profile-container", "wallet_error", {error: error.message});
      }
    },

    handleAccountsChanged(accounts) {
      if (accounts.length === 0) {
        this.pushEventTo("#profile-container", "wallet_error", {error: "Wallet disconnected"});
      } else {
        this.pushEventTo("#profile-container", "wallet_connected", {address: accounts[0]});
      }
    }
  }


 