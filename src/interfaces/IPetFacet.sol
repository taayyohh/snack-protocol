// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPetFacet
 * @notice Interface for the PetFacet contract
 */
interface IPetFacet {
    /**
     * @notice Enum representing the state of the pet
     */
    enum PetState {
        HUNGRY,
        CONTENT,
        FULL,
        STUFFED,
        STARVING
    }

    /**
     * @notice Enum representing the type of food that can be fed to the pet
     */
    enum FoodType {
        BANANA,
        EGG,
        TOAST,
        DONUT,
        ONIGIRI,
        SALMON,
        STEAK
    }

    /**
     * @notice Enum representing the type of pet
     */
    enum PetType {
        DOG,
        CAT,
        BIRD,
        FISH,
        HAMSTER,
        RABBIT
    }

    /**
     * @notice Struct representing the pet's data
     */
    struct Pet {
        PetType petType;          // Type of the pet
        PetState state;           // Current state of the pet
        uint256 lastFed;          // Timestamp of the last feeding
        uint256 happiness;        // Current happiness level
        bool isPremium;           // Whether the pet has premium status
        uint256 totalSavings;     // Total ETH savings linked to the pet
        uint256 dailyTarget;      // Daily savings target
        FoodType lastMeal;        // The last food type fed to the pet
        address[] owners;         // List of authorized owners
        mapping(address => bool) isOwner; // Mapping of owners for quick lookup
    }

    /**
   * @notice Simplified struct to return pet information without nested mappings
     */
    struct PetInfo {
        PetType petType;
        PetState state;
        uint256 lastFed;
        uint256 happiness;
        bool isPremium;
        uint256 totalSavings;
        uint256 dailyTarget;
        FoodType lastMeal;
        address[] owners;
    }

    /**
     * @notice Emitted when a new pet is created
     * @param owner The address of the pet's primary owner
     * @param petType The type of pet created
     * @param dailyTarget The daily savings target for the pet
     */
    event PetCreated(address indexed owner, PetType petType, uint256 dailyTarget);

    /**
     * @notice Emitted when the pet's state or happiness changes
     * @param owner The address of the pet's primary owner
     * @param state The new state of the pet
     * @param happiness The new happiness level of the pet
     */
    event PetStateChanged(address indexed owner, PetState state, uint256 happiness);

    /**
     * @notice Emitted when the pet is fed
     * @param owner The address of the pet's primary owner
     * @param foodType The type of food fed to the pet
     * @param amount The amount of ETH used to feed the pet
     * @param happiness The updated happiness level of the pet
     */
    event PetFed(address indexed owner, FoodType foodType, uint256 amount, uint256 happiness);

    /**
     * @notice Emitted when the daily target is updated
     * @param owner The address of the pet's primary owner
     * @param newTarget The new daily target for the pet
     */
    event DailyTargetUpdated(address indexed owner, uint256 newTarget);

    /**
     * @notice Initialize a new pet for the user with co-owners
     * @param petType The type of pet to initialize
     * @param dailyTarget The daily target savings for feeding the pet
     * @param coOwners An array of additional co-owners for the pet
     */
    function initializePet(PetType petType, uint256 dailyTarget, address[] calldata coOwners) external;


    /**
     * @notice Retrieve information about a pet
     * @param owner The address of the pet owner
     * @return A PetInfo struct with the pet's details
     */
    function getPet(address owner) external view returns (PetInfo memory);

    /**
     * @notice Feed the user's pet and save the ETH in the corresponding safe
     * @param foodType The type of food being fed to the pet
     */
    function feed(FoodType foodType) external payable;

    /**
     * @notice Update the daily savings target for the user's pet
     * @param newTarget The new daily target for the pet
     */
    function updateDailyTarget(uint256 newTarget) external;

    /**
     * @notice Calculate the current state of the user's pet
     * @param owner The address of the pet owner
     * @return The current state of the pet
     */
    function calculatePetState(address owner) external view returns (PetState);

    /**
     * @notice Calculate the current happiness of the user's pet
     * @param owner The address of the pet owner
     * @return The current happiness of the pet
     */
    function calculateHappiness(address owner) external view returns (uint256);

    /**
     * @notice Retrieve the price of a specific food type
     * @param foodType The type of food to price
     * @return The price of the food in wei
     */
    function getFoodPrice(FoodType foodType) external pure returns (uint256);
}
