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
        // Function selector mappings
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        address[] facetAddresses;

        // Contract owner
        address contractOwner;

        // ERC165 supported interfaces
        mapping(bytes4 => bool) supportedInterfaces;

        // Safe-related storage
        address safeProxyFactory;
        address payable safeSingleton;

        // Liquity-related storage
        address borrowerOperations;
        address troveManager;
        address stabilityPool;
        address lusdToken;

        // Protocol parameters
        uint256 minCollateralRatio;
        uint256 borrowFee;
        uint256 minDailyDeposit;

        // Yield strategy parameters
        uint256 minimumAllocation;
        uint256 maxAllocationPercentage;
        uint256 targetCollateralRatio;
    }
