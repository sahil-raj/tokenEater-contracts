// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TokenPool.sol";

contract PoolFactory is Ownable {
    mapping(string => address) public pools;
    string[] public poolIds;

    event PoolCreated(string indexed poolId, address poolAddress);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function createPool(string memory poolId, address token, address owner) external onlyOwner returns (address) {
        require(bytes(poolId).length > 0, "Invalid pool ID");
        require(pools[poolId] == address(0), "Pool already exists");

        TokenPool pool = new TokenPool(poolId, token, owner);
        pools[poolId] = address(pool);
        poolIds.push(poolId);

        emit PoolCreated(poolId, address(pool));
        return address(pool);
    }

    function getAllPools() external view returns (string[] memory) {
        return poolIds;
    }

    function getPoolAddress(string memory poolId) external view returns (address) {
        return pools[poolId];
    }
}