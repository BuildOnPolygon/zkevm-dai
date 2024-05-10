// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";

import {L2Dai} from "src/L2Dai.sol";
import {L2DaiV2} from "src/L2DaiV2.sol";
import {NativeConverter} from "src/NativeConverter.sol";

import {UUPSProxy} from "./UUPSProxy.sol";

contract NativeConverterTest is Test {
  string ZKEVM_RPC_URL = vm.envString("ZKEVM_RPC_URL");

  address _bridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
  address _deployer = vm.addr(0xC14C13);
  address _admin = vm.addr(0xB453D);
  address _emergency = vm.addr(0xEEEEE);
  address _migrator = vm.addr(0xD4DD1);

  address _alice = vm.addr(0xA11CE);
  address _bob = vm.addr(0xB0B);
  address _l1Escrow = address(4);
  uint32 _l1NetworkId = 0;

  IERC20 _bwDai = IERC20(0xC5015b9d9161Dca7e18e32f6f25C4aD850731Fd4);
  L2DaiV2 _nativeDai;
  NativeConverter _nativeConverter;

  function setUp() public {
    vm.selectFork(vm.createFork(ZKEVM_RPC_URL));

    // deploy L2DaiV2
    _nativeDai = L2DaiV2(
      address(
        new UUPSProxy(
          address(new L2DaiV2()),
          abi.encodeWithSelector(
            L2Dai.initialize.selector, _admin, _bridge, _l1Escrow, _l1NetworkId
          )
        )
      )
    );

    // deploy NativeConverter
    _nativeConverter = NativeConverter(
      address(
        new UUPSProxy(
          address(new NativeConverter()),
          abi.encodeWithSelector(
            NativeConverter.initialize.selector,
            _admin,
            _emergency,
            _migrator,
            _bridge,
            _l1NetworkId,
            _l1Escrow,
            address(_bwDai),
            address(_nativeDai)
          )
        )
      )
    );

    // configure native converter to be a native dai minter with 1B allowance
    vm.startPrank(_admin);
    _nativeDai.addMinter(address(_nativeConverter), 10 ** 9 * 10 ** 18);
    vm.stopPrank();
  }

  function testConvertsWrappedToNative() external {
    // alice has 1M bwdai
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwDai), _alice, amount);

    // convert to native and send to bob
    vm.startPrank(_alice);
    _bwDai.approve(address(_nativeConverter), amount);
    _nativeConverter.convert(_bob, amount);
    vm.stopPrank();

    // alice has no more bwdai
    assertEq(_bwDai.balanceOf(_alice), 0);

    // bob has 1M native dai
    assertEq(_nativeDai.balanceOf(_bob), amount);
  }

  function testDeconvertsNativeToWrapped() external {
    // seed the native converter with some bridge-wrapped dai
    deal(address(_bwDai), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // alice has 800k native dai
    uint256 amount = 800_000 * 10 ** 18;
    deal(address(_nativeDai), _alice, amount);

    // deconvert to bridge-wrapped dai and send to bob
    vm.startPrank(_alice);
    _nativeDai.approve(address(_nativeConverter), amount);
    _nativeConverter.deconvert(_bob, amount);
    vm.stopPrank();

    // alice has no more native dai
    assertEq(_nativeDai.balanceOf(_alice), 0);

    // bob has 800k bridge-wrapped dai
    assertEq(_bwDai.balanceOf(_bob), amount);
    // native converter has 200k bridge-wrapped dai
    assertEq(_bwDai.balanceOf(address(_nativeConverter)), 200_000 * 10 ** 18);
  }

  function testOwnerCanMigrate() external {
    // seed the native converter with some bridge-wrapped dai
    deal(address(_bwDai), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // migrator calls migrate
    vm.startPrank(_migrator);
    _nativeConverter.migrate();
    vm.stopPrank();

    // native converter has no more bridge-wrapped dai
    assertEq(_bwDai.balanceOf(address(_nativeConverter)), 0);

    // and we assume things got transferred to the other network
  }

  function testNonOwnerCannotMigrate() external {
    // seed the native converter with some bridge-wrapped dai
    deal(address(_bwDai), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // non-migrator tries to call migrate, fail
    vm.startPrank(_alice);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3"
    );
    _nativeConverter.migrate();
    vm.stopPrank();
  }

  function testOwnerCanPauseUnpause() external {
    vm.startPrank(_emergency);

    // unpaused, pause
    assertEq(_nativeConverter.paused(), false);
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), true);

    // paused, unpause
    _nativeConverter.unpause();
    assertEq(_nativeConverter.paused(), false);

    vm.stopPrank();
  }

  function testNonOwnerCannotPauseUnpause() external {
    vm.startPrank(_alice);

    // unpaused, try to pause, fail
    assertEq(_nativeConverter.paused(), false);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), false);

    // pause
    vm.startPrank(_emergency);
    assertEq(_nativeConverter.paused(), false);
    _nativeConverter.pause();
    assertEq(_nativeConverter.paused(), true);

    // paused, try to unpause, fail
    changePrank(_alice);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0xbf233dd2aafeb4d50879c4aa5c81e96d92f6e6945c906a58f9f2d1c1631b4b26"
    );
    _nativeConverter.unpause();
    assertEq(_nativeConverter.paused(), true);
  }

  function testCannotConvertWhenPaused() external {
    // pause
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // alice has 1M bwdai
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwDai), _alice, amount);

    // try to convert to native, fail
    vm.startPrank(_alice);
    _bwDai.approve(address(_nativeConverter), amount);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.convert(_alice, amount);
    vm.stopPrank();

    // alice still has the bwdai
    assertEq(_bwDai.balanceOf(_alice), amount);
  }

  function testCannotDeconvertWhenPaused() external {
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // seed the native converter with some bridge-wrapped dai
    deal(address(_bwDai), address(_nativeConverter), 1_000_000 * 10 ** 18);

    // alice has 800k native dai
    uint256 amount = 800_000 * 10 ** 18;
    deal(address(_nativeDai), _alice, amount);

    // try to deconvert, fail
    vm.startPrank(_alice);
    _nativeDai.approve(address(_nativeConverter), amount);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.deconvert(_alice, amount);
    vm.stopPrank();

    // alice has the same native dai
    assertEq(_nativeDai.balanceOf(_alice), amount);
  }

  function testCannotMigrateWhenPaused() external {
    vm.startPrank(_emergency);
    _nativeConverter.pause();
    vm.stopPrank();

    // seed the native converter with some bridge-wrapped dai
    uint256 amount = 1_000_000 * 10 ** 18;
    deal(address(_bwDai), address(_nativeConverter), amount);

    // call migrate
    vm.startPrank(_migrator);
    vm.expectRevert("Pausable: paused");
    _nativeConverter.migrate();
    vm.stopPrank();

    // native converter has no more bridge-wrapped dai
    assertEq(_bwDai.balanceOf(address(_nativeConverter)), amount);
  }
}
