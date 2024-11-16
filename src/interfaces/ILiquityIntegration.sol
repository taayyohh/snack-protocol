// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILiquityIntegration
 * @notice Interface for Liquity V2 protocol integration
 */
interface ILiquityIntegration {
    /**
     * @notice Position status in Liquity
     */
    struct Position {
        uint256 collateral;      // ETH amount deposited
        uint256 debt;            // LUSD borrowed
        uint256 rewardsClaimed;  // LQTY rewards claimed
        uint256 lastUpdate;      // Last position update timestamp
        bool isActive;           // Whether position is active
    }

    /**
     * @notice Emitted when a new position is opened
     */
    event PositionOpened(address indexed user, uint256 collateral, uint256 debt);

    /**
     * @notice Emitted when collateral is added
     */
    event CollateralAdded(address indexed user, uint256 amount);

    /**
     * @notice Emitted when debt is adjusted
     */
    event DebtAdjusted(address indexed user, uint256 newDebt);

    /**
     * @notice Emitted when rewards are claimed
     */
    event RewardsClaimed(address indexed user, uint256 lqtyAmount, uint256 ethGains);

    /**
     * @notice Errors
     */
    error InsufficientCollateral();
    error PositionNotFound();
    error InvalidAmount();
    error UnsafePositionRatio();
    error PositionAlreadyExists();
    error NoRewardsAvailable();

    /**
     * @notice Open a new position with ETH collateral
     * @param borrowAmount Amount of LUSD to borrow
     */
    function openPosition(uint256 borrowAmount) external payable;

    /**
     * @notice Add collateral to existing position
     */
    function addCollateral() external payable;

    /**
     * @notice Adjust position's debt (borrow more or repay)
     * @param newDebt New total debt amount
     */
    function adjustDebt(uint256 newDebt) external;

    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards() external;

    /**
     * @notice Close position and withdraw all collateral
     */
    function closePosition() external;

    /**
     * @notice Get user's current position
     * @param user Address to query
     * @return Position struct with user's position details
     */
    function getPosition(address user) external view returns (Position memory);

    /**
     * @notice Get user's current reward amounts
     * @param user Address to query
     * @return lqtyRewards Amount of LQTY rewards
     * @return ethGains ETH gained from liquidations
     */
    function getRewards(address user) external view returns (uint256 lqtyRewards, uint256 ethGains);
}
