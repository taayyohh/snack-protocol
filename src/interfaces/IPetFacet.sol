// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPetFacet
 * @notice Interface for the PetFacet contract which manages pet interactions and savings mechanics
 * @dev This interface aligns with the PetFacet implementation in the Snack Protocol
 */
interface IPetFacet {
    /**
     * @notice States a pet can be in, reflecting their savings status
     * @dev Order is important as it's used in state calculations and transitions
     */
    enum PetState {
        STUFFED,    // Over daily goal
        FULL,       // Max daily goal
        CONTENT,    // More than half
        HUNGRY,     // Saved but still hungry
        STARVING    // No savings
    }

    /**
     * @notice Types of food that can be fed to pets, each with different costs and effects
     * @dev Food types are tied to specific ETH values and happiness boosts
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
     * @notice Available pet types in the game
     * @dev Each pet type may have unique characteristics or bonuses
     */
    enum PetType {
        DOG,
        CAT,
        MOO
    }

    /**
     * @notice Complete pet data structure including ownership information
     * @dev This struct contains both basic pet info and multi-owner functionality
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
     * @notice View-friendly pet information structure
     * @dev Used for external queries to avoid issues with nested mappings
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
     * @param owner Address of the pet's primary owner
     * @param petType Type of pet that was created
     * @param dailyTarget Initial daily savings target for the pet
     */
    event PetCreated(address indexed owner, PetType petType, uint256 dailyTarget);

    /**
     * @notice Emitted when a pet's state or happiness changes
     * @param owner Address of the pet's owner
     * @param state New state of the pet
     * @param happiness Updated happiness level
     */
    event PetStateChanged(address indexed owner, PetState state, uint256 happiness);

    /**
     * @notice Emitted when a pet is fed
     * @param owner Address of the pet's owner
     * @param foodType Type of food used
     * @param amount Amount of ETH spent on food/saved
     * @param happiness Updated happiness level
     */
    event PetFed(address indexed owner, FoodType foodType, uint256 amount, uint256 happiness);

    /**
     * @notice Emitted when a pet's daily target is updated
     * @param owner Address of the pet's owner
     * @param newTarget New daily savings target
     */
    event DailyTargetUpdated(address indexed owner, uint256 newTarget);

    /**
     * @notice Emitted when a co-owner is added to a pet
     * @param owner Address of the primary owner
     * @param coOwner Address of the new co-owner
     */
    event CoOwnerAdded(address indexed owner, address indexed coOwner);

    /**
     * @notice Initializes a new pet for the caller
     * @dev Creates a pet and links it to a new Safe for fund management
     * @param petType The type of pet to create
     * @param dailyTarget The daily savings target in wei (minimum 0.000333 ETH)
     */
    function initializePet(PetType petType, uint256 dailyTarget) external;

    /**
     * @notice Retrieves information about a specific pet
     * @param owner The address of the pet owner to query
     * @return PetInfo struct containing the pet's current state and attributes
     */
    function getPet(address owner) external view returns (PetInfo memory);

    /**
     * @notice Feeds the pet and saves ETH in the corresponding safe
     * @dev The msg.value must match or exceed the food price
     * @param foodType The type of food to feed the pet
     */
    function feed(FoodType foodType) external payable;

    /**
     * @notice Updates the daily savings target for the pet
     * @param newTarget New daily target in wei (minimum 0.000333 ETH)
     */
    function updateDailyTarget(uint256 newTarget) external;

    /**
     * @notice Calculates the current state of a pet based on feeding history
     * @param owner The address of the pet owner
     * @return The current PetState
     */
    function calculatePetState(address owner) external view returns (PetState);

    /**
     * @notice Calculates the current happiness level of a pet
     * @param owner The address of the pet owner
     * @return The current happiness value (0-100)
     */
    function calculateHappiness(address owner) external view returns (uint256);

    /**
     * @notice Gets the price for a specific food type
     * @param foodType The type of food to check
     * @return The price in wei
     */
    function getFoodPrice(FoodType foodType) external pure returns (uint256);

    /**
     * @notice Adds a co-owner to the caller's pet
     * @param coOwner The address to add as a co-owner
     */
    function addCoOwner(address coOwner) external;


    /**
     * @notice Reduces the hunger level of a pet based on a specified number of levels
     * @param owner The address of the pet owner
     * @param levels The number of hunger levels to reduce
     */
    function reduceHunger(address owner, uint256 levels) external;
}
