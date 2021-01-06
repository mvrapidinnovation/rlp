// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/ERC20Interface.sol';
import '../Interfaces/rStrategyInterface.sol';
import '../Interfaces/MultisigInterface.sol';

contract rController {



    address royaleAddress;

    MultiSignatureInterface multiSig;

    rStrategyI[3] rStrategy;

    uint256[3] totalProfit;

    uint256 profitBreak=75;

    Erc20[3] Coins;

    modifier onlyAuthorized(address _caller) {
        require(
             multiSig.checkOwner(_caller) || _caller == royaleAddress, 
            "not authorized"
        );
        _;
    }

    constructor(Erc20[3] memory coins, address _royaleaddress,address _multiSig) public {
     
        multiSig= MultiSignatureInterface(_multiSig);
        royaleAddress =_royaleaddress;

        for(uint8 i=0; i<3; i++) {
            Coins[i] = coins[i];
        }
    }


    function setStrategy(address _addr, uint8 coin) public onlyAuthorized(msg.sender) {
        require(
            address(rStrategy[coin]) == address(0),
            "cannot set strategy again: use changeStrategy()"
        );
        rStrategy[coin] = rStrategyI(_addr);
    }

    function setProfitBreak(uint8 _profitBreak) public onlyAuthorized(msg.sender) {
        profitBreak = _profitBreak;
    }

    function getStrategies() external view returns(rStrategyI[3] memory) {
        return rStrategy;
    }


    function deposit(uint[3] calldata amounts) external onlyAuthorized(msg.sender) {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                totalProfit[coin] += rStrategy[coin].calculateProfit();
                rStrategy[coin].deposit(amounts[coin]);
            }
        }
    }

    function withdraw(uint[3] calldata amounts) external onlyAuthorized(msg.sender) {
        for(uint8 coin=0; coin<3; coin++) {
            if(amounts[coin] > 0) {
                rStrategy[coin].withdraw(amounts[coin]);
            }
        }
    }

    function getTotalProfit() external onlyAuthorized(msg.sender) returns(uint256[3] memory) {
        for(uint8 coin=0; coin<3; coin++){
            totalProfit[coin] += rStrategy[coin].sellCRV();
        }

        uint256[3] memory royaleLPProfit;
        for(uint8 coin=0; coin<3; coin++){
            royaleLPProfit[coin] = (totalProfit[coin]*profitBreak)/100;
            totalProfit[coin] -= royaleLPProfit[coin];
            Coins[coin].transferFrom(
                address(rStrategy[coin]),
                royaleAddress,
                royaleLPProfit[coin]
            );
        }

        return royaleLPProfit;
    }


    function stakeLPtokens(uint8 coin) external onlyAuthorized(msg.sender) {
        rStrategy[coin].stakeLP();
    }

    function unstakeLPtokens(uint8 coin,uint256 _amount) external onlyAuthorized(msg.sender) {
        rStrategy[coin].unstakeLP(_amount);
    }


    function updateRoyalePool(address _royale) public onlyAuthorized(msg.sender){
       royaleAddress = _royale;
    }

    function changeStrategy(address _to, uint8 coin) external onlyAuthorized(msg.sender) {
        require(
            address(rStrategy[coin]) != address(0),
            "cannot change strategy: not set"
        );

        rStrategy[coin].withdrawAll();

        setStrategy(_to, coin);

        uint bal = Coins[coin].balanceOf(address(this));
        Coins[coin].transfer(_to, bal);
        rStrategy[coin].deposit(bal);

    }


}