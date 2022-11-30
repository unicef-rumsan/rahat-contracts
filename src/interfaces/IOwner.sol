//SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.16;

interface IOwner {
    function addOwner(address _account) external returns (bool);
    function removeOwner(address _account) external returns (bool);
}