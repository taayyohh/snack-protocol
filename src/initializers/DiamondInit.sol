// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IERC165 } from "../interfaces/IERC165.sol";
import { IERC173 } from "../interfaces/IERC173.sol";
import { Safe } from "../../lib/safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "../../lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { ILiquityCore } from "../interfaces/ILiquityCore.sol";

contract DiamondInit {
    struct Args {
        address safeProxyFactory;
        address safeSingleton;
        address borrowerOperations;
        address troveManager;
        address stabilityPool;
        address lusdToken;
        uint256 minCollateralRatio;
        uint256 borrowFee;
        uint256 minDailyDeposit;
        uint256 minimumAllocation;
        uint256 maxAllocationPercentage;
        uint256 targetCollateralRatio;
    }

    function init(Args calldata _args) external {
        DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Initialize interfaces
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // Initialize contracts and parameters
        ds.safeProxyFactory = _args.safeProxyFactory;
        ds.safeSingleton = payable(_args.safeSingleton);
        ds.borrowerOperations = _args.borrowerOperations;
        ds.troveManager = _args.troveManager;
        ds.stabilityPool = _args.stabilityPool;
        ds.lusdToken = _args.lusdToken;
        ds.minCollateralRatio = _args.minCollateralRatio;
        ds.borrowFee = _args.borrowFee;
        ds.minDailyDeposit = _args.minDailyDeposit;
        ds.minimumAllocation = _args.minimumAllocation;
        ds.maxAllocationPercentage = _args.maxAllocationPercentage;
        ds.targetCollateralRatio = _args.targetCollateralRatio;
    }
}
