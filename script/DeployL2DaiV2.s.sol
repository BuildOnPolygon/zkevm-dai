// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {L2DaiV2} from "src/L2DaiV2.sol";

/*
forge script script/DeployL2DaiV2.s.sol:DeployL2DaiV2 \
  --rpc-url https://zkevm-rpc.com/ \
  --chain-id 1101 \
  --verify \
  --verifier etherscan \
  --etherscan-api-key ... \
  -vvvvv \
  --broadcast
*/
contract DeployL2DaiV2 is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    new L2DaiV2(); // deploy new implementation
    vm.stopBroadcast();
  }
}
