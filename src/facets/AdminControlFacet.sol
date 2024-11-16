// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IAdminControl } from "../interfaces/IAdminControl.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import { ILiquityIntegration } from "../interfaces/ILiquityIntegration.sol";
import { Safe } from "../../lib/safe-smart-account/contracts/Safe.sol";

/**
 * @title AdminControlFacet
 * @notice Manages admin functions and emergency controls
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
    }

    /**
     * @dev Get admin storage
     * @return adminStorage The AdminStorage struct from its dedicated storage slot
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
     * @notice Set protocol pause state
     * @param state New pause state
     */
    function setPauseState(PauseState state) external override onlyAdmin notShutdown {
        AdminStorage storage adminStorage = _getAdminStorage();
        if (state == adminStorage.currentState) revert AlreadyPaused();

        adminStorage.currentState = state;
        adminStorage.lastEmergencyAction = block.timestamp;

        // Update allowed actions based on state
        adminStorage.allowedActions[EmergencyAction.PAUSE] = true;
        adminStorage.allowedActions[EmergencyAction.WITHDRAW] =
            (state == PauseState.WITHDRAWALS_ONLY || state == PauseState.ACTIVE);

        emit ProtocolPaused(state);
    }

    /**
     * @notice Execute emergency withdrawal
     * @param user Address to withdraw funds for
     */
    function emergencyWithdraw(address user) external override onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();

        if (!adminStorage.allowedActions[EmergencyAction.WITHDRAW]) {
            revert InvalidState();
        }

        // Get user's Safe and savings info
        ISavingsFacet savings = ISavingsFacet(address(this));
        address safeAddress = savings.getUserSafe(user);
        if (safeAddress == address(0)) revert InvalidState();

        // Get total withdrawable amount
        uint256 withdrawAmount = Safe(safeAddress).getBalance();
        if (withdrawAmount == 0) revert InvalidAmount();

        // Execute withdrawal through Safe
        try Safe(safeAddress).execTransaction(
            payable(user),
            withdrawAmount,
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

        emit EmergencyWithdrawal(user, withdrawAmount);
    }

    /**
     * @notice Complete protocol shutdown
     */
    function emergencyShutdown() external override onlyAdmin {
        AdminStorage storage adminStorage = _getAdminStorage();

        // Update state
        adminStorage.isShutdown = true;
        adminStorage.currentState = PauseState.FULLY_PAUSED;
        adminStorage.lastEmergencyAction = block.timestamp;

        // Disable all actions except withdrawals
        adminStorage.allowedActions[EmergencyAction.PAUSE] = false;
        adminStorage.allowedActions[EmergencyAction.SHUTDOWN] = true;
        adminStorage.allowedActions[EmergencyAction.WITHDRAW] = true;

        emit ProtocolPaused(PauseState.FULLY_PAUSED);
    }

    /**
     * @notice Get current protocol state
     * @return Current pause state of the protocol
     */
    function getProtocolState() external view override returns (PauseState) {
        return _getAdminStorage().currentState;
    }

    /**
     * @notice Check if action is allowed
     * @param action Action to check
     * @return bool indicating if action is allowed
     */
    function isActionAllowed(EmergencyAction action) external view override returns (bool) {
        return _getAdminStorage().allowedActions[action];
    }

    /**
     * @notice Add a new admin
     * @param admin Address to add as admin
     */
    function addAdmin(address admin) external onlyAdmin {
        if (admin == address(0)) revert InvalidState();
        _getAdminStorage().admins[admin] = true;
    }

    /**
     * @notice Remove an admin
     * @param admin Address to remove as admin
     */
    function removeAdmin(address admin) external onlyAdmin {
        if (admin == LibDiamond.contractOwner()) revert InvalidState();
        _getAdminStorage().admins[admin] = false;
    }

    /**
     * @notice Check if address is admin
     * @param account Address to check
     * @return bool indicating if address is admin
     */
    function isAdmin(address account) external view returns (bool) {
        return _getAdminStorage().admins[account] || account == LibDiamond.contractOwner();
    }
}
