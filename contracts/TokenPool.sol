// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenPool is Ownable, ReentrancyGuard {
    string public poolId;
    IERC20 public token;
    
    constructor(
        string memory _poolId, 
        address _token, 
        address _owner
    ) Ownable(_owner) {
        poolId = _poolId;
        token = IERC20(_token);
    }
    
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        token.transferFrom(msg.sender, address(this), amount);
    }
    
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        token.transfer(msg.sender, amount);
    }
    
    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}