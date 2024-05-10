// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./L2Dai.sol";

contract L2DaiV2 is L2Dai {
  mapping(address => bool) public minters;
  mapping(address => uint256) public minterAllowance;

  modifier onlyMinters() {
    require(minters[msg.sender], "NOT_MINTER");
    _;
  }

  /// @notice Function to add/update a new minter
  function addMinter(address minter, uint256 allowance) external onlyOwner {
    minters[minter] = true;
    minterAllowance[minter] = allowance;
  }

  /// @notice Function to remove a minter
  function removeMinter(address minter) external onlyOwner {
    delete minters[minter];
    delete minterAllowance[minter];
  }

  /// @notice Function to mint tokens
  /// Only select addresses (minters) are allowed to execute this
  function mint(address to, uint256 amount) external onlyMinters {
    require(to != address(0), "INVALID_RECEIVER");
    require(amount > 0, "INVALID_AMOUNT");
    require(amount <= minterAllowance[msg.sender], "EXCEEDS_MINT_ALLOWANCE");

    minterAllowance[msg.sender] -= amount;
    _mint(to, amount);
  }

  /// @notice Function to burn tokens
  /// Only select addresses (minters) are allowed to execute this
  function burn(uint256 amount) external onlyMinters {
    require(amount > 0, "INVALID_AMOUNT");

    // we don't re-add to the allowance, following USDC's behavior
    _burn(msg.sender, amount);
  }
}
