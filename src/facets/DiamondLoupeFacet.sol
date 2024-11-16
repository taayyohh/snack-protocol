// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IERC165 } from "../interfaces/IERC165.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";

/**
 * @title DiamondLoupeFacet
 * @notice Implements EIP-2535 Diamond standard
 * @dev Provides introspection functions for the diamond
 */
contract DiamondLoupeFacet is IDiamondLoupe {
    /**
     * @notice Gets all facets and their selectors
     * @return facets_ Array of facet addresses and their selectors
     */
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddr = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddr;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddr].functionSelectors;
        }
    }

    /**
     * @notice Gets all the function selectors supported by a specific facet
     * @param _facet The facet address
     * @return facetFunctionSelectors_ Array of function selectors
     */
    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory facetFunctionSelectors_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /**
     * @notice Get all the facet addresses used by a diamond
     * @return facetAddresses_ Array of facet addresses
     */
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /**
     * @notice Gets the facet that supports the given selector
     * @param _functionSelector The function selector to find
     * @return facetAddress_ The facet address
     */
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /**
     * @notice ERC165 support
     * @param _interfaceId The interface identifier, as specified in ERC-165
     * @return bool Whether the contract implements the interface
     */
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.supportedInterfaces[_interfaceId];
    }
}
