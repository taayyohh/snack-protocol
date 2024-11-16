// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/Console.sol"; //
import { AdminControlFacet } from "../src/facets/AdminControlFacet.sol";
import { DiamondCutFacet } from "../src/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../src/facets/DiamondLoupeFacet.sol";
import { LiquityStakingFacet } from "../src/facets/LiquityStakingFacet.sol";
import { PetFacet } from "../src/facets/PetFacet.sol";
import { SavingsFacet } from "../src/facets/SavingsFacet.sol";
import { SavingsLiquityConnector } from "../src/facets/SavingsLiquityConnector.sol";
import { Diamond } from "../src/core/Diamond.sol";
import { DiamondInit } from "../src/initializers/DiamondInit.sol";
import { IDiamondCut } from "../src/interfaces/IDiamondCut.sol";
import { ILiquityIntegration } from "../src/interfaces/ILiquityIntegration.sol";


contract DeployDiamond is Script {
    // Base Sepolia addresses (with correct checksums)
    address constant SAFE_PROXY_FACTORY = 0x8cCE54C22DE1E5C989d1f274C664aEE71739B250;
    address constant SAFE_SINGLETON = 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA;

    // Liquity on Base Sepolia (with correct checksums)
    address constant BORROWER_OPERATIONS = 0x293495cB5f88CbdEE3cfF0C9057f0d7a917e014B;
    address constant TROVE_MANAGER = 0x1005178d3618424dfA2991a436E5f426288b3E2F;
    address constant STABILITY_POOL = 0xA36b979F1d11D9B9410A841bbc2Fc5598eEefC20;
    address constant LUSD_TOKEN = 0x1FfB1C9cC231FA71EadB62BC5faAA8B1EA78058D;

    // Protocol parameters
    uint256 constant MIN_COLLATERAL_RATIO = 150; // 150%
    uint256 constant BORROW_FEE = 1; // 1%
    uint256 constant MIN_DAILY_DEPOSIT = 0.000333 ether;
    uint256 constant MINIMUM_ALLOCATION = 1 ether;
    uint256 constant MAX_ALLOCATION_PERCENTAGE = 80; // 80%
    uint256 constant TARGET_COLLATERAL_RATIO = 200; // 200%

    function run() external {
        vm.startBroadcast();

        // Deploy facets
        AdminControlFacet adminControlFacet = new AdminControlFacet();
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        LiquityStakingFacet liquityStakingFacet = new LiquityStakingFacet();
        PetFacet petFacet = new PetFacet();
        SavingsFacet savingsFacet = new SavingsFacet();
        SavingsLiquityConnector savingsLiquityConnector = new SavingsLiquityConnector();

        // Deploy diamond with deployer as owner
        Diamond diamond = new Diamond(msg.sender, address(diamondCutFacet));

        // Deploy initializer
        DiamondInit diamondInit = new DiamondInit();

        // Create initialization arguments
        DiamondInit.Args memory initArgs = DiamondInit.Args({
            safeProxyFactory: SAFE_PROXY_FACTORY,
            safeSingleton: SAFE_SINGLETON,
            borrowerOperations: BORROWER_OPERATIONS,
            troveManager: TROVE_MANAGER,
            stabilityPool: STABILITY_POOL,
            lusdToken: LUSD_TOKEN,
            minCollateralRatio: MIN_COLLATERAL_RATIO,
            borrowFee: BORROW_FEE,
            minDailyDeposit: MIN_DAILY_DEPOSIT,
            minimumAllocation: MINIMUM_ALLOCATION,
            maxAllocationPercentage: MAX_ALLOCATION_PERCENTAGE,
            targetCollateralRatio: TARGET_COLLATERAL_RATIO
        });

        // Create FacetCuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);

        // Admin Control facet
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

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // Diamond Loupe facet
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Liquity Staking facet
        bytes4[] memory stakingSelectors = new bytes4[](7);
        stakingSelectors[0] = LiquityStakingFacet.openPosition.selector;
        stakingSelectors[1] = LiquityStakingFacet.addCollateral.selector;
        stakingSelectors[2] = LiquityStakingFacet.adjustDebt.selector;
        stakingSelectors[3] = LiquityStakingFacet.claimRewards.selector;
        stakingSelectors[4] = LiquityStakingFacet.closePosition.selector;
        stakingSelectors[5] = ILiquityIntegration.getPosition.selector;
        stakingSelectors[6] = ILiquityIntegration.getRewards.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(liquityStakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        // Pet facet
        bytes4[] memory petSelectors = new bytes4[](7);
        petSelectors[0] = PetFacet.initializePet.selector;
        petSelectors[1] = PetFacet.feed.selector;
        petSelectors[2] = PetFacet.updateDailyTarget.selector;
        petSelectors[3] = PetFacet.getPet.selector;
        petSelectors[4] = PetFacet.calculatePetState.selector;
        petSelectors[5] = PetFacet.calculateHappiness.selector;
        petSelectors[6] = PetFacet.getFoodPrice.selector;

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(petFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: petSelectors
        });

        // Savings facet
        bytes4[] memory savingsSelectors = new bytes4[](9);
        savingsSelectors[0] = SavingsFacet.deposit.selector;
        savingsSelectors[1] = SavingsFacet.withdraw.selector;
        savingsSelectors[2] = SavingsFacet.linkSafe.selector;
        savingsSelectors[3] = SavingsFacet.createSafe.selector;
        savingsSelectors[4] = SavingsFacet.initiateStaking.selector;
        savingsSelectors[5] = SavingsFacet.getSavingsInfo.selector;
        savingsSelectors[6] = SavingsFacet.canStake.selector;
        savingsSelectors[7] = SavingsFacet.getUserSafe.selector;
        savingsSelectors[8] = SavingsFacet.getUserContributions.selector;

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(savingsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: savingsSelectors
        });

        // Savings Liquity Connector facet
        bytes4[] memory connectorSelectors = new bytes4[](3);
        connectorSelectors[0] = SavingsLiquityConnector.allocateToLiquity.selector;
        connectorSelectors[1] = SavingsLiquityConnector.claimYield.selector;
        connectorSelectors[2] = SavingsLiquityConnector.getYieldStrategy.selector;

        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(savingsLiquityConnector),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: connectorSelectors
        });

        // Perform diamond cut with initialization
        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeWithSelector(DiamondInit.init.selector, initArgs)
        );

        vm.stopBroadcast();

        // Log addresses for manual saving
        console.log("--- Contract Addresses ---");
        console.log("Diamond:", address(diamond));
        console.log("AdminControlFacet:", address(adminControlFacet));
        console.log("DiamondCutFacet:", address(diamondCutFacet));
        console.log("DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("LiquityStakingFacet:", address(liquityStakingFacet));
        console.log("PetFacet:", address(petFacet));
        console.log("SavingsFacet:", address(savingsFacet));
        console.log("SavingsLiquityConnector:", address(savingsLiquityConnector));
        console.log("DiamondInit:", address(diamondInit));
        console.log("------------------------");
    }
}
