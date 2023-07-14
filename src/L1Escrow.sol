// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {ISavingsDAI} from "./ISavingsDAI.sol";
import {IBridge} from "./IBridge.sol";

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @notice Main smart contract to bridge DAI from Ethereum to Polygon zkEVM
 */
contract L1Escrow is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  using SafeERC20 for IERC20;

  IERC20 dai;
  ISavingsDAI sdai;
  IBridge bridge;
  address destTokenAddress;
  uint32 destNetworkId;

  /// @notice The total amount of DAI bridged to Polygon zkEVM
  uint256 public totalBridgedDAI;

  /// @notice The target amount of DAI locked in this smart contract
  uint256 public totalProtocolDAI;

  /// @notice The address to which yield from DSR should be sent
  address public beneficiary;

  /// @notice This event is emitted when the beneficiary address is updated
  event BeneficiaryUpdated(address newBeneficiary);

  /// @notice This event is emitted when the totalProtocolDAI is updated
  event TotalProtocolDAIUpdated(uint256 newAmount);

  /// @notice This event is emitted when the DAI is bridged
  event DAIBridged(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This event is emitted when the DAI is claimed
  event DAIClaimed(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This event is emitted when the excess DAI is claimed
  event YieldClaimed(address indexed beneficiary, uint256 amount);

  /// @notice This event is emitted when assets is rebalanced
  event AssetRebalanced();

  /// @notice This error is raised if new beneficiary address is invalid
  error BeneficiaryInvalid(address newBeneficiary);

  /// @notice This error is raised if message from the bridge is invalid
  error MessageInvalid();

  /**
   * @notice L1Escrow initializer
   * @param _dai The DAI address
   * @param _sdai The sDAI address
   * @param _bridge The Polygon zkEVM bridge address
   * @param _destNetworkId The Polygon zkEVM ID on the bridge
   * @param _destTokenAddress The token address on the Polygon zkEVM network
   * @param _totalProtocolDAI The target amount of DAI locked
   * @param _beneficiary The address to which yield from DSR should be sent
   */
  function initialize(
    address _dai,
    address _sdai,
    address _bridge,
    uint32 _destNetworkId,
    address _destTokenAddress,
    uint256 _totalProtocolDAI,
    address _beneficiary
  ) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();

    dai = IERC20(_dai);
    sdai = ISavingsDAI(_sdai);
    bridge = IBridge(_bridge);
    destNetworkId = _destNetworkId;
    destTokenAddress = _destTokenAddress;
    beneficiary = _beneficiary;
    totalProtocolDAI = _totalProtocolDAI;
  }

  /**
   * @dev The L1Escrow can only be upgraded by the owner
   * @param v new L1Escrow version
   */
  function _authorizeUpgrade(address v) internal override onlyOwner {}

  /**
   * @notice Set a new target amount of DAI locked in this smart contract
   * @param amount A new target amount
   */
  function setProtocolDAI(uint256 amount) public virtual onlyOwner {
    totalProtocolDAI = amount;
    emit TotalProtocolDAIUpdated(amount);
  }

  /**
   * @notice Bridge DAI from Ethereum mainnet to Polygon zkEVM
   * @param amount DAI amount
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is
   *        updated or not
   */
  function bridgeDAI(uint256 amount, bool forceUpdateGlobalExitRoot)
    public
    virtual
  {
    dai.safeTransferFrom(msg.sender, address(this), amount);
    uint256 balance = dai.balanceOf(address(this));
    if (balance > totalProtocolDAI) {
      uint256 depositAmount = balance - totalProtocolDAI;
      dai.safeApprove(address(sdai), depositAmount);
      sdai.deposit(depositAmount, address(this));
    }
    bytes memory messageData = abi.encode(msg.sender, amount);
    bridge.bridgeMessage(
      destNetworkId, destTokenAddress, forceUpdateGlobalExitRoot, messageData
    );
    totalBridgedDAI += amount;
    emit DAIBridged(msg.sender, amount, totalBridgedDAI);
  }

  /**
   * @notice Send excess yield to beneficiary
   */
  function sendExcessYield() public {
    uint256 sdaiBalance = IERC20(address(sdai)).balanceOf(address(this));
    uint256 daiBalance = IERC20(address(dai)).balanceOf(address(this));
    uint256 savingsBalance = sdai.previewRedeem(sdaiBalance);
    uint256 totalBalance = savingsBalance + daiBalance;
    if (totalBalance > 0) {
      uint256 excess = totalBalance - totalBridgedDAI;
      if (excess > daiBalance) {
        uint256 withdrawAmount = excess - daiBalance;
        sdai.withdraw(withdrawAmount, address(this), address(this));
      }
      if (excess > 0) {
        dai.transfer(beneficiary, excess - 1); // NOTE: Handle simple rounding
        emit YieldClaimed(beneficiary, excess - 1);
      }
    }
  }

  /**
   * @notice Rebalance total locked DAI in this smart contract
   */
  function rebalance() public {
    uint256 balance = IERC20(address(dai)).balanceOf(address(this));
    if (balance > totalProtocolDAI) {
      uint256 depositAmount = balance - totalProtocolDAI;
      if (depositAmount > 0) {
        dai.safeApprove(address(sdai), depositAmount);
        sdai.deposit(depositAmount, address(this));
        emit AssetRebalanced();
      }
    } else {
      uint256 sdaiBalance = IERC20(address(sdai)).balanceOf(address(this));
      uint256 savingsBalance = sdai.previewRedeem(sdaiBalance);
      uint256 withdrawAmount = totalProtocolDAI - balance;
      if (withdrawAmount > 0 && savingsBalance > withdrawAmount) {
        sdai.withdraw(withdrawAmount, address(this), address(this));
        emit AssetRebalanced();
      }
    }
  }

  /**
   * @notice Set new beneficiary address
   * @param b new beneficiary address
   */
  function setBeneficiary(address b) public virtual onlyOwner {
    if (b == beneficiary || b == address(0)) {
      revert BeneficiaryInvalid(b);
    }
    sendExcessYield();
    beneficiary = b;
    emit BeneficiaryUpdated(b);
  }

  /**
   * @notice This function will be triggered by the bridge
   * @param originAddress The origin address
   * @param originNetwork The origin network
   * @param metadata Abi encoded metadata
   */
  function onMessageReceived(
    address originAddress,
    uint32 originNetwork,
    bytes memory metadata
  ) external payable {
    if (msg.sender != address(bridge)) revert MessageInvalid();
    if (originAddress != destTokenAddress) revert MessageInvalid();
    if (originNetwork != destNetworkId) revert MessageInvalid();

    (address recipient, uint256 amount) =
      abi.decode(metadata, (address, uint256));
    uint256 balance = IERC20(address(dai)).balanceOf(address(this));
    if (amount > balance) {
      uint256 withdrawAmount = amount - balance;
      sdai.withdraw(withdrawAmount, address(this), address(this));
    }

    totalBridgedDAI -= amount;
    dai.transfer(recipient, amount);
    emit DAIClaimed(recipient, amount, totalBridgedDAI);
  }
}
