// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Initializable} from "upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @notice Main contract to bridge DAI from Ethereum to Polygon zkEVM
 */
contract L1Escrow is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  /// @notice DSR yields recipient
  address public beneficiary;

  /// @notice Event emitted if beneficiary address is updated
  event BeneficiaryUpdated(address newBeneficiary);

  /// @notice Error is raised if beneficiary address is invalid
  error BeneficiaryInvalid(address beneficiary);

  /**
   * @notice L1Escrow initializer
   * @param b DSR yields recipient
   */
  function initialize(address b) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();

    beneficiary = b;
  }

  /**
   * @dev Make sure only owner can upgrade the L1Escrow
   * @param newImplementation new L1Escrow version
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner
  {}

  /**
   * @notice Set new beneficiary address
   * @param b new beneficiary address
   */
  function setBeneficiary(address b) public virtual onlyOwner {
    if (b == beneficiary || b == address(0)) {
      revert BeneficiaryInvalid(b);
    }

    // TODO: send yield to previous beneficiary
    beneficiary = b;
    emit BeneficiaryUpdated(b);
  }
}
