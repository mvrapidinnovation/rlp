// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/ERC20Interface.sol';
import '../Interfaces/rStrategyInterface.sol';

contract rController {


    address public owner;

    address royaleAddress;

    rStrategyI[3] rStrategy;

    uint256[3] totalProfit;

    uint256 profitBreak=75;

    Erc20[3] Coins;

     modifier onlyAuthorized {
        require(msg.sender == owner || msg.sender == royaleAddress, "not authorized");
        _;
    }

    constructor(Erc20[3] memory coins, address _royaleaddress) public {
        owner = msg.sender;
        royaleAddress =_royaleaddress;
        for(uint8 i=0; i<3; i++) {
            Coins[i] = coins[i];
        }
    }

    function setStrategy(address _addr, uint8 coin) public onlyAuthorized {
        rStrategy[coin] = rStrategyI(_addr);
    }

     function setProfitBreak(uint8 _profitBreak) public onlyAuthorized {
        profitBreak=_profitBreak;
    }

    function getStrategies() external view returns(rStrategyI[3] memory) {
        return rStrategy;
    }


    function deposit(uint[3] calldata amounts) external onlyAuthorized {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                totalProfit[coin] += rStrategy[coin].calculateProfit();
                rStrategy[coin].deposit(amounts[coin]);
            }
        }
    }

    function withdraw(uint[3] calldata amounts) external onlyAuthorized {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                rStrategy[coin].withdraw(amounts[coin]);
            }
        }
    }

    function changeStrategy(address _to, uint8 coin) external onlyAuthorized {

        rStrategy[coin].withdrawAll();

        setStrategy(_to, coin);

        uint bal = Coins[coin].balanceOf(address(this));
        Coins[coin].transfer(_to, bal);
        rStrategy[coin].deposit(bal);

    }

    function getTotalProfit() external onlyAuthorized returns(uint256[3] memory) {
              for(uint8 coin=0; coin<3; coin++){
                  totalProfit[coin] += rStrategy[coin].sellCRV();
              }
              uint256[3] memory royaleLPProfit;
              for(uint8 coin=0; coin<3; coin++){
                  royaleLPProfit[coin] = (totalProfit[coin] * profitBreak) / 100;
                  totalProfit[coin] -= royaleLPProfit[coin];
              }
              return royaleLPProfit;
    }

    function stakeLPtokens(uint8 coin) external onlyAuthorized {
        rStrategy[coin].stakeLP();
    }

    function unstakeLPtokens(uint8 coin,uint256 _amount) external onlyAuthorized {
        rStrategy[coin].unstakeLP(_amount);
    }

}