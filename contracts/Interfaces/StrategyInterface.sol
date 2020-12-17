// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;


abstract contract Strategy{
    function deposit(uint256 ) virtual external;
     function withdraw(uint256) virtual external;
     function withdrawAll() virtual external; 

}