// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

interface MRoya {

    function totalSupply() external view  returns (uint256);
    
    function balanceOf(address tokenOwner) external view returns (uint);

    function transfer(address receiver, uint numTokens) external returns (bool);

    function approve(address delegate, uint numTokens) external returns (bool);

    function allowance(address owner, address delegate) external view returns (uint);
    
    function transferFrom(address owner, address buyer, uint numTokens) external returns (bool);
    
    function mint(address account, uint256 amount) external;
    
    function _burn(address account, uint256 amount) external;
    
    function burn(uint256 amount) external;
}

interface RPToken {

    function totalSupply() external view returns (uint256);
    
    function balanceOf(address tokenOwner) external view returns (uint);

    function transfer(address receiver, uint numTokens) external returns (bool);

    function approve(address delegate, uint numTokens) external returns (bool);

    function allowance(address owner, address delegate) external view returns (uint);
    
    function transferFrom(address owner, address buyer, uint numTokens) external returns (bool);
}


contract MRoyaFarm {
    address public owner;

    MRoya public mRoya;
    RPToken public rpToken;

    address[] public stakers;
    mapping(address => bool) hasStaked;
    mapping(address => bool) isStaking;
    uint256 mRoyaPerBlock = 1*10**18;
    
    struct stakerData {
        uint256 stakedRPT;
        uint256 startTimestamp;
        uint256 blockNumber;
    }
    
    mapping(address => stakerData) public staker;

    using SafeMath for uint256;

    constructor(RPToken _rpToken, MRoya _mRoya) public {
        rpToken = _rpToken;
        mRoya = _mRoya;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }
    
    // function to get the mRoya of the staker
    function calculateMRoya(address recipient) public view returns (uint){
        uint256 stakedRPTAmount = staker[recipient].stakedRPT;
        uint256 duration = block.number.sub(staker[recipient].blockNumber);
        uint256 totalRPT = rpToken.totalSupply();
        
        require(totalRPT > 0, 'No RPT available');
    
        uint256 mRoyaAmount = duration * stakedRPTAmount * 10**18 / totalRPT;
        return (mRoyaAmount * mRoyaPerBlock) / 10 ** 18;
    }
    
    // function to stake tokens
    function stakeTokens(uint _amount) public {
        require(_amount > 0, "amount can not be 0");

        rpToken.transferFrom(msg.sender, address(this), _amount);

        staker[msg.sender].stakedRPT += _amount;
        staker[msg.sender].startTimestamp = now;
        staker[msg.sender].blockNumber = block.number;

        if(!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
        }

        hasStaked[msg.sender] = true;
        isStaking[msg.sender] = true;
    }

    // function to distribute mRoya
    function issueTokens() public onlyOwner {
        for(uint i=0; i<stakers.length; i++) {
            address recipient = stakers[i];
            uint256 balance = calculateMRoya(recipient);
            

            if(balance > 0) {
                mRoya.mint(recipient, balance);
                staker[recipient].startTimestamp = now;
                staker[recipient].blockNumber = block.number;
            }
        }
    }

    // function to clain rewards
    function claimRewards() public returns (bool) {
        uint256 balance = staker[msg.sender].stakedRPT;
        
        require(balance > 0, 'Staking balance cannot be 0');

        uint256 rewards = calculateMRoya(msg.sender);
            

        if(rewards > 0) {

                mRoya.mint(msg.sender, rewards);

                //staker[msg.sender].stakedRPT = balance;
                staker[msg.sender].startTimestamp = now;
                staker[msg.sender].blockNumber = block.number;
                return true;
            }
        
        return false;

    }

    // function to unstake tokens
    function unstakeTokens(uint amount) public {
        uint256 balance = staker[msg.sender].stakedRPT;
        require(balance > amount, 'staking balance cannot be less');

        rpToken.transfer(msg.sender, amount);
        
        uint256 rewards = calculateMRoya(msg.sender);

        staker[msg.sender].stakedRPT -= amount;    
        
        if(rewards > 0) {
            mRoya.mint(msg.sender, rewards);

            staker[msg.sender].startTimestamp = now;
            staker[msg.sender].blockNumber = block.number;
        }

        if(staker[msg.sender].stakedRPT == 0) {
            staker[msg.sender].stakedRPT = 0;
            staker[msg.sender].startTimestamp = 0;
            staker[msg.sender].blockNumber = 0;
            isStaking[msg.sender] = false;
        }
    }

    /* Admin Functions */

    function updateMRoyaPerBlock(uint256 _mRoyaPerBlock) public onlyOwner {
        mRoyaPerBlock = _mRoyaPerBlock*10**18;
    }

    function updateMRoyaAddress(MRoya _mRoya) public onlyOwner returns (bool){
        mRoya = _mRoya;
        return true;
    }
      
    function updateRPTAddress(RPToken _rpToken) public onlyOwner returns (bool){
        rpToken = _rpToken;
        return true;
    }

}