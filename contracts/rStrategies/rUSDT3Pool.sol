// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../../Interfaces/CurveInterface.sol';
import '../../Interfaces/ERC20Interface.sol';

contract rUSDT3Pool {

    Erc20 Coin;
    Erc20 PoolToken;
    curvePool public Pool;
    PoolGauge public gauge;

    address rControllerAddress;
    address RoyaleLPaddr;

    uint256 depositBal;

    constructor(
        address _controller, 
        address _crvpool,
        address _coin,
        address _crvtoken,
        address _royaLP,
        address _gauge
    ) public {
        rControllerAddress = _controller;
        Pool = curvePool(_crvpool);
        Coin = Erc20(_coin);
        PoolToken = Erc20(_crvtoken);
        RoyaleLPaddr = _royaLP;
        gauge = PoolGauge(_gauge);
    }

    function deposit(uint amount) external {
        require(msg.sender == rControllerAddress, "not authorized");

        Coin.approve(address(Pool), amount);
        
        uint mintAmount = Pool.calc_token_amount([0, 0, amount], true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity([0, 0, amount], mintAmount);

        depositBal += amount;
    }

    function withdraw(uint amount) external {
        require(msg.sender == rControllerAddress, "not authorized");

        uint256 max_burn = 0;
        uint256 decimal = 0;

        decimal = Coin.decimals();
        max_burn = amount / 10**decimal;

        max_burn = max_burn + (max_burn * 2) / 100;
        decimal = PoolToken.decimals();
        max_burn = max_burn * 10**decimal;

        Pool.remove_liquidity_imbalance([0, 0, amount], max_burn);
        
        Coin.transfer(RoyaleLPaddr, Coin.balanceOf(address(this)));
        
        depositBal -= amount;
    }

    function withdrawAll() external {
        require(msg.sender == rControllerAddress, "not authorized");
        uint bal = PoolToken.balanceOf(address(this));

        uint min_amount = depositBal - (depositBal / 10);
        Pool.remove_liquidity_one_coin(bal, 2, min_amount);
        Coin.transfer(rControllerAddress, Coin.balanceOf(address(this)));
    }

    function stakeLP(uint _perc) external {
        require(msg.sender == rControllerAddress, "not authorized");

        uint depositAmt = (PoolToken.balanceOf(address(this)) * _perc) / 100;
        gauge.deposit(depositAmt);
    }

}