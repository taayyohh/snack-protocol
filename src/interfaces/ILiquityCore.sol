// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IBorrowerOperations
 * @notice Interface for Liquity's BorrowerOperations contract
 */
interface IBorrowerOperations {
    function openTrove(
        uint256 _maxFeePercentage,
        uint256 _LUSDAmount,
        uint256 _ETHAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function addColl(address _upperHint, address _lowerHint) external payable;

    function withdrawColl(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawLUSD(
        uint256 _maxFeePercentage,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function repayLUSD(
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove() external;
}

/**
 * @title ITroveManager
 * @notice Interface for Liquity's TroveManager contract
 */
interface ITroveManager {
    function getTroveStatus(address _borrower) external view returns (uint256);
    function getTroveCollAndDebt(address _borrower) external view returns (
        uint256 coll,
        uint256 debt
    );
}

/**
 * @title IStabilityPool
 * @notice Interface for Liquity's StabilityPool contract
 */
interface IStabilityPool {
    function provideToSP(uint256 _amount) external;
    function withdrawFromSP(uint256 _amount) external;
    function getCompoundedLUSDDeposit(address _depositor) external view returns (uint256);
    function getDepositorETHGain(address _depositor) external view returns (uint256);
}

/**
 * @title ILUSD
 * @notice Interface for LUSD token
 */
interface ILUSD {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
