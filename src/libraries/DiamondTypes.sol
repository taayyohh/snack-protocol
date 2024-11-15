// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DiamondTypes
 * @notice Contains all type definitions for the Diamond pattern
 */

/**
 * @notice Maps function selectors to facet addresses and positions
 */
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

/**
 * @notice Maps facet addresses to their function selectors
 */
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

/**
 * @notice Main diamond storage structure
 */
    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        address[] facetAddresses;
        address contractOwner;
        mapping(bytes4 => bool) supportedInterfaces;
    }
