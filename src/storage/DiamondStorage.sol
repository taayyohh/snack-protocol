// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DiamondStorage
 * @notice Central storage layout for the Snack Protocol Diamond
 * @dev Uses the diamond storage pattern to avoid storage collisions
 */

/**
 * @notice Maps function selectors to facet addresses and positions
 * @dev Used to efficiently lookup facets for function calls
 * @param facetAddress The address of the facet contract
 * @param functionSelectorPosition Position in the facetFunctionSelectors.functionSelectors array
 */
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

/**
 * @notice Maps facet addresses to their function selectors
 * @dev Used for facet management and introspection
 * @param functionSelectors Array of function selectors supported by the facet
 * @param facetAddressPosition Position of facetAddress in facetAddresses array
 */
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

/**
 * @notice Main diamond storage structure
 * @dev Holds all protocol-level storage for the diamond
 * @param selectorToFacetAndPosition Maps function selector to the facet address and position
 * @param facetFunctionSelectors Maps facet addresses to their function selectors
 * @param facetAddresses Array of all facet addresses
 * @param contractOwner Address of the contract owner
 * @param supportedInterfaces Maps interface IDs to boolean (ERC-165 support)
 */
    struct DiamondStorage {
        // maps function selector to the facet address and position in facetFunctionSelectors
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // owner of the contract
        address contractOwner;
        // supported interfaces
        mapping(bytes4 => bool) supportedInterfaces;
    }

/**
 * @title LibDiamondStorage
 * @notice Library for accessing diamond storage
 * @dev Provides functions to access the diamond storage slot
 */
library LibDiamondStorage {
    /**
     * @dev Unique storage position for diamond storage
     * keccak256 hash of "snack.protocol.diamond.storage" ensures a unique storage position
     */
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("snack.protocol.diamond.storage");

    /**
     * @notice Get the diamond storage
     * @dev Uses assembly to access a specific storage slot
     * @return ds The diamond storage struct from its special storage position
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        return ds;
    }
}
