// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibDiamond.sol";
import "../interfaces/ISavingsLiquityConnector.sol";
import "../interfaces/ISavingsFacet.sol";
import "../interfaces/ILiquityIntegration.sol";

/**
 * @title SavingsLiquityConnector
 * @notice Manages the interaction between savings and Liquity positions
 */
contract SavingsLiquityConnector is ISavingsLiquityConnector {
    /**
     * @dev Storage for yield strategies
     */
    struct ConnectorStorage {
        mapping(address => YieldStrategy) strategies;
        uint256 minimumAllocation;  // Minimum amount that can be allocated
        uint256 maxAllocationPercentage;  // Maximum % of savings that can be allocated
    }

    /**
     * @dev Get connector storage
     */
    function _getStorage() internal pure returns (ConnectorStorage storage cs) {
        bytes32 position = keccak256("snack.protocol.storage.connector");
        assembly {
            cs.slot := position
        }
        return cs;
    }

    /**
     * @notice Allocate savings to Liquity yield generation
     * @param amount Amount to allocate
     */
    function allocateToLiquity(uint256 amount) external override {
        ConnectorStorage storage cs = _getStorage();
        YieldStrategy storage strategy = cs.strategies[msg.sender];

        // Get user's savings info
        ISavingsFacet savings = ISavingsFacet(address(this));
        ISavingsFacet.SavingsInfo memory savingsInfo = savings.getSavingsInfo(msg.sender);

        // Validate allocation
        if (amount < cs.minimumAllocation) revert InsufficientSavings();
        if (amount > savingsInfo.currentBalance) revert InsufficientSavings();

        uint256 allocationPercentage = (amount * 100) / savingsInfo.currentBalance;
        if (allocationPercentage > cs.maxAllocationPercentage) revert UnsafeAllocation();

        // Open or update Liquity position
        ILiquityIntegration liquity = ILiquityIntegration(address(this));

        if (!strategy.isActive) {
            // Calculate safe LUSD borrow amount (e.g., 50% of collateral)
            uint256 borrowAmount = amount * 50 / 100;
            liquity.openPosition{value: amount}(borrowAmount);

            strategy.isActive = true;
            strategy.lusdMinted = borrowAmount;
        } else {
            liquity.addCollateral{value: amount}();
        }

        // Update strategy
        strategy.savingsAllocated += amount;
        strategy.lastYieldClaim = block.timestamp;

        emit SavingsAllocated(msg.sender, amount);
    }

    /**
     * @notice Claim generated yields
     */
    function claimYield() external override returns (uint256) {
        ConnectorStorage storage cs = _getStorage();
        YieldStrategy storage strategy = cs.strategies[msg.sender];

        if (!strategy.isActive) revert NoSavingsAllocated();

        // Get yields from Liquity
        ILiquityIntegration liquity = ILiquityIntegration(address(this));
        (uint256 lqtyRewards, uint256 ethGains) = liquity.getRewards(msg.sender);

        if (ethGains == 0) revert NoYieldAvailable();

        // Claim rewards
        liquity.claimRewards();

        // Update strategy
        strategy.totalYieldGenerated += ethGains;
        strategy.lastYieldClaim = block.timestamp;

        emit YieldGenerated(msg.sender, ethGains, block.timestamp);

        return ethGains;
    }

    /**
     * @notice Get user's yield strategy details
     */
    function getYieldStrategy(address user) external view override returns (YieldStrategy memory) {
        return _getStorage().strategies[user];
    }
}
