// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AccessControlDefaultAdminRulesUpgradeable} from
  "upgradeable/access/AccessControlDefaultAdminRulesUpgradeable.sol";
import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from
  "upgradeable/security/PausableUpgradeable.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {IBridge} from "./IBridge.sol";
import {L2DaiV2} from "./L2DaiV2.sol";

/// @notice Copied from USDC's NativeConverter, with the addition of
/// `deconvert` for bidirectional support, and using Ownable2StepUpgradeable
/// as it seems to be the convention in this project.
/// https://zkevm.polygonscan.com/address/0xd4F3531Fc95572D9e7b9e9328D9FEaa8e8496054#code
contract NativeConverter is
  Initializable,
  AccessControlDefaultAdminRulesUpgradeable,
  PausableUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20 for IERC20;

  bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  event Convert(address indexed from, address indexed to, uint256 amount);
  event Deconvert(address indexed from, address indexed to, uint256 amount);
  event Migrate(uint256 amount);

  IBridge public zkEvmBridge;
  uint32 public l1NetworkId;
  address public l1Escrow;

  IERC20 public bwDAI;
  L2DaiV2 public nativeDAI;

  constructor() {
    _disableInitializers();
  }

  function _authorizeUpgrade(address v)
    internal
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {}

  function initialize(
    address admin_,
    address emergency_,
    address migrator_,
    address bridge_,
    uint32 l1NetworkId_,
    address l1Escrow_,
    address bwDAI_,
    address nativeDAI_
  ) public initializer {
    __AccessControlDefaultAdminRules_init(3 days, admin_);
    __Pausable_init();
    __UUPSUpgradeable_init();

    _grantRole(EMERGENCY_ROLE, emergency_);
    _grantRole(MIGRATOR_ROLE, migrator_);

    zkEvmBridge = IBridge(bridge_);
    l1NetworkId = l1NetworkId_;
    l1Escrow = l1Escrow_;

    bwDAI = IERC20(bwDAI_);
    nativeDAI = L2DaiV2(nativeDAI_);
  }

  /// @dev called by the emergency role to pause, triggers stopped state
  function pause() external onlyRole(EMERGENCY_ROLE) {
    _pause();
  }

  /// @dev called by the emergency role to unpause, returns to normal state2
  function unpause() external onlyRole(EMERGENCY_ROLE) {
    _unpause();
  }

  /// @notice Converts BridgeWrappedDAI to NativeDAI
  function convert(address receiver, uint256 amount) external whenNotPaused {
    require(receiver != address(0), "INVALID_RECEIVER");
    require(amount > 0, "INVALID_AMOUNT");

    // transfer bridge-wrapped dai to converter
    bwDAI.safeTransferFrom(msg.sender, address(this), amount);
    // and mint native dai to user
    nativeDAI.mint(receiver, amount);

    emit Convert(msg.sender, receiver, amount);
  }

  /// @notice Deconverts NativeDAI back to BridgeWrappedDAI
  /// Note: The NativeDAI is burned in the process.
  function deconvert(address receiver, uint256 amount) external whenNotPaused {
    require(receiver != address(0), "INVALID_RECEIVER");
    require(amount > 0, "INVALID_AMOUNT");
    require(amount <= bwDAI.balanceOf(address(this)), "AMOUNT_TOO_LARGE");

    // transfer native dai from user to the converter, and burn it
    IERC20(address(nativeDAI)).safeTransferFrom(
      msg.sender, address(this), amount
    );
    nativeDAI.burn(amount);
    // and then send bridge-wrapped dai to the user
    bwDAI.safeTransfer(receiver, amount);

    emit Deconvert(msg.sender, receiver, amount);
  }

  /// @notice Migrates the L2 BridgeWrappedDAI to L1
  /// The L1 DAI will be sent to the L1Escrow.
  function migrate() external onlyRole(MIGRATOR_ROLE) whenNotPaused {
    uint256 amount = bwDAI.balanceOf(address(this));

    if (amount > 0) {
      bwDAI.safeApprove(address(zkEvmBridge), amount);

      zkEvmBridge.bridgeAsset(
        l1NetworkId,
        l1Escrow,
        amount,
        address(bwDAI),
        true, // forceUpdateGlobalExitRoot
        "" // empty permitData because we're doing approve
      );

      emit Migrate(amount);
    }
  }
}
