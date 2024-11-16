// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { ILiquityIntegration } from "../interfaces/ILiquityIntegration.sol";
import { IBorrowerOperations, ITroveManager, IStabilityPool, ILUSD } from "../interfaces/ILiquityCore.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";

/**
 * @title LiquityStakingFacet
 * @notice Manages Liquity V2 integration for yield generation
 */
contract LiquityStakingFacet is ILiquityIntegration {
    /**
     * @dev Storage for Liquity-related data
     */
    struct LiquityStorage {
        IBorrowerOperations borrowerOperations;
        ITroveManager troveManager;
        IStabilityPool stabilityPool;
        ILUSD lusdToken;
        mapping(address => Position) positions;
        uint256 minCollateralRatio;  // Minimum collateral ratio (in percentage)
        uint256 borrowFee;           // Borrowing fee (in percentage)
    }

    /**
     * @dev Get Liquity storage
     */
    function _getLiquityStorage() internal pure returns (LiquityStorage storage ls) {
        bytes32 position = keccak256("snack.protocol.storage.liquity");
        assembly {
            ls.slot := position
        }
        return ls;
    }

    /**
     * @notice Open a new Liquity position with ETH collateral
     * @param borrowAmount Amount of LUSD to borrow
     */
    function openPosition(uint256 borrowAmount) external payable override {
        if (msg.value == 0) revert InsufficientCollateral();

        LiquityStorage storage ls = _getLiquityStorage();
        if (ls.positions[msg.sender].isActive) revert PositionAlreadyExists();

        // Calculate safe borrowing amount based on collateral
        uint256 maxBorrowAmount = _calculateMaxBorrow(msg.value);
        if (borrowAmount > maxBorrowAmount) revert UnsafePositionRatio();

        // Open Trove (Liquity's term for a position)
        ls.borrowerOperations.openTrove{value: msg.value}(
            ls.borrowFee,
            borrowAmount,
            msg.value,
            address(0), // Upper hint - optimized later
            address(0)  // Lower hint - optimized later
        );

        // Update storage
        ls.positions[msg.sender] = Position({
            collateral: msg.value,
            debt: borrowAmount,
            rewardsClaimed: 0,
            lastUpdate: block.timestamp,
            isActive: true
        });

        emit PositionOpened(msg.sender, msg.value, borrowAmount);
    }

    /**
     * @notice Add collateral to existing position
     */
    function addCollateral() external payable override {
        if (msg.value == 0) revert InvalidAmount();

        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        if (!position.isActive) revert PositionNotFound();

        // Add collateral to Trove
        ls.borrowerOperations.addColl{value: msg.value}(
            address(0), // Upper hint
            address(0)  // Lower hint
        );

        // Update storage
        position.collateral += msg.value;
        position.lastUpdate = block.timestamp;

        emit CollateralAdded(msg.sender, msg.value);
    }

    /**
     * @notice Adjust position's debt
     * @param newDebt New total debt amount
     */
    function adjustDebt(uint256 newDebt) external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        if (!position.isActive) revert PositionNotFound();

        uint256 maxBorrow = _calculateMaxBorrow(position.collateral);
        if (newDebt > maxBorrow) revert UnsafePositionRatio();

        if (newDebt > position.debt) {
            // Borrow more
            uint256 borrowMore = newDebt - position.debt;
            ls.borrowerOperations.withdrawLUSD(
                ls.borrowFee,
                borrowMore,
                address(0),
                address(0)
            );
        } else {
            // Repay debt
            uint256 repayAmount = position.debt - newDebt;
            ls.borrowerOperations.repayLUSD(
                repayAmount,
                address(0),
                address(0)
            );
        }

        position.debt = newDebt;
        position.lastUpdate = block.timestamp;

        emit DebtAdjusted(msg.sender, newDebt);
    }

    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards() external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        if (!position.isActive) revert PositionNotFound();

        // Claim ETH gains from stability pool if any
        uint256 ethGains = ls.stabilityPool.getDepositorETHGain(msg.sender);

        if (ethGains == 0) revert NoRewardsAvailable();

        // Withdraw from stability pool
        ls.stabilityPool.withdrawFromSP(0); // 0 to just claim rewards

        position.rewardsClaimed += ethGains;
        position.lastUpdate = block.timestamp;

        emit RewardsClaimed(msg.sender, 0, ethGains);
    }

    /**
     * @notice Close position and withdraw all collateral
     */
    function closePosition() external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        if (!position.isActive) revert PositionNotFound();

        // Close Trove
        ls.borrowerOperations.closeTrove();

        // Clean up storage
        delete ls.positions[msg.sender];
    }

    /**
     * @notice Get user's current position
     */
    function getPosition(address user) external view override returns (Position memory) {
        return _getLiquityStorage().positions[user];
    }

    /**
     * @notice Get user's current rewards
     */
    function getRewards(address user) external view override returns (uint256 lqtyRewards, uint256 ethGains) {
        LiquityStorage storage ls = _getLiquityStorage();
        ethGains = ls.stabilityPool.getDepositorETHGain(user);
        // LQTY rewards would be implemented based on Liquity V2 specs
        return (0, ethGains);
    }

    /**
     * @dev Calculate maximum safe borrowing amount
     */
    function _calculateMaxBorrow(uint256 collateralAmount) internal view returns (uint256) {
        LiquityStorage storage ls = _getLiquityStorage();
        return (collateralAmount * 100) / ls.minCollateralRatio;
    }
}
