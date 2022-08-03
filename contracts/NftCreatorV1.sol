// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {Token} from './Token.sol';

contract NftCreatorV1 is OwnableUpgradeable, UUPSUpgradeable {
  string private constant CANNOT_BE_ZERO = 'Cannot be 0 address';

  event CreatedToken(address indexed creator, address indexed tokenAddress);

  constructor() {}

  /// @dev Initializes the proxy contract
  function initialize() external initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
  }

  /// @dev Function to determine who is allowed to upgrade this contract.
  /// @param _newImplementation: unused in access check
  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

  function createToken(
    string memory _name,
    string memory _symbol,
    string memory _baseUri,
    string memory _contractUri,
    uint256 _jbxProjectId,
    IJBDirectory _jbxDirectory,
    uint256 _maxSupply,
    uint256 _unitPrice,
    uint256 _mintAllowance,
    uint128 _mintPeriodStart,
    uint128 _mintPeriodEnd
  ) public returns (address) {
    Token newToken = new Token(
      _name,
      _symbol,
      _baseUri,
      _contractUri,
      _jbxProjectId,
      _jbxDirectory,
      _maxSupply,
      _unitPrice,
      _mintAllowance,
      _mintPeriodStart,
      _mintPeriodEnd
    );
    address payable newTokenAddress = payable(address(newToken));
    emit CreatedToken({creator: msg.sender, tokenAddress: newTokenAddress});
    return newTokenAddress;
  }
}
