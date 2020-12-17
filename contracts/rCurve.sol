// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import './Interfaces/CurveInterface.sol';
import './Interfaces/ERC20Interface.sol';

contract rCurve {

    uint128 constant N_COINS = 3;

    address owner;
    
    Erc20[N_COINS] tokens;
    Erc20 PoolToken;
    curvePool public Pool; 
//= curvePool(0x5B2A3246d70ABB9121EA532a9Ac6f77D45366643);
    address LPaddr;

    constructor(
        Erc20 _poolToken,
        Erc20[N_COINS] memory _tokens,
        address addr
    ) public {
        owner = msg.sender;

        PoolToken = _poolToken;

        for(uint8 i=0; i<N_COINS; i++) {
            tokens[i] = _tokens[i];
        }

        LPaddr = addr;
    }

    //set pool
    function setPool(curvePool _pool) public {
        require(msg.sender == owner);
        Pool = _pool;
    }

    // Deposit
    function _deposit(uint256[N_COINS] memory amounts) internal {
        for(uint8 i=0; i<N_COINS; i++){
            if(amounts[i] > 0){
               tokens[i].approve(address(Pool), amounts[i]);
            }
        }

        uint mintAmount = Pool.calc_token_amount(amounts, true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity(amounts, mintAmount);
    }

    // Withdraw
    function _withdraw(uint256[N_COINS] memory amounts) internal {
        uint256 max_burn = 0;
        uint256 decimal = 0;
        uint256 temp = 0;

        for(uint8 i=0; i<N_COINS; i++) {
            decimal = tokens[i].decimals();
            temp = amounts[i] / 10**decimal;
            max_burn = max_burn + temp;
        }

        max_burn = max_burn + (max_burn * 2) / 100;
        decimal = PoolToken.decimals();
        max_burn = max_burn * 10**decimal;

        Pool.remove_liquidity_imbalance(amounts, max_burn);

        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                tokens[i].transfer(LPaddr, amounts[i]);
            }
        }
    }

    function deposit(uint256[N_COINS] calldata amount) external {
        _deposit(amount);
    }

    function withdraw(uint256[N_COINS] calldata amount) external {
        _withdraw(amount);
    }

    function updateRoyalelp(address _addr) external {
        require(msg.sender == owner);
        LPaddr = _addr;
    }
}