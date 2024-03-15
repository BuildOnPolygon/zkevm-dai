// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {NativeConverter} from "src/NativeConverter.sol";
import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

import {L2DaiV2} from "src/L2DaiV2.sol";

// forge script script/DeployNativeConverter.s.sol:DeployNativeConverter --rpc-url ... -vvvvv --verify --broadcast
contract DeployNativeConverter is Script {
  address internal constant _ADMIN = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _PAUSER = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _MIGRATOR = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  uint32 internal constant _L1_NETWORK_ID = 0;
  address internal constant _L1_ESCROW = 0x4A27aC91c5cD3768F140ECabDe3FC2B2d92eDb98;
  address internal constant _L2_BW_DAI = 0xC5015b9d9161Dca7e18e32f6f25C4aD850731Fd4;
  address internal constant _L2_DAI = 0x744C5860ba161b5316F7E80D9Ec415e2727e5bD5;

  function run() external {
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

    // deploy and init native converter
    NativeConverter nc = new NativeConverter();
    bytes memory ncInitData = abi.encodeWithSelector(
      NativeConverter.initialize.selector,
      _ADMIN,
      _PAUSER,
      _MIGRATOR,
      _BRIDGE,
      _L1_NETWORK_ID,
      _L1_ESCROW,
      _L2_BW_DAI,
      _L2_DAI
    );
    bytes32 salt = keccak256(bytes("DaiNativeConverter"));
    bytes memory proxyCreationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(nc), ncInitData));
    ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(salt, proxyCreationCode);

    vm.stopBroadcast();
  }
}
