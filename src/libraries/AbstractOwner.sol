// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../interfaces/IOwner.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

abstract contract AbstractOwner is IOwner, Multicall {
  using EnumerableSet for EnumerableSet.AddressSet;
  EnumerableSet.AddressSet private owners;
  mapping(address => bool) public owner;

  modifier OnlyOwner {
    require(
      owner[msg.sender],
      "Only owner can execute this transaction"
    );
    _;
  }

  /// @notice Add an account to the owner role
  /// @param _account address of new owner
  function addOwner(address _account) public OnlyOwner virtual returns(bool) {
    owner[_account] = true;
    owners.add(_account);
    return true;
  }

  /// @notice Remove an account from the owner role
  /// @param _account address of existing owner
  function removeOwner(address _account) public OnlyOwner virtual returns(bool) {
    owner[_account] = false;
    owners.remove(_account);
    return true;
  }

  function listAdmins() public view returns(address[] memory){
    return owners.values();
  }
}