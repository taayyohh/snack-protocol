// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IAdminControl } from "../interfaces/IAdminControl.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import { ILiquityIntegration } from "../interfaces/ILiquityIntegration.sol";
import { Safe } from "../../lib/safe-smart-account/contracts/Safe.sol";

/**
 * @title AdminControlFacet
 * @notice Enhanced admin controls with timelock and rate limiting
 */
contract AdminControlFacet is IAdminControl {
    /**
     * @dev Storage for admin controls
     */
    struct AdminStorage {
        // Existing storage
        PauseState currentState;
        mapping(address => bool) admins;
        mapping(EmergencyAction => bool) allowedActions;
        bool isShutdown;
        uint256 lastEmergencyAction;

        // New storage for enhanced security
        mapping(bytes32 => TimelockOperation) pendingOperations;
        mapping(address => WithdrawalLimit) withdrawalLimits;
        uint256 globalWithdrawalLimit;
        uint256 lastWithdrawalReset;
        uint256 currentDailyWithdrawals;
        uint256 minAdminSignatures;
        mapping(bytes32 => mapping(address => bool)) adminSignatures;
    }

    /**
     * @dev Timelock operation details
     */
    struct TimelockOperation {
        bytes32 operationId;
        uint256 timestamp;
        uint256 signaturesRequired;
        uint256 signaturesReceived;
        bool executed;
        OperationType operationType;
        bytes parameters;
    }

    /**
     * @dev Withdrawal rate limiting
     */
    struct WithdrawalLimit {
        uint256 dailyLimit;
        uint256 currentDay;
        uint256 todayWithdrawn;
    }

    /**
     * @dev Operation types for timelock
     */
    enum OperationType {
        CHANGE_ADMIN,
        UPDATE_LIMITS,
        EMERGENCY_ACTION,
        PROTOCOL_UPGRADE
    }

    // Constants
    uint256 constant TIMELOCK_DELAY = 24 hours;
    uint256 constant EMERGENCY_TIMELOCK_DELAY = 1 hours;
    uint256 constant MAX_DAILY_WITHDRAWAL = 100 ether;
    uint256 constant WITHDRAWAL_WINDOW = 24 hours;

    // New errors
    error TimelockNotExpired();
    error InsufficientSignatures();
    error OperationNotFound();
    error DailyLimitExceeded();
    error AlreadyExecuted();
    error InvalidTimelock();
    error SignatureAlreadyAdded();

    /**
     * @dev Get admin storage
     */
    function _getAdminStorage() internal pure returns (AdminStorage storage adminStorage) {
        bytes32 position = keccak256("snack.protocol.storage.admin");
        assembly {
            adminStorage.slot := position
        }
        return adminStorage;
    }

    /**
     * @dev Only allow admin access
     */
    modifier onlyAdmin() {
        if (!_getAdminStorage().admins[msg.sender] && msg.sender != LibDiamond.contractOwner()) {
            revert NotAuthorized();
        }
        _;
    }

    /**
     * @dev Check protocol is not shutdown
     */
    modifier notShutdown() {
        if (_getAdminStorage().isShutdown) {
            revert InvalidState();
        }
        _;
    }

    /**
     * @dev Initialize admin controls
     * @param minSignatures Minimum signatures required for admin actions
     * @param initialAdmins Array of initial admin addresses
     */
    function initializeAdminControls(uint256 minSignatures, address[] calldata initialAdmins) external {
        require(msg.sender == LibDiamond.contractOwner(), "Only owner");
        AdminStorage storage adminStorage = _getAdminStorage();

        adminStorage.minAdminSignatures = minSignatures;
        adminStorage.globalWithdrawalLimit = MAX_DAILY_WITHDRAWAL;
        adminStorage.lastWithdrawalReset = block.timestamp;

        for (uint i = 0; i < initialAdmins.length; i++) {
            adminStorage.admins[initialAdmins[i]] = true;
        }
    }

    /**
     * @notice Propose a new timelock operation
     * @param operationType Type of operation
     * @param parameters Encoded parameters for the operation
     * @return operationId The ID of the created operation
     */
    function proposeOperation(
        OperationType operationType,
        bytes calldata parameters
    ) external onlyAdmin returns (bytes32 operationId) {
        AdminStorage storage adminStorage = _getAdminStorage();

        operationId = keccak256(abi.encodePacked(
            block.timestamp,
            operationType,
            parameters
        ));

        // Create new timelock operation
        uint256 delay = operationType == OperationType.EMERGENCY_ACTION
            ? EMERGENCY_TIMELOCK_DELAY
            : TIMELOCK_DELAY;

        adminStorage.pendingOperations[operationId] = TimelockOperation({
            operationId: operationId,
            timestamp: block.timestamp + delay,
            signaturesRequired: adminStorage.minAdminSignatures,
            signaturesReceived: 1, // Proposer automatically signs
            executed: false,
            operationType: operationType,
            parameters: parameters
        });

        // Record proposer's signature
        adminStorage.adminSignatures[operationId][msg.sender] = true;

        emit OperationProposed(operationId, msg.sender, operationType);
    }

    /**
     * @notice Sign a pending operation
     * @param operationId The operation to sign
     */
    function signOperation(bytes32 operationId) external onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();
        TimelockOperation storage operation = adminStorage.pendingOperations[operationId];

        if (operation.operationId == bytes32(0)) revert OperationNotFound();
        if (operation.executed) revert AlreadyExecuted();
        if (adminStorage.adminSignatures[operationId][msg.sender]) revert SignatureAlreadyAdded();

        adminStorage.adminSignatures[operationId][msg.sender] = true;
        operation.signaturesReceived += 1;

        emit OperationSigned(operationId, msg.sender);
    }

    /**
     * @notice Execute a timelock operation
     * @param operationId The operation to execute
     */
    function executeOperation(bytes32 operationId) external onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();
        TimelockOperation storage operation = adminStorage.pendingOperations[operationId];

        if (operation.operationId == bytes32(0)) revert OperationNotFound();
        if (operation.executed) revert AlreadyExecuted();
        if (block.timestamp < operation.timestamp) revert TimelockNotExpired();
        if (operation.signaturesReceived < operation.signaturesRequired) revert InsufficientSignatures();

        operation.executed = true;

        if (operation.operationType == OperationType.EMERGENCY_ACTION) {
            _executeEmergencyAction(operation.parameters);
        } else if (operation.operationType == OperationType.UPDATE_LIMITS) {
            _executeUpdateLimits(operation.parameters);
        } else if (operation.operationType == OperationType.CHANGE_ADMIN) {
            _executeAdminChange(operation.parameters);
        }

        emit OperationExecuted(operationId, msg.sender);
    }

    /**
     * @notice Execute emergency withdrawal with rate limiting
     * @param user Address to withdraw funds for
     */
    function emergencyWithdraw(address user) external override onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();

        if (!adminStorage.allowedActions[EmergencyAction.WITHDRAW]) {
            revert InvalidState();
        }

        // Check and update withdrawal limits
        _checkWithdrawalLimits(user);

        // Get user's Safe and savings info
        ISavingsFacet savings = ISavingsFacet(address(this));
        address safeAddress = savings.getUserSafe(user);
        if (safeAddress == address(0)) revert InvalidState();

        // Get total withdrawable amount
        uint256 withdrawAmount = Safe(safeAddress).getBalance();
        if (withdrawAmount == 0) revert InvalidAmount();

        // Update withdrawal tracking
        adminStorage.withdrawalLimits[user].todayWithdrawn += withdrawAmount;
        adminStorage.currentDailyWithdrawals += withdrawAmount;

        // Execute withdrawal through Safe
        _executeWithdrawal(safeAddress, user, withdrawAmount);

        emit EmergencyWithdrawal(user, withdrawAmount);
    }

    /**
     * @notice Update protocol pause state with timelock
     * @param state New pause state
     */
    function setPauseState(PauseState state) external override onlyAdmin notShutdown {
        AdminStorage storage adminStorage = _getAdminStorage();
        if (state == adminStorage.currentState) revert AlreadyPaused();

        bytes32 operationId = keccak256(abi.encodePacked("PAUSE", state, block.timestamp));
        TimelockOperation storage operation = adminStorage.pendingOperations[operationId];

        if (operation.timestamp == 0) {
            // Create new timelock operation
            operation.timestamp = block.timestamp + EMERGENCY_TIMELOCK_DELAY;
            operation.signaturesRequired = adminStorage.minAdminSignatures;
            operation.parameters = abi.encode(state);
        }

        if (block.timestamp < operation.timestamp) revert TimelockNotExpired();

        // Update state
        adminStorage.currentState = state;
        adminStorage.lastEmergencyAction = block.timestamp;

        // Update allowed actions based on state
        adminStorage.allowedActions[EmergencyAction.PAUSE] = true;
        adminStorage.allowedActions[EmergencyAction.WITHDRAW] =
            (state == PauseState.WITHDRAWALS_ONLY || state == PauseState.ACTIVE);

        emit ProtocolPaused(state);
    }

    // Internal functions

    function _executeWithdrawal(address safeAddress, address user, uint256 amount) internal {
        try Safe(safeAddress).execTransaction(
            payable(user),
            amount,
            "",
            Safe.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            new bytes(0)
        ) returns (bool success) {
            if (!success) revert WithdrawalFailed();
        } catch {
            revert WithdrawalFailed();
        }
    }

    function _checkWithdrawalLimits(address user) internal {
        AdminStorage storage adminStorage = _getAdminStorage();
        WithdrawalLimit storage userLimit = adminStorage.withdrawalLimits[user];

        // Reset daily limits if needed
        if (block.timestamp >= adminStorage.lastWithdrawalReset + WITHDRAWAL_WINDOW) {
            adminStorage.lastWithdrawalReset = block.timestamp;
            adminStorage.currentDailyWithdrawals = 0;
        }

        if (block.timestamp >= userLimit.currentDay + WITHDRAWAL_WINDOW) {
            userLimit.currentDay = block.timestamp;
            userLimit.todayWithdrawn = 0;
        }

        // Check limits
        if (userLimit.todayWithdrawn >= userLimit.dailyLimit) revert DailyLimitExceeded();
        if (adminStorage.currentDailyWithdrawals >= adminStorage.globalWithdrawalLimit) {
            revert DailyLimitExceeded();
        }
    }

    function _executeEmergencyAction(bytes memory parameters) internal {
        (EmergencyAction action) = abi.decode(parameters, (EmergencyAction));
        AdminStorage storage adminStorage = _getAdminStorage();

        if (action == EmergencyAction.SHUTDOWN) {
            adminStorage.isShutdown = true;
            adminStorage.currentState = PauseState.FULLY_PAUSED;
            adminStorage.allowedActions[EmergencyAction.WITHDRAW] = true;
        }
    }

    function _executeUpdateLimits(bytes memory parameters) internal {
        (uint256 newGlobalLimit, uint256 newMinSignatures) = abi.decode(parameters, (uint256, uint256));
        AdminStorage storage adminStorage = _getAdminStorage();

        adminStorage.globalWithdrawalLimit = newGlobalLimit;
        adminStorage.minAdminSignatures = newMinSignatures;
    }

    function _executeAdminChange(bytes memory parameters) internal {
        (address admin, bool isAdd) = abi.decode(parameters, (address, bool));
        AdminStorage storage adminStorage = _getAdminStorage();

        if (isAdd) {
            adminStorage.admins[admin] = true;
        } else {
            adminStorage.admins[admin] = false;
        }
    }

    // Events
    event OperationProposed(bytes32 indexed operationId, address indexed proposer, OperationType operationType);
    event OperationSigned(bytes32 indexed operationId, address indexed signer);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);
}
