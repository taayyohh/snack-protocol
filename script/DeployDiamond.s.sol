// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {AdminControlFacet} from "../src/facets/AdminControlFacet.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {LiquityStakingFacet} from "../src/facets/LiquityStakingFacet.sol";
import {PetFacet} from "../src/facets/PetFacet.sol";
import {SavingsFacet} from "../src/facets/SavingsFacet.sol";
import {SavingsLiquityConnector} from "../src/facets/SavingsLiquityConnector.sol";
import {Diamond} from "../src/core/Diamond.sol";
import {DiamondInit} from "../src/initializers/DiamondInit.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";

contract DeployDiamond is Script {
    function run() external {
        vm.startBroadcast();

        // Step 1: Deploy all facets
        AdminControlFacet adminControlFacet = new AdminControlFacet();
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        LiquityStakingFacet liquityStakingFacet = new LiquityStakingFacet();
        PetFacet petFacet = new PetFacet();
        SavingsFacet savingsFacet = new SavingsFacet();
        SavingsLiquityConnector savingsLiquityConnector = new SavingsLiquityConnector();

        // Step 2: Deploy the Diamond contract
        Diamond diamond = new Diamond(address(msg.sender), address(diamondCutFacet));

        // Step 3: Deploy the initializer
        DiamondInit diamondInit = new DiamondInit();

        // Step 4: Define selectors for each facet
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](6);

        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getAdminControlSelectors()
        });

        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeSelectors()
        });

        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(liquityStakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getLiquityStakingSelectors()
        });

        facetCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(petFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getPetFacetSelectors()
        });

        facetCuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(savingsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSavingsSelectors()
        });

        facetCuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(savingsLiquityConnector),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSavingsLiquityConnectorSelectors()
        });

        // Step 5: Perform diamondCut
        IDiamondCut(address(diamond)).diamondCut(
            facetCuts,
            address(diamondInit),
            abi.encodeWithSelector(DiamondInit.init.selector)
        );

        vm.stopBroadcast();
    }

    // Define selectors for each facet
    function getAdminControlSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](11);
        selectors[0] = bytes4(0x30783666); // Function: addAdmin()
        selectors[1] = bytes4(0x30786362); // Function: removeAdmin()
        selectors[2] = bytes4(0x30783239); // Function: setPauseState()
        selectors[3] = bytes4(0x30783237); // Function: proposeOperation()
        selectors[4] = bytes4(0x30786437); // Function: signOperation()
        selectors[5] = bytes4(0x30786337); // Function: executeOperation()
        selectors[6] = bytes4(0x30783134); // Function: isAdmin()
        selectors[7] = bytes4(0x30786561); // Function: getProtocolState()
        selectors[8] = bytes4(0x30783234); // Function: getOperation()
        selectors[9] = bytes4(0x30783933); // Function: getWithdrawalLimit()
        selectors[10] = bytes4(0x30783633); // Function: emergencyWithdraw()
    }

    function getDiamondLoupeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5) ;
        selectors[0] = bytes4(0x30786364); // Function: facets()
        selectors[1] = bytes4(0x30783532); // Function: facetFunctionSelectors()
        selectors[2] = bytes4(0x30786164); // Function: facetAddresses()
        selectors[3] = bytes4(0x30783761); // Function: facetAddress()
        selectors[4] = bytes4(0x30783031); // Function: supportsInterface()
    }

    function getLiquityStakingSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3) ;
        selectors[0] = bytes4(0x30786638); // Function: stake()
        selectors[1] = bytes4(0x30786435); // Function: unstake()
        selectors[2] = bytes4(0x30783938); // Function: getStakingBalance()
    }

    function getPetFacetSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3) ;
        selectors[0] = bytes4(0x30786662); // Function: checkPetHealth()
        selectors[1] = bytes4(0x30783437); // Function: feedPet()
        selectors[2] = bytes4(0x30783338); // Function: playWithPet()
    }

    function getSavingsSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](4) ;
        selectors[0] = bytes4(0x30786236); // Function: deposit()
        selectors[1] = bytes4(0x30783265); // Function: withdraw()
        selectors[2] = bytes4(0x30783132); // Function: checkBalance()
        selectors[3] = bytes4(0x30783532); // Function: accrueInterest()
    }

    function getSavingsLiquityConnectorSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3) ;
        selectors[0] = bytes4(0x30783766);
        selectors[1] = bytes4(0x30783536);
        selectors[2] = bytes4(0x30786532);
    }
}
