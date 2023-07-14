// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {IERC20Permit} from "oz/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {L1Escrow} from "src/L1Escrow.sol";
import {ISavingsDAI} from "src/ISavingsDAI.sol";
import {L1EscrowUUPSProxy} from "src/L1EscrowUUPSProxy.sol";

/**
 * @title L1EscrowV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L1Escrow smart contract
 */
contract L1EscrowV2Mock is L1Escrow {
  /// @dev Update setBeneficiary logic for testing purpose
  function setBeneficiary(address b) public view override onlyOwner {
    revert BeneficiaryInvalid(b);
  }

  /// @dev Add new function for testing purpose
  function getBeneficiary() public view returns (address b) {
    b = beneficiary;
  }
}

/**
 * @title L1EscrowV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L1Escrow smart contract
 */
contract BridgeMock {
  uint32 public destNetworkId;
  address public l2Address;
  address public recipient;
  uint256 public amount;
  bool public forceUpdateGlobalExitRoot;

  function bridgeMessage(
    uint32 destinationNetwork,
    address destinationAddress,
    bool force,
    bytes calldata metadata
  ) external payable {
    destNetworkId = destinationNetwork;
    l2Address = destinationAddress;
    forceUpdateGlobalExitRoot = force;
    (recipient, amount) = abi.decode(metadata, (address, uint256));
  }
}

/**
 * @title L1EscrowTest
 * @author sepyke.eth
 * @notice Unit tests for L1Escrow
 */
contract L1EscrowTest is Test {
  using SafeERC20 for IERC20;

  address void = address(0);
  address alice = address(0xA11CE);
  address bob = address(2);
  address beneficiary = address(3);

  address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address sdai = address(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
  address bridgeAddress = address(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
  address l2Address = address(4);

  L1Escrow v1;
  L1Escrow proxyV1;
  L1Escrow mockedV1;
  L1Escrow mockedProxyV1;
  L1EscrowV2Mock v2;
  L1EscrowV2Mock proxyV2;
  BridgeMock bridge;

  function setUp() public {
    v1 = new L1Escrow();
    L1EscrowUUPSProxy proxy = new L1EscrowUUPSProxy(address(v1), "");
    proxyV1 = L1Escrow(address(proxy));
    proxyV1.initialize(
      dai, sdai, bridgeAddress, 1, l2Address, 1 ether, beneficiary
    );

    mockedV1 = new L1Escrow();
    L1EscrowUUPSProxy mockedProxy = new L1EscrowUUPSProxy(address(v1), "");
    mockedProxyV1 = L1Escrow(address(mockedProxy));
    bridge = new BridgeMock();
    mockedProxyV1.initialize(
      dai, sdai, address(bridge), 1, l2Address, 1 ether, beneficiary
    );

    v2 = new L1EscrowV2Mock();
    proxyV2 = L1EscrowV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as owner; make sure it works as expected
  function testUpgradeAsOwner() public {
    // Pre-upgrade check
    assertEq(proxyV1.beneficiary(), beneficiary);

    proxyV1.upgradeTo(address(v2));
    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BeneficiaryInvalid.selector, alice)
    );
    proxyV2.setBeneficiary(alice);

    // Post-upgrade check
    // Make sure new function exists
    assertEq(proxyV2.getBeneficiary(), beneficiary);
  }

  /// @notice Upgrade as non-owner; make sure it reverted
  function testUpgradeAsNonOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    proxyV1.upgradeTo(address(v2));
  }

  // ==========================================================================
  // == setProtocolDAI ========================================================
  // ==========================================================================

  /// @notice Make sure owner can update the totalProtocolDAI
  function testSetProtocolDAIAsOwner() public {
    proxyV1.setProtocolDAI(1 ether);
    assertEq(proxyV1.totalProtocolDAI(), 1 ether);
  }

  /// @notice Make sure non-owner cannot update the totalProtocolDAI
  function testSetProtocolDAIAsNonOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    proxyV1.setProtocolDAI(1 ether);
  }

  // ==========================================================================
  // == bridgeDAI =============================================================
  // ==========================================================================

  /// @notice Make sure L1Escrow submit correct message to the bridge
  function testBridgeDAIWithMockedBridge() public {
    uint256 bridgeAmount = 2 ether;
    uint256 totalProtocolDAI = 1 ether;
    mockedProxyV1.setProtocolDAI(totalProtocolDAI);
    uint256 expectedBalance =
      ISavingsDAI(sdai).previewDeposit(bridgeAmount - totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(mockedProxyV1), bridgeAmount);
    mockedProxyV1.bridgeDAI(bridgeAmount, false);

    assertEq(IERC20(dai).balanceOf(alice), 0);
    assertEq(
      IERC20(dai).balanceOf(address(mockedProxyV1)),
      bridgeAmount - totalProtocolDAI
    );
    assertEq(IERC20(sdai).balanceOf(address(mockedProxyV1)), expectedBalance);
    assertEq(mockedProxyV1.totalBridgedDAI(), bridgeAmount);

    assertEq(bridge.destNetworkId(), 1);
    assertEq(bridge.l2Address(), l2Address);
    assertEq(bridge.forceUpdateGlobalExitRoot(), false);
    assertEq(bridge.recipient(), alice);
    assertEq(bridge.amount(), bridgeAmount);
  }

  /// @notice Make sure L1Escrow can interact with the bridge
  function testBridgeDAIWithRealBridge() public {
    uint256 bridgeAmount = 2 ether;
    uint256 totalProtocolDAI = 1 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);
    uint256 expectedBalance =
      ISavingsDAI(sdai).previewDeposit(bridgeAmount - totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);

    assertEq(proxyV1.totalBridgedDAI(), bridgeAmount);
    assertEq(IERC20(dai).balanceOf(alice), 0);
    assertEq(
      IERC20(dai).balanceOf(address(proxyV1)), bridgeAmount - totalProtocolDAI
    );
    assertEq(IERC20(sdai).balanceOf(address(proxyV1)), expectedBalance);
  }

  // ==========================================================================
  // == sendExcessYield =======================================================
  // ==========================================================================

  /// @notice Make sure send excess yield to the beneficiary
  function testSendExcessYield() public {
    vm.roll(17_693_387); // pin block

    uint256 bridgeAmount = 10_000_000 ether;
    uint256 totalProtocolDAI = 1 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);

    vm.startPrank(alice);
    uint256 prevRate = ISavingsDAI(sdai).previewDeposit(1 ether);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);
    assertEq(proxyV1.totalBridgedDAI(), bridgeAmount);

    vm.warp(block.timestamp + 360 days);
    uint256 afterRate = ISavingsDAI(sdai).previewDeposit(1 ether);
    assertGt(prevRate, afterRate);

    uint256 sdaiBalance = IERC20(address(sdai)).balanceOf(address(proxyV1));
    uint256 daiBalance = IERC20(address(dai)).balanceOf(address(proxyV1));
    uint256 savingsBalance = ISavingsDAI(sdai).previewRedeem(sdaiBalance);
    uint256 totalBalance = savingsBalance + daiBalance;
    uint256 excess = totalBalance - bridgeAmount;

    proxyV1.sendExcessYield();
    uint256 balance = IERC20(address(dai)).balanceOf(beneficiary);
    assertTrue(excess - 5 <= balance);
    assertTrue(excess + 5 >= balance);

    sdaiBalance = IERC20(address(sdai)).balanceOf(address(proxyV1));
    daiBalance = IERC20(address(dai)).balanceOf(address(proxyV1));
    savingsBalance = ISavingsDAI(sdai).previewRedeem(sdaiBalance);
    totalBalance = savingsBalance + daiBalance;
    // NOTE: totalBalance should always greater than totalBridgedDAI
    assertTrue(proxyV1.totalBridgedDAI() <= totalBalance);
  }

  // ==========================================================================
  // == rebalance =============================================================
  // ==========================================================================

  /// @notice The contract should deposit the DAI to sDAI if the balance is
  ///         greater than the totalProtocolDAI.
  function testRebalanceDeposit() public {
    uint256 bridgeAmount = 10 ether;
    uint256 totalProtocolDAI = 5 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);
    vm.stopPrank();

    assertEq(IERC20(dai).balanceOf(address(proxyV1)), 5 ether);

    uint256 sDaiBalancePrev = IERC20(sdai).balanceOf(address(proxyV1));
    proxyV1.setProtocolDAI(3 ether);
    proxyV1.rebalance();
    uint256 sDaiBalanceAfter = IERC20(sdai).balanceOf(address(proxyV1));
    assertTrue(sDaiBalancePrev < sDaiBalanceAfter);
    assertEq(IERC20(dai).balanceOf(address(proxyV1)), 3 ether);
  }

  /// @notice The contract should withdraw the DAI from sDAI if the balance is
  ///         less than the totalProtocolDAI.
  function testRebalanceWithdraw() public {
    uint256 bridgeAmount = 10 ether;
    uint256 totalProtocolDAI = 3 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);
    vm.stopPrank();

    assertEq(IERC20(dai).balanceOf(address(proxyV1)), 3 ether);

    uint256 sDaiBalancePrev = IERC20(sdai).balanceOf(address(proxyV1));
    proxyV1.setProtocolDAI(5 ether);
    proxyV1.rebalance();
    uint256 sDaiBalanceAfter = IERC20(sdai).balanceOf(address(proxyV1));
    assertTrue(sDaiBalancePrev > sDaiBalanceAfter);
    assertEq(IERC20(dai).balanceOf(address(proxyV1)), 5 ether);
  }

  // ==========================================================================
  // == setBeneficiary ========================================================
  // ==========================================================================

  /// @notice Make sure owner can update the beneficiary
  function testSetBeneficiaryAsOwner() public {
    proxyV1.setBeneficiary(bob);
    assertEq(proxyV1.beneficiary(), bob);
  }

  /// @notice Make sure non-owner cannot update the beneficiary
  function testSetBeneficiaryAsNonOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    proxyV1.setBeneficiary(bob);
  }

  /// @notice Make sure revert if beneficiary is invalid
  function testSetBeneficiaryToInvalidAddress() public {
    address prevBeneficiary = proxyV1.beneficiary();
    vm.expectRevert(
      abi.encodeWithSelector(
        L1Escrow.BeneficiaryInvalid.selector, prevBeneficiary
      )
    );
    proxyV1.setBeneficiary(prevBeneficiary);

    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BeneficiaryInvalid.selector, void)
    );
    proxyV1.setBeneficiary(void);
  }

  // ==========================================================================
  // == onMessageReceived =====================================================
  // ==========================================================================
  function testOnMessageReceivedInvalidCaller() public {
    uint256 bridgeAmount = 10 ether;
    uint256 totalProtocolDAI = 3 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);
    vm.stopPrank();

    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.CallerInvalid.selector));
    proxyV1.onMessageReceived(address(0), 0, "");
  }

  function testOnMessageReceived() public {
    uint256 bridgeAmount = 10 ether;
    uint256 totalProtocolDAI = 3 ether;
    proxyV1.setProtocolDAI(totalProtocolDAI);

    vm.startPrank(alice);
    vm.store(dai, keccak256(abi.encode(alice, 2)), bytes32(bridgeAmount));
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeDAI(bridgeAmount, false);
    vm.stopPrank();

    bytes memory messageData = abi.encode(alice, 5 ether);
    vm.startPrank(bridgeAddress);
    proxyV1.onMessageReceived(address(0), 0, messageData);

    assertEq(IERC20(dai).balanceOf(alice), 5 ether);
    assertEq(proxyV1.totalBridgedDAI(), 5 ether);
  }
}
