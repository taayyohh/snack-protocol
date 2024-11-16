// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/Console.sol";
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
// Get deployer address from environment
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        require(deployer != address(0), "DEPLOYER_ADDRESS not set");

        console.log("\n=== Starting Diamond Deployment ===");
        console.log("Deployer address:", deployer);

        vm.startBroadcast();

// Deploy individual facets
        console.log("\n=== Deploying Facets ===");

        console.log("\nDeploying AdminControlFacet...");
        AdminControlFacet adminControlFacet = new AdminControlFacet();
        console.log("AdminControlFacet deployed at:", address(adminControlFacet));

        console.log("\nDeploying DiamondCutFacet...");
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));

        console.log("\nDeploying DiamondLoupeFacet...");
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet deployed at:", address(diamondLoupeFacet));

        console.log("\nDeploying LiquityStakingFacet...");
        LiquityStakingFacet liquityStakingFacet = new LiquityStakingFacet();
        console.log("LiquityStakingFacet deployed at:", address(liquityStakingFacet));

        console.log("\nDeploying PetFacet...");
        PetFacet petFacet = new PetFacet();
        console.log("PetFacet deployed at:", address(petFacet));

        console.log("\nDeploying SavingsFacet...");
        SavingsFacet savingsFacet = new SavingsFacet();
        console.log("SavingsFacet deployed at:", address(savingsFacet));

        console.log("\nDeploying SavingsLiquityConnector...");
        SavingsLiquityConnector savingsLiquityConnector = new SavingsLiquityConnector();
        console.log("SavingsLiquityConnector deployed at:", address(savingsLiquityConnector));

// Deploy main diamond with deployer as owner
        console.log("\n=== Deploying Main Diamond ===");
        Diamond diamond = new Diamond(deployer, address(diamondCutFacet));
        console.log("Diamond deployed at:", address(diamond));

// Deploy initializer
        console.log("\n=== Deploying DiamondInit ===");
        DiamondInit diamondInit = new DiamondInit();
        console.log("DiamondInit deployed at:", address(diamondInit));

// Create initialization arguments
        console.log("\n=== Preparing Initialization Arguments ===");
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

