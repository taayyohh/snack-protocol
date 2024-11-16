// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAdminControl
 * @notice Enhanced interface for admin and emergency controls
 * @dev Includes timelock and multi-signature functionality
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

    /**
     * @notice Operation types for timelock
     */
    enum OperationType {
        CHANGE_ADMIN,
        UPDATE_LIMITS,
        EMERGENCY_ACTION,
        PROTOCOL_UPGRADE
    }

    /**
     * @notice Structure for timelock operations
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
     * @notice Structure for withdrawal limits
     */
    struct WithdrawalLimit {
        uint256 dailyLimit;
        uint256 currentDay;
        uint256 todayWithdrawn;
    }

    /**
     * @notice Events
     */
    event ProtocolPaused(PauseState state);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event OperationProposed(bytes32 indexed operationId, address indexed proposer, OperationType operationType);
    event OperationSigned(bytes32 indexed operationId, address indexed signer);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);
    event WithdrawalLimitUpdated(address indexed user, uint256 newLimit);
    event GlobalLimitUpdated(uint256 newLimit);
    event MinSignaturesUpdated(uint256 newMinSignatures);

    /**
     * @notice Errors
     */
    error NotAuthorized();
    error InvalidState();
    error WithdrawalFailed();
    error InvalidAmount();
    error AlreadyPaused();
    error TimelockNotExpired();
    error InsufficientSignatures();
    error OperationNotFound();
    error DailyLimitExceeded();
    error AlreadyExecuted();
    error InvalidTimelock();
    error SignatureAlreadyAdded();

    /**
     * @notice Initialize admin controls
     * @param minSignatures Minimum signatures required for admin actions
     * @param initialAdmins Array of initial admin addresses
     */
    function initializeAdminControls(
        uint256 minSignatures,
        address[] calldata initialAdmins
    ) external;

    /**
     * @notice Propose a new timelock operation
     * @param operationType Type of operation
     * @param parameters Encoded parameters for the operation
     * @return operationId The ID of the created operation
     */
    function proposeOperation(
        OperationType operationType,
        bytes calldata parameters
    ) external returns (bytes32 operationId);

    /**
     * @notice Sign a pending operation
     * @param operationId The operation to sign
     */
    function signOperation(bytes32 operationId) external;

    /**
     * @notice Execute a timelock operation
     * @param operationId The operation to execute
     */
    function executeOperation(bytes32 operationId) external;

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
     * @notice Get current protocol state
     * @return Current pause state of the protocol
     */
    function getProtocolState() external view returns (PauseState);

    /**
     * @notice Check if specific action is allowed
     * @param action Action to check
     * @return bool indicating if action is allowed
     */
    function isActionAllowed(EmergencyAction action) external view returns (bool);

    /**
     * @notice Get operation details
     * @param operationId The operation to query
     * @return operation The operation details
     */
    function getOperation(bytes32 operationId) external view returns (TimelockOperation memory operation);

    /**
     * @notice Get withdrawal limits for a user
     * @param user The user to query
     * @return limit The withdrawal limit details
     */
    function getWithdrawalLimit(address user) external view returns (WithdrawalLimit memory limit);

    /**
     * @notice Get global withdrawal limit
     * @return limit The global daily withdrawal limit
     */
    function getGlobalWithdrawalLimit() external view returns (uint256 limit);

    /**
     * @notice Check if address is admin
     * @param account Address to check
     * @return bool indicating if address is admin
     */
    function isAdmin(address account) external view returns (bool);
}
