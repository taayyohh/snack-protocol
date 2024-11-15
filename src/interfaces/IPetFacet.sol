// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPetFacet
 * @notice Interface for the pet management functionality
 */
interface IPetFacet {
    /**
     * @notice Pet types available in the game
     */
    enum PetType {
        DOG,
        CAT,
        MOO_DENG
    }

    /**
     * @notice Food types and their relative values
     */
    enum FoodType {
        BANANA,     // Basic food - min daily (0.000333 ETH)
        EGG,        // 2x min daily
        TOAST,      // 3x min daily
        DONUT,      // 5x min daily
        ONIGIRI,    // 7x min daily
        SALMON,     // 10x min daily
        STEAK       // Premium food - 20x min daily
    }

    /**
     * @notice Emotional states of the pet
     */
    enum PetState {
        STUFFED,    // Over daily goal
        FULL,       // Max daily goal
        CONTENT,    // More than half
        HUNGRY,     // Saved but still hungry
        STARVING    // No savings
    }

    /**
     * @notice Pet information structure
     */
    struct Pet {
        PetType petType;
        PetState state;
        uint256 lastFed;
        uint256 happiness;
        bool isPremium;
        uint256 totalSavings;
        uint256 dailyTarget;    // Customizable daily savings target
        FoodType lastMeal;      // Track last food type used
    }

    /**
     * @notice Emitted when a new pet is created
     */
    event PetCreated(address indexed owner, PetType petType, uint256 dailyTarget);

    /**
     * @notice Emitted when pet state changes
     */
    event PetStateChanged(address indexed owner, PetState newState, uint256 happiness);

    /**
     * @notice Emitted when pet is fed
     */
    event PetFed(address indexed owner, FoodType food, uint256 amount, uint256 newHappiness);

    /**
     * @notice Emitted when daily target is updated
     */
    event DailyTargetUpdated(address indexed owner, uint256 newTarget);

    /**
     * @notice Initialize a new pet for the caller
     * @param petType The type of pet to create
     * @param dailyTarget Custom daily savings target (minimum 0.000333 ETH)
     */
    function initializePet(PetType petType, uint256 dailyTarget) external;

    /**
     * @notice Feed the pet with specific food type
     * @param foodType The type of food to feed
     */
    function feed(FoodType foodType) external payable;

    /**
     * @notice Update daily savings target
     * @param newTarget New daily target (minimum 0.000333 ETH)
     */
    function updateDailyTarget(uint256 newTarget) external;

    /**
     * @notice Get pet information for an address
     */
    function getPet(address owner) external view returns (Pet memory);

    /**
     * @notice Get food price for specific food type
     * @param foodType The food type to check
     * @return Food price in ETH
     */
    function getFoodPrice(FoodType foodType) external pure returns (uint256);
}
