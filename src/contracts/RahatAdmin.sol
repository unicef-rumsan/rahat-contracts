//SPDX-License-Identifier: LGPL-3.0

pragma solidity ^0.8.16;

import "./RahatERC20.sol";
import "./Rahat.sol";
import "../libraries/AbstractERC20Func.sol";

/// @title Rahat Admin contract - owns all the tokens initially minted
/// @author Rumsan Associates
/// @notice You can use this contract to manage Rahat tokens and projects
/// @dev All function calls are only executed by contract owner
contract RahatAdmin is AbstractERC20Func {
  using EnumerableSet for EnumerableSet.UintSet;

  event ProjectERC20BudgetUpdated(
    bytes32 indexed projectId,
    uint256 projectCapital,
    string tag
  );

  event Minted(bool success);

  // uint256 public mintData ;
  // bool public mintSuccess =false;

  RahatERC20 public erc20;
  RahatERC20 public cashToken;

  /// @notice list of projects
  bytes32[] public projectId;

  /// @notice check if projectId exists or not;
  mapping(bytes32 => bool) public projectExists;

  /// @notice assign budgets to project
  mapping(bytes32 => uint256) public projectERC20Capital;

  modifier CheckProject(string memory _projectId) {
    bytes32 _id = findHash(_projectId);
    if (projectExists[_id]) {
      _;
    } else {
      projectId.push(_id);
      projectExists[_id] = true;
      _;
    }
  }

  /// @notice All the supply is allocated to this contract
  /// @dev deploys AidToken and Rahat contract by sending supply to this contract
  constructor(
    RahatERC20 _erc20,
    address _admin
  ) {
    erc20 = _erc20;
    owner[_admin] = true;
  }

  /// @notice allocate token to projects
  /// @dev Allocates token to the given projectId, Creates project and transfer tokens to Rahat contract.
  /// @param _projectId Unique Id of Project
  /// @param _projectCapital Budget Allocated to project
  function setProjectBudget_ERC20(
    address rahatContract,
    string memory _projectId,
    uint256 _projectCapital
  ) public OnlyOwner CheckProject(_projectId) {
    bytes32 _id = findHash(_projectId);
    projectERC20Capital[_id] += _projectCapital;
    erc20.mint(rahatContract, _projectCapital);
    cashToken.approve(rahatContract, _projectCapital);
    emit ProjectERC20BudgetUpdated(_id, _projectCapital, "add");
  }


  function claimToken(address _token, address _from, uint256 _amount) public override OnlyOwner {
    if(address(cashToken) == address(0)) cashToken = RahatERC20(_token);
    super.claimToken(_token, _from, _amount);
  }

  /// @notice mint new tokens
  /// @param _address address to send the minted tokens
  /// @param _amount Amount of token to Mint
  function mintERC20(address _address, uint256 _amount) public OnlyOwner {
    erc20.mint(_address, _amount);
  }

  /// @notice generates the hash of the given string
  /// @param _data String of which hash is to be generated
  function findHash(string memory _data) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(_data));
  }
}
