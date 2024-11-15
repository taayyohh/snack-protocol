// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";
import { IPetFacet } from "../interfaces/IPetFacet.sol";
import "../../lib/safe-smart-account/contracts/Safe.sol";
import "../../lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @title SavingsFacet
 * @notice Manages user savings, Safe integration, and coordinates with pet mechanics
 * @dev Integrates with Safe for secure fund management and pet system for gamification
 */
contract SavingsFacet is ISavingsFacet {
    // Constants
    uint256 constant STAKING_AMOUNT = 32 ether;
    uint256 constant MIN_DEPOSIT = 0.000333 ether;

    event YieldGenerated(address indexed user, uint256 amount);
    event StakingInitiated(address indexed user, uint256 amount);
    event DailyTargetMet(address indexed user, uint256 amount);

    error ExceedsContribution();
    error SafeOperationFailed();
    error StakingConditionsNotMet();
    error DailyLimitExceeded();
    error YieldClaimFailed();
    error NoSafeLinked();
    error SafeAlreadyLinked();
    error InvalidSafeAddress();
    error InsufficientBalance();
    error InvalidAmount();
    error NotEnoughForStaking();
    error StakingInProgress();

    /**
     * @dev Storage for savings-related data
     */
    struct SavingsStorage {
        mapping(address => SavingsInfo) savings;
        mapping(address => address) userSafes;
        mapping(address => UserContributions) contributions;
        uint256 totalSavings;
        SafeProxyFactory safeFactory;
        Safe safeSingleton;
        mapping(address => uint256) dailySavings;
        mapping(address => uint256) lastSavingDay;
    }

    /**
     * @dev Track individual user contributions
     */
    struct UserContributions {
        uint256 totalContributed;
        uint256 availableForWithdrawal;
        uint256 yieldsGenerated;
        uint256 lastYieldClaim;
    }

    /**
     * @dev Get savings storage
     */
    function _getSavingsStorage() internal pure returns (SavingsStorage storage ss) {
        bytes32 position = keccak256("snack.protocol.storage.savings");
        assembly {
            ss.slot := position
        }
        return ss;
    }

    /**
     * @notice Deposit ETH into savings and feed pet
     * @param foodType The type of food to feed the pet with this deposit
     */
    function deposit(uint8 foodType) external payable override {
        if (msg.value < MIN_DEPOSIT) revert InvalidAmount();

        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];
        UserContributions storage contributions = ss.contributions[msg.sender];

        // Check daily savings limit
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay != ss.lastSavingDay[msg.sender]) {
            ss.dailySavings[msg.sender] = 0;
            ss.lastSavingDay[msg.sender] = currentDay;
        }
        ss.dailySavings[msg.sender] += msg.value;

        // Update contribution tracking
        contributions.totalContributed += msg.value;
        contributions.availableForWithdrawal += msg.value;

        // Update general savings info
        info.totalDeposited += msg.value;
        info.currentBalance += msg.value;
        info.lastDepositTime = block.timestamp;

        // Feed pet
        IPetFacet petFacet = IPetFacet(address(this));
        petFacet.feed{value: msg.value}(IPetFacet.FoodType(foodType));

        // Forward to Safe if exists
        if (info.safeAddress != address(0)) {
            (bool success,) = info.safeAddress.call{value: msg.value}("");
            if (!success) revert SafeOperationFailed();
        }

        ss.totalSavings += msg.value;
        info.progressToGoal = (info.currentBalance * 100) / STAKING_AMOUNT;

        // Check if daily target met
        if (ss.dailySavings[msg.sender] >= info.dailyTarget) {
            emit DailyTargetMet(msg.sender, ss.dailySavings[msg.sender]);
        }

        emit Deposited(msg.sender, msg.value, info.currentBalance);
    }

    /**
     * @notice Withdraw ETH from savings
     * @dev Only allows withdrawal of user's own contributions minus any staked amount
     */
    function withdraw(uint256 amount, string calldata reason) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];
        UserContributions storage contributions = ss.contributions[msg.sender];

        if (info.isStaking) revert StakingInProgress();
        if (amount > contributions.availableForWithdrawal) revert InsufficientBalance();
        if (info.safeAddress == address(0)) revert NoSafeLinked();

        // Update contribution tracking
        contributions.availableForWithdrawal -= amount;
        info.currentBalance -= amount;

        // Execute withdrawal through Safe
        bytes memory data = "";
        bool success = Safe(info.safeAddress).execTransaction(
            payable(msg.sender),
            amount,
            data,
            Safe.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            new bytes(0)
        );

        if (!success) revert SafeOperationFailed();

        info.progressToGoal = (info.currentBalance * 100) / STAKING_AMOUNT;
        ss.totalSavings -= amount;

        emit Withdrawn(msg.sender, amount, reason);
    }

    /**
     * @notice Claim generated yield
     */
    function claimYield() external {
        SavingsStorage storage ss = _getSavingsStorage();
        UserContributions storage contributions = ss.contributions[msg.sender];
        SavingsInfo storage info = ss.savings[msg.sender];

        if (contributions.yieldsGenerated == 0) revert YieldClaimFailed();

        uint256 yieldAmount = contributions.yieldsGenerated;
        contributions.yieldsGenerated = 0;
        contributions.lastYieldClaim = block.timestamp;

        // Transfer yield through Safe
        bytes memory data = "";
        bool success = Safe(info.safeAddress).execTransaction(
            payable(msg.sender),
            yieldAmount,
            data,
            Safe.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            new bytes(0)
        );

        if (!success) revert YieldClaimFailed();

        emit YieldGenerated(msg.sender, yieldAmount);
    }

    /**
     * @notice Link existing Safe
     */
    function linkSafe(address safeAddress) external override {
        if (safeAddress == address(0)) revert InvalidSafeAddress();

        SavingsStorage storage ss = _getSavingsStorage();
        if (ss.userSafes[msg.sender] != address(0)) revert SafeAlreadyLinked();

        // Verify it's a valid Safe and user is owner
        require(Safe(safeAddress).isOwner(msg.sender), "Not Safe owner");

        ss.userSafes[msg.sender] = safeAddress;
        ss.savings[msg.sender].safeAddress = safeAddress;

        emit SafeLinked(msg.sender, safeAddress);
    }

    /**
     * @notice Create new Safe
     */
    function createSafe(address[] calldata owners, uint256 threshold) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        if (ss.userSafes[msg.sender] != address(0)) revert SafeAlreadyLinked();

        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            threshold,
            address(0),
            "",
            address(0),
            address(0),
            0,
            payable(address(0))
        );

        address safeAddress = address(ss.safeFactory.createProxyWithNonce(
            address(ss.safeSingleton),
            initializer,
            block.timestamp
        ));

        ss.userSafes[msg.sender] = safeAddress;
        ss.savings[msg.sender].safeAddress = safeAddress;

        emit SafeLinked(msg.sender, safeAddress);
    }

    /**
     * @notice Begin staking process when requirements are met
     */
    function initiateStaking() external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];
        UserContributions storage contributions = ss.contributions[msg.sender];

        if (info.currentBalance < STAKING_AMOUNT) revert NotEnoughForStaking();
        if (info.safeAddress == address(0)) revert NoSafeLinked();
        if (info.isStaking) revert StakingInProgress();

        // Additional checks for staking requirements
        if (!_checkStakingConditions(msg.sender)) revert StakingConditionsNotMet();

        info.isStaking = true;
        contributions.availableForWithdrawal -= STAKING_AMOUNT; // Lock staked amount

        emit StakingInitiated(msg.sender, STAKING_AMOUNT);
        emit StakingStatusChanged(msg.sender, true);
    }

    /**
     * @notice Check if all staking conditions are met
     */
    function _checkStakingConditions(address user) internal view returns (bool) {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[user];
        UserContributions storage contributions = ss.contributions[user];

        return (
            info.currentBalance >= STAKING_AMOUNT &&
            contributions.availableForWithdrawal >= STAKING_AMOUNT &&
            !info.isStaking &&
            info.safeAddress != address(0)
        );
    }

    /**
     * @notice Get user's savings information
     */
    function getSavingsInfo(address user) external view override returns (SavingsInfo memory) {
        return _getSavingsStorage().savings[user];
    }

    /**
     * @notice Check if user can stake
     */
    function canStake(address user) external view override returns (bool) {
        return _checkStakingConditions(user);
    }

    /**
     * @notice Get user's Safe address
     */
    function getUserSafe(address user) external view override returns (address) {
        return _getSavingsStorage().userSafes[user];
    }

    /**
     * @notice Get user's contribution information
     */
    function getUserContributions(address user) external view returns (
        uint256 totalContributed,
        uint256 availableForWithdrawal,
        uint256 yieldsGenerated,
        uint256 lastYieldClaim
    ) {
        UserContributions storage contributions = _getSavingsStorage().contributions[user];
        return (
            contributions.totalContributed,
            contributions.availableForWithdrawal,
            contributions.yieldsGenerated,
            contributions.lastYieldClaim
        );
    }
}
