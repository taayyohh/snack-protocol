// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../facets/AdminControlFacet.sol";
import "../core/Diamond.sol";
import "../interfaces/IAdminControl.sol";
import "../facets/DiamondCutFacet.sol";
import "../facets/DiamondLoupeFacet.sol";

contract AdminControlFacetTest is Test {
    // Constants for testing
    uint256 internal constant TIMELOCK_DELAY = 24 hours;
    uint256 internal constant EMERGENCY_TIMELOCK_DELAY = 1 hours;
    uint256 internal constant MAX_DAILY_WITHDRAWAL = 100 ether;

    // Contract instances
    Diamond internal diamond;
    AdminControlFacet internal adminFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;

    // Test accounts
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
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy facets
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        adminFacet = new AdminControlFacet();

        // Create diamond
        diamond = new Diamond(owner, address(cutFacet));

        // Build cut struct
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

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
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

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
        vm.expectEmit(true, true, true, true);
        emit OperationProposed(
            keccak256(abi.encodePacked(block.timestamp, IAdminControl.OperationType.EMERGENCY_ACTION, params)),
            admin1,
            IAdminControl.OperationType.EMERGENCY_ACTION
        );

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
        // Start prank for admin1
        vm.startPrank(admin1);

        // Propose operation
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.PAUSE);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        // Stop prank for admin1 and start prank for admin2
        vm.stopPrank();
        vm.startPrank(admin2);

        // Sign operation
        vm.expectEmit(true, true, false, true);
        emit OperationSigned(operationId, admin2);
        IAdminControl(address(diamond)).signOperation(operationId);

        // Verify signatures
        IAdminControl.TimelockOperation memory operation = IAdminControl(address(diamond)).getOperation(operationId);
        assertEq(operation.signaturesReceived, 2);

        vm.stopPrank();
    }

    function testExecuteOperation() public {
        // Start prank for admin1
        vm.startPrank(admin1);

        // Propose operation
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.PAUSE);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );

        // Stop prank for admin1 and start prank for admin2
        vm.stopPrank();
        vm.startPrank(admin2);

        // Sign operation
        IAdminControl(address(diamond)).signOperation(operationId);

        // Stop prank for admin2
        vm.stopPrank();

        // Warp time to satisfy timelock
        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        // Start prank for admin1 to execute operation
        vm.startPrank(admin1);
        vm.expectEmit(true, true, false, true);
        emit OperationExecuted(operationId, admin1);
        IAdminControl(address(diamond)).executeOperation(operationId);

        // Verify operation executed
        IAdminControl.TimelockOperation memory operation = IAdminControl(address(diamond)).getOperation(operationId);
        assertTrue(operation.executed);

        vm.stopPrank();
    }


//    function testEmergencyWithdrawal() public {
//        // User address for withdrawal
//        address userAddress = address(5);
//        uint256 withdrawAmount = 1 ether;
//
//        // Step 1: Enable withdrawals by changing the pause state
//        vm.startPrank(admin1);
//        bytes memory params = abi.encode(IAdminControl.EmergencyAction.WITHDRAW);
//        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
//            IAdminControl.OperationType.EMERGENCY_ACTION,
//            params
//        );
//        vm.stopPrank();
//
//        vm.startPrank(admin2);
//        IAdminControl(address(diamond)).signOperation(operationId);
//        vm.stopPrank();
//
//        vm.warp(block.timestamp + 1 hours + 1); // Warp past timelock
//        vm.startPrank(admin1);
//        IAdminControl(address(diamond)).executeOperation(operationId);
//
//        // Step 2: Fund the contract and set the expected emit
//        vm.deal(address(diamond), withdrawAmount);
//        vm.expectEmit(true, true, true, true);
//        emit EmergencyWithdrawal(userAddress, withdrawAmount);
//
//        // Step 3: Perform the withdrawal
//        IAdminControl(address(diamond)).emergencyWithdraw(userAddress);
//        vm.stopPrank();
//    }

//    function testRateLimiting() public {
//        address userAddress = address(5);
//        uint256 dailyLimit = 1 ether; // Set global withdrawal limit
//
//        // Step 1: Set new global withdrawal limit
//        vm.startPrank(admin1);
//        bytes memory params = abi.encode(dailyLimit, 2); // Limit and min signatures
//        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
//            IAdminControl.OperationType.UPDATE_LIMITS,
//            params
//        );
//        vm.stopPrank();
//
//        vm.startPrank(admin2);
//        IAdminControl(address(diamond)).signOperation(operationId);
//        vm.stopPrank();
//
//        vm.warp(block.timestamp + 24 hours + 1); // Warp past timelock
//        vm.startPrank(admin1);
//        IAdminControl(address(diamond)).executeOperation(operationId);
//
//        // Step 2: Fund the contract and perform first withdrawal
//        vm.deal(address(diamond), 2 ether);
//        IAdminControl(address(diamond)).emergencyWithdraw(userAddress); // First withdrawal
//
//        // Step 3: Expect revert for exceeding limit
//        vm.expectRevert(IAdminControl.DailyLimitExceeded.selector);
//        IAdminControl(address(diamond)).emergencyWithdraw(userAddress); // Exceeds limit
//        vm.stopPrank();
//    }

    function testTimelockDelay() public {
        vm.startPrank(admin1);
        bytes memory params = abi.encode(IAdminControl.EmergencyAction.SHUTDOWN);
        bytes32 operationId = IAdminControl(address(diamond)).proposeOperation(
            IAdminControl.OperationType.EMERGENCY_ACTION,
            params
        );
        vm.stopPrank();

        vm.startPrank(admin2);
        IAdminControl(address(diamond)).signOperation(operationId);
        vm.stopPrank();

        vm.warp(block.timestamp + (EMERGENCY_TIMELOCK_DELAY - 1)); // Warp time just before timelock expiry

        vm.startPrank(admin1);
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

        vm.warp(block.timestamp + EMERGENCY_TIMELOCK_DELAY + 1);

        vm.prank(admin1);
        vm.expectRevert(IAdminControl.InsufficientSignatures.selector);
        IAdminControl(address(diamond)).executeOperation(operationId);
    }
}
