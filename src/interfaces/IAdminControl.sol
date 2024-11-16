// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAdminControl
 * @notice Interface for admin and emergency controls
 */
interface IAdminControl {
    /**
     * @notice Protocol pause states
     */
    enum PauseState {
        ACTIVE,         // All functionality active
        DEPOSITS_ONLY,  // Only deposits allowed
        WITHDRAWALS_ONLY, // Only withdrawals allowed
        FULLY_PAUSED    // All functionality paused
    }

    /**
     * @notice Emergency action types
     */
    enum EmergencyAction {
        PAUSE,
        WITHDRAW,
        SHUTDOWN
    }

    event ProtocolPaused(PauseState state);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    error NotAuthorized();
    error InvalidState();
    error WithdrawalFailed();
    error InvalidAmount();
    error AlreadyPaused();

    /**
     * @notice Set protocol pause state
     * @param state New pause state
     */
    function setPauseState(PauseState state) external;

    /**
     * @notice Execute emergency withdrawal
     * @param user Address to withdraw funds for
     */
    function emergencyWithdraw(address user) external;

    /**
     * @notice Complete protocol shutdown
     * @dev Only callable in extreme emergencies
     */
    function emergencyShutdown() external;

    /**
     * @notice Get current protocol state
     */
    function getProtocolState() external view returns (PauseState);

    /**
     * @notice Check if specific action is allowed
     * @param action Action to check
     */
    function isActionAllowed(EmergencyAction action) external view returns (bool);
}
