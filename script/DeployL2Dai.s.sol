// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {L2Dai} from "src/L2Dai.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

/**
 * @title DeployL2Dai
 * @author sepyke.eth
 * @notice Script to deploy L2Dai
 */
contract DeployL2Dai is Script {
  // sepyke.eth
  // https://zkevm.polygonscan.com/address/0x17ae0a6BE2e97b384165626dB2569729d5006640
  address deployer = 0x17ae0a6BE2e97b384165626dB2569729d5006640;

  // Multisig Owned by Polygon Team
  // https://app.safe.global/home?safe=zkevm:0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f
  address owner = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;

  // zkEVM Bridge
  // https://zkevm.polygonscan.com/address/0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe
  address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  uint32 zkEVMBridgeDestID = 0; // zkEVM -> Ethereum

  address l1Address;

  // CREATE3 Factory
  ICREATE3Factory factory =
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  function setUp() public {
    l1Address = factory.getDeployed(deployer, keccak256(bytes("L1Escrow")));
  }

  function run() public returns (address proxy) {
    uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    vm.startBroadcast(deployerPrivateKey);

    L2Dai l2Dai = new L2Dai();
    bytes memory data = abi.encodeWithSelector(
      L2Dai.initialize.selector,
      owner,
      zkEVMBridge,
      l1Address,
      zkEVMBridgeDestID
    );
    bytes32 salt = keccak256(bytes("L2Dai"));
    bytes memory creationCode = abi.encodePacked(
      type(UUPSProxy).creationCode, abi.encode(address(l2Dai), data)
    );
    proxy = factory.deploy(salt, creationCode);

    vm.stopBroadcast();
  }
}
