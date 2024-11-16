// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IAdminControl } from "../interfaces/IAdminControl.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import { ILiquityIntegration } from "../interfaces/ILiquityIntegration.sol";
import { Safe } from "../../lib/safe-smart-account/contracts/Safe.sol";
import { Enum } from "../../lib/safe-smart-account/contracts/libraries/Enum.sol";
/**
 * @title AdminControlFacet
 * @notice Enhanced admin controls with timelock and rate limiting
 */
contract AdminControlFacet is IAdminControl {
    /**
     * @dev Storage for admin controls
     */
    struct AdminStorage {
        PauseState currentState;
        mapping(address => bool) admins;
        mapping(EmergencyAction => bool) allowedActions;
        bool isShutdown;
        uint256 lastEmergencyAction;
        mapping(bytes32 => TimelockOperation) pendingOperations;
        mapping(address => WithdrawalLimit) withdrawalLimits;
        uint256 globalWithdrawalLimit;
        uint256 lastWithdrawalReset;
        uint256 currentDailyWithdrawals;
        uint256 minAdminSignatures;
        mapping(bytes32 => mapping(address => bool)) adminSignatures;
    }

    // Constants
    uint256 private constant TIMELOCK_DELAY = 24 hours;
    uint256 private constant EMERGENCY_TIMELOCK_DELAY = 1 hours;
    uint256 private constant MAX_DAILY_WITHDRAWAL = 100 ether;
    uint256 private constant WITHDRAWAL_WINDOW = 24 hours;

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
     * @notice Initialize admin controls
     */
    function initializeAdminControls(
        uint256 minSignatures,
        address[] calldata initialAdmins
    ) external override {
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
     */
    function proposeOperation(
        OperationType operationType,
        bytes calldata parameters
    ) external override onlyAdmin returns (bytes32 operationId) {
        AdminStorage storage adminStorage = _getAdminStorage();

        operationId = keccak256(abi.encodePacked(
            block.timestamp,
            operationType,
            parameters
        ));

        uint256 delay = operationType == OperationType.EMERGENCY_ACTION
            ? EMERGENCY_TIMELOCK_DELAY
            : TIMELOCK_DELAY;

        adminStorage.pendingOperations[operationId] = TimelockOperation({
            operationId: operationId,
            timestamp: block.timestamp + delay,
            signaturesRequired: adminStorage.minAdminSignatures,
            signaturesReceived: 1,
            executed: false,
            operationType: operationType,
            parameters: parameters
        });

        adminStorage.adminSignatures[operationId][msg.sender] = true;

        emit OperationProposed(operationId, msg.sender, operationType);
        return operationId;
    }

    /**
     * @notice Sign a pending operation
     */
    function signOperation(bytes32 operationId) external override onlyAdmin {
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
     */
    function executeOperation(bytes32 operationId) external override onlyAdmin {
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
     * @notice Set protocol pause state
     */
    function setPauseState(PauseState state) external override onlyAdmin notShutdown {
        AdminStorage storage adminStorage = _getAdminStorage();
        if (state == adminStorage.currentState) revert AlreadyPaused();

        adminStorage.currentState = state;
        adminStorage.lastEmergencyAction = block.timestamp;

        adminStorage.allowedActions[EmergencyAction.PAUSE] = true;
        adminStorage.allowedActions[EmergencyAction.WITHDRAW] =
            (state == PauseState.WITHDRAWALS_ONLY || state == PauseState.ACTIVE);

        emit ProtocolPaused(state);
    }

    /**
     * @notice Execute emergency withdrawal with rate limiting
     */
    function emergencyWithdraw(address user) external override onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();

        if (!adminStorage.allowedActions[EmergencyAction.WITHDRAW]) {
            revert InvalidState();
        }

        _checkWithdrawalLimits(user);

        ISavingsFacet savings = ISavingsFacet(address(this));
        address payable safeAddress = payable(savings.getUserSafe(user));
        if (safeAddress == address(0)) revert InvalidState();

        uint256 withdrawAmount = address(safeAddress).balance;
        if (withdrawAmount == 0) revert InvalidAmount();

        adminStorage.withdrawalLimits[user].todayWithdrawn += withdrawAmount;
        adminStorage.currentDailyWithdrawals += withdrawAmount;

        _executeWithdrawal(safeAddress, user, withdrawAmount);

        emit EmergencyWithdrawal(user, withdrawAmount);
    }

    /**
     * @notice Get current protocol state
     */
    function getProtocolState() external view override returns (PauseState) {
        return _getAdminStorage().currentState;
    }

    /**
     * @notice Check if specific action is allowed
     */
    function isActionAllowed(EmergencyAction action) external view override returns (bool) {
        return _getAdminStorage().allowedActions[action];
    }

    /**
     * @notice Get operation details
     */
    function getOperation(bytes32 operationId) external view override returns (TimelockOperation memory operation) {
        return _getAdminStorage().pendingOperations[operationId];
    }

    /**
     * @notice Get withdrawal limits for a user
     */
    function getWithdrawalLimit(address user) external view override returns (WithdrawalLimit memory limit) {
        return _getAdminStorage().withdrawalLimits[user];
    }

    /**
     * @notice Get global withdrawal limit
     */
    function getGlobalWithdrawalLimit() external view override returns (uint256 limit) {
        return _getAdminStorage().globalWithdrawalLimit;
    }

    /**
     * @notice Check if address is admin
     */
    function isAdmin(address account) external view override returns (bool) {
        AdminStorage storage adminStorage = _getAdminStorage();
        return adminStorage.admins[account] || account == LibDiamond.contractOwner();
    }

    // Internal functions

    function _executeWithdrawal(address payable safeAddress, address user, uint256 amount) internal {
        try Safe(safeAddress).execTransaction{value: 0}(
            payable(user),
            amount,
            "",
            Enum.Operation.Call,
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

        if (block.timestamp >= adminStorage.lastWithdrawalReset + WITHDRAWAL_WINDOW) {
            adminStorage.lastWithdrawalReset = block.timestamp;
            adminStorage.currentDailyWithdrawals = 0;
        }

        if (block.timestamp >= userLimit.currentDay + WITHDRAWAL_WINDOW) {
            userLimit.currentDay = block.timestamp;
            userLimit.todayWithdrawn = 0;
        }

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

        emit GlobalLimitUpdated(newGlobalLimit);
        emit MinSignaturesUpdated(newMinSignatures);
    }

    function _executeAdminChange(bytes memory parameters) internal {
        (address admin, bool isAdd) = abi.decode(parameters, (address, bool));
        AdminStorage storage adminStorage = _getAdminStorage();

        if (isAdd) {
            adminStorage.admins[admin] = true;
        } else {
            adminStorage.admins[admin] = false;
        }

        emit AdminChanged(msg.sender, admin);
    }
}
