// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract RPToken is ERC20 {

    address public owner;
    address public caller;

    constructor() public ERC20("Royale Protocol", "RPT") {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner || msg.sender == caller, "not authorized");
        _;
    }

    function setCaller(address addr) external onlyOwner {
        caller = addr;
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function burn(address sender, uint256 amount) external onlyOwner {
        _burn(sender, amount);
    }
}