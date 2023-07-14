// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title L1EscrowUUPSProxy
 * @author sepyke.eth
 * @notice ERC1967Proxy
 *
 * Learn more here:
 * https://docs.openzeppelin.com/contracts/4.x/api/proxy#ERC1967Proxy
 */
contract L1EscrowUUPSProxy is ERC1967Proxy {
  constructor(address _implementation, bytes memory _data)
    ERC1967Proxy(_implementation, _data)
  {}
}
