// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

contract rNum {
    uint public constant BASE_DECIMAL = 10**18;

    function btoi(uint a) internal pure returns (uint) {
        return a / BASE_DECIMAL;
    }

    function bfloor(uint a) internal pure returns (uint) {
        return btoi(a) * BASE_DECIMAL;
    }

    function badd(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "ERR_ADD_OVERFLOW");
        return c;
    }

    function bsub(uint a, uint b) internal pure returns (uint) {
        (uint c, bool flag) = bsubSign(a, b);
        require(!flag, "ERR_SUB_UNDERFLOW");
        return c;
    }

    function bsubSign(uint a, uint b) internal pure returns (uint, bool) {
        if (a >= b) {
            return (a - b, false);
        } else {
            return (b - a, true);
        }
    }

    function bmul(uint a, uint b) internal pure returns (uint) {
        uint c0 = a * b;
        require(a == 0 || c0 / a == b, "ERR_MUL_OVERFLOW");
        uint c1 = c0 + (BASE_DECIMAL / 2);
        require(c1 >= c0, "ERR_MUL_OVERFLOW");
        uint c2 = c1 / BASE_DECIMAL;
        return c2;
    }

    function bdiv(uint a, uint b) internal pure returns (uint) {
        require(b != 0, "ERR_DIV_ZERO");
        uint c0 = a * BASE_DECIMAL;
        require(a == 0 || c0 / a == BASE_DECIMAL, "ERR_DIV_INTERNAL"); // bmul overflow
        uint c1 = c0 + (b / 2);
        require(c1 >= c0, "ERR_DIV_INTERNAL"); //  badd require
        uint c2 = c1 / b;
        return c2;
    }
}