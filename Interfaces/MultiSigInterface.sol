// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


interface MultiSignatureInterface{
       function checkOwner(address)external view returns(bool);
        function getRequired()external view returns(uint8);
        function getNumberOfOwner()external view returns(uint);
        function getOwner(uint _index)external view returns(address);
}