// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

abstract contract IYieldOpt {
    function deposit(uint256[3] calldata amount) virtual external;

    function withdraw(uint256[3] calldata amount) virtual external;
}