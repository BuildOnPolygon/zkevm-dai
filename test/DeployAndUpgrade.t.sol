// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {L2DaiV2} from "src/L2DaiV2.sol";
import {NativeConverter} from "src/NativeConverter.sol";
import {ICREATE3Factory} from "script/ICREATE3Factory.sol";
import {UUPSProxy} from "script/UUPSProxy.sol";

contract TestDaiV2andNativeConverter is Test {
  function testDeployAndUpgradeDaiToV2AndNativeConverter() external {
    vm.selectFork(vm.createFork(vm.envString("ZKEVM_RPC_URL")));

    address daiOwner = 0x2be7b3e7b9BFfbB38B85f563f88A34d84Dc99c9f;
    address l2dai = 0x744C5860ba161b5316F7E80D9Ec415e2727e5bD5;
    address bwDai = 0xC5015b9d9161Dca7e18e32f6f25C4aD850731Fd4;

    vm.deal(daiOwner, 10 ** 18); // fund with 1 eth

    // DEPLOY DAIv2 AND UPGRADE THE PROXY
    vm.startPrank(daiOwner);
    L2DaiV2 daiV2 = new L2DaiV2(); // deploy new implementation
    UUPSUpgradeable proxy = UUPSUpgradeable(l2dai); // get proxy
    proxy.upgradeTo(address(daiV2)); // upgrade to new implementation
    vm.stopPrank();

    // DEPLOY NATIVE CONVERTER
    vm.startPrank(daiOwner);
    NativeConverter nc = new NativeConverter();
    bytes memory ncInitData = abi.encodeWithSelector(
      NativeConverter.initialize.selector,
      daiOwner,
      daiOwner,
      daiOwner,
      0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe, // bridge
      0, // l1 network id
      0x4A27aC91c5cD3768F140ECabDe3FC2B2d92eDb98, // l1 escrow
      bwDai,
      l2dai
    );
    bytes32 salt = keccak256(bytes("DaiNativeConverter"));
    bytes memory proxyCreationCode = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(nc), ncInitData));
    address ncProxy = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(salt, proxyCreationCode);
    vm.stopPrank();

    // SET NATIVE CONVERTER AS A DAI MINTER
    vm.startPrank(daiOwner);
    L2DaiV2(l2dai).addMinter(ncProxy, 10 ** 9 * 10 ** 18); // 1B allowance
    vm.stopPrank();

    // TEST NATIVE CONVERTER
    address alice = vm.addr(8);
    uint256 amount = 10 ** 3 * 10 ** 18;
    deal(bwDai, alice, amount); // fund alice with 1k bwDAI

    vm.startPrank(alice);
    assertEq(IERC20(l2dai).balanceOf(alice), 0);
    IERC20(bwDai).approve(ncProxy, amount);
    NativeConverter(ncProxy).convert(alice, amount);
    assertEq(IERC20(l2dai).balanceOf(alice), amount);
    vm.stopPrank();
  }
}
