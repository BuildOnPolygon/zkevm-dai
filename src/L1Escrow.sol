// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * L1Escrow
 * Escrow contract
 */
contract L1Escrow {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
