// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

abstract contract curvePool {

    function get_virtual_price()virtual external view returns(uint256);

    function calc_token_amount(
        uint256[3] calldata, 
        bool
    ) virtual external view returns(uint256);

    function add_liquidity(
        uint256[3] calldata,
        uint256
    ) virtual external;

    function remove_liquidity(
        uint256,
        uint256[3] calldata
    ) virtual external;

    function remove_liquidity_imbalance(
        uint256[3] calldata,
        uint256
    ) virtual external;

    function calc_token_amount(
        uint256[4] calldata, 
        bool
    ) virtual external view returns(uint256);

    function add_liquidity(
        uint256[4] calldata,
        uint256
    ) virtual external;

    function remove_liquidity(
        uint256,
        uint256[4] calldata
    ) virtual external;

    function remove_liquidity_imbalance(
        uint256[4] calldata,
        uint256
    ) virtual external;


    function remove_liquidity_one_coin(
        uint256,
        int128,
        uint256
    ) virtual external;
}

abstract contract PoolGauge {
    function deposit(uint256) virtual external;
    function withdraw(uint256) virtual external;
    function claimable_tokens(address) virtual external returns(uint256);
}

abstract contract Minter {
    function mint(address) virtual external;
}