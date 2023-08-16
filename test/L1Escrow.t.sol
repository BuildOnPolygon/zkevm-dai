// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {L1Escrow} from "src/L1Escrow.sol";
import {ISavingsDAI} from "src/ISavingsDAI.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {UUPSProxy} from "./UUPSProxy.sol";

/**
 * @title L1EscrowV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L1Escrow smart contract
 */
contract L1EscrowV2Mock is L1Escrow {
  /// @dev Update setBeneficiary logic for testing purpose
  function setBeneficiary(address b)
    public
    view
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    revert BeneficiaryInvalid(b);
  }

  /// @dev Add new function for testing purpose
  function getBeneficiary() public view returns (address b) {
    b = beneficiary;
  }
}

/**
 * @title L1EscrowTest
 * @author sepyke.eth
 * @notice Unit tests for L1Escrow
 */
contract L1EscrowTest is Test {
  using SafeERC20 for IERC20;

  string ETH_RPC_URL = vm.envString("ETH_RPC_URL");

  address void = address(0);
  address admin = vm.addr(0xB453D);
  address maker = vm.addr(0xD4160D);
  address alice = vm.addr(0xA11CE);
  address bob = vm.addr(0xB0B);
  address beneficiary = vm.addr(0xC001);

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
    uint256 mainnetFork = vm.createFork(ETH_RPC_URL);
    vm.selectFork(mainnetFork);

    v1 = new L1Escrow();
    bytes memory v1Data = abi.encodeWithSelector(
      L1Escrow.initialize.selector,
      admin,
      maker,
      dai,
      sdai,
      bridgeAddress,
      1,
      l2Address,
      1 ether,
      beneficiary
    );
    UUPSProxy proxy = new UUPSProxy(address(v1), v1Data);
    proxyV1 = L1Escrow(address(proxy));

    mockedV1 = new L1Escrow();
    bridge = new BridgeMock();
    bytes memory mockedV1Data = abi.encodeWithSelector(
      L1Escrow.initialize.selector,
      admin,
      maker,
      dai,
      sdai,
      address(bridge),
      1,
      l2Address,
      1 ether,
      beneficiary
    );
    UUPSProxy mockedProxy = new UUPSProxy(address(v1), mockedV1Data);
    mockedProxyV1 = L1Escrow(address(mockedProxy));
    v2 = new L1EscrowV2Mock();
    proxyV2 = L1EscrowV2Mock(address(proxyV1));

    // Donate small amount of DAI to L1Escrow
    uint256 donateAmount = 0.01 ether;
    vm.store(
      dai, keccak256(abi.encode(address(proxyV1), 2)), bytes32(donateAmount)
    );
    vm.store(
      dai,
      keccak256(abi.encode(address(mockedProxyV1), 2)),
      bytes32(donateAmount)
    );
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as admin; make sure it works as expected
  function testUpgradeAsAdmin() public {
    // Pre-upgrade check
    assertEq(proxyV1.beneficiary(), beneficiary);

    vm.startPrank(admin);
    proxyV1.upgradeTo(address(v2));
    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BeneficiaryInvalid.selector, alice)
    );
    proxyV2.setBeneficiary(alice);

    // Post-upgrade check
    // Make sure new function exists
    assertEq(proxyV2.getBeneficiary(), beneficiary);
  }

  /// @notice Upgrade as non-admin; make sure it reverted
  function testUpgradeAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    proxyV1.upgradeTo(address(v2));
  }

  // ==========================================================================
  // == setProtocolDAI ========================================================
  // ==========================================================================

  /// @notice Make sure Maker can update the totalProtocolDAI
  function testSetProtocolDAIAsMaker() public {
    vm.startPrank(maker);
    proxyV1.setProtocolDAI(1 ether);
    vm.stopPrank();
    assertEq(proxyV1.totalProtocolDAI(), 1 ether);
  }

  /// @notice Make sure non-maker cannot update the totalProtocolDAI
  function testSetProtocolDAIAsNonMaker() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x70d8f6b4dfca278d41482e0778a0bf123d87b86b23b71cc0ef42c2f082e8053a"
      )
    );
    proxyV1.setProtocolDAI(1 ether);

    vm.startPrank(admin);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xba0af250cc5ffecaca8ff49310d5b9478a6f758e is missing role 0x70d8f6b4dfca278d41482e0778a0bf123d87b86b23b71cc0ef42c2f082e8053a"
      )
    );
    proxyV1.setProtocolDAI(1 ether);
  }

  // ==========================================================================
  // == bridge ================================================================
  // ==========================================================================

  /// @notice Make sure it revert if amount is invalid
  function testBridgeWithInvalidAmount() public {
    vm.startPrank(alice);
    IERC20(dai).safeApprove(address(mockedProxyV1), 1 ether);
    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BridgeAmountInvalid.selector)
    );
    proxyV1.bridgeToken(alice, 0, false);
  }

  /// @notice Make sure L1Escrow submit correct message to the bridge
  function testBridgeWithMockedBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    uint256 sDAIBalance = ISavingsDAI(sdai).previewDeposit(bridgeAmount);

    vm.startPrank(alice);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(mockedProxyV1), bridgeAmount);
    mockedProxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(IERC20(dai).balanceOf(alice), 0);
    assertEq(IERC20(sdai).balanceOf(address(mockedProxyV1)), sDAIBalance);
    assertEq(mockedProxyV1.totalBridgedDAI(), bridgeAmount);

    assertEq(bridge.destId(), 1);
    assertEq(bridge.destAddress(), l2Address);
    assertEq(bridge.forceUpdateGlobalExitRoot(), false);
    assertEq(bridge.recipient(), alice);
    assertEq(bridge.amount(), bridgeAmount);
  }

  /// @notice Make sure L1Escrow can interact with the bridge
  function testBridgeWithRealBridge(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    uint256 sDAIBalance = ISavingsDAI(sdai).previewDeposit(bridgeAmount);

    vm.startPrank(alice);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(proxyV1.totalBridgedDAI(), bridgeAmount);
    assertEq(IERC20(dai).balanceOf(alice), 0);
    assertEq(IERC20(sdai).balanceOf(address(proxyV1)), sDAIBalance);
  }

  // ==========================================================================
  // == sendExcessYield =======================================================
  // ==========================================================================

  /// @notice Make sure send excess yield to the beneficiary
  function testSendExcessYield() public {
    vm.roll(17_693_387); // pin block

    vm.startPrank(alice);
    uint256 bridgeAmount = 1_000_000_000 ether;
    uint256 prevRate = ISavingsDAI(sdai).previewDeposit(1 ether);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    assertEq(proxyV1.totalBridgedDAI(), bridgeAmount);

    // Time travel to get interest earned
    vm.warp(block.timestamp + 360 days);

    // Make sure rate is higher than previous one
    uint256 afterRate = ISavingsDAI(sdai).previewDeposit(1 ether);
    assertGt(prevRate, afterRate);

    proxyV1.sendExcessYield();
    uint256 balance = IERC20(address(dai)).balanceOf(beneficiary);
    assertGt(balance, 0);

    // Check post-effect
    uint256 sdaiBalance = IERC20(address(sdai)).balanceOf(address(proxyV1));
    uint256 daiBalance = IERC20(address(dai)).balanceOf(address(proxyV1));
    uint256 savingsBalance = ISavingsDAI(sdai).previewRedeem(sdaiBalance);
    uint256 totalManagedDAI = savingsBalance + daiBalance;
    // NOTE: totalManagedDAI should always greater than totalBridgedDAI
    assertTrue(proxyV1.totalBridgedDAI() <= totalManagedDAI);
  }

  // ==========================================================================
  // == rebalance =============================================================
  // ==========================================================================

  /// @notice The contract should deposit the DAI to sDAI if the balance is
  ///         greater than the totalProtocolDAI.
  function testRebalance() public {
    uint256 bridgeAmount = 5 ether;

    vm.startPrank(alice);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    // It should withdraw DAI from sDAI
    uint256 sDaiBalancePrev = IERC20(sdai).balanceOf(address(proxyV1));
    vm.startPrank(maker);
    proxyV1.setProtocolDAI(3 ether);
    vm.stopPrank();
    proxyV1.rebalance();
    uint256 sDaiBalanceAfter = IERC20(sdai).balanceOf(address(proxyV1));
    assertTrue(sDaiBalancePrev > sDaiBalanceAfter);
    assertTrue(IERC20(dai).balanceOf(address(proxyV1)) >= 3 ether);

    // It should deposit DAI to sDAI
    sDaiBalancePrev = IERC20(sdai).balanceOf(address(proxyV1));
    vm.startPrank(maker);
    proxyV1.setProtocolDAI(1 ether);
    vm.stopPrank();
    proxyV1.rebalance();
    sDaiBalanceAfter = IERC20(sdai).balanceOf(address(proxyV1));
    assertTrue(sDaiBalancePrev < sDaiBalanceAfter);
    assertTrue(IERC20(dai).balanceOf(address(proxyV1)) >= 1 ether);
  }

  // ==========================================================================
  // == setBeneficiary ========================================================
  // ==========================================================================

  /// @notice Make sure admin can update the beneficiary
  function testSetBeneficiaryAsAdmin() public {
    vm.startPrank(admin);
    proxyV1.setBeneficiary(bob);
    vm.stopPrank();
    assertEq(proxyV1.beneficiary(), bob);
  }

  /// @notice Make sure non-admin cannot update the beneficiary
  function testSetBeneficiaryAsNonAdmin() public {
    vm.startPrank(alice);
    vm.expectRevert(
      bytes(
        "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    );
    proxyV1.setBeneficiary(bob);
    vm.stopPrank();
  }

  /// @notice Make sure revert if beneficiary is invalid
  function testSetBeneficiaryToInvalidAddress() public {
    vm.startPrank(admin);
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
    vm.stopPrank();
  }

  // ==========================================================================
  // == onMessageReceived =====================================================
  // ==========================================================================

  /// @notice Make sure to revert if message is invalid
  function testOnMessageReceivedInvalidMessage(uint256 bridgeAmount) public {
    vm.assume(bridgeAmount > 1 ether);
    vm.assume(bridgeAmount < 1_000_000_000 ether);

    vm.startPrank(alice);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(alice, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory metadata = abi.encode(bob, 1 ether);

    // Invalid caller
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin address
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(address(0), originNetwork, metadata);
    vm.stopPrank();

    // Valid caller; invalid origin network
    vm.startPrank(currentBridgeAddress);
    vm.expectRevert(abi.encodeWithSelector(L1Escrow.MessageInvalid.selector));
    proxyV1.onMessageReceived(originAddress, 0, metadata);
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

    vm.startPrank(alice);
    deal(dai, alice, bridgeAmount);
    IERC20(dai).safeApprove(address(proxyV1), bridgeAmount);
    proxyV1.bridgeToken(bob, bridgeAmount, false);
    vm.stopPrank();

    address currentBridgeAddress = address(proxyV1.zkEvmBridge());
    address originAddress = proxyV1.destAddress();
    uint32 originNetwork = proxyV1.destId();
    bytes memory messageData = abi.encode(bob, bridgeAmount);

    vm.startPrank(currentBridgeAddress);
    proxyV1.onMessageReceived(originAddress, originNetwork, messageData);
    vm.stopPrank();

    assertEq(IERC20(dai).balanceOf(bob), bridgeAmount);
    assertEq(proxyV1.totalBridgedDAI(), 0);
  }
}
