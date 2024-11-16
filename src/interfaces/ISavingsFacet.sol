// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISavingsFacet
 * @notice Interface for managing user savings, Safe integration, and staking coordination
 */
interface ISavingsFacet {
    /**
     * @notice Represents the status of a user's savings
     */
    struct SavingsInfo {
        uint256 totalDeposited;      // Total amount user has deposited
        uint256 currentBalance;      // Current balance including yields
        uint256 lastDepositTime;     // Timestamp of last deposit
        bool isStaking;              // Whether funds are being staked
        address safeAddress;         // User's Safe address
    }

    /**
     * @notice Emitted when a deposit is made
     * @param user Address of the user making the deposit
     * @param amount Amount of ETH deposited
     * @param newTotal New total savings balance
     */
    event Deposited(address indexed user, uint256 amount, uint256 newTotal);

    /**
     * @notice Emitted when a withdrawal is made
     * @param user Address of the user making the withdrawal
     * @param amount Amount of ETH withdrawn
     * @param reason Reason for the withdrawal
     */
    event Withdrawn(address indexed user, uint256 amount, string reason);

    /**
     * @notice Emitted when a Safe is created or linked
     * @param user Address of the user linking the Safe
     * @param safeAddress Address of the linked Safe
     */
    event SafeLinked(address indexed user, address indexed safeAddress);

    /**
     * @notice Emitted when staking status changes
     * @param user Address of the user changing staking status
     * @param isStaking Boolean indicating if staking is active
     */
    event StakingStatusChanged(address indexed user, bool isStaking);

    /**
     * @notice Emitted when funds are allocated to Liquity
     * @param user Address of the user allocating funds
     * @param liquityFacetAddress Address of the Liquity integration facet
     * @param amount Amount of ETH allocated
     */
    event AllocatedToLiquity(address indexed user, address indexed liquityFacetAddress, uint256 amount);

    /**
     * @notice The required amount for staking
     */
    function STAKING_AMOUNT() external view returns (uint256);

    /**
     * @notice The address of the Safe singleton contract
     */
    function SAFE_SINGLETON() external view returns (address);

    /**
     * @notice The address of the Safe factory contract
     */
    function SAFE_FACTORY() external view returns (address);

    /**
     * @notice Deposit ETH into savings
     */
    function deposit() external payable;

    /**
     * @notice Deposit ETH directly into a user's Safe
     */
    function depositToSafe() external payable;

    /**
     * @notice Withdraw ETH from savings
     * @param amount Amount to withdraw
     * @param reason Reason for the withdrawal
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
     * @notice Allocate ETH from Safe to Liquity
     * @param amount Amount of ETH to allocate
     * @param liquityFacetAddress Address of the LiquityStakingFacet
     */
    function allocateToLiquity(uint256 amount, address liquityFacetAddress) external;

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
     * @return Address of the user's linked Safe
     */
    function getUserSafe(address user) external view returns (address);

    /**
     * @notice Get user's contribution and balance information
     * @param user The address of the user
     * @return totalContributed The total amount the user has contributed
     * @return availableForWithdrawal The amount available for withdrawal
     */
    function getUserContributions(address user) external view returns (uint256 totalContributed, uint256 availableForWithdrawal);
}
