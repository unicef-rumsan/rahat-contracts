// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AbstractOwner.sol";

abstract contract AbstractERC20Func is AbstractOwner {
  function transferToken(address _token, address _to, uint256 _amount) public OnlyOwner {
    IERC20(_token).transfer(_to, _amount);
  }

  function approveToken(address _token, address _spender, uint256 _amount) public OnlyOwner {
    IERC20(_token).approve(_spender, _amount);
  }

  function claimToken(address _token, address _from, uint256 _amount) public virtual OnlyOwner {
    IERC20(_token).transferFrom(_from, address(this), _amount);
  }

  function transferFromToken(address _token, address _from, address _to, uint256 _amount) public OnlyOwner {
    IERC20(_token).transferFrom(_from, _to,_amount);
  }

  function getAllowanceAndBalance(address _token, address _from) public virtual view returns(uint allowance, uint balance) {
    allowance = IERC20(_token).allowance(_from, address(this));
    balance = IERC20(_token).balanceOf(address(this));
  }
}