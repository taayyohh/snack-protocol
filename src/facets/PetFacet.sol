// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibMath } from "../libraries/LibMath.sol";
import { IPetFacet } from "../interfaces/IPetFacet.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";
import { SavingsFacet } from "./SavingsFacet.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";

/**
 * @title PetFacet
 * @notice Manages pet state, interactions, and integrates savings functionality
 * @dev Part of the Snack Protocol Diamond
 */
contract PetFacet is IPetFacet {
    using LibMath for uint256;

    // Constants for game mechanics
    uint256 private constant MIN_DAILY_SAVING = 0.000333 ether;
    uint256 private constant STATE_UPDATE_INTERVAL = 12 hours;

    // Multipliers for food prices (relative to MIN_DAILY_SAVING)
    uint256 private constant BANANA_MULTIPLIER = 1;
    uint256 private constant EGG_MULTIPLIER = 2;
    uint256 private constant TOAST_MULTIPLIER = 3;
    uint256 private constant DONUT_MULTIPLIER = 5;
    uint256 private constant ONIGIRI_MULTIPLIER = 7;
    uint256 private constant SALMON_MULTIPLIER = 10;
    uint256 private constant STEAK_MULTIPLIER = 20;

    /**
     * @dev Storage structure for managing pets
     */
    struct PetStorage {
        mapping(address => Pet) pets; // Mapping of owner address to pet
        uint256 totalPets;           // Total number of pets created
    }

    // Custom errors
    error InvalidDailyTarget();
    error PetAlreadyExists();
    error PetDoesNotExist();
    error InsufficientPayment();

    /**
     * @dev Modifier to restrict access to pet owners
     * @param owner The address of the pet owner
     */
    modifier onlyPetOwner(address owner) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];

        if (!pet.isOwner[msg.sender]) {
            revert("NotAuthorized: Caller is not a pet owner");
        }
        _;
    }

    /**
     * @dev Retrieve the storage struct for pet-related data
     * @return ps The storage struct containing all pet-related data
     */
    function _getPetStorage() internal pure returns (PetStorage storage ps) {
        bytes32 position = keccak256("snack.protocol.storage.pet");
        assembly {
            ps.slot := position
        }
        return ps;
    }

    /**
     * @notice Initialize a new pet for the caller
     * @dev Creates a pet with the specified type and daily savings target. Links a Safe for managing funds.
     * @param petType The type of the pet being created (e.g., CAT, DOG)
     * @param dailyTarget The daily savings target for the pet in wei
    */
    function initializePet(PetType petType, uint256 dailyTarget) external override {
        if (dailyTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        if (ps.pets[msg.sender].lastFed != 0) revert PetAlreadyExists();

        // Initialize the pet in storage directly
        ps.pets[msg.sender].petType = petType;
        ps.pets[msg.sender].state = PetState.HUNGRY;
        ps.pets[msg.sender].lastFed = block.timestamp;
        ps.pets[msg.sender].happiness = 50;
        ps.pets[msg.sender].totalSavings = 0;
        ps.pets[msg.sender].dailyTarget = dailyTarget;
        ps.pets[msg.sender].lastMeal = FoodType.BANANA;

        // Add the primary owner to the owners array and `isOwner` mapping
        ps.pets[msg.sender].owners.push(msg.sender);
        ps.pets[msg.sender].isOwner[msg.sender] = true;

        // Create a dynamic array to store the owner's address
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;

        try ISavingsFacet(address(this)).createSafe(owners, 1) {
            // Safe created successfully
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Safe creation failed: ", reason)));
        }

        emit PetCreated(msg.sender, petType, dailyTarget);
    }


    /**
     * @notice Add a co-owner to the caller's pet
     * @dev Adds the specified address as a co-owner of the pet. Ensures no duplicates are added.
     * @param coOwner The address of the co-owner to add
     */
    function addCoOwner(address coOwner) external {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[msg.sender];

        if (pet.lastFed == 0) revert PetDoesNotExist(); // Ensure the pet exists
        if (pet.isOwner[coOwner]) revert("Already a co-owner");

        // Add the co-owner
        pet.owners.push(coOwner);
        pet.isOwner[coOwner] = true;

        emit CoOwnerAdded(msg.sender, coOwner);
    }


    /**
    * @notice Retrieve pet information for a specific owner
    * @param owner The address of the pet owner
    * @return petInfo A PetInfo struct with the pet's details, or default values if no pet exists
    */
    function getPet(address owner) external view override returns (PetInfo memory petInfo) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];

        // Return a default PetInfo if the pet doesn't exist
        if (pet.lastFed == 0) {
            return PetInfo({
                petType: PetType(0), // Cast to PetType enum
                state: PetState(0), // Cast to PetState enum
                lastFed: 0,
                happiness: 0,
                totalSavings: 0,
                dailyTarget: 0,
                lastMeal: FoodType(0), // Cast to FoodType enum
                owners: new address[](0)
            });
        }

        // Return the actual pet information if it exists
        return PetInfo({
            petType: pet.petType,
            state: pet.state,
            lastFed: pet.lastFed,
            happiness: pet.happiness,
            totalSavings: pet.totalSavings,
            dailyTarget: pet.dailyTarget,
            lastMeal: pet.lastMeal,
            owners: pet.owners
        });
    }



    /**
     * @notice Feed the user's pet and save the ETH in the corresponding safe
     * @param foodType The type of food being fed to the pet
     */
    function feed(FoodType foodType) external payable override onlyPetOwner(msg.sender) {
        uint256 price = getFoodPrice(foodType);
        if (msg.value < price) revert InsufficientPayment();

        SavingsFacet savingsFacet = SavingsFacet(address(this));
        savingsFacet.depositToSafe{value: msg.value}();

        _updatePetState(msg.sender, foodType, msg.value);
    }


    /**
     * @notice Update the daily savings target for the user's pet
     * @param newTarget The new daily target for the pet
     */
    function updateDailyTarget(uint256 newTarget) external override onlyPetOwner(msg.sender) {
        if (newTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[msg.sender];

        pet.dailyTarget = newTarget;
        emit DailyTargetUpdated(msg.sender, newTarget);
    }

    /**
     * @notice Calculate the current state of the user's pet
     * @param owner The address of the pet owner
     * @return The current state of the pet
     */
    function calculatePetState(address owner) external view override returns (PetState) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];
        if (pet.lastFed == 0) revert PetDoesNotExist();

        uint256 timeSinceLastFed = block.timestamp - pet.lastFed;
        uint256 periodsWithoutFeeding = timeSinceLastFed / STATE_UPDATE_INTERVAL;

        if (periodsWithoutFeeding == 0) {
            return pet.state;
        }

        uint8 currentStateIndex = uint8(pet.state);
        uint8 newStateIndex = currentStateIndex + uint8(periodsWithoutFeeding);

        if (newStateIndex >= uint8(PetState.STARVING)) {
            return PetState.STARVING;
        }

        return PetState(newStateIndex);
    }

    /**
     * @notice Calculate the current happiness of the user's pet
     * @param owner The address of the pet owner
     * @return The current happiness of the pet
     */
    function calculateHappiness(address owner) external view override returns (uint256) {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];
        if (pet.lastFed == 0) revert PetDoesNotExist();

        PetState currentState = this.calculatePetState(owner);

        uint256 baseHappiness = pet.happiness;
        uint256 stateImpact = uint256(currentState) * 10;

        if (baseHappiness <= stateImpact) {
            return 0;
        }

        return baseHappiness - stateImpact;
    }

    /**
     * @notice Retrieve the price of a specific food type
     * @param foodType The type of food to price
     * @return The price of the food in wei
     */
    function getFoodPrice(FoodType foodType) public pure override returns (uint256) {
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
     * @dev Internal function to update the pet's state and happiness
     * @param owner The address of the pet owner
     * @param foodType The type of food used to feed the pet
     * @param amount The amount of ETH deposited for feeding
     */
    function _updatePetState(address owner, FoodType foodType, uint256 amount) internal {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];

        pet.totalSavings += amount;
        pet.lastFed = block.timestamp;
        pet.lastMeal = foodType;

        uint256 happinessBoost = calculateHappinessBoost(foodType);

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

    /**
     * @notice Calculate the happiness boost based on food type
     * @param foodType The type of food being fed
     * @return The calculated happiness boost
     */
    function calculateHappinessBoost(FoodType foodType) internal pure returns (uint256) {
        uint256 baseBoost = foodType == FoodType.STEAK ? 20 : foodType == FoodType.SALMON ? 15 : 10;
        return baseBoost;
    }

/**
 * @notice Reduce the hunger level of the user's pet
 * @param owner The address of the pet owner
 * @param levels The number of hunger levels to lose
 */
    function reduceHunger(address owner, uint256 levels) external {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.pets[owner];

        // Ensure the pet exists
        if (pet.lastFed == 0) revert PetDoesNotExist();

        // Get the current state as an integer
        uint8 currentState = uint8(pet.state);

        // Calculate the new state after reducing levels
        if (currentState + levels >= uint8(PetState.STARVING)) {
            // If levels exceed the lowest state, set to STARVING
            pet.state = PetState.STARVING;
        } else {
            // Otherwise, decrement the state by the given levels
            pet.state = PetState(currentState + uint8(levels));
        }

        // Emit the PetStateChanged event with the updated happiness
        emit PetStateChanged(owner, pet.state, pet.happiness);
    }

}
