//SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract RahatTriggerResponse {
  using EnumerableSet for EnumerableSet.AddressSet;

  event ResponseTriggered(
    address indexed adminAddress,
    bool isLive
  );

  bool public isLive;
  uint128 public requiredConfirmations;
  mapping(bytes32 => mapping(address => bool)) public adminConfirmations; //TxHash > Admin > bool
  EnumerableSet.AddressSet internal _adminSet;
  mapping(address => bool) public isAdmin;

  //Modifiers
  modifier OnlyAdmin() {
    require(
      isAdmin[msg.sender],
      "TriggerRespose: Only Admin can execute this transaction"
    );
    _;
  }

  constructor(address _adminAddress, uint128 _requiredConfirmations) {
    _adminSet.add(_adminAddress);
    isAdmin[_adminAddress] = true;
    requiredConfirmations = _requiredConfirmations;
  }

  // Admin manage
  function addAdmin(address _adminAddress) public OnlyAdmin {
    _adminSet.add(_adminAddress);
    isAdmin[_adminAddress] = true;
  }

   function listAdmins() public view returns (address[] memory) {
    return _adminSet.values();
  }

  function removeAdmin(address _adminAddress) public OnlyAdmin {
    _adminSet.remove(_adminAddress);
    isAdmin[_adminAddress] = false;
  }

  function deactivateResponse(string memory _projectId) public OnlyAdmin {
    bytes32 _hash = keccak256(abi.encodePacked(_projectId));
    adminConfirmations[_hash][msg.sender] = false;
    isLive = this.isConfirmed(_hash);
    emit ResponseTriggered(msg.sender, isLive);
  }

  function activateResponse(string memory _projectId) public OnlyAdmin {
    bytes32 _hash = keccak256(abi.encodePacked(_projectId));
    adminConfirmations[_hash][msg.sender] = true;
    isLive = this.isConfirmed(_hash);
    emit ResponseTriggered(msg.sender, isLive);
  }

  function isConfirmed(bytes32 _hash) public view returns (bool _confirmed) {
    _confirmed = false;
    uint256 count = 0;
    for (uint256 i = 0; i < _adminSet.length(); i++) {
      if (adminConfirmations[_hash][_adminSet.at(i)]) count += 1;
      if (count == requiredConfirmations) _confirmed = true;
    }
  }

  //#region Token manage

  function transferEther(address payable _destAddress, uint256 _amount)
    public
    OnlyAdmin
    returns (bool)
  {
    (bool success, ) = _destAddress.call{ value: _amount }("");
    return success;
  }

  receive() external payable {}
  //#endregion
}
