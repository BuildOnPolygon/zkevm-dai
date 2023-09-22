// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {L1Escrow} from "src/L1Escrow.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

/**
 * @title DeployL1Escrow
 * @author sepyke.eth
 * @notice Script to deploy L1Escrow
 */
contract DeployL1Escrow is Script {
  // sepyke.eth
  // https://etherscan.io/address/0x17ae0a6BE2e97b384165626dB2569729d5006640
  address deployer = 0x17ae0a6BE2e97b384165626dB2569729d5006640;

  // Multisig owned by Polygon team
  // https://app.safe.global/home?safe=eth:0xf694C9e3a34f5Fa48b6f3a0Ff186C1c6c4FcE904
  address admin = 0xf694C9e3a34f5Fa48b6f3a0Ff186C1c6c4FcE904;

  // Maker DAO
  // https://etherscan.io/address/0x3300f198988e4C9C63F75dF86De36421f06af8c4
  address makerDao = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

  // DAI
  // https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F
  address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  // sDAI
  // https://etherscan.io/address/0x83F20F44975D03b1b09e64809B757c47f942BEeA
  address sdai = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

  // zkEVM Bridge
  // https://etherscan.io/address/0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe
  address zkEVMBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  uint32 zkEVMBridgeDestID = 1; // Ethereum -> zkEVM

  // Protocol Guild Pilot Vesting Contract
  // https://app.0xsplits.xyz/accounts/0xF29Ff96aaEa6C9A1fBa851f74737f3c069d4f1a9/
  address beneficiary = 0xF29Ff96aaEa6C9A1fBa851f74737f3c069d4f1a9;

  // Initial totalProtocolDAI
  uint256 totalProtocolDAI = 1 ether;

  address l2Address;

  // CREATE3 Factory
  ICREATE3Factory factory =
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1);

  function setUp() public {
    l2Address = factory.getDeployed(deployer, keccak256(bytes("L2Dai")));
  }

  function run() public returns (address proxy) {
    uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

    vm.startBroadcast(deployerPrivateKey);

    L1Escrow l1Escrow = new L1Escrow();
    bytes memory data = abi.encodeWithSelector(
      L1Escrow.initialize.selector,
      admin,
      makerDao,
      dai,
      sdai,
      zkEVMBridge,
      zkEVMBridgeDestID,
      l2Address,
      totalProtocolDAI,
      beneficiary
    );
    bytes32 salt = keccak256(bytes("L1Escrow"));
    bytes memory creationCode = abi.encodePacked(
      type(UUPSProxy).creationCode, abi.encode(address(l1Escrow), data)
    );
    proxy = factory.deploy(salt, creationCode);

    vm.stopBroadcast();
  }
}
