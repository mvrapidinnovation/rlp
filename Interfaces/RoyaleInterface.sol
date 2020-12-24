// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

abstract contract RoyaleInterface {
    function _loanWithdraw(uint256[3] calldata amounts,address _loanSeeker) virtual  external returns(bool);
    function _loanRepayment(uint256[3] calldata amounts,address _loanSeeker) virtual  external returns(bool);
    function getTotalPoolBalance() virtual external view returns(uint256[3] memory);
    function getTotalLoanGiven() virtual external view returns(uint256[3] memory);
}