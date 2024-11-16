import { keccak256, toHex } from "viem";

// Define function signatures for each facet
const adminControlFacetFunctions = [
    "emergencyWithdraw(address)",
    "executeOperation(bytes32)",
    "getGlobalWithdrawalLimit()",
    "getOperation(bytes32)",
    "getProtocolState()",
    "getWithdrawalLimit(address)",
    "initializeAdminControls(uint256,address[])",
    "isActionAllowed(uint8)",
    "isAdmin(address)",
    "proposeOperation(uint8,bytes)",
    "setPauseState(uint8)",
];

const diamondCutFacetFunctions = ["diamondCut((address,uint8,bytes4[])[],address,bytes)"];
const diamondLoupeFacetFunctions = [
    "facetAddress(bytes4)",
    "facetAddresses()",
    "facetFunctionSelectors(address)",
    "facets()",
    "supportsInterface(bytes4)",
];

const liquityStakingFacetFunctions = [
    "stakeLQTY(uint256)",
    "unstakeLQTY(uint256)",
    "getStakingRewards()",
];

const petFacetFunctions = ["feedPet(uint256)", "playWithPet(uint256)", "checkPetHealth(uint256)"];
const savingsFacetFunctions = [
    "deposit(uint256)",
    "withdraw(uint256)",
    "getBalance()",
    "getInterestRate()",
];

const savingsLiquityConnectorFunctions = [
    "connectToSavings(address)",
    "disconnectFromSavings(address)",
    "getConnectionDetails()",
];

// Helper to generate selectors
function generateSelectors(functions: string[]): string[] {
    return functions.map((fn) => toHex(keccak256(new TextEncoder().encode(fn))).slice(0, 10));
}

// Generate selectors
console.log("AdminControlFacet Selectors:", generateSelectors(adminControlFacetFunctions));
console.log("DiamondCutFacet Selectors:", generateSelectors(diamondCutFacetFunctions));
console.log("DiamondLoupeFacet Selectors:", generateSelectors(diamondLoupeFacetFunctions));
console.log("LiquityStakingFacet Selectors:", generateSelectors(liquityStakingFacetFunctions));
console.log("PetFacet Selectors:", generateSelectors(petFacetFunctions));
console.log("SavingsFacet Selectors:", generateSelectors(savingsFacetFunctions));
console.log(
    "SavingsLiquityConnector Selectors:",
    generateSelectors(savingsLiquityConnectorFunctions)
);
