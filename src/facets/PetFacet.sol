// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibMath } from "../libraries/LibMath.sol";
import { IPetFacet } from "../interfaces/IPetFacet.sol";
import { DiamondStorage } from "../libraries/DiamondTypes.sol";
import { SavingsFacet } from "./SavingsFacet.sol";
import { ISavingsFacet } from "../interfaces/ISavingsFacet.sol";

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

    struct PetStorage {
        mapping(uint256 => Pet) petsById;           // Pet ID to Pet data
        mapping(address => uint256) addressToPetId;  // Owner address to Pet ID
        uint256 nextPetId;                          // Counter for generating unique pet IDs
    }

    // Custom errors
    error InvalidDailyTarget();
    error PetAlreadyExists();
    error PetDoesNotExist();
    error InsufficientPayment();
    error AlreadyCoOwner();
    error CoOwnerHasPet();
    error NotAuthorized();

    modifier onlyPetOwner(address owner) {
        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[owner];
        if (petId == 0) revert PetDoesNotExist();
        if (!ps.petsById[petId].isOwner[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    function _getPetStorage() internal pure returns (PetStorage storage ps) {
        bytes32 position = keccak256("snack.protocol.storage.pet");
        assembly {
            ps.slot := position
        }
    }

    function initializePet(PetType petType, uint256 dailyTarget) external override {
        if (dailyTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        if (ps.addressToPetId[msg.sender] != 0) revert PetAlreadyExists();

        uint256 newPetId = ++ps.nextPetId;
        Pet storage newPet = ps.petsById[newPetId];

        newPet.petType = petType;
        newPet.state = PetState.HUNGRY;
        newPet.lastFed = block.timestamp;
        newPet.happiness = 50;
        newPet.totalSavings = 0;
        newPet.dailyTarget = dailyTarget;
        newPet.lastMeal = FoodType.BANANA;

        newPet.owners.push(msg.sender);
        newPet.isOwner[msg.sender] = true;
        ps.addressToPetId[msg.sender] = newPetId;

        address[] memory owners = new address[](1);
        owners[0] = msg.sender;

        try ISavingsFacet(address(this)).createSafe(owners, 1) {
            // Safe created successfully
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Safe creation failed: ", reason)));
        }

        emit PetCreated(msg.sender, petType, dailyTarget);
    }

    function addCoOwner(address coOwner) external {
        if (coOwner == address(0)) revert("Invalid address");

        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[msg.sender];
        if (petId == 0) revert PetDoesNotExist();

        Pet storage pet = ps.petsById[petId];
        if (pet.isOwner[coOwner]) revert AlreadyCoOwner();
        if (ps.addressToPetId[coOwner] != 0) revert CoOwnerHasPet();

        pet.owners.push(coOwner);
        pet.isOwner[coOwner] = true;
        ps.addressToPetId[coOwner] = petId;

        emit CoOwnerAdded(msg.sender, coOwner);
    }

    function getPet(address owner) external view override returns (PetInfo memory) {
        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[owner];

        if (petId == 0) {
            return PetInfo({
                petType: PetType(0),
                state: PetState(0),
                lastFed: 0,
                happiness: 0,
                totalSavings: 0,
                dailyTarget: 0,
                lastMeal: FoodType(0),
                owners: new address[](0)
            });
        }

        Pet storage pet = ps.petsById[petId];
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

    function feed(FoodType foodType) external payable override onlyPetOwner(msg.sender) {
        uint256 price = getFoodPrice(foodType);
        if (msg.value < price) revert InsufficientPayment();

        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[msg.sender];

        SavingsFacet savingsFacet = SavingsFacet(address(this));
        savingsFacet.depositToSafe{value: msg.value}();

        _updatePetState(petId, foodType, msg.value);
    }

    function updateDailyTarget(uint256 newTarget) external override onlyPetOwner(msg.sender) {
        if (newTarget < MIN_DAILY_SAVING) revert InvalidDailyTarget();

        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[msg.sender];
        Pet storage pet = ps.petsById[petId];

        pet.dailyTarget = newTarget;
        emit DailyTargetUpdated(msg.sender, newTarget);
    }

    function calculatePetState(address owner) external view override returns (PetState) {
        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[owner];
        if (petId == 0) revert PetDoesNotExist();

        Pet storage pet = ps.petsById[petId];
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

    function calculateHappiness(address owner) external view override returns (uint256) {
        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[owner];
        if (petId == 0) revert PetDoesNotExist();

        Pet storage pet = ps.petsById[petId];
        PetState currentState = this.calculatePetState(owner);

        uint256 baseHappiness = pet.happiness;
        uint256 stateImpact = uint256(currentState) * 10;

        if (baseHappiness <= stateImpact) {
            return 0;
        }

        return baseHappiness - stateImpact;
    }

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

    function _updatePetState(uint256 petId, FoodType foodType, uint256 amount) internal {
        PetStorage storage ps = _getPetStorage();
        Pet storage pet = ps.petsById[petId];

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

        address primaryOwner = pet.owners[0];
        emit PetStateChanged(primaryOwner, pet.state, pet.happiness);
        emit PetFed(primaryOwner, foodType, amount, pet.happiness);
    }

    function calculateHappinessBoost(FoodType foodType) internal pure returns (uint256) {
        if (foodType == FoodType.STEAK) return 20;
        if (foodType == FoodType.SALMON) return 15;
        return 10;
    }

    function reduceHunger(address owner, uint256 levels) external {
        PetStorage storage ps = _getPetStorage();
        uint256 petId = ps.addressToPetId[owner];
        if (petId == 0) revert PetDoesNotExist();

        Pet storage pet = ps.petsById[petId];
        uint8 currentState = uint8(pet.state);

        if (currentState + levels >= uint8(PetState.STARVING)) {
            pet.state = PetState.STARVING;
        } else {
            pet.state = PetState(currentState + uint8(levels));
        }

        emit PetStateChanged(owner, pet.state, pet.happiness);
    }
}
