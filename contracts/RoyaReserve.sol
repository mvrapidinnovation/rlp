// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

interface MRoya{

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

interface RoyaleToken{

    function totalSupply() external view returns (uint256);
    
    function balanceOf(address tokenOwner) external view returns (uint);

    function transfer(address receiver, uint numTokens) external returns (bool);

    function approve(address delegate, uint numTokens) external returns (bool);

    function allowance(address owner, address delegate) external view returns (uint);
    
    function transferFrom(address owner, address buyer, uint numTokens) external returns (bool);
}

interface BToken{

    function totalSupply() external view returns (uint256);
    
    function balanceOf(address tokenOwner) external view returns (uint);

    function transfer(address receiver, uint numTokens) external returns (bool);

    function approve(address delegate, uint numTokens) external returns (bool);

    function allowance(address owner, address delegate) external view returns (uint);
    
    function transferFrom(address owner, address buyer, uint numTokens) external returns (bool);
}


contract Reserve {
    address public owner;

    MRoya public mRoya;
    RoyaleToken public royaT;
    BToken public bptToken;

    address[] stakersRPT;
    mapping(address => bool) hasStakedRPT;
    mapping(address => bool) isStakingRPT;

    address[] stakersBPT;
    mapping(address => bool) hasStakedBPT;
    mapping(address => bool) isStakingBPT;

    uint256 mRoyaPerBlock = 1 * 10**18;
    
    struct stakerRData {
        uint256 stakedRPT;
        uint256 initialStakedRPT;
        uint256 startTimestamp;
        uint256 blockNumber;
    }

    struct stakerBData {
        uint256 stakedBPT;
        uint256 initialStakedBPT;
        uint256 startTimestamp;
        uint256 blockNumber;
    }
    
    mapping(address => stakerRData) public stakerRPT;
    mapping(address => stakerBData) public stakerBPT;

    using SafeMath for uint256;

    constructor(RoyaleToken _royaT, BToken _bptToken, MRoya _mRoya) public {
        royaT = _royaT;
        mRoya = _mRoya;
        bptToken = _bptToken;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the Owner");
        _;
    }
    
    
    function updateMRoyaAddress(MRoya _mRoya) public onlyOwner returns (bool){
        mRoya = _mRoya;
        return true;
    }
    
    
    function updateRPTAddress(RoyaleToken _royaT) public onlyOwner returns (bool){
        royaT = _royaT;
        return true;
    }

    function updateBPTAddress(BToken _bptToken) public onlyOwner returns (bool){
        bptToken = _bptToken;
        return true;
    }
    
    
    function stakeRoya(uint _amount) public {
        require(_amount > 0, "amount can not be 0");

        royaT.transferFrom(msg.sender, address(this), _amount);

        stakerRPT[msg.sender].stakedRPT += _amount;
        stakerRPT[msg.sender].initialStakedRPT += _amount;
        stakerRPT[msg.sender].startTimestamp = now;
        stakerRPT[msg.sender].blockNumber = block.number;

        if(!hasStakedRPT[msg.sender]) {
            stakersRPT.push(msg.sender);
        }

        hasStakedRPT[msg.sender] = true;
        isStakingRPT[msg.sender] = true;
    }
    
        
    function stakeBPT(uint _amount) public {
        require(_amount > 0, "amount can not be 0");

        bptToken.transferFrom(msg.sender, address(this), _amount);

        stakerBPT[msg.sender].stakedBPT += _amount;
        stakerRPT[msg.sender].initialStakedRPT += _amount;
        stakerBPT[msg.sender].startTimestamp = now;
        stakerBPT[msg.sender].blockNumber = block.number;

        if(!hasStakedBPT[msg.sender]) {
            stakersBPT.push(msg.sender);
        }

        hasStakedBPT[msg.sender] = true;
        isStakingBPT[msg.sender] = true;
    }


    
    
    function calculateMRoyaRPT(address recipient) public view returns (uint){
        uint256 stakedRPTAmount = stakerRPT[recipient].stakedRPT;
        
        uint256 duration = block.number.sub(stakerRPT[recipient].blockNumber);
        uint256 totalRPT = royaT.balanceOf(address(this)); // getting total staked RPT Amount
        
        require(totalRPT > 0, 'No RPT available');
    
        uint256 mRoyaAmt = duration * stakedRPTAmount * 10**18 / totalRPT;

        return mRoyaAmt * mRoyaPerBlock / 10**18;
    }
    
    
    function calculateMRoyaBPT(address recipient) public view returns (uint){
        uint256 stakedBPTAmount = stakerBPT[recipient].stakedBPT;
        uint256 duration = block.number.sub(stakerBPT[recipient].blockNumber);
        uint256 totalBPT = bptToken.balanceOf(address(this)); // getting total staked BPT Amount
        
        require(totalBPT > 0, 'No BPT available');
    
        uint256 mRoyaAmt = duration * stakedBPTAmount * 10**18 / totalBPT;

        return mRoyaAmt * mRoyaPerBlock / 10**18;
    }

    
    function calculateMRoyaTotal(address recipient) public view returns (uint){
        return calculateMRoyaBPT(recipient).add(calculateMRoyaRPT(recipient));
    }


    function _claimRewardsRPT(address recipient) internal returns (bool) {
        uint256 balance = stakerRPT[recipient].stakedRPT;
        
        require(balance > 0, 'Staking balance cannot be 0');

        uint256 rewards = calculateMRoyaRPT(recipient);
            

        if(rewards > 0) {

                mRoya.mint(recipient, rewards);

                //stakerRPT[msg.sender].stakedRPT = balance;
                stakerRPT[recipient].startTimestamp = now;
                stakerRPT[recipient].blockNumber = block.number;
                return true;
            }
        
        return false;

    }

    function _claimRewardsBPT(address recipient) internal returns (bool) {
        uint256 balance = stakerBPT[recipient].stakedBPT;
        
        require(balance > 0, 'Staking balance cannot be 0');

        uint256 rewards = calculateMRoyaBPT(recipient);
            

        if(rewards > 0) {

                mRoya.mint(recipient, rewards);

                //stakerRPT[msg.sender].stakedBPT = balance;
                stakerBPT[recipient].startTimestamp = now;
                stakerBPT[recipient].blockNumber = block.number;
                return true;
            }
        
        return false;

    }


    function claimRewardsRPT() public returns (bool) {
        return _claimRewardsRPT(msg.sender);
    }

    function claimRewardsBPT() public returns (bool) {
        return _claimRewardsBPT(msg.sender);
    }
    
    
    function claimRewardsTotal() public returns (bool){
            bool b = _claimRewardsBPT(msg.sender);
            bool r = _claimRewardsRPT(msg.sender);
            return r && b;
    }


    function unstakeRPT() public {
        uint256 balance = stakerRPT[msg.sender].stakedRPT;
        uint256 duration = stakerRPT[msg.sender].startTimestamp.sub(now) / 86400;
        
        //require (isStaking[msg.sender],'Not staking any RPT');

        require(balance > 0, 'Staking balance cannot be 0');
        require(duration > 10, 'Should stake at least 10 days');

        royaT.transfer(msg.sender, balance);
        
        uint256 rewards = calculateMRoyaRPT(msg.sender);
            

        if(rewards > 0) {
                mRoya.mint(msg.sender, rewards);
            }

        stakerRPT[msg.sender].stakedRPT = 0;
        stakerRPT[msg.sender].startTimestamp = 0;
        stakerRPT[msg.sender].blockNumber = 0;

        isStakingRPT[msg.sender] = false;
    }

    function unstakeBPT() public {
        uint256 balance = stakerBPT[msg.sender].stakedBPT;
        uint256 duration = stakerBPT[msg.sender].startTimestamp.sub(now) / 86400;
        
        //require (isStaking[msg.sender],'Not staking any RPT');

        require(balance > 0, 'Staking balance cannot be 0');
        require(duration > 10, 'Should stake at least 10 days');

        bptToken.transfer(msg.sender, balance);
        
        uint256 rewards = calculateMRoyaBPT(msg.sender);
            

        if(rewards > 0) {
                mRoya.mint(msg.sender, rewards);
            }

        stakerBPT[msg.sender].stakedBPT = 0;
        stakerBPT[msg.sender].startTimestamp = 0;
        stakerBPT[msg.sender].blockNumber = 0;

        isStakingBPT[msg.sender] = false;
    }


    function updateMRoyaPerBlock(uint256 _mRoyaPerBlock) public {
        require(msg.sender == owner, "only owner can upadate data");
        mRoyaPerBlock = _mRoyaPerBlock;
    }

    function distributedWithdrawROYA(address recipient, uint256 amount) public onlyOwner returns (bool){
        uint256 totalRoyaStaked = royaT.balanceOf(address(this));
        require(amount>totalRoyaStaked,"Not enough Roya to withdraw");
        uint256 deductionPercent = amount * 10000 / totalRoyaStaked;
        uint256 totalDeduction = 0;
        for(uint i=0; i<stakersRPT.length; i++) {
            uint256 balance = stakerRPT[stakersRPT[i]].stakedRPT;
            uint256 deductionAmount = balance * deductionPercent / 10000;
            stakerRPT[stakersRPT[i]].stakedRPT = balance.sub(deductionAmount);
            totalDeduction.add(deductionAmount);

        }
        royaT.transfer(recipient,totalDeduction);
        return totalDeduction == amount;
    }
    
    
    function distributedWithdrawBPT(address recipient, uint256 amount) public onlyOwner returns (bool){
        uint256 totalBPTStaked = bptToken.balanceOf(address(this));
        require(amount>totalBPTStaked,"Not enough Roya to withdraw");
        uint256 deductionPercent = amount * 10000 / totalBPTStaked;
        uint256 totalDeduction = 0;
        for(uint i=0; i<stakersBPT.length; i++) {
            uint256 balance = stakerBPT[stakersBPT[i]].stakedBPT;
            uint256 deductionAmount = balance * deductionPercent / 10000;
            stakerBPT[stakersBPT[i]].stakedBPT = balance.sub(deductionAmount);
            totalDeduction.add(deductionAmount);

        }
        bptToken.transfer(recipient,totalDeduction);
        return totalDeduction == amount;
    }

}