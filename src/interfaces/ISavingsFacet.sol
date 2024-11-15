// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISavingsFacet
 * @notice Interface for savings functionality and Safe integration
 */
interface ISavingsFacet {
    /**
     * @notice Represents the status of a user's savings
     */
    struct SavingsInfo {
        uint256 totalDeposited;      // Total amount user has deposited
        uint256 currentBalance;       // Current balance including yields
        uint256 lastDepositTime;      // Timestamp of last deposit
        bool isStaking;              // Whether funds are being staked
        address safeAddress;         // User's Safe address
        uint256 progressToGoal;      // Progress towards 32 ETH (in percentage)
        uint256 dailyTarget;         // Daily savings target
    }

    /**
     * @notice Emitted when a deposit is made
     */
    event Deposited(address indexed user, uint256 amount, uint256 newTotal);

    /**
     * @notice Emitted when a withdrawal is made
     */
    event Withdrawn(address indexed user, uint256 amount, string reason);

    /**
     * @notice Emitted when a Safe is created or linked
     */
    event SafeLinked(address indexed user, address indexed safeAddress);

    /**
     * @notice Emitted when staking status changes
     */
    event StakingStatusChanged(address indexed user, bool isStaking);

    /**
     * @notice Deposit ETH into savings
     * @param foodType Type of food to feed pet with this deposit
     */
    function deposit(uint8 foodType) external payable;

    /**
     * @notice Withdraw ETH from savings
     * @param amount Amount to withdraw
     * @param reason Reason for withdrawal
     */
    function withdraw(uint256 amount, string calldata reason) external;

    /**
     * @notice Link an existing Safe to the account
     * @param safeAddress Address of the Safe to link
     */
    function linkSafe(address safeAddress) external;

    /**
     * @notice Create and link a new Safe
     * @param owners Array of Safe owner addresses
     * @param threshold Number of required confirmations
     */
    function createSafe(address[] calldata owners, uint256 threshold) external;

    /**
     * @notice Begin staking process when 32 ETH is reached
     */
    function initiateStaking() external;

    /**
     * @notice Get user's savings information
     * @param user Address to query
     * @return SavingsInfo struct containing user's savings data
     */
    function getSavingsInfo(address user) external view returns (SavingsInfo memory);

    /**
     * @notice Check if user has enough balance to stake
     * @param user Address to check
     * @return bool indicating if user can stake
     */
    function canStake(address user) external view returns (bool);

    /**
     * @notice Get the Safe address for a user
     * @param user Address to query
     * @return Safe address
     */
    function getUserSafe(address user) external view returns (address);
}
