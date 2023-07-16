// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title BridgeMock
 * @author sepyke.eth
 * @notice This mock contract is used to make sure passed message are valid
 */
contract BridgeMock {
  uint32 public destNetworkId;
  address public l2Address;
  address public recipient;
  uint256 public amount;
  bool public forceUpdateGlobalExitRoot;

  function bridgeMessage(
    uint32 destinationNetwork,
    address destinationAddress,
    bool force,
    bytes calldata metadata
  ) external payable {
    destNetworkId = destinationNetwork;
    l2Address = destinationAddress;
    forceUpdateGlobalExitRoot = force;
    (recipient, amount) = abi.decode(metadata, (address, uint256));
  }
}
