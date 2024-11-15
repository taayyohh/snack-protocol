// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library LibMath {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
