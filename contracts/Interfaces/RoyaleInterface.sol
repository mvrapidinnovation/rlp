// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface RoyaleInterface{
    function _loanWithdraw(uint256[3] memory amounts,address _loanSeeker)external returns(bool);
    function _loanRepayment(uint256[3] memory amounts,address _loanSeeker)external returns(bool);
    function getCurrentPoolBalance()external view returns(uint256[3] memory);
    function getTotalLoanGiven()external view returns(uint256[3] memory);
}