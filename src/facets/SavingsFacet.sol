// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";
import { IPetFacet }  from "../interfaces/IPetFacet.sol";

import { SafeProxyFactory } from "../../lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { ISafe } from "../../lib/safe-smart-account/contracts/interfaces/ISafe.sol";

/**
 * @title SavingsFacet
 * @notice Manages user savings, Safe integration, and provides functionality to allocate funds to Liquity.
 */
contract SavingsFacet is ISavingsFacet {
    uint256 public constant STAKING_AMOUNT = 32 ether;
    uint256 public constant MIN_DAILY_SAVING = 0.000333 ether;


    // Safe configuration - Base Sepolia addresses
    address public immutable SAFE_SINGLETON = address(0xfb1bffC9d739B8D520DaF37dF666da4C687191EA);
    address public immutable SAFE_FACTORY = address(0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67);

    /**
     * @dev Storage structure for managing savings
     */
    struct SavingsStorage {
        mapping(address => SavingsInfo) savings; // User-specific savings information
        mapping(address => address) userSafes;   // Mapping of users to their linked Safe addresses
        uint256 totalSavings;                   // Total savings in the protocol
    }

    /**
     * @notice Retrieve the savings storage for the protocol
     * @return ss The storage struct containing all user savings data
     */
    function _getSavingsStorage() internal pure returns (SavingsStorage storage ss) {
        bytes32 position = keccak256("snack.protocol.storage.savings");
        assembly {
            ss.slot := position
        }
        return ss;
    }

    /**
     * @notice Deposit ETH into the user's savings
     */
    function deposit() external payable override {
        require(msg.value > 0, "Deposit must be greater than zero");

        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        info.totalDeposited += msg.value;
        info.currentBalance += msg.value;

        ss.totalSavings += msg.value;

        emit Deposited(msg.sender, msg.value, info.currentBalance);
    }

    /**
 * @notice Deposit ETH directly into a user's Safe
 */
    function depositToSafe() external payable override {
        require(msg.value > 0, "Deposit must be greater than zero");

        SavingsStorage storage ss = _getSavingsStorage();
        address safeAddress = ss.userSafes[msg.sender];
        require(safeAddress != address(0), "No linked Safe");

        // Update storage first (Checks-Effects)
        SavingsInfo storage info = ss.savings[msg.sender];
        info.totalDeposited += msg.value;
        info.currentBalance += msg.value;

        ss.totalSavings += msg.value;

        // Transfer ETH to the Safe (Interactions)
        (bool success, ) = safeAddress.call{value: msg.value}("");
        require(success, "Failed to transfer ETH to Safe");

        emit Deposited(safeAddress, msg.value, info.currentBalance);
    }



    /**
    * @notice Withdraw ETH from the user's savings in their Safe
 * @param amount The amount to withdraw
 * @param reason Reason for the withdrawal
 */
    function withdraw(uint256 amount, string calldata reason) external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        require(amount > 0, "Amount must be greater than zero");
        require(info.currentBalance >= amount, "Insufficient balance");
        require(info.totalDeposited >= amount, "Insufficient personal deposit");

        address safeAddress = ss.userSafes[msg.sender];
        require(safeAddress != address(0), "No linked Safe");

        // Update user balances
        info.currentBalance -= amount;
        info.totalDeposited -= amount;

        ss.totalSavings -= amount;

        emit Withdrawn(msg.sender, amount, reason);

        // Transfer ETH from Safe to the user
        (bool success, ) = safeAddress.call(
            abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)", msg.sender, amount, "", 0)
        );
        require(success, "Withdrawal from Safe failed");

        // Update the pet's hunger state based on the withdrawal
        uint256 hungerLevelsToLose = amount / MIN_DAILY_SAVING;
        updatePetHungerOnWithdrawal(msg.sender, hungerLevelsToLose);
    }

    /**
     * @notice Update the pet's hunger state based on the withdrawal amount
     * @param owner The address of the pet owner
     * @param amount The amount withdrawn
     */
    function updatePetHungerOnWithdrawal(address owner, uint256 amount) internal {
        uint256 hungerLevelsToLose = amount / MIN_DAILY_SAVING;

        // Use the IPetFacet interface to call the reduceHunger function
        IPetFacet(address(this)).reduceHunger(owner, hungerLevelsToLose);
    }


    /**
    * @notice Create and link a new Safe for the user
     * @param owners Array of Safe owner addresses
     * @param threshold Number of required confirmations
     */
    function createSafe(address[] calldata owners, uint256 threshold) external override {
        SavingsStorage storage ss = _getSavingsStorage();

        // Ensure the owners array is non-empty
        require(owners.length > 0, "Owners array cannot be empty");

        // Validate the threshold
        require(threshold > 0 && threshold <= owners.length, "Invalid threshold");

        // Validate owner addresses
        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), "Invalid owner address");
        }

        // Prepare initialization data for Safe, including module setup
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,                          // Owners of the Safe
            threshold,                       // Threshold for transactions
            address(0),                      // No delegate call target during setup
            bytes(""),
            address(0),                      // Fallback handler
            address(0),                      // Payment token
            0,                               // Payment amount
            payable(address(0))              // Payment receiver
        );

        // Deploy the Safe using the Proxy Factory
        address safe = address(SafeProxyFactory(SAFE_FACTORY).createProxyWithNonce(
            SAFE_SINGLETON,
            initializer,
            block.timestamp // Using timestamp as salt
        ));

        // Store the Safe address in storage
        ss.userSafes[msg.sender] = safe;

        // Update savings info
        SavingsInfo storage info = ss.savings[msg.sender];
        info.safeAddress = safe;

        emit SafeLinked(msg.sender, safe);
    }



    /**
     * @notice Link an existing Safe to the user's account
     * @param safeAddress Address of the Safe to link
     */
    function linkSafe(address safeAddress) external override {
        SavingsStorage storage ss = _getSavingsStorage();

        ss.userSafes[msg.sender] = safeAddress;

        SavingsInfo storage info = ss.savings[msg.sender];
        info.safeAddress = safeAddress;

        emit SafeLinked(msg.sender, safeAddress);
    }

    /**
     * @notice Allocate ETH from the user's Safe to LiquityStakingFacet
     * @param amount The amount of ETH to allocate
     * @param liquityFacetAddress Address of the LiquityStakingFacet contract
     */
    function allocateToLiquity(uint256 amount, address liquityFacetAddress) external {
        SavingsStorage storage ss = _getSavingsStorage();
        address safeAddress = ss.userSafes[msg.sender];

        require(safeAddress != address(0), "No Safe linked");
        require(amount > 0, "Amount must be greater than zero");
        require(safeAddress.balance >= amount, "Insufficient balance in Safe");

        // Transfer ETH from Safe to LiquityStakingFacet
        (bool success, ) = payable(liquityFacetAddress).call{value: amount}("");
        require(success, "Transfer to Liquity failed");

        // Update user's savings information
        SavingsInfo storage info = ss.savings[msg.sender];
        info.currentBalance -= amount;

        emit AllocatedToLiquity(msg.sender, liquityFacetAddress, amount);
    }

    /**
     * @notice Begin the staking process once 32 ETH is reached
     */
    function initiateStaking() external override {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[msg.sender];

        require(info.currentBalance >= STAKING_AMOUNT, "Insufficient balance to stake");
        require(!info.isStaking, "Already staking");

        info.isStaking = true;

        emit StakingStatusChanged(msg.sender, true);
    }

    /**
     * @notice Retrieve a user's savings information
     * @param user The address of the user
     * @return SavingsInfo struct containing the user's savings details
     */
    function getSavingsInfo(address user) external view override returns (SavingsInfo memory) {
        return _getSavingsStorage().savings[user];
    }

    /**
     * @notice Check if a user has enough balance to initiate staking
     * @param user The address to check
     * @return bool indicating if the user meets the staking requirements
     */
    function canStake(address user) external view override returns (bool) {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[user];

        return info.currentBalance >= STAKING_AMOUNT && !info.isStaking;
    }

    /**
     * @notice Retrieve the Safe address linked to a user
     * @param user The address of the user
     * @return The address of the user's linked Safe
     */
    function getUserSafe(address user) external view override returns (address) {
        return _getSavingsStorage().userSafes[user];
    }

    /**
     * @notice Retrieve the total contributions and available balance of a user
     * @param user The address of the user
     * @return totalContributed The total amount the user has contributed
     * @return availableForWithdrawal The user's available balance
     */
    function getUserContributions(address user) external view returns (uint256 totalContributed, uint256 availableForWithdrawal) {
        SavingsStorage storage ss = _getSavingsStorage();
        SavingsInfo storage info = ss.savings[user];

        totalContributed = info.totalDeposited;
        availableForWithdrawal = info.currentBalance;
    }
}
