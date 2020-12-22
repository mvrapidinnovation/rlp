// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../../Interfaces/CurveInterface.sol';
import '../../Interfaces/ERC20Interface.sol';

contract rUSDT3Pool {

    Erc20 Coin;
    Erc20 PoolToken;
    curvePool public Pool;
    PoolGauge public gauge;
    Minter public minter;

    address rControllerAddress;
    address RoyaleLPaddr;

    uint256 depositBal;

    uint256 virtual_price;

    address public owner;

    uint256 public stakedAmt;

    modifier onlyAuthorized {
        require(msg.sender == owner || msg.sender == rControllerAddress,"not authorized");
        _;
    }

    constructor(
        address _controller, 
        address _crvpool,
        address _coin,
        address _crvtoken,
        address _royaLP,
        address _gauge
    ) public {
        owner = msg.sender;
        rControllerAddress = _controller;
        Pool = curvePool(_crvpool);
        Coin = Erc20(_coin);
        PoolToken = Erc20(_crvtoken);
        RoyaleLPaddr = _royaLP;
        gauge = PoolGauge(_gauge);
    }


    function deposit(uint amount) external onlyAuthorized {
        Coin.approve(address(Pool), amount);
        
        uint mintAmount = Pool.calc_token_amount([0, 0, amount], true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity([0, 0, amount], mintAmount);
        virtual_price = Pool.get_virtual_price();
        depositBal += amount;
    }

    function withdraw(uint amount) external onlyAuthorized{
       

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

    function withdrawAll() external onlyAuthorized {
        uint bal = PoolToken.balanceOf(address(this));

        uint min_amount = depositBal - (depositBal / 10);
        Pool.remove_liquidity_one_coin(bal, 2, min_amount);
        Coin.transfer(rControllerAddress, Coin.balanceOf(address(this)));
    }

    function stakeLP(uint _perc) external onlyAuthorized {
        uint depositAmt = (PoolToken.balanceOf(address(this)) * _perc) / 100;
        stakedAmt += depositAmt;
        PoolToken.approve(address(gauge), depositAmt);
        gauge.deposit(depositAmt);
    }

    function unstakeLP() external onlyAuthorized {
        uint withdrawAmt = stakedAmt;
        stakedAmt = 0;
        gauge.withdraw(withdrawAmt);
    }

    function claimCRV() external onlyAuthorized {
        minter.mint(address(gauge));
    }

    function calculateProfit() external view onlyAuthorized returns(uint256) {
         uint current_virtual_price = Pool.get_virtual_price();
         uint profit = (PoolToken.balanceOf(address(this))*(current_virtual_price-virtual_price))/(10**18);
         return profit;
    }

}