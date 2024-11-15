// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title DiamondCutFacet
 * @notice External interface for diamond cuts
 * @dev Handles adding, replacing, and removing facets from the diamond
 */
contract DiamondCutFacet is IDiamondCut {
    /// @notice modifier for owner-only functions
    modifier onlyOwner {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    /**
     * @notice Add/replace/remove any number of functions and optionally execute a function with delegatecall
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override onlyOwner {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
