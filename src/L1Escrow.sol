// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @notice Main contract to bridge DAI from Ethereum to Polygon zkEVM
 */
contract L1Escrow is Initializable {
  uint256 public number;

  constructor() {
    _disableInitializers();
  }

  function setNumber(uint256 newNumber) public {
    number = newNumber;
  }

  function increment() public {
    number++;
  }
}
