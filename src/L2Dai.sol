// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "upgradeable/token/ERC20/ERC20Upgradeable.sol";

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
  /// @notice The Polygon zkEVM bridge contract
  IBridge public zkEvmBridge;

  /// @notice L1Escrow contract address on Ethereum mainnet
  address public destAddress;

  /// @notice Network ID of Ethereum mainnet on the Polygon zkEVM bridge
  uint32 public destId;

  /// @notice This event is emitted when the DAI is bridged
  event DAIBridged(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This event is emitted when the DAI is claimed
  event DAIClaimed(address indexed bridgoor, uint256 amount, uint256 total);

  /// @notice This error is raised if message from the bridge is invalid
  error MessageInvalid();

  /// @notice This error is raised if bridged amount is invalid
  error BridgeAmountInvalid();

  /**
   * @notice L2Dai initializer
   * @dev This initializer should be called via UUPSProxy constructor
   * @param _ownerAddress The contract owner
   * @param _bridgeAddress The Polygon zkEVM bridge address
   * @param _destAddress The contract address of L1Escrow
   * @param _destId ID of Ethereum mainnet on the Polygon zkEVM bridge
   */
  function initialize(
    address _ownerAddress,
    address _bridgeAddress,
    address _destAddress,
    uint32 _destId
  ) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __ERC20_init("Dai Stablecoin", "DAI");
    transferOwnership(_ownerAddress);
    zkEvmBridge = IBridge(_bridgeAddress);
    destAddress = _destAddress;
    destId = _destId;
  }

  /**
   * @dev The L2Dai can only be upgraded by the owner
   * @param v new L2Dai version
   */
  function _authorizeUpgrade(address v) internal override onlyOwner {}

  /**
   * @notice Bridge DAI from Polygon zkEVM to Ethereum mainnet
   * @param amount DAI amount
   * @param forceUpdateGlobalExitRoot Indicates if the global exit root is
   *        updated or not
   */
  function bridge(uint256 amount, bool forceUpdateGlobalExitRoot)
    public
    virtual
  {
    if (amount < 1 ether) revert BridgeAmountInvalid();

    _burn(msg.sender, amount);
    bytes memory messageData = abi.encode(msg.sender, amount);
    zkEvmBridge.bridgeMessage(
      destId, destAddress, forceUpdateGlobalExitRoot, messageData
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
  ) external payable virtual {
    if (msg.sender != address(zkEvmBridge)) revert MessageInvalid();
    if (originAddress != destAddress) revert MessageInvalid();
    if (originNetwork != destId) revert MessageInvalid();

    (address recipient, uint256 amount) =
      abi.decode(metadata, (address, uint256));
    _mint(recipient, amount);

    emit DAIClaimed(recipient, amount, totalSupply());
  }
}
