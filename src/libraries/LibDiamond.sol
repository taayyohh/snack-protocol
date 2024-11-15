// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { DiamondStorage, FacetAddressAndPosition, FacetFunctionSelectors } from "./DiamondTypes.sol";

/**
 * @title LibDiamond
 * @notice Core diamond pattern functionality for managing facets
 * @dev Handles adding, replacing, and removing facets and their functions
 */
library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("snack.protocol.diamond.storage");

    error InitializationFailed();
    error NoSelectorsProvidedForFacetForCut();
    error CannotAddSelectorsToZeroAddress();
    error NoBytecodeAtAddress();
    error CannotAddFunctionToDiamondThatAlreadyExists();
    error CannotReplaceFunctionsFromFacetWithZeroAddress();
    error CannotReplaceImmutableFunction();
    error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet();
    error CannotReplaceFunctionThatDoesNotExists();
    error RemoveFacetAddressMustBeZeroAddress();
    error CannotRemoveFunctionThatDoesNotExist();
    error CannotRemoveImmutableFunction();
    error IncorrectFacetCutAction();

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Get the diamond storage
     * @return ds The diamond storage struct
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Set the contract owner
     * @param _newOwner Address of the new owner
     */
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @notice Get the contract owner
     * @return owner Address of the contract owner
     */
    function contractOwner() internal view returns (address owner) {
        owner = diamondStorage().contractOwner;
    }

    /**
     * @notice Enforce owner-only access
     * @dev Reverts if caller is not the contract owner
     */
    function enforceIsContractOwner() internal view {
        if(msg.sender != diamondStorage().contractOwner) {
            revert("LibDiamond: Must be contract owner");
        }
    }

    /**
     * @notice Add/replace/remove functions and optionally execute initialization function
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     */
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(ds, _diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(ds, _diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(ds, _diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert IncorrectFacetCutAction();
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    /**
     * @notice Add functions to the diamond
     * @param ds The diamond storage
     * @param _facetAddress Address of the facet containing functions
     * @param _functionSelectors Function selectors to add
     */
    function addFunctions(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if(_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut();
        }
        if(_facetAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress();
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        // add new facet address if it does not exist
        if(selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for(uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if(oldFacetAddress != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists();
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @notice Replace functions in the diamond
     * @param ds The diamond storage
     * @param _facetAddress Address of the facet containing functions
     * @param _functionSelectors Function selectors to replace
     */
    function replaceFunctions(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if(_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut();
        }
        if(_facetAddress == address(0)) {
            revert CannotReplaceFunctionsFromFacetWithZeroAddress();
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if(selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for(uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if(oldFacetAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists();
            }
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @notice Remove functions from the diamond
     * @param ds The diamond storage
     * @param _facetAddress Must be address(0)
     * @param _functionSelectors Function selectors to remove
     */
    function removeFunctions(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if(_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut();
        }
        if(_facetAddress != address(0)) {
            revert RemoveFacetAddressMustBeZeroAddress();
        }
        for(uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    /**
     * @notice Add a new facet to the diamond
     * @param ds The diamond storage
     * @param _facetAddress Address of the facet to add
     */
    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress);
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    /**
     * @notice Add a function to a facet
     * @param ds The diamond storage
     * @param _selector Function selector to add
     * @param _selectorPosition Position in the selectors array
     * @param _facetAddress Address of the facet
     */
    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
    }

    /**
     * @notice Remove a function from a facet
     * @param ds The diamond storage
     * @param _facetAddress Address of the facet
     * @param _selector Function selector to remove
     */
    function removeFunction(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        if(selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        if(lastSelectorPosition == 0) {
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;

            if(facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress];
        }
    }

    /**
     * @notice Initialize the diamond cut
     * @param _init Address of the initialization contract
     * @param _calldata Initialization function call data
     */
    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init);
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFailed();
            }
        }
    }

    /**
     * @notice Enforce that an address contains contract code
     * @param _contract The address to check
     */
    function enforceHasContractCode(address _contract) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if(contractSize == 0) {
            revert NoBytecodeAtAddress();
        }
    }
}
