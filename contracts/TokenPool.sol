// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenPool
 * @dev Individual pool contract that handles native currency (ETH) deposits and share management
 */
contract TokenPool is Ownable, ReentrancyGuard {
    // Pool information
    string public poolId;
    uint256 public totalDeposits;
    uint256 public lockTimestamp;
    
    // User share mappings
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userDeposits;
    address[] public depositors;
    
    // Events
    event TokensDeposited(address indexed user, uint256 amount, uint256 newShare);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event SharesUpdated(address indexed user, uint256 oldShare, uint256 newShare);
    event SharesBatchUpdated(address[] users, uint256[] newShares);
    
    /**
     * @dev Constructor for individual pool
     * @param _poolId Unique identifier for the pool
     * @param _owner Owner of the pool contract
     * @param _lockTimestamp Timestamp before which withdrawals are not allowed
     */
    constructor(
        string memory _poolId,
        address _owner,
        uint256 _lockTimestamp
    ) Ownable(_owner) {
        require(_owner != address(0), "Invalid owner address");
        require(_lockTimestamp > block.timestamp, "Lock timestamp must be in the future");
        
        poolId = _poolId;
        lockTimestamp = _lockTimestamp;
    }
    
    /**
     * @dev Deposit native currency to the pool
     */
    function depositTokens() external payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");
        
        // Update user's deposit amount
        if (userDeposits[msg.sender] == 0) {
            depositors.push(msg.sender);
        }
        userDeposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        
        // Calculate and update user's share (percentage * 10000 for precision)
        uint256 newShare = (userDeposits[msg.sender] * 10000) / totalDeposits;
        userShares[msg.sender] = newShare;
        
        // Recalculate all shares to maintain accuracy
        _recalculateAllShares();
        
        emit TokensDeposited(msg.sender, msg.value, newShare);
    }
    
    /**
     * @dev Withdraw native currency from the pool
     * @param amount Amount of currency to withdraw
     */
    function withdrawTokens(uint256 amount) external nonReentrant {
        require(block.timestamp >= lockTimestamp, "Withdrawals are locked until the specified timestamp");
        require(amount > 0, "Amount must be greater than 0");
        require(userDeposits[msg.sender] >= amount, "Insufficient deposits");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        // Update user's deposit amount
        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // If user has no more deposits, remove from depositors array and reset share
        if (userDeposits[msg.sender] == 0) {
            userShares[msg.sender] = 0;
            _removeDepositor(msg.sender);
        }
        
        // Recalculate all shares
        _recalculateAllShares();
        
        // Transfer currency back to user
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit TokensWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Update a single user's share (only owner)
     * @param user User address
     * @param newShare New share value (percentage * 10000)
     */
    function updateUserShare(address user, uint256 newShare) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(newShare <= 10000, "Share cannot exceed 100%");
        
        uint256 oldShare = userShares[user];
        userShares[user] = newShare;
        
        emit SharesUpdated(user, oldShare, newShare);
    }
    
    /**
     * @dev Update multiple users' shares in batch (only owner)
     * @param users Array of user addresses
     * @param newShares Array of new share values
     */
    function updateSharesBatch(
        address[] calldata users, 
        uint256[] calldata newShares
    ) external onlyOwner {
        require(users.length == newShares.length, "Arrays length mismatch");
        require(users.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user address");
            require(newShares[i] <= 10000, "Share cannot exceed 100%");
            userShares[users[i]] = newShares[i];
        }
        
        emit SharesBatchUpdated(users, newShares);
    }
    
    /**
     * @dev Force recalculation of all shares based on current deposits (only owner)
     */
    function recalculateShares() external onlyOwner {
        _recalculateAllShares();
    }
    
    /**
     * @dev Get pool information
     */
    function getPoolInfo() external view returns (
        string memory _poolId,
        uint256 _totalDeposits,
        uint256 _totalDepositors,
        uint256 _contractBalance,
        uint256 _lockTimestamp
    ) {
        return (poolId, totalDeposits, depositors.length, address(this).balance, lockTimestamp);
    }
    
    /**
     * @dev Get user information
     * @param user User address
     */
    function getUserInfo(address user) external view returns (
        uint256 deposits,
        uint256 share
    ) {
        return (userDeposits[user], userShares[user]);
    }
    
    /**
     * @dev Get all depositors
     */
    function getAllDepositors() external view returns (address[] memory) {
        return depositors;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Check if withdrawals are currently locked
     */
    function isWithdrawalLocked() external view returns (bool) {
        return block.timestamp < lockTimestamp;
    }
    
    /**
     * @dev Get remaining lock time in seconds
     */
    function getRemainingLockTime() external view returns (uint256) {
        if (block.timestamp >= lockTimestamp) {
            return 0;
        }
        return lockTimestamp - block.timestamp;
    }
    
    /**
     * @dev Emergency withdraw function for owner (only in case of emergency and after lock period)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner nonReentrant {
        require(block.timestamp >= lockTimestamp, "Emergency withdrawals are also locked until the specified timestamp");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Internal function to recalculate all shares based on deposits
     */
    function _recalculateAllShares() internal {
        if (totalDeposits == 0) return;
        
        for (uint256 i = 0; i < depositors.length; i++) {
            address depositor = depositors[i];
            if (userDeposits[depositor] > 0) {
                userShares[depositor] = (userDeposits[depositor] * 10000) / totalDeposits;
            }
        }
    }
    
    /**
     * @dev Internal function to remove depositor from array
     */
    function _removeDepositor(address depositor) internal {
        for (uint256 i = 0; i < depositors.length; i++) {
            if (depositors[i] == depositor) {
                depositors[i] = depositors[depositors.length - 1];
                depositors.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Fallback function to receive Ether
     */
    receive() external payable {
        // Allow the contract to receive Ether directly, but don't update shares automatically
        // Users should use depositTokens() for proper share calculation
    }
}