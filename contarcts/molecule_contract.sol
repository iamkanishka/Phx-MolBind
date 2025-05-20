// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MoleculeStorage {
    struct MoleculeEntry {
        string algorithm;
        uint256 numMolecules;
        string propertyName;
        bool minimize;
        uint256 particles;
        uint256 iterations;
        string smiles;
        string[] generatedMolecules; // Now an array of strings
        uint256 minSimilarityScaled; // e.g., 0.82 => 8200 (4 decimal precision)
    }

    mapping(address => MoleculeEntry[]) public userEntries;

    event MoleculeAdded(address indexed user, uint256 entryIndex);

    function addMoleculeEntry(
        string memory _algorithm,
        uint256 _numMolecules,
        string memory _propertyName,
        bool _minimize,
        uint256 _particles,
        uint256 _iterations,
        string memory _smiles,
        string[] memory _generatedMolecules,
        uint256 _minSimilarityScaled
    ) public {
        MoleculeEntry memory newEntry = MoleculeEntry({
            algorithm: _algorithm,
            numMolecules: _numMolecules,
            propertyName: _propertyName,
            minimize: _minimize,
            particles: _particles,
            iterations: _iterations,
            smiles: _smiles,
            generatedMolecules: _generatedMolecules,
            minSimilarityScaled: _minSimilarityScaled
        });

        userEntries[msg.sender].push(newEntry);
        emit MoleculeAdded(msg.sender, userEntries[msg.sender].length - 1);
    }

    function getMoleculeCount(address user) external view returns (uint256) {
        return userEntries[user].length;
    }

    function getMoleculeByIndex(address user, uint256 index) external view returns (
        string memory,
        uint256,
        string memory,
        bool,
        uint256,
        uint256,
        string memory,
        string[] memory,
        uint256
    ) {
        require(index < userEntries[user].length, "Index out of bounds");
        MoleculeEntry memory m = userEntries[user][index];
        return (
            m.algorithm,
            m.numMolecules,
            m.propertyName,
            m.minimize,
            m.particles,
            m.iterations,
            m.smiles,
            m.generatedMolecules,
            m.minSimilarityScaled
        );
    }
}
