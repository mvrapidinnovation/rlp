// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/Erc20Interface.sol';
import '../Interfaces/ControllerInterface.sol';
import '../Interfaces/rStrategyInterface.sol';
import '../Interfaces/MultisigInterface.sol';

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
    
    function resetQueue()internal{
        first=1;
        last=0;
    }
}

contract RoyaleLPstorage  is WithdrawQueue {


    //storage for pool features

    uint128 constant N_COINS = 3;

    uint128 public fees = 25; // for .25% fee, for 1.75% fee => 175

    uint128 public poolPart = 95; // 95% of pool to deposit into smart backed pool

    uint256[N_COINS] public selfBalance;

    address public owner;

    Erc20[N_COINS] tokens;

    Erc20 rpToken;

    //storage for Yield Optimization

    rControllerI controller;

    MultiSignatureInterface multiSig;

    uint[N_COINS] public YieldPoolBalance;

    uint256 public thresholdTokenAmount = 500;

    uint256[N_COINS] public profitFromYield;


   //storage for user related to supply and withdraw
    uint128 public lock_period = 0 minutes;

    struct depositDetails {
        uint256[N_COINS] amount;
        uint256[N_COINS] remAmt;
        uint256 time;
        bool[N_COINS] withdrawn;
    }

    mapping(address => uint256[N_COINS]) public amountSupplied;
    mapping(address => depositDetails[]) supplyTime;

    mapping(address => uint256[N_COINS]) amountWithdraw;
    mapping(address => bool) public isInQ;
    uint32 recipientCount;
    uint256[N_COINS] public totalWithdraw;


    //storage to store total loan given
    uint256[N_COINS] public loanGiven;  


    //storage realated to loan contract
     address public loanContract;
}