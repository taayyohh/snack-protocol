// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDiamondCut
 * @notice Interface for the facet cutting functionality of the diamond pattern
 * @dev Based on EIP-2535 Diamond Standard
 */
interface IDiamondCut {
    /// @notice Represents the type of facet cut operation
    enum FacetCutAction {
        Add,        // Add a new facet
        Replace,    // Replace functions in a facet
        Remove      // Remove a facet
    }

    /// @notice Represents a facet cut operation
    struct FacetCut {
        address facetAddress;      // Address of the facet contract to be added/replaced/removed
        FacetCutAction action;     // Type of cut operation
        bytes4[] functionSelectors; // Function selectors to be added/replaced/removed
    }

    /// @dev Emitted when a facet cut is executed
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    /// @dev Custom errors for better gas efficiency and clarity
    error InitializationFailed();
    error InvalidFacetCutAction();
    error InvalidFunctionSelectors();
    error FacetAddressIsZero();
    error FacetAddressIsNotContract();
    error FunctionAlreadyExists();
    error FunctionDoesNotExist();
    error NoSelectorsGivenToAdd();

    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}
