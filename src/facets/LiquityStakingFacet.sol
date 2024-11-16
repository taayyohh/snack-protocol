// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ILiquityIntegration } from "../interfaces/ILiquityIntegration.sol";
import { IBorrowerOperations, ITroveManager, IStabilityPool, ILUSD } from "../interfaces/ILiquityCore.sol";

/**
 * @title LiquityStakingFacet
 * @notice Facilitates integration with the Liquity protocol for yield generation and collateralized borrowing.
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
        uint256 minCollateralRatio;
        uint256 borrowFee;
    }

    /// @dev Get Liquity storage
    function _getLiquityStorage() internal pure returns (LiquityStorage storage ls) {
        bytes32 position = keccak256("snack.protocol.storage.liquity");
        assembly {
            ls.slot := position
        }

        return ls;
    }

    /// @inheritdoc ILiquityIntegration
    function openPosition(uint256 borrowAmount) external payable override {
        require(msg.value > 0, "Insufficient collateral");

        LiquityStorage storage ls = _getLiquityStorage();
        require(!ls.positions[msg.sender].isActive, "Position already exists");

        uint256 maxBorrowAmount = _calculateMaxBorrow(msg.value);
        require(borrowAmount <= maxBorrowAmount, "Unsafe position ratio");

        ls.borrowerOperations.openTrove{value: msg.value}(
            ls.borrowFee,
            borrowAmount,
            msg.value,
            address(0),
            address(0)
        );

        ls.positions[msg.sender] = Position({
            collateral: msg.value,
            debt: borrowAmount,
            rewardsClaimed: 0,
            lastUpdate: block.timestamp,
            isActive: true
        });

        emit PositionOpened(msg.sender, msg.value, borrowAmount);
    }

    /// @inheritdoc ILiquityIntegration
    function addCollateral() external payable override {
        require(msg.value > 0, "Invalid collateral amount");

        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        require(position.isActive, "Position not found");

        ls.borrowerOperations.addColl{value: msg.value}(address(0), address(0));
        position.collateral += msg.value;
        position.lastUpdate = block.timestamp;

        emit CollateralAdded(msg.sender, msg.value);
    }

    /// @inheritdoc ILiquityIntegration
    function adjustDebt(uint256 newDebt) external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        require(position.isActive, "Position not found");

        uint256 maxBorrow = _calculateMaxBorrow(position.collateral);
        require(newDebt <= maxBorrow, "Unsafe position ratio");

        if (newDebt > position.debt) {
            uint256 borrowMore = newDebt - position.debt;
            ls.borrowerOperations.withdrawLUSD(ls.borrowFee, borrowMore, address(0), address(0));
        } else {
            uint256 repayAmount = position.debt - newDebt;
            ls.borrowerOperations.repayLUSD(repayAmount, address(0), address(0));
        }

        position.debt = newDebt;
        position.lastUpdate = block.timestamp;

        emit DebtAdjusted(msg.sender, newDebt);
    }

    /// @inheritdoc ILiquityIntegration
    function claimRewards() external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        require(position.isActive, "Position not found");

        uint256 ethGains = ls.stabilityPool.getDepositorETHGain(msg.sender);
        require(ethGains > 0, "No rewards available");

        ls.stabilityPool.withdrawFromSP(0);
        position.rewardsClaimed += ethGains;
        position.lastUpdate = block.timestamp;

        emit RewardsClaimed(msg.sender, 0, ethGains);
    }

    /// @inheritdoc ILiquityIntegration
    function closePosition() external override {
        LiquityStorage storage ls = _getLiquityStorage();
        Position storage position = ls.positions[msg.sender];
        require(position.isActive, "Position not found");

        ls.borrowerOperations.closeTrove();
        delete ls.positions[msg.sender];

        emit PositionClosed(msg.sender);
    }

    /// @inheritdoc ILiquityIntegration
    function getPosition(address user) external view override returns (Position memory position) {
        LiquityStorage storage ls = _getLiquityStorage();
        return ls.positions[user];
    }

    /// @inheritdoc ILiquityIntegration
    function getRewards(address user) external view override returns (uint256 lqtyRewards, uint256 ethGains) {
        LiquityStorage storage ls = _getLiquityStorage();
        ethGains = ls.stabilityPool.getDepositorETHGain(user);
        return (0, ethGains);
    }

    function _calculateMaxBorrow(uint256 collateralAmount) internal view returns (uint256) {
        LiquityStorage storage ls = _getLiquityStorage();
        return (collateralAmount * 100) / ls.minCollateralRatio;
    }
}
