// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import './Interfaces/Erc20Interface.sol';
import './Interfaces/YieldOptInterface.sol';

contract WithdrawQueue {
    mapping(uint256 => address) withdrawQ;
    uint256 first = 1;
    uint256 last = 0;
    address data;

    function addToQ(address addr) internal {
        last += 1;
        withdrawQ[last] = addr;
    }

    function getFromQ() internal returns(address) {
        require(last >= first);

        data = withdrawQ[first];

        delete withdrawQ[first];
        first += 1;

        return data;
    }
}

contract RoyaleLPstorage  is WithdrawQueue {

    uint128 constant N_COINS = 3;

    uint128 public fees = 25;

    uint128 public poolPart = 95;

    uint256[N_COINS] public selfBalance;

    IYieldOpt yldOpt;

    address public owner;
    // curvePool Pool;
    Erc20[N_COINS] tokens;
    // Erc20 PoolToken;
    Erc20 rpToken;

    uint[N_COINS] public YieldPoolBalance;

    uint256 public thresholdTokenAmount = 500;

    // Lock period in days
    uint128 public lock_period;

    struct depositDetails {
        uint256[N_COINS] amount;
        uint256[N_COINS] remAmt;
        uint256 time;
        bool[N_COINS] withdrawn;
    }

    mapping(address => uint256[N_COINS]) amountSupplied;
    mapping(address => depositDetails[]) supplyTime;

    mapping(address => uint256[N_COINS]) amountWithdraw;
    mapping(address => bool) public isInQ;
    uint32 recipientCount;
    uint256[N_COINS] public totalWithdraw;
    uint256[N_COINS ] public loanGiven;  
}