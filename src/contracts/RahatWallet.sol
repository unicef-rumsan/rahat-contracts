//SPDX-License-Identifier: LGPL-3.0

pragma solidity ^0.8.16;

import "../libraries/AbstractERC20Func.sol";

/// @title Donor contract to create tokens
/// @author Rumsan Associates
/// @notice You can use this contract to manage Rahat tokens and projects
/// @dev All function calls are only executed by contract owner

contract RahatWallet is AbstractERC20Func {
  constructor(
    address _admin
  ) {
    owner[_admin] = true;
  }
}
