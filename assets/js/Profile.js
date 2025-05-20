import { ethers } from "ethers";

const MetamaskUserHook = {
  mounted() {
    this.handleInitialize();
  },

  async handleInitialize() {
    // Check if MetaMask is installed
    if (window.ethereum) {
      try {
        // Request account access
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        this.userAddress = accounts[0];
        this.pushEvent("metamask_connected", { address: this.userAddress });
        
        // Set up provider and contract
        this.provider = new ethers.providers.Web3Provider(window.ethereum);
        this.signer = this.provider.getSigner();
        
        // Initialize contract (replace with your actual contract ABI and address)
        const contractABI = [/* Your contract ABI here */];
        const contractAddress = "0x..."; // Your contract address
        this.contract = new ethers.Contract(contractAddress, contractABI, this.signer);
        
        // Check if user exists
        await this.checkUserExists();
        
        // Listen for account changes
        window.ethereum.on('accountsChanged', (accounts) => {
          this.userAddress = accounts[0];
          this.pushEvent("metamask_account_changed", { address: this.userAddress });
          this.checkUserExists();
        });
        
      } catch (error) {
        console.error("User denied account access", error);
        this.pushEvent("metamask_error", { error: "Access denied" });
      }
    } else {
      this.pushEvent("metamask_error", { error: "MetaMask not installed" });
    }
  },

  async checkUserExists() {
    try {
      const exists = await this.contract.profileExists(this.userAddress);
      this.pushEvent("user_exists_check", { exists: exists, address: this.userAddress });
      
      if (!exists) {
        // You might want to show a form to create profile
        this.pushEvent("user_does_not_exist", { address: this.userAddress });
      }
    } catch (error) {
      console.error("Error checking user existence:", error);
      this.pushEvent("metamask_error", { error: error.message });
    }
  },

  async createUserProfile(profileData) {
    try {
      const tx = await this.contract.createProfile(
        profileData.firstName,
        profileData.lastName,
        profileData.email,
        profileData.userBio,
        profileData.photo,
        profileData.id,
        profileData.phone
      );
      
      await tx.wait();
      this.pushEvent("profile_created", { address: this.userAddress });
      return true;
    } catch (error) {
      console.error("Error creating profile:", error);
      this.pushEvent("metamask_error", { error: error.message });
      return false;
    }
  },

  async updateUserProfile(profileData) {
    try {
      const tx = await this.contract.updateProfile(
        profileData.firstName,
        profileData.lastName,
        profileData.email,
        profileData.userBio,
        profileData.photo,
        profileData.id,
        profileData.phone
      );
      
      await tx.wait();
      this.pushEvent("profile_updated", { address: this.userAddress });
      return true;
    } catch (error) {
      console.error("Error updating profile:", error);
      this.pushEvent("metamask_error", { error: error.message });
      return false;
    }
  },

  async getUserProfile() {
    try {
      const profile = await this.contract.getProfile(this.userAddress);
      this.pushEvent("profile_retrieved", { 
        address: this.userAddress,
        profile: {
          firstName: profile[0],
          lastName: profile[1],
          email: profile[2],
          userBio: profile[3],
          photo: profile[4],
          id: profile[5],
          phone: profile[6],
          exists: profile[7]
        }
      });
      return profile;
    } catch (error) {
      console.error("Error getting profile:", error);
      this.pushEvent("metamask_error", { error: error.message });
      return null;
    }
  }
};

export default MetamaskUserHook;