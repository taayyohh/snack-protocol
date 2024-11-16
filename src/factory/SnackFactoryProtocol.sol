// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Diamond } from "../core/Diamond.sol";
import { DiamondInit } from "../initializers/DiamondInit.sol";
import { DiamondCutFacet } from "../facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../facets/DiamondLoupeFacet.sol";
import { PetFacet } from "../facets/PetFacet.sol";
import { SavingsFacet } from "../facets/SavingsFacet.sol";
import { LiquityStakingFacet } from "../facets/LiquityStakingFacet.sol";
import { AdminControlFacet } from "../facets/AdminControlFacet.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

/**
 * @title SnackProtocolFactory
 * @notice Deploys and initializes the complete Snack Protocol
 * @dev Single factory pattern for deploying all protocol components
 */
contract SnackProtocolFactory {
    // Version control
    string public constant VERSION = "1.0.0";

    // Events
    event ProtocolDeployed(address indexed diamond, address indexed init, address deployer);
    event FacetDeployed(address indexed facet, string facetName);

    // Errors
    error DeploymentFailed();
    error InitializationFailed();
    error InvalidArguments();

    /**
     * @notice Deploy the complete protocol
     * @param _owner Address that will own the protocol
     * @param _initArgs Initialization arguments
     * @return diamondAddress The address of the deployed protocol
     */
    function deployProtocol(
        address _owner,
        DiamondInit.Args calldata _initArgs
    ) external returns (address diamondAddress) {
        // Input validation
        if (_owner == address(0)) revert InvalidArguments();

        // Deploy facets
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        emit FacetDeployed(address(cutFacet), "DiamondCutFacet");

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        emit FacetDeployed(address(loupeFacet), "DiamondLoupeFacet");

        PetFacet petFacet = new PetFacet();
        emit FacetDeployed(address(petFacet), "PetFacet");

        SavingsFacet savingsFacet = new SavingsFacet();
        emit FacetDeployed(address(savingsFacet), "SavingsFacet");

        LiquityStakingFacet stakingFacet = new LiquityStakingFacet();
        emit FacetDeployed(address(stakingFacet), "LiquityStakingFacet");

        AdminControlFacet adminFacet = new AdminControlFacet();
        emit FacetDeployed(address(adminFacet), "AdminControlFacet");

        // Deploy diamond
        Diamond diamond = new Diamond(_owner, address(cutFacet));
        diamondAddress = address(diamond);

        // Deploy initializer
        DiamondInit init = new DiamondInit();

        // Build cut struct for all facets
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](6);

        // Add DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Add PetFacet
        bytes4[] memory petSelectors = new bytes4[](8);
        petSelectors[0] = PetFacet.initializePet.selector;
        petSelectors[1] = PetFacet.feed.selector;
        petSelectors[2] = PetFacet.getPet.selector;
        petSelectors[3] = PetFacet.calculatePetState.selector;
        petSelectors[4] = PetFacet.calculateHappiness.selector;
        petSelectors[5] = PetFacet.getFoodPrice.selector;
        petSelectors[6] = PetFacet.updateDailyTarget.selector;

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(petFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: petSelectors
        });

        // Add SavingsFacet
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

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(savingsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: savingsSelectors
        });

        // Add LiquityStakingFacet
        bytes4[] memory stakingSelectors = new bytes4[](8);
        stakingSelectors[0] = LiquityStakingFacet.openPosition.selector;
        stakingSelectors[1] = LiquityStakingFacet.addCollateral.selector;
        stakingSelectors[2] = LiquityStakingFacet.adjustDebt.selector;
        stakingSelectors[3] = LiquityStakingFacet.claimRewards.selector;
        stakingSelectors[4] = LiquityStakingFacet.closePosition.selector;
        stakingSelectors[5] = LiquityStakingFacet.getPosition.selector;
        stakingSelectors[6] = LiquityStakingFacet.getRewards.selector;

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        // Add AdminControlFacet
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

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // Initialize
        try init.init(_initArgs) {
            // Execute diamond cut
            IDiamondCut(diamondAddress).diamondCut(cut, address(init), abi.encodeWithSelector(DiamondInit.init.selector, _initArgs));
            emit ProtocolDeployed(diamondAddress, address(init), msg.sender);
            return diamondAddress;
        } catch {
            revert DeploymentFailed();
        }
    }
}
