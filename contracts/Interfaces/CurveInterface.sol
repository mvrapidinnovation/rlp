// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

abstract contract curvePool {
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

    function remove_liquidity_one_coin(
        uint256 ,
        int128,
        uint256
    )virtual external;
}
