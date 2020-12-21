// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/ERC20Interface.sol';
import '../Interfaces/rStrategyInterface.sol';

contract rController {

    address public owner;

    rStrategyI[3] rStrategy;

    Erc20[3] Coins;

    constructor(Erc20[3] memory coins) public {
        owner = msg.sender;

        for(uint8 i=0; i<3; i++) {
            Coins[i] = coins[i];
        }
    }

    function setStrategy(address _addr, uint8 coin) public {
        require(msg.sender == owner, "not authorized");
        
        rStrategy[coin] = rStrategyI(_addr);
    }

    function getStrategies() external view returns(rStrategyI[3] memory) {
        return rStrategy;
    }


    function deposit(uint[3] calldata amounts) external {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                rStrategy[coin].deposit(amounts[coin]);
            }
        }
    }

    function withdraw(uint[3] calldata amounts) external {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                rStrategy[coin].withdraw(amounts[coin]);
            }
        }
    }

    function changeStrategy(address _to, uint8 coin) external {
        require(msg.sender == owner, "not authorized");

        rStrategy[coin].withdrawAll();

        setStrategy(_to, coin);

        uint bal = Coins[coin].balanceOf(address(this));
        Coins[coin].transfer(_to, bal);
        rStrategy[coin].deposit(bal);

    }

}