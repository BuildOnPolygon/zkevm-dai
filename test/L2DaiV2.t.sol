// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {L2Dai} from "src/L2Dai.sol";
import {L2DaiV2} from "src/L2DaiV2.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

contract L2DaiV2Test is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  address _owner = vm.addr(0xB453D);
  address _minter = vm.addr(0xA11CE);
  address _nonMinter = vm.addr(0xB0B);
  address _bridgeAddress = address(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
  address _destAddress = address(4);
  uint32 _destId = 0;

  L2DaiV2 _l2daiV2;

  function setUp() public {
    // deploy L2DaiV2
    vm.selectFork(vm.createFork(ZKEVM_RPC_URL));

    UUPSProxy proxy = new UUPSProxy(
      address(new L2DaiV2()),
      abi.encodeWithSelector(
        L2Dai.initialize.selector,
        _owner,
        _bridgeAddress,
        _destAddress,
        _destId
      )
    );
    _l2daiV2 = L2DaiV2(address(proxy));
  }

  function testOwnerCanAddMinter() external {
    // was not a minter
    vm.startPrank(_minter);
    vm.expectRevert("NOT_MINTER");
    _l2daiV2.mint(_destAddress, 1000 * 10 ** 18);
    vm.stopPrank();

    // owner sets minter
    vm.startPrank(_owner);
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();

    // can mint
    vm.startPrank(_minter);
    _l2daiV2.mint(_destAddress, 1000 * 10 ** 18);
    vm.stopPrank();

    // it minted
    assertEq(_l2daiV2.balanceOf(_destAddress), 1000 * 10 ** 18);
  }

  function testOwnerCanRemoveMinter() external {
    // owner sets minter
    vm.startPrank(_owner);
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();

    // can mint
    vm.startPrank(_minter);
    _l2daiV2.mint(_destAddress, 1000 * 10 ** 18);
    vm.stopPrank();

    // it minted
    assertEq(_l2daiV2.balanceOf(_destAddress), 1000 * 10 ** 18);

    // owner removes minter
    vm.startPrank(_owner);
    _l2daiV2.removeMinter(_minter);
    vm.stopPrank();

    // cannot mint
    vm.startPrank(_minter);
    vm.expectRevert("NOT_MINTER");
    _l2daiV2.mint(_destAddress, 1000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonOwnerCannotAddMinter() external {
    // trying to make itself a minter
    vm.startPrank(_minter);
    vm.expectRevert("Ownable: caller is not the owner");
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();
  }

  function testNonOwnerCannotRemoveMinter() external {
    // owner sets minter
    vm.startPrank(_owner);
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();

    // non-owner tries to remove minter
    vm.startPrank(_minter);
    vm.expectRevert("Ownable: caller is not the owner");
    _l2daiV2.removeMinter(_minter);
    vm.stopPrank();
  }

  function testMinterCannotMintOverAllowance() external {
    // owner sets minter
    vm.startPrank(_owner);
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();

    // can mint 500k
    vm.startPrank(_minter);
    _l2daiV2.mint(_destAddress, 500_000 * 10 ** 18);
    vm.stopPrank();

    // cannot mint 750k
    vm.startPrank(_minter);
    vm.expectRevert("EXCEEDS_MINT_ALLOWANCE");
    _l2daiV2.mint(_destAddress, 750_000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonMinterCannotMint() external {
    // cannot mint
    vm.startPrank(_nonMinter);
    vm.expectRevert("NOT_MINTER");
    _l2daiV2.mint(_destAddress, 1000 * 10 ** 18);
    vm.stopPrank();
  }

  function testMinterCanBurn() external {
    // owner sets minter
    vm.startPrank(_owner);
    _l2daiV2.addMinter(_minter, 10 ** 6 * 10 ** 18); // 1M DAI
    vm.stopPrank();

    // mint 500k and burn 500k
    vm.startPrank(_minter);
    _l2daiV2.mint(_minter, 500_000 * 10 ** 18);
    _l2daiV2.burn(500_000 * 10 ** 18);
    vm.stopPrank();
  }

  function testNonMinterCannotBurn() external {
    // mint 500k and burn 500k
    vm.startPrank(_nonMinter);
    vm.expectRevert("NOT_MINTER");
    _l2daiV2.burn(500_000 * 10 ** 18);
    vm.stopPrank();
  }
}
