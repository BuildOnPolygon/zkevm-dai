// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {NativeConverter} from "src/NativeConverter.sol";
import {UUPSProxy} from "./UUPSProxy.sol";
import {ICREATE3Factory} from "./ICREATE3Factory.sol";

import {L2DaiV2} from "src/L2DaiV2.sol";

// forge script script/SetNativeConverterAsMinter.s.sol:SetNativeConverterAsMinter --rpc-url ... -vvvvv
contract SetNativeConverterAsMinter is Script {
  address internal constant _DEPLOYER = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
  address internal constant _L2_DAI = 0x744C5860ba161b5316F7E80D9Ec415e2727e5bD5;

  function run() external {
    vm.startBroadcast(vm.envUint("DAI_OWNER_PRIVATE_KEY"));

    // set as minter on l2dai (v2)
    address ncProxy = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).getDeployed(
      _DEPLOYER, keccak256(bytes("DaiNativeConverter"))
    );
    L2DaiV2(_L2_DAI).addMinter(ncProxy, 10 ** 9 * 10 ** 18); // 1B allowance

    vm.stopBroadcast();
  }
}
