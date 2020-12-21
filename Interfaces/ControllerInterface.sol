// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/rStrategyInterface.sol';

abstract contract rControllerI {
    function getStrategies() virtual external  returns(rStrategyI[3] memory);
    function deposit(uint256[3] calldata) virtual external;
    function withdraw(uint256[3] calldata) virtual external;
}