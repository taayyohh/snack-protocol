// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "./IERC165.sol";

/**
 * @title IDiamondLoupe
 * @notice Diamond Loupe Functions Interface
 * @dev Adds/updates/removes functions to facets of the diamond
 */
interface IDiamondLoupe is IERC165 {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Gets all facets and their selectors
     * @return facets_ Facet
     */
    function facets() external view returns (Facet[] memory facets_);

    /**
     * @notice Gets all the function selectors provided by a facet
     * @param _facet The facet address
     * @return facetFunctionSelectors_
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /**
     * @notice Get all the facet addresses used by a diamond
     * @return facetAddresses_
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /**
     * @notice Gets the facet that supports the given selector
     * @dev If facet is not found return address(0)
     * @param _functionSelector The function selector
     * @return facetAddress_ The facet address
     */
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}
