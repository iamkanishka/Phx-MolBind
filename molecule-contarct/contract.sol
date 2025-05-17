// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MoleculeOptimizationStorage {
    struct MoleculeOptimization {
        string algorithm;
        uint256 numMolecules;
        string propertyName;
        bool minimize;
        uint256 minSimilarity; // Stored as basis points (e.g., 0.75 => 7500)
        uint256 particles;
        uint256 iterations;
        string smiles;
        string generatedMolecules; // JSON string representation
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => MoleculeOptimization[]) private userOptimizations;

    event OptimizationAdded(address indexed user, uint256 index);
    event OptimizationUpdated(address indexed user, uint256 index);

    modifier validIndex(uint256 index) {
        require(index < userOptimizations[msg.sender].length, "Invalid index");
        _;
    }

    function addOptimization(
        string memory algorithm,
        uint256 numMolecules,
        string memory propertyName,
        bool minimize,
        uint256 minSimilarity, // Expected in basis points
        uint256 particles,
        uint256 iterations,
        string memory smiles,
        string memory generatedMolecules
    ) public {
        MoleculeOptimization memory newOptimization = MoleculeOptimization({
            algorithm: algorithm,
            numMolecules: numMolecules,
            propertyName: propertyName,
            minimize: minimize,
            minSimilarity: minSimilarity,
            particles: particles,
            iterations: iterations,
            smiles: smiles,
            generatedMolecules: generatedMolecules,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        userOptimizations[msg.sender].push(newOptimization);
        emit OptimizationAdded(msg.sender, userOptimizations[msg.sender].length - 1);
    }

    function updateOptimization(
        uint256 index,
        string memory algorithm,
        uint256 numMolecules,
        string memory propertyName,
        bool minimize,
        uint256 minSimilarity, // Expected in basis points
        uint256 particles,
        uint256 iterations,
        string memory smiles,
        string memory generatedMolecules
    ) public validIndex(index) {
        MoleculeOptimization storage optimization = userOptimizations[msg.sender][index];
        optimization.algorithm = algorithm;
        optimization.numMolecules = numMolecules;
        optimization.propertyName = propertyName;
        optimization.minimize = minimize;
        optimization.minSimilarity = minSimilarity;
        optimization.particles = particles;
        optimization.iterations = iterations;
        optimization.smiles = smiles;
        optimization.generatedMolecules = generatedMolecules;
        optimization.updatedAt = block.timestamp;

        emit OptimizationUpdated(msg.sender, index);
    }

    function getOptimization(address user, uint256 index) public view returns (
        string memory algorithm,
        uint256 numMolecules,
        string memory propertyName,
        bool minimize,
        uint256 minSimilarity,
        uint256 particles,
        uint256 iterations,
        string memory smiles,
        string memory generatedMolecules,
        uint256 createdAt,
        uint256 updatedAt
    ) {
        require(index < userOptimizations[user].length, "Invalid index");
        MoleculeOptimization storage optimization = userOptimizations[user][index];
        return (
            optimization.algorithm,
            optimization.numMolecules,
            optimization.propertyName,
            optimization.minimize,
            optimization.minSimilarity,
            optimization.particles,
            optimization.iterations,
            optimization.smiles,
            optimization.generatedMolecules,
            optimization.createdAt,
            optimization.updatedAt
        );
    }

    function getOptimizationCount(address user) public view returns (uint256) {
        return userOptimizations[user].length;
    }
}
