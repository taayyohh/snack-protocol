// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";

/**
 * @title Diamond
 * @notice Main diamond proxy contract for the Snack Protocol
 * @dev Implements EIP-2535 Diamond Standard
 */
contract Diamond {
    /**
     * @notice Construct a new Diamond
     * @param _contractOwner The address of the diamond owner
     * @param _diamondCutFacet The address of the diamondCut facet contract
     */
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        require(_contractOwner != address(0), "Diamond: owner cannot be zero address");
        require(_diamondCutFacet != address(0), "Diamond: cut facet cannot be zero address");

        LibDiamond.setContractOwner(_contractOwner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        LibDiamond.diamondCut(cut, address(0), new bytes(0));
    }

    /**
     * @dev Finds facet for function that is called and executes the
     * function if a facet is found and returns any value.
     */
    fallback() external payable {
        DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }

        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}

    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceId The interface identifier, as specified in ERC-165
     * @return bool Indicates whether the contract implements `_interfaceId`
     */
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        return ds.supportedInterfaces[_interfaceId];
    }
}