// Create FacetCuts array
        console.log("\n=== Creating FacetCuts ===");
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);

        // Admin Control facet
        console.log("\nPreparing AdminControlFacet selectors...");
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
        console.log("Admin facet cut created with", adminSelectors.length, "selectors");

        // Diamond Loupe facet
        console.log("\nPreparing DiamondLoupeFacet selectors...");
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
        console.log("Loupe facet cut created with", loupeSelectors.length, "selectors");

        // Liquity Staking facet
        console.log("\nPreparing LiquityStakingFacet selectors...");
        bytes4[] memory stakingSelectors = new bytes4[](7);
        stakingSelectors[0] = LiquityStakingFacet.openPosition.selector;
        stakingSelectors[1] = LiquityStakingFacet.addCollateral.selector;
        stakingSelectors[2] = LiquityStakingFacet.adjustDebt.selector;
        stakingSelectors[3] = LiquityStakingFacet.claimRewards.selector;
        stakingSelectors[4] = LiquityStakingFacet.closePosition.selector;
        stakingSelectors[5] = LiquityStakingFacet.getPosition.selector;
        stakingSelectors[6] = LiquityStakingFacet.getRewards.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(liquityStakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });
        console.log("Staking facet cut created with", stakingSelectors.length, "selectors");

        // Pet facet
        console.log("\nPreparing PetFacet selectors...");
        bytes4[] memory petSelectors = new bytes4[](8);
        petSelectors[0] = PetFacet.initializePet.selector;
        console.log("Added initializePet selector:", vm.toString(PetFacet.initializePet.selector));

        petSelectors[1] = PetFacet.feed.selector;
        console.log("Added feed selector:", vm.toString(PetFacet.feed.selector));

        petSelectors[2] = PetFacet.updateDailyTarget.selector;
        console.log("Added updateDailyTarget selector:", vm.toString(PetFacet.updateDailyTarget.selector));

        petSelectors[3] = PetFacet.getPet.selector;
        console.log("Added getPet selector:", vm.toString(PetFacet.getPet.selector));

        petSelectors[4] = PetFacet.calculatePetState.selector;
        console.log("Added calculatePetState selector:", vm.toString(PetFacet.calculatePetState.selector));

        petSelectors[5] = PetFacet.calculateHappiness.selector;
        console.log("Added calculateHappiness selector:", vm.toString(PetFacet.calculateHappiness.selector));

        petSelectors[6] = PetFacet.getFoodPrice.selector;
        console.log("Added getFoodPrice selector:", vm.toString(PetFacet.getFoodPrice.selector));

        petSelectors[7] = PetFacet.addCoOwner.selector;
        console.log("Added addCoOwner selector:", vm.toString(PetFacet.addCoOwner.selector));

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(petFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: petSelectors
        });
        console.log("Pet facet cut created with", petSelectors.length, "selectors");

        // Savings facet
        console.log("\nPreparing SavingsFacet selectors...");
        bytes4[] memory savingsSelectors = new bytes4[](10);
        savingsSelectors[0] = SavingsFacet.deposit.selector;
        console.log("Added deposit selector:", vm.toString(SavingsFacet.deposit.selector));

        savingsSelectors[1] = SavingsFacet.depositToSafe.selector;
        console.log("Added depositToSafe selector:", vm.toString(SavingsFacet.depositToSafe.selector));

        savingsSelectors[2] = SavingsFacet.withdraw.selector;
        console.log("Added withdraw selector:", vm.toString(SavingsFacet.withdraw.selector));

        savingsSelectors[3] = SavingsFacet.linkSafe.selector;
        console.log("Added linkSafe selector:", vm.toString(SavingsFacet.linkSafe.selector));

        savingsSelectors[4] = SavingsFacet.createSafe.selector;
        console.log("Added createSafe selector:", vm.toString(SavingsFacet.createSafe.selector));

        savingsSelectors[5] = SavingsFacet.allocateToLiquity.selector;
        console.log("Added allocateToLiquity selector:", vm.toString(SavingsFacet.allocateToLiquity.selector));

        savingsSelectors[6] = SavingsFacet.initiateStaking.selector;
        console.log("Added initiateStaking selector:", vm.toString(SavingsFacet.initiateStaking.selector));

        savingsSelectors[7] = SavingsFacet.getSavingsInfo.selector;
        console.log("Added getSavingsInfo selector:", vm.toString(SavingsFacet.getSavingsInfo.selector));

        savingsSelectors[8] = SavingsFacet.canStake.selector;
        console.log("Added canStake selector:", vm.toString(SavingsFacet.canStake.selector));

        savingsSelectors[9] = SavingsFacet.getUserContributions.selector;
        console.log("Added getUserContributions selector:", vm.toString(SavingsFacet.getUserContributions.selector));

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(savingsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: savingsSelectors
        });
        console.log("Savings facet cut created with", savingsSelectors.length, "selectors");

        // Savings Liquity Connector facet
        console.log("\nPreparing SavingsLiquityConnector selectors...");
        bytes4[] memory connectorSelectors = new bytes4[](3);
        connectorSelectors[0] = SavingsLiquityConnector.allocateToLiquity.selector;
        connectorSelectors[1] = SavingsLiquityConnector.claimYield.selector;
        connectorSelectors[2] = SavingsLiquityConnector.getYieldStrategy.selector;

        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(savingsLiquityConnector),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: connectorSelectors
        });
        console.log("Connector facet cut created with", connectorSelectors.length, "selectors");

        // Prepare initialization data
        console.log("\n=== Preparing Initialization Data ===");
        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, initArgs);
        console.log("Init data length:", initData.length);

        // Perform diamond cut with initialization
        console.log("\n=== Performing Diamond Cut ===");
        try IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            initData
        ) {
            console.log("Diamond cut successful!");
        } catch Error(string memory reason) {
            console.log("Diamond cut failed:", reason);
            revert(string(abi.encodePacked("Diamond cut failed: ", reason)));
        } catch {
            console.log("Diamond cut failed with no reason");
            revert("Diamond cut failed with no reason");
        }

        vm.stopBroadcast();

        // Final deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Diamond:", address(diamond));
        console.log("AdminControlFacet:", address(adminControlFacet));
        console.log("DiamondCutFacet:", address(diamondCutFacet));
        console.log("DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("LiquityStakingFacet:", address(liquityStakingFacet));
        console.log("PetFacet:", address(petFacet));
        console.log("SavingsFacet:", address(savingsFacet));
        console.log("SavingsLiquityConnector:", address(savingsLiquityConnector));
        console.log("DiamondInit:", address(diamondInit));
        console.log("\n=== Deployment Complete ===");
    }
}
