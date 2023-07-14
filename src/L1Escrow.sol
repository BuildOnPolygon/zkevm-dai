// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @notice Main contract to bridge DAI from Ethereum to Polygon zkEVM
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
