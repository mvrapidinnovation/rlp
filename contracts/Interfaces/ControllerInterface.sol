// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import './StrategyInterface.sol';


abstract contract Controller1{
    
    function getCurrentStrategy()virtual external  returns(Strategy[3] memory);
    function deposit(uint256[3] memory )virtual external;
    function withdraw(uint256[3] memory )virtual external;
}