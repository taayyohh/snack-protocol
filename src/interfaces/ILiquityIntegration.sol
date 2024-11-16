// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILiquityIntegration
 * @notice Interface for integrating with the Liquity protocol.
 */
interface ILiquityIntegration {
    /**
     * @notice Position struct representing a user's Liquity position.
     */
    struct Position {
        uint256 collateral;    // Amount of ETH collateral in the position
        uint256 debt;          // Amount of LUSD debt in the position
        uint256 rewardsClaimed; // Total ETH rewards claimed
        uint256 lastUpdate;    // Timestamp of the last update
        bool isActive;         // Whether the position is active
    }

    /**
     * @notice Emitted when a new position is opened.
     * @param user Address of the user opening the position
     * @param collateral Amount of ETH collateral
     * @param debt Amount of LUSD debt
     */
    event PositionOpened(address indexed user, uint256 collateral, uint256 debt);

    /**
     * @notice Emitted when collateral is added to a position.
     * @param user Address of the user adding collateral
     * @param amount Amount of ETH added
     */
    event CollateralAdded(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a position's debt is adjusted.
     * @param user Address of the user adjusting debt
     * @param newDebt New total LUSD debt
     */
    event DebtAdjusted(address indexed user, uint256 newDebt);

    /**
     * @notice Emitted when rewards are claimed.
     * @param user Address of the user claiming rewards
     * @param lqtyRewards Amount of LQTY rewards claimed
     * @param ethGains Amount of ETH rewards claimed
     */
    event RewardsClaimed(address indexed user, uint256 lqtyRewards, uint256 ethGains);

    /**
     * @notice Emitted when a position is closed.
     * @param user Address of the user closing the position
     */
    event PositionClosed(address indexed user);

    /**
     * @notice Open a new Liquity position with ETH collateral.
     * @param borrowAmount Amount of LUSD to borrow
     */
    function openPosition(uint256 borrowAmount) external payable;

    /**
     * @notice Add collateral to an existing Liquity position.
     */
    function addCollateral() external payable;

    /**
     * @notice Adjust the debt of an existing Liquity position.
     * @param newDebt New total debt amount
     */
    function adjustDebt(uint256 newDebt) external;

    /**
     * @notice Claim rewards from the Stability Pool.
     */
    function claimRewards() external;

    /**
     * @notice Close the user's Liquity position.
     */
    function closePosition() external;

    /**
     * @notice Get the current position of a user.
     * @param user Address of the user
     * @return Position struct containing the user's position data
     */
    function getPosition(address user) external view returns (Position memory);

    /**
     * @notice Get the rewards available for a user.
     * @param user Address of the user
     * @return lqtyRewards LQTY rewards earned
     * @return ethGains ETH gains from the Stability Pool
     */
    function getRewards(address user) external view returns (uint256 lqtyRewards, uint256 ethGains);
}
