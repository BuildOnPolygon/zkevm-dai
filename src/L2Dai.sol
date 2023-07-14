// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";

import {ISavingsDAI} from "./ISavingsDAI.sol";
import {IBridge} from "./IBridge.sol";

/**
 * @title L2Dai
 * @author sepyke.eth
 * @notice Main smart contract to bridge DAI from Polygon zkEVM to Ethereum
 */
contract L2Dai is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  ERC20Upgradeable
{
  IBridge bridge;
  address destTokenAddress;
  uint32 destNetworkId;

  /// @notice This event is emitted when the L1 address is updated
  event BridgeDestinationUpdated(address newAddress, uint32 newNetworkId);

  /// @notice This event is emitted when the DAI is bridged
  event DAIBridged(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This event is emitted when the DAI is claimed
  event DAIClaimed(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This error is raised if message from the bridge is invalid
  error MessageInvalid();

  /**
   * @notice L2Dai initializer
   * @param _bridge The Polygon zkEVM bridge address
   * @param _destNetworkId The Polygon zkEVM ID on the bridge
   * @param _destTokenAddress The token address on the Polygon zkEVM network
   */
  function initialize(
    address _bridge,
    uint32 _destNetworkId,
    address _destTokenAddress
  ) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __ERC20_init("Dai Stablecoin", "DAI");

    bridge = IBridge(_bridge);
    destNetworkId = _destNetworkId;
    destTokenAddress = _destTokenAddress;
  }

  /**
   * @dev The L2Dai can only be upgraded by the owner
   * @param v new L2Dai version
   */
  function _authorizeUpgrade(address v) internal override onlyOwner {}

  /**
   * @dev Set bridge destination to send and confirm bridge message
   * @param _destTokenAddress L1Escrow smart contract address
   * @param _destNetworkId 0 for Mainnet
   */
  function setBridgeDestination(
    address _destTokenAddress,
    uint32 _destNetworkId
  ) public onlyOwner {
    destTokenAddress = _destTokenAddress;
    destNetworkId = _destNetworkId;
    emit BridgeDestinationUpdated(_destTokenAddress, _destNetworkId);
  }

  /**
   * @notice Bridge DAI from Polygon zkEVM to Ethereum mainnet
   * @param amount DAI amount
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is
   *        updated or not
   */
  function bridgeDAI(uint256 amount, bool forceUpdateGlobalExitRoot)
    public
    virtual
  {
    _burn(msg.sender, amount);
    bytes memory messageData = abi.encode(msg.sender, amount);
    bridge.bridgeMessage(
      destNetworkId, destTokenAddress, forceUpdateGlobalExitRoot, messageData
    );
    emit DAIBridged(msg.sender, amount, totalSupply());
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
    _mint(recipient, amount);

    emit DAIClaimed(recipient, amount, totalSupply());
  }
}
