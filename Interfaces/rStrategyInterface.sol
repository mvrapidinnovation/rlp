// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

abstract contract rStrategyI {
    function deposit(uint) virtual external;
    function withdraw(uint) virtual external;
    function withdrawAll() virtual external;
    function stakeLP() virtual external;
    function unstakeLP(uint) virtual external;
    
    function calculateProfit()virtual external returns(uint256);
    function sellCRV()virtual external returns(uint256) ;
}