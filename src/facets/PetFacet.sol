// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibMath } from "../libraries/LibMath.sol";
import { IPetFacet } from "../interfaces/IPetFacet.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";

/**
 * @title PetFacet
 * @notice Manages pet state and interactions
 * @dev Part of the Snack Protocol Diamond
 */
contract PetFacet is IPetFacet {
    using LibMath for uint256;

    /**
     * @dev Constants for game mechanics
     */
    uint256 private constant MIN_DAILY_SAVING = 0.000333 ether;
    uint256 private constant STATE_UPDATE_INTERVAL = 12 hours;
    uint256 private constant PREMIUM_PRICE = 0.1 ether;

    // Multipliers for food prices (relative to MIN_DAILY_SAVING)
    uint256 private constant BANANA_MULTIPLIER = 1;    // 0.000333 ETH
    uint256 private constant EGG_MULTIPLIER = 2;       // 0.000666 ETH
    uint256 private constant TOAST_MULTIPLIER = 3;     // 0.000999 ETH
    uint256 private constant DONUT_MULTIPLIER = 5;     // 0.001665 ETH
    uint256 private constant ONIGIRI_MULTIPLIER = 7;   // 0.002331 ETH
    uint256 private constant SALMON_MULTIPLIER = 10;   // 0.00333 ETH
    uint256 private constant STEAK_MULTIPLIER = 20;    // 0.00666 ETH

    /**
     * @dev Storage for pet-related data
     */
    struct PetStorage {
        mapping(address => Pet) pets;
        uint256 totalPets;
    }

    /**
     * @dev Get pet storage
     */
    function _getPetStorage() internal pure returns (PetStorage storage ps) {
        bytes32 position = keccak256("snack.protocol.storage.pet");
        assembly {
            ps.slot := position
        }
        return ps;
    }

    /**
     * @notice Initialize a new pet
     */
    function initializePet(PetType petType, uint256 dailyTarget) external override {
        if (dailyTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        if (ps.pets[msg.sender].lastFed != 0) revert PetAlreadyExists();

        Pet memory newPet = Pet({
            petType: petType,
            state: PetState.HUNGRY,
            lastFed: block.timestamp,
            happiness: 50,
            isPremium: false,
            totalSavings: 0,
            dailyTarget: dailyTarget,
            lastMeal: FoodType.BANANA
        });

        ps.pets[msg.sender] = newPet;
        ps.totalPets++;

        emit PetCreated(msg.sender, petType, dailyTarget);
    }

    /**
     * @notice Feed the pet
     */
    function feed(FoodType foodType) external payable override {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[msg.sender];

        if (pet.lastFed == 0) revert PetDoesNotExist();

        uint256 price = getFoodPrice(foodType);
        if (msg.value < price) revert InsufficientPayment();

        _updatePetState(msg.sender, foodType, msg.value);
    }

    /**
     * @notice Get pet information
     */
    function getPet(address owner) external view override returns (Pet memory) {
        return _getPetStorage().pets[owner];
    }

    /**
     * @notice Calculate current pet state
     */
    function calculatePetState(address owner) external view override returns (PetState) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];
        if (pet.lastFed == 0) revert PetDoesNotExist();

        uint256 timeSinceLastFed = block.timestamp - pet.lastFed;

        // State degrades every STATE_UPDATE_INTERVAL
        uint256 periodsWithoutFeeding = timeSinceLastFed / STATE_UPDATE_INTERVAL;

        if (periodsWithoutFeeding == 0) {
            return pet.state;
        }

        // Calculate new state based on periods without feeding
        uint8 currentStateIndex = uint8(pet.state);
        uint8 newStateIndex = currentStateIndex + uint8(periodsWithoutFeeding);

        // Cap at STARVING state
        if (newStateIndex >= uint8(PetState.STARVING)) {
            return PetState.STARVING;
        }

        return PetState(newStateIndex);
    }

    /**
     * @notice Calculate current happiness
     */
    function calculateHappiness(address owner) external view override returns (uint256) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];
        if (pet.lastFed == 0) revert PetDoesNotExist();

        PetState currentState = this.calculatePetState(owner);

        // Happiness decreases based on state
        uint256 baseHappiness = pet.happiness;
        uint256 stateImpact = uint256(currentState) * 10;

        if (baseHappiness <= stateImpact) {
            return 0;
        }

        return baseHappiness - stateImpact;
    }

    /**
     * @notice Get food price for specific food type
     */
    function getFoodPrice(FoodType foodType) public pure override returns (uint256 price) {
        uint256 multiplier = BANANA_MULTIPLIER;

        if (foodType == FoodType.EGG) multiplier = EGG_MULTIPLIER;
        else if (foodType == FoodType.TOAST) multiplier = TOAST_MULTIPLIER;
        else if (foodType == FoodType.DONUT) multiplier = DONUT_MULTIPLIER;
        else if (foodType == FoodType.ONIGIRI) multiplier = ONIGIRI_MULTIPLIER;
        else if (foodType == FoodType.SALMON) multiplier = SALMON_MULTIPLIER;
        else if (foodType == FoodType.STEAK) multiplier = STEAK_MULTIPLIER;

        return MIN_DAILY_SAVING * multiplier;
    }

    /**
     * @notice Update daily savings target
     */
    function updateDailyTarget(uint256 newTarget) external override {
        if (newTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[msg.sender];

        if (pet.lastFed == 0) revert PetDoesNotExist();

        pet.dailyTarget = newTarget;
        emit DailyTargetUpdated(msg.sender, newTarget);
    }

    /**
     * @notice Upgrade pet to premium
     */
    function upgradeToPremium() external payable override {
        if (msg.value < PREMIUM_PRICE) revert InsufficientPayment();

        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[msg.sender];

        if (pet.lastFed == 0) revert PetDoesNotExist();
        if (pet.isPremium) revert AlreadyPremium();

        pet.isPremium = true;
        pet.happiness = LibMath.min(100, pet.happiness + 10); // Premium bonus
    }

    /**
     * @notice Internal function to update pet state
     */
    function _updatePetState(address owner, FoodType foodType, uint256 amount) internal {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];

        pet.totalSavings += amount;
        pet.lastFed = block.timestamp;
        pet.lastMeal = foodType;

        // Calculate happiness boost based on food type
        uint256 happinessBoost;
        if (foodType == FoodType.STEAK) happinessBoost = 20;
        else if (foodType == FoodType.SALMON) happinessBoost = 15;
        else if (foodType == FoodType.ONIGIRI) happinessBoost = 12;
        else if (foodType == FoodType.DONUT) happinessBoost = 10;
        else if (foodType == FoodType.TOAST) happinessBoost = 8;
        else if (foodType == FoodType.EGG) happinessBoost = 5;
        else happinessBoost = 3;

        // Premium pets get extra happiness
        if (pet.isPremium) {
            happinessBoost += 5;
        }

        // Update state based on amount relative to daily target
        if (amount >= pet.dailyTarget) {
            pet.state = PetState.STUFFED;
        } else if (amount >= pet.dailyTarget * 3 / 4) {
            pet.state = PetState.FULL;
        } else if (amount >= pet.dailyTarget / 2) {
            pet.state = PetState.CONTENT;
        } else {
            pet.state = PetState.HUNGRY;
        }

        pet.happiness = LibMath.min(100, pet.happiness + happinessBoost);

        emit PetStateChanged(owner, pet.state, pet.happiness);
        emit PetFed(owner, foodType, amount, pet.happiness);
    }
}
