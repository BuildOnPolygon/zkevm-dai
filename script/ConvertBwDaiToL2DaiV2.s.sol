// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {NativeConverter} from "src/NativeConverter.sol";

// forge script script/ConvertBwDaiToL2DaiV2.s.sol:ConvertBwDaiToL2DaiV2 --rpc-url ... -vvvvv
contract ConvertBwDaiToL2DaiV2 is Script {
  function run() external {
    address bwDai = 0xC5015b9d9161Dca7e18e32f6f25C4aD850731Fd4;

    address ncAddr = 0x0000000000000000000000000000000000000000; // TODO: CHANGE THIS
    uint256 amount = 10 ** 19; // TODO: CHANGE THIS if you want (10 DAI)
    uint256 myPk = vm.envUint("TESTER_PRIVATE_KEY");
    address myAddr = vm.addr(myPk);

    vm.startBroadcast(myPk);
    IERC20(bwDai).approve(ncAddr, amount);
    NativeConverter(ncAddr).convert(myAddr, amount);
    vm.stopBroadcast();
  }
}
