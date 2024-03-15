// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {L2DaiV2} from "src/L2DaiV2.sol";

// forge script script/UpgradeToL2DaiV2.s.sol:DeployAndUpgradeL2DaiV2 --rpc-url ... -vvvvv --verify
contract DeployAndUpgradeL2DaiV2 is Script {
  address internal constant _L2_DAI_PROXY = 0x744C5860ba161b5316F7E80D9Ec415e2727e5bD5;

  function run() external {
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

    L2DaiV2 daiV2 = new L2DaiV2(); // deploy new implementation
    UUPSUpgradeable proxy = UUPSUpgradeable(_L2_DAI_PROXY); // get proxy
    proxy.upgradeTo(address(daiV2)); // upgrade to new implementation

    vm.stopBroadcast();
  }
}
