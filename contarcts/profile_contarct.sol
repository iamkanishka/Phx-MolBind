// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserProfile {
    struct Profile {
        string firstName;
        string lastName;
        string email;
        string userBio;
        string photo;
        string id;
        string phone;
        bool exists;
    }
    
    mapping(address => Profile) private userProfiles;
    
    event ProfileCreated(address indexed userAddress);
    event ProfileUpdated(address indexed userAddress, string fieldUpdated);
    event ProfileDeleted(address indexed userAddress);
    
    /**
     * @dev Checks if a profile exists for the given address
     * @param _userAddress The address to check
     * @return bool True if profile exists, false otherwise
     */
    function profileExists(address _userAddress) public view returns (bool) {
        return userProfiles[_userAddress].exists;
    }
    
    /**
     * @dev Creates a new profile for the sender
     * @param _firstName User's first name
     * @param _lastName User's last name
     * @param _email User's email address
     * @param _userBio User's biography
     * @param _photo URL or hash of user's photo
     * @param _id User's ID string
     * @param _phone User's phone number
     */
    function createProfile(
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _userBio,
        string memory _photo,
        string memory _id,
        string memory _phone
    ) external {
        require(!userProfiles[msg.sender].exists, "Profile already exists");
        
        userProfiles[msg.sender] = Profile({
            firstName: _firstName,
            lastName: _lastName,
            email: _email,
            userBio: _userBio,
            photo: _photo,
            id: _id,
            phone: _phone,
            exists: true
        });
        
        emit ProfileCreated(msg.sender);
    }
    
    /**
     * @dev Updates the entire profile for the sender
     * @param _firstName Updated first name
     * @param _lastName Updated last name
     * @param _email Updated email
     * @param _userBio Updated bio
     * @param _photo Updated photo
     * @param _id Updated ID
     * @param _phone Updated phone
     */
    function updateProfile(
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _userBio,
        string memory _photo,
        string memory _id,
        string memory _phone
    ) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        
        userProfiles[msg.sender] = Profile({
            firstName: _firstName,
            lastName: _lastName,
            email: _email,
            userBio: _userBio,
            photo: _photo,
            id: _id,
            phone: _phone,
            exists: true
        });
        
        emit ProfileUpdated(msg.sender, "all");
    }
    
    // Individual update functions
    function updateFirstName(string memory _firstName) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].firstName = _firstName;
        emit ProfileUpdated(msg.sender, "firstName");
    }
    
    function updateLastName(string memory _lastName) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].lastName = _lastName;
        emit ProfileUpdated(msg.sender, "lastName");
    }
    
    function updateEmail(string memory _email) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].email = _email;
        emit ProfileUpdated(msg.sender, "email");
    }
    
    function updateUserBio(string memory _userBio) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].userBio = _userBio;
        emit ProfileUpdated(msg.sender, "userBio");
    }
    
    function updatePhoto(string memory _photo) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].photo = _photo;
        emit ProfileUpdated(msg.sender, "photo");
    }
    
    function updateId(string memory _id) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].id = _id;
        emit ProfileUpdated(msg.sender, "id");
    }
    
    function updatePhone(string memory _phone) external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        userProfiles[msg.sender].phone = _phone;
        emit ProfileUpdated(msg.sender, "phone");
    }
    
    /**
     * @dev Deletes the sender's profile
     */
    function deleteProfile() external {
        require(userProfiles[msg.sender].exists, "Profile does not exist");
        delete userProfiles[msg.sender];
        emit ProfileDeleted(msg.sender);
    }
    
    /**
     * @dev Gets the complete profile for a given address
     * @param _userAddress The address to look up
     * @return Profile data and existence flag
     */
    function getProfile(address _userAddress) external view returns (
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        bool
    ) {
        Profile memory profile = userProfiles[_userAddress];
        return (
            profile.firstName,
            profile.lastName,
            profile.email,
            profile.userBio,
            profile.photo,
            profile.id,
            profile.phone,
            profile.exists
        );
    }
    
    /**
     * @dev Gets the sender's complete profile
     * @return Profile data and existence flag
     */
    function getMyProfile() external view returns (
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        bool
    ) {
        Profile memory profile = userProfiles[msg.sender];
        return (
            profile.firstName,
            profile.lastName,
            profile.email,
            profile.userBio,
            profile.photo,
            profile.id,
            profile.phone,
            profile.exists
        );
    }
}