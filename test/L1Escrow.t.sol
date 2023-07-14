// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {L1Escrow} from "src/L1Escrow.sol";
import {L1EscrowUUPSProxy} from "src/L1EscrowUUPSProxy.sol";

/**
 * @title L1EscrowV2Mock
 * @author sepyke.eth
 * @notice Mock contract to test upgradeability of L1Escrow
 */
contract L1EscrowV2Mock is L1Escrow {
  /// @dev Update setBeneficiary logic for testing purpose
  function setBeneficiary(address b) public view override onlyOwner {
    revert BeneficiaryInvalid(b);
  }

  /// @dev Add getters for testing purpose
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
  address void;
  address alice;
  address bob;
  L1Escrow v1;
  L1Escrow proxyV1;
  L1EscrowV2Mock v2;
  L1EscrowV2Mock proxyV2;

  function setUp() public {
    void = address(0);
    alice = address(1);
    bob = address(2);

    v1 = new L1Escrow();
    L1EscrowUUPSProxy proxy = new L1EscrowUUPSProxy(address(v1), "");
    proxyV1 = L1Escrow(address(proxy));
    proxyV1.initialize(alice);

    v2 = new L1EscrowV2Mock();
    proxyV2 = L1EscrowV2Mock(address(proxyV1));
  }

  // ==========================================================================
  // == Upgradeability ========================================================
  // ==========================================================================

  /// @notice Upgrade as owner; make sure it works as expected
  function testUpgradeAsOwner() public {
    // Pre-upgrade check
    assertEq(proxyV1.beneficiary(), alice);

    proxyV1.upgradeTo(address(v2));
    vm.expectRevert(
      abi.encodeWithSelector(L1Escrow.BeneficiaryInvalid.selector, alice)
    );
    proxyV2.setBeneficiary(alice);

    // Post-upgrade check
    // Make sure new function exists
    assertEq(proxyV2.getBeneficiary(), alice);
  }

  /// @notice Upgrade as non-owner; make sure it reverted
  function testUpgradeAsNonOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    proxyV1.upgradeTo(address(v2));
  }

  // ==========================================================================
  // == setBeneficiary ========================================================
  // ==========================================================================

  /// @notice Make sure owner can update the beneficiary
  function testSetBeneficiaryAsOwner() public {
    proxyV1.setBeneficiary(bob);
    assertEq(proxyV1.beneficiary(), bob);
    // TODO(pyk): make sure sendYield is called
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
}
