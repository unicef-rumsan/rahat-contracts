//SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.16;

//ERC20 Tokens
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

//Utils
import '@openzeppelin/contracts/access/AccessControl.sol';

//Interfaces
import "../interfaces/IRahatAgencyToken.sol";

contract RahatAgencyToken is ERC20, ERC20Snapshot, ERC20Burnable, IRahatAgencyToken{    
	uint256 snapshotid;
	///@dev owner of the ERC20 contract 
	mapping(address => bool) public owner;

	modifier OnlyOwner {
		require(owner[tx.origin], 'Only RahatAdmin contract can execute this transaction');
		_;
	}

	constructor(
		string memory _name,
		string memory _symbol,
		address _agencyContract
	)  ERC20(_name, _symbol) {
		owner[_agencyContract] = true;
	}

	///@dev Mint x amount of ERC20 token to given address
	///@param _address Address to which ERC20 token will be minted
	///@param _amount Amount of token to be minted
    function mintToken(address _address, uint256 _amount) public OnlyOwner override {
        ERC20._mint(_address, _amount);
    }

	///@notice Creates a new snapshot and returns it's id
    function createSnapshot() public OnlyOwner returns (uint256 currentId) {
        snapshotid = ERC20Snapshot._snapshot();
        emit Snapshotcreated(snapshotid);
        return snapshotid;
    }

	function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    
	// function addOwner(address _account) public OnlyOwner {
	// 	owner[_account] = true;
	// }
}
