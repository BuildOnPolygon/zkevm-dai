// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {ISavingsDAI} from "src/ISavingsDAI.sol";

/**
 * @title sDAITest
 * @author sepyke.eth
 * @notice Rounding issue test
 */
contract sDAITest is Test {
  using SafeERC20 for IERC20;

  string ETH_RPC_URL = vm.envString("ETH_RPC_URL");

  address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  ISavingsDAI sdai = ISavingsDAI(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

  function setUp() public {
    uint256 mainnetFork = vm.createFork(ETH_RPC_URL);
    vm.selectFork(mainnetFork);
  }

  function testRoundingIssue() public {
    vm.roll(17_693_387); // pin block

    uint256 x = 1 ether + 1;
    vm.store(dai, keccak256(abi.encode(address(this), 2)), bytes32(x));
    IERC20(dai).safeApprove(address(sdai), x);
    uint256 y = sdai.deposit(x, address(this));
    uint256 x_ = sdai.redeem(y, address(this), address(this));
    assertEq(x_, 1 ether);
  }
}
