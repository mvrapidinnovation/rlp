// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../Interfaces/CurveInterface.sol';
 import '../Interfaces/ERC20Interface.sol';

contract Pool3DAI {

    address owner;
    Erc20 tokens;
    
    Erc20 PoolToken;
    curvePool public Pool; 
//= curvePool(0x5B2A3246d70ABB9121EA532a9Ac6f77D45366643);
    address LPaddr;

    uint256 depositBalance;

    constructor( Erc20 _poolToken, Erc20 _tokens, address addr,curvePool _pool) public {
        owner = msg.sender;
        PoolToken = _poolToken;
        tokens = _tokens;
        LPaddr = addr;
        Pool = _pool;
    }

    // Deposit
    function deposit(uint256 amount) external {
        tokens.approve(address(Pool), amount);
        uint mintAmount = Pool.calc_token_amount([amount,0,0], true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity([amount,0,0], mintAmount);
        depositBalance+=amount;
    }

    // Withdraw
    function withdraw(uint256 amount) external {
        uint256 max_burn = 0;
        uint256 decimal = 0;
        uint256 temp = 0;
        decimal = tokens.decimals();
        temp = amount / 10**decimal;
        max_burn = max_burn + temp;
        max_burn = max_burn + (max_burn * 2) / 100;
        decimal = PoolToken.decimals();
        max_burn = max_burn * 10**decimal;

        Pool.remove_liquidity_imbalance([amount,0,0], max_burn);
        tokens.transfer(LPaddr, tokens.balanceOf(address(this)));
        depositBalance-=amount;
            
    }
    
     function withdrawAll() internal {
        uint crvBal = PoolToken.balanceOf(address(this));
        Pool.remove_liquidity_one_coin(crvBal,0, depositBalance);
        tokens.transfer(LPaddr, tokens.balanceOf(address(this)));
    }

    
}
