// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import "../../lib/safe-smart-account/contracts/Safe.sol";

/**
 * @title SavingsFacet
 * @notice Manages user savings, Safe integration, and coordinates with pet mechanics
 */
contract SavingsFacet is ISavingsFacet {
    uint256 constant STAKING_AMOUNT = 32 ether;

    struct SavingsStorage {
        mapping(address => SavingsInfo) savings;
        mapping(address => address) userSafes;
        uint256 totalSavings;
    }

    /**
     * @notice Retrieve the savings storage for the protocol
     * @return ss The storage struct containing all user savings data
     */
    function _getSavingsStorage() internal pure returns (SavingsStorage storage ss) {
        bytes32 position = keccak256("snack.protocol.storage.savings");
        assembly {
            ss.slot := position
        }

        return ss;
    }

    /**
     * @notice Deposit ETH into the savings contract
     */
    function deposit(uint8 /* unused */) external payable override {
        require(msg.value > 0, "Deposit must be greater than zero");
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        info.totalDeposited += msg.value;
        info.currentBalance += msg.value;
        emit Deposited(msg.sender, msg.value, info.currentBalance);
    }

    /**
     * @notice Withdraw ETH from the savings contract
     * @param amount The amount to withdraw
     * @param reason A string explaining the reason for the withdrawal
     */
    function withdraw(uint256 amount, string calldata reason) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        require(amount > 0, "Amount must be greater than zero");
        require(info.currentBalance >= amount, "Insufficient balance");

        info.currentBalance -= amount;
        emit Withdrawn(msg.sender, amount, reason);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Link an existing Safe to the user's account
     * @param safeAddress The address of the Safe to be linked
     */
    function linkSafe(address safeAddress) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        require(ss.userSafes[msg.sender] == address(0), "Safe already linked");

        ss.userSafes[msg.sender] = safeAddress;
        SavingsInfo storage info = ss.savings[msg.sender];
        info.safeAddress = safeAddress;

        emit SafeLinked(msg.sender, safeAddress);
    }

    /**
     * @notice Create a new Safe and link it to the user's account
     */
    function createSafe(address[] calldata /* unused */, uint256 /* unused */) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        require(ss.userSafes[msg.sender] == address(0), "Safe already linked");

        address safeAddress = address(new Safe()); // Simplified example
        ss.userSafes[msg.sender] = safeAddress;

        SavingsInfo storage info = ss.savings[msg.sender];
        info.safeAddress = safeAddress;

        emit SafeLinked(msg.sender, safeAddress);
    }

    /**
     * @notice Initiate staking with the user's balance
     */
    function initiateStaking() external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        require(info.currentBalance >= STAKING_AMOUNT, "Insufficient balance to stake");
        require(!info.isStaking, "Already staking");

        info.isStaking = true;
        emit StakingStatusChanged(msg.sender, true);
    }

    /**
     * @notice Retrieve the savings information for a specific user
     * @param user The address of the user
     * @return The SavingsInfo struct containing the user's savings details
     */
    function getSavingsInfo(address user) external view override returns (SavingsInfo memory) {
        return _getSavingsStorage().savings[user];
    }

    /**
     * @notice Check if a user can initiate staking
     * @param user The address of the user to check
     * @return True if the user meets the staking requirements
     */
    function canStake(address user) external view override returns (bool) {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[user];
        return info.currentBalance >= STAKING_AMOUNT && !info.isStaking;
    }

    /**
     * @notice Retrieve the Safe address linked to a user
     * @param user The address of the user
     * @return The address of the linked Safe
     */
    function getUserSafe(address user) external view override returns (address) {
        return _getSavingsStorage().userSafes[user];
    }

    /**
     * @notice Retrieve the total contributions and available balance of a user
     * @param user The address of the user
     * @return totalContributed The total amount the user has contributed
     * @return availableForWithdrawal The user's available balance
     */
    function getUserContributions(address user) external view returns (uint256 totalContributed, uint256 availableForWithdrawal) {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[user];
        totalContributed = info.totalDeposited;
        availableForWithdrawal = info.currentBalance;
    }
}
