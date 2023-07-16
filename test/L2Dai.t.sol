// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
// import {IERC20} from "oz/token/ERC20/IERC20.sol";
// import {IERC20Permit} from "oz/token/ERC20/extensions/IERC20Permit.sol";
// import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {L2Dai} from "src/L2Dai.sol";
// import {ISavingsDAI} from "src/ISavingsDAI.sol";
// import {L1EscrowUUPSProxy} from "src/L1EscrowUUPSProxy.sol";

import {UUPSProxy} from "./UUPSProxy.sol";
import {BridgeMock} from "./BridgeMock.sol";

/**
 * @title L2DaiV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L2Dai smart contract
 */
contract L2DaiV2Mock is L2Dai {
  uint256 public some;

  /// @dev Update onMessageReceived implementation for testing purpose
  function onMessageReceived(address, uint32, bytes memory)
    external
    payable
    override
  {
    some = 42;
  }

  /// @dev Add new function for testing purpose
  function getValue() public view returns (uint256 b) {
    b = some;
  }
}

/**
 * @title L2DaiTest
 * @author sepyke.eth
 * @notice Unit tests for L2Dai
 */
contract L2DaiTest is Test {
  address owner = address(0xB453D);
  address alice = address(0xA11CE);
  address bob = address(0xB0B);

  address bridgeAddress = address(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
  address destAddress = address(4);
  uint32 destId = 0;

  L2Dai v1;
  L2Dai proxyV1;
  L2DaiV2Mock v2;
  L2DaiV2Mock proxyV2;
  L2Dai mockedV1;
  L2Dai mockedProxyV1;
  BridgeMock bridge;

  function setUp() public {
    v1 = new L2Dai();
    bytes memory v1Data = abi.encodeWithSelector(
      L2Dai.initialize.selector, owner, bridgeAddress, destAddress, destId
    );
    UUPSProxy proxy = new UUPSProxy(address(v1), v1Data);
    proxyV1 = L2Dai(address(proxy));

    mockedV1 = new L2Dai();
    bridge = new BridgeMock();
    bytes memory v2Data = abi.encodeWithSelector(
      L2Dai.initialize.selector, owner, address(bridge), destAddress, destId
    );
    UUPSProxy mockedProxy = new UUPSProxy(address(v1), v2Data);
    mockedProxyV1 = L2Dai(address(mockedProxy));

    v2 = new L2DaiV2Mock();
    proxyV2 = L2DaiV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as owner; make sure it works as expected
  function testUpgradeAsOwner() public {
    // Pre-upgrade check
    assertEq(proxyV1.owner(), owner);

    vm.startPrank(owner);
    proxyV1.upgradeTo(address(v2));
    vm.stopPrank();

    // Post-upgrade check
    // Make sure new function exists
    proxyV2.onMessageReceived(address(0), 0, "");
    assertEq(proxyV2.getValue(), 42);
  }

  /// @notice Upgrade as non-owner; make sure it reverted
  function testUpgradeAsNonOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    proxyV1.upgradeTo(address(v2));
  }

  // ==========================================================================
  // == bridge ================================================================
  // ==========================================================================

  /// @notice Make sure it revert if amount is invalid
  function testBridgeWithInvalidAmount() public {
    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(L2Dai.BridgeAmountInvalid.selector));
    proxyV1.bridge(0, false);
  }

  /// @notice Make sure L2Dai submit correct message to the bridge
  function testBridgeWithMockedBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(address(bridge));
    bytes memory data = abi.encode(alice, bridgeAmount);
    mockedProxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    mockedProxyV1.bridge(bridgeAmount, false);
    vm.stopPrank();

    assertEq(mockedProxyV1.balanceOf(alice), 0);
    assertEq(mockedProxyV1.totalSupply(), 0);

    assertEq(bridge.destId(), 0);
    assertEq(bridge.destAddress(), destAddress);
    assertEq(bridge.forceUpdateGlobalExitRoot(), false);
    assertEq(bridge.recipient(), alice);
    assertEq(bridge.amount(), bridgeAmount);
  }

  /// @notice Make sure L2Dai can interact with the bridge
  function testBridgeWithRealBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridge(bridgeAmount, false);
    vm.stopPrank();

    assertEq(proxyV1.balanceOf(alice), 0);
    assertEq(proxyV1.totalSupply(), 0);
  }

  // ==========================================================================
  // == onMessageReceived =====================================================
  // ==========================================================================

  /// @notice Make sure to revert if message is invalid
  function testOnMessageReceivedInvalidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridge(bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory metadata = abi.encode(bob, 1 ether);

    // Invalid caller
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(L2Dai.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin address
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L2Dai.MessageInvalid.selector));
    proxyV1.onMessageReceived(address(0), originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin network
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L2Dai.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, 1, metadata);
    vm.stopPrank();

    // Valid caller; invalid metadata
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert();
    proxyV1.onMessageReceived(originAddress, originNetwork, "");
    vm.stopPrank();
  }

  /// @notice Make sure user can claim the DAI
  function testOnMessageReceivedValidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    // Mint test NativeDAI
    vm.startPrank(bridgeAddress);
    bytes memory data = abi.encode(alice, bridgeAmount);
    proxyV1.onMessageReceived(destAddress, destId, data);
    vm.stopPrank();

    vm.startPrank(alice);
    proxyV1.bridge(bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory messageData = abi.encode(alice, bridgeAmount);

    vm.startPrank(currentBridgeAddress);
    proxyV1.onMessageReceived(originAddress, originNetwork, messageData);
    vm.stopPrank();

    assertEq(proxyV1.balanceOf(alice), bridgeAmount);
    assertEq(proxyV1.totalSupply(), bridgeAmount);
  }
}
