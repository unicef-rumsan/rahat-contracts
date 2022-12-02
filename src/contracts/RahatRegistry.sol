//SPDX-License-Identifier: LGPL-3.0

pragma solidity ^0.8.16;

import "../libraries/AbstractOwner.sol";

/// @title Donor contract to create tokens
/// @author Rumsan Associates
/// @notice You can use this contract to manage Rahat tokens and projects
/// @dev All function calls are only executed by contract owner
contract RahatRegistry is AbstractOwner {

  mapping(bytes32=>address) public id2Address;

  constructor(
    address _admin
  ) {
    owner[_admin] = true;
  }

  function addId2AddressMap(bytes32 _id, address _addr) public OnlyOwner returns(bool) {
    id2Address[_id] = _addr;
    return true;
  }

  function exists(bytes32 _id) public view returns(bool){
    return id2Address[_id]!=address(0);
  }
}
