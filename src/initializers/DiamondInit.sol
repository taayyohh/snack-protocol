// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";
import { Safe } from "../../lib/safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "../../lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IERC165.sol";
import "../interfaces/IERC173.sol";
import "../interfaces/ILiquityCore.sol";
import "../interfaces/ISavingsLiquityConnector.sol";

/**
 * @title DiamondInit
 * @notice Initializes the Snack Protocol Diamond with all necessary configurations
 */
contract DiamondInit {
    struct Args {
        // Safe contracts
        address safeProxyFactory;
        address safeSingleton;

        // Liquity contracts
        address borrowerOperations;
        address troveManager;
        address stabilityPool;
        address lusdToken;

        // Protocol parameters
        uint256 minCollateralRatio;
        uint256 borrowFee;
        uint256 minDailyDeposit;

        // Yield strategy parameters
        uint256 minimumAllocation;      // Minimum amount for yield strategy
        uint256 maxAllocationPercentage; // Max % of savings that can be allocated
        uint256 targetCollateralRatio;  // Target collateral ratio for Liquity
    }

    /**
     * @notice Errors
     */
    error InvalidAddress();
    error InvalidParameter();
    error InitializationFailed();

    /**
     * @notice Initialize the diamond with all necessary configuration
     * @param _args Struct containing all initialization parameters
     */
    function init(Args calldata _args) external {
        // Validate addresses
        if (_args.safeProxyFactory == address(0) ||
        _args.safeSingleton == address(0) ||
        _args.borrowerOperations == address(0) ||
        _args.troveManager == address(0) ||
        _args.stabilityPool == address(0) ||
            _args.lusdToken == address(0)) {
            revert InvalidAddress();
        }

        // Validate parameters
        if (_args.minCollateralRatio == 0 ||
        _args.borrowFee == 0 ||
        _args.minDailyDeposit == 0 ||
        _args.minimumAllocation == 0 ||
        _args.maxAllocationPercentage == 0 ||
        _args.maxAllocationPercentage > 100 ||
            _args.targetCollateralRatio == 0) {
            revert InvalidParameter();
        }

        // Initialize Diamond Storage
        DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Set ERC165 support
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // Initialize Safe Factory Storage
        bytes32 safePosition = keccak256("snack.protocol.storage.safe");
        assembly {
            let slot := safePosition
            sstore(slot, _args.safeProxyFactory)
            sstore(add(slot, 1), _args.safeSingleton)
        }

        // Initialize Liquity Storage
        bytes32 liquityPosition = keccak256("snack.protocol.storage.liquity");
        assembly {
            let slot := liquityPosition
        // Store contract addresses
            sstore(slot, _args.borrowerOperations)
            sstore(add(slot, 1), _args.troveManager)
            sstore(add(slot, 2), _args.stabilityPool)
            sstore(add(slot, 3), _args.lusdToken)
        // Store parameters
            sstore(add(slot, 4), _args.minCollateralRatio)
            sstore(add(slot, 5), _args.borrowFee)
        }

        // Initialize Connector Storage
        bytes32 connectorPosition = keccak256("snack.protocol.storage.connector");
        assembly {
            let slot := connectorPosition
        // Store yield strategy parameters
            sstore(slot, _args.minimumAllocation)
            sstore(add(slot, 1), _args.maxAllocationPercentage)
            sstore(add(slot, 2), _args.targetCollateralRatio)
        }

        // Initialize Pet Storage
        bytes32 petPosition = keccak256("snack.protocol.storage.pet");
        assembly {
            let slot := petPosition
        // Initialize base values
            sstore(add(slot, 1), 0) // totalPets = 0
        }

        // Initialize Savings Storage
        bytes32 savingsPosition = keccak256("snack.protocol.storage.savings");
        assembly {
            let slot := savingsPosition
        // Initialize base values
            sstore(add(slot, 1), 0) // totalSavings = 0
            sstore(add(slot, 2), _args.minDailyDeposit)
        }

        // Verify initialization
        try this.verifyInitialization(_args) {
        } catch {
            revert InitializationFailed();
        }
    }

    /**
     * @notice Verify initialization was successful
     * @dev This is called internally during init
     * @param _args The initialization arguments to verify against
     */
    function verifyInitialization(Args calldata _args) external view {
        // Verify Liquity contracts are responsive
        require(
            ITroveManager(_args.troveManager).getTroveStatus(address(this)) >= 0,
            "TroveManager not responsive"
        );

        require(
            ILUSD(_args.lusdToken).totalSupply() >= 0,
            "LUSD token not responsive"
        );

        // Verify Safe contracts
        require(
            SafeProxyFactory(_args.safeProxyFactory).proxyCreationCode().length > 0,
            "SafeFactory not responsive"
        );

        require(
            Safe(_args.safeSingleton).VERSION().length > 0,
            "Safe singleton not responsive"
        );
    }
}
