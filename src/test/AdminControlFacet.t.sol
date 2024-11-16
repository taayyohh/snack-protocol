// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../facets/AdminControlFacet.sol";
import "../core/Diamond.sol";
import "../interfaces/IAdminControl.sol";
import "../facets/DiamondCutFacet.sol";
import "../facets/DiamondLoupeFacet.sol";

contract AdminControlFacetTest is Test {
    // Constants for testing - mark as internal
    uint256 internal constant TIMELOCK_DELAY = 24 hours;
    uint256 internal constant EMERGENCY_TIMELOCK_DELAY = 1 hours;
    uint256 internal constant MAX_DAILY_WITHDRAWAL = 100 ether;

    // Contract instances - mark as internal
    Diamond internal diamond;
    AdminControlFacet internal adminFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;

    // Test accounts - mark as internal
    address internal owner = address(1);
    address internal admin1 = address(2);
    address internal admin2 = address(3);
    address internal admin3 = address(4);
    address internal user = address(5);

    // Events to test
    event OperationProposed(bytes32 indexed operationId, address indexed proposer, IAdminControl.OperationType operationType);
    event OperationSigned(bytes32 indexed operationId, address indexed signer);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);
    event ProtocolPaused(IAdminControl.PauseState state);
    event EmergencyWithdrawal(address indexed user, uint256 amount); // Added missing event

    function setUp() public {
        // Deploy diamond with facets
        vm.startPrank(owner);

        // Deploy facets
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        adminFacet = new AdminControlFacet();

        // Create diamond
        diamond = new Diamond(owner, address(cutFacet));

        // Build cut struct
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // Add admin facet
        bytes4[] memory adminSelectors = new bytes4[](12);
        adminSelectors[0] = AdminControlFacet.initializeAdminControls.selector;
        adminSelectors[1] = AdminControlFacet.proposeOperation.selector;
        adminSelectors[2] = AdminControlFacet.signOperation.selector;
        adminSelectors[3] = AdminControlFacet.executeOperation.selector;
        adminSelectors[4] = AdminControlFacet.setPauseState.selector;
        adminSelectors[5] = AdminControlFacet.emergencyWithdraw.selector;
        adminSelectors[6] = AdminControlFacet.getProtocolState.selector;
        adminSelectors[7] = AdminControlFacet.isActionAllowed.selector;
        adminSelectors[8] = AdminControlFacet.getOperation.selector;
        adminSelectors[9] = AdminControlFacet.getWithdrawalLimit.selector;
        adminSelectors[10] = AdminControlFacet.getGlobalWithdrawalLimit.selector;
        adminSelectors[11] = AdminControlFacet.isAdmin.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // Add loupe facet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Execute diamond cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), ""); // Fixed the diamond cut call

        // Initialize admin controls
        address[] memory initialAdmins = new address[](3);
        initialAdmins[0] = admin1;
        initialAdmins[1] = admin2;
        initialAdmins[2] = admin3;

        IAdminControl(address(diamond)).initializeAdminControls(2, initialAdmins);

        vm.stopPrank();
    }

    function testInitialization() public {
        assertTrue(IAdminControl(address(diamond)).isAdmin(admin1));
        assertTrue(IAdminControl(address(diamond)).isAdmin(admin2));
        assertTrue(IAdminControl(address(diamond)).isAdmin(admin3));
        assertEq(uint256(IAdminControl(address(diamond)).getProtocolState()), uint256(IAdminControl.PauseState.ACTIVE));
    }

    function testProposeOperation() public {
        vm.startPrank(admin1);

        bytes memory params = abi.encode(IAdminControl.EmergencyAction.PAUSE);

        vm.expectEmit(true, true, false, true);
        emit OperationProposed(bytes32(0), admin1, IAdminControl.OperationType.EMERGENCY_ACTION);

        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        IAdminControl.TimelockOperation memory operation = IAdminControl(address(diamond)).getOperation(operationId);
        assertEq(operation.signaturesReceived, 1);
        assertEq(operation.signaturesRequired, 2);
        assertFalse(operation.executed);

        vm.stopPrank();
    }

    function testSignOperation() public {
        // First propose operation
        vm.prank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.PAUSE);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        // Second admin signs
        vm.prank(admin2);
        vm.expectEmit(true, true, false, true);
        emit OperationSigned(operationId, admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        IAdminControl.TimelockOperation memory operation = IAdminControl(address(diamond)).getOperation(operationId);
        assertEq(operation.signaturesReceived, 2);
    }

    function testExecuteOperation() public {
        // Propose and sign operation
        vm.prank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.PAUSE);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        vm.prank(admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        // Wait for timelock
        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        // Execute
        vm.prank(admin1);
        vm.expectEmit(true, true, false, true);
        emit OperationExecuted(operationId, admin1);
        IAdminControl(address(diamond)).executeOperation(operationId);

        IAdminControl.TimelockOperation memory operation = IAdminControl(address(diamond)).getOperation(operationId);
        assertTrue(operation.executed);
    }

    function testEmergencyWithdrawal() public {
        // Setup: Put protocol in withdrawal state
        vm.startPrank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.WITHDRAW);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );
        vm.stopPrank();

        vm.prank(admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        vm.prank(admin1);
        IAdminControl(address(diamond)).executeOperation(operationId);

        // Test withdrawal
        vm.deal(address(diamond), 1 ether);
        vm.prank(admin1);
        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdrawal(user, 1 ether);
        IAdminControl(address(diamond)).emergencyWithdraw(user);
    }

    function testRateLimiting() public {
        // Setup emergency withdrawal state
        vm.startPrank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.WITHDRAW);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );
        vm.stopPrank();

        vm.prank(admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        vm.prank(admin1);
        IAdminControl(address(diamond)).executeOperation(operationId);

        // Try to exceed daily limit
        vm.deal(address(diamond), 101 ether);
        vm.prank(admin1);
        vm.expectRevert(IAdminControl.DailyLimitExceeded.selector);
        IAdminControl(address(diamond)).emergencyWithdraw(user);
    }

    function testTimelockDelay() public {
        vm.startPrank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.SHUTDOWN);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        vm.prank(admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        // Try to execute before timelock expires
        vm.expectRevert(IAdminControl.TimelockNotExpired.selector);
        IAdminControl(address(diamond)).executeOperation(operationId);
        vm.stopPrank();
    }

    function testInsufficientSignatures() public {
        vm.prank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.SHUTDOWN);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        // Wait for timelock but try to execute with only one signature
        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        vm.prank(admin1);
        vm.expectRevert(IAdminControl.InsufficientSignatures.selector);
        IAdminControl(address(diamond)).executeOperation(operationId);
    }
}
