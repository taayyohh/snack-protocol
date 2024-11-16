// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISavingsLiquityConnector
 * @notice Manages the interaction between savings and Liquity yield generation
 */
interface ISavingsLiquityConnector {
    /**
     * @notice Represents a user's yield strategy details
     */
    struct YieldStrategy {
        bool isActive;
        uint256 savingsAllocated;
        uint256 lastYieldClaim;
        uint256 totalYieldGenerated;
        uint256 lusdMinted;
    }

    /**
     * @notice Emitted when savings are allocated to Liquity
     */
    event SavingsAllocated(address indexed user, uint256 amount);

    /**
     * @notice Emitted when yields are generated and claimed
     */
    event YieldGenerated(address indexed user, uint256 amount, uint256 timestamp);

    /**
     * @notice Error cases
     */
    error NoSavingsAllocated();
    error InsufficientSavings();
    error NoYieldAvailable();
    error StrategyAlreadyActive();
    error UnsafeAllocation();

    /**
     * @notice Allocate savings to Liquity yield generation
     * @param amount Amount to allocate
     */
    function allocateToLiquity(uint256 amount) external;

    /**
     * @notice Claim generated yields
     */
    function claimYield() external returns (uint256);

    /**
     * @notice Get user's yield strategy details
     */
    function getYieldStrategy(address user) external view returns (YieldStrategy memory);
}
