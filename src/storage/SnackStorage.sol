// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SnackStorage
 * @notice Storage layout for Snack Protocol specific data
 * @dev Uses specific storage slots to avoid collisions
 */
library SnackStorage {
    bytes32 constant PET_STORAGE_POSITION = keccak256("snack.protocol.pet.storage");
    bytes32 constant SAVINGS_STORAGE_POSITION = keccak256("snack.protocol.savings.storage");
    bytes32 constant YIELD_STORAGE_POSITION = keccak256("snack.protocol.yield.storage");

    /**
     * @notice Storage structure for pet-related data
     * @dev Maps user addresses to their pet information
     */
    struct PetStorage {
        mapping(address => PetInfo) pets;
        uint256 totalPets;
    }

    /**
     * @notice Detailed information about a single pet
     * @dev Packed into minimal storage slots
     */
    struct PetInfo {
        uint8 petType;      // 0: Dog, 1: Cat, 2: Moo Deng
        uint8 state;        // 0: Stuffed -> 4: Starving
        uint32 lastFed;     // Timestamp
        uint32 happiness;   // 0-100
        bool isPremium;     // Premium status
    }

    /**
     * @notice Storage structure for savings-related data
     * @dev Tracks both individual and protocol-wide savings metrics
     */
    struct SavingsStorage {
        mapping(address => UserSavings) userSavings;
        uint256 totalSavingsETH;
        uint256 totalUsers;
    }

    /**
     * @notice Individual user savings information
     * @dev Tracks deposits and staking status per user
     */
    struct UserSavings {
        uint256 ethDeposited;
        uint256 lastDepositTime;
        bool isStaking;
    }

    /**
     * @notice Storage structure for yield strategy data
     * @dev Manages protocol integrations and yield targets
     */
    struct YieldStorage {
        uint256 targetAPY;
        mapping(address => bool) approvedProtocols;
        mapping(address => uint256) protocolAllocations;
    }

    /**
     * @notice Get the pet storage
     * @dev Uses assembly to access a specific storage slot
     * @return ps The pet storage struct from its special storage position
     */
    function getPetStorage() internal pure returns (PetStorage storage ps) {
        bytes32 position = PET_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
        return ps;
    }

    /**
     * @notice Get the savings storage
     * @dev Uses assembly to access a specific storage slot
     * @return ss The savings storage struct from its special storage position
     */
    function getSavingsStorage() internal pure returns (SavingsStorage storage ss) {
        bytes32 position = SAVINGS_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
        return ss;
    }

    /**
     * @notice Get the yield storage
     * @dev Uses assembly to access a specific storage slot
     * @return ys The yield storage struct from its special storage position
     */
    function getYieldStorage() internal pure returns (YieldStorage storage ys) {
        bytes32 position = YIELD_STORAGE_POSITION;
        assembly {
            ys.slot := position
        }
        return ys;
    }
}
