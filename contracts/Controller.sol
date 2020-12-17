// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './Interfaces/CurveInterface.sol';
import './Interfaces/StrategyInterface.sol';

contract Controller{

    Strategy[3] strategy;

    address owner;
     modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    /* constructor() public{
        owner=msg.sender;
    } */

    function setStrategy(address _strategyAddress,uint _forToken)public {
         strategy[_forToken]=Strategy(_strategyAddress);
    }

    function getCurrentStrategy()external view returns(Strategy[3] memory){
        return strategy;
    }

    function deposit(uint256[3] memory amounts) external {
         for(uint8 i=0;i<3;i++){
             if(amounts[i]>0){
                 strategy[i].deposit(amounts[i]);
             }
         }
    }


    function withdraw(uint[3] memory amounts)external{
        for(uint8 i=0;i<3;i++){
             if(amounts[i]>0){
                 strategy[i].withdraw(amounts[i]);
             }
         }
    }

    function withdrawAll()external{
        for(uint8 i=0;i<3;i++){
                 strategy[i].withdrawAll();
         }
    }
}