// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Diamond } from "../core/Diamond.sol";
import { DiamondInit } from "../initializers/DiamondInit.sol";
import { DiamondCutFacet } from "../facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../facets/DiamondLoupeFacet.sol";
import { PetFacet } from "../facets/PetFacet.sol";
import { SavingsFacet } from "../facets/SavingsFacet.sol";
import { LiquityStakingFacet } from "../facets/LiquityStakingFacet.sol";

/**
 * @title SnackProtocolFactory
 * @notice Deploys and initializes the complete Snack Protocol
 */
contract SnackProtocolFactory {
    event ProtocolDeployed(address diamond, address init);

    error DeploymentFailed();

    /**
     * @notice Deploy the complete protocol
     * @param _owner Address that will own the protocol
     * @param _initArgs Initialization arguments
     */
    function deployProtocol(
        address _owner,
        DiamondInit.Args calldata _initArgs
    ) external returns (address) {
        // Deploy facets
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        PetFacet petFacet = new PetFacet();
        SavingsFacet savingsFacet = new SavingsFacet();
        LiquityStakingFacet stakingFacet = new LiquityStakingFacet();

        // Deploy diamond
        Diamond diamond = new Diamond(_owner, address(cutFacet));

        // Deploy initializer
        DiamondInit init = new DiamondInit();

        // Initialize
        try init.init(_initArgs) {
            emit ProtocolDeployed(address(diamond), address(init));
            return address(diamond);
        } catch {
            revert DeploymentFailed();
        }
    }
}
