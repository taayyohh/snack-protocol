// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IERC165 } from "../interfaces/IERC165.sol";
import { IERC173 } from "../interfaces/IERC173.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";

/**
 * @title DiamondInit
 * @notice Initializes state variables for a diamond
 * @dev Used with diamondCut to initialize state variables
 */
contract DiamondInit {
    event Debug(string message);

    /**
     * @notice Initialize the diamond
     * @dev Sets up initial interface support
     */
    function init() external {
        emit Debug("Starting initialization");

        DiamondStorage storage ds = LibDiamond.diamondStorage();
        emit Debug("Got diamond storage");

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        emit Debug("Set IERC165");

        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        emit Debug("Set IDiamondCut");

        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        emit Debug("Set IDiamondLoupe");

        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        emit Debug("Set IERC173");
    }
}
