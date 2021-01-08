// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

interface USDC{

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


contract StakingLots {
    using SafeMath for uint256;
    
 
    struct StakeOption {
        string  stakeName;
        uint256 stakeID;
        uint256 interestPercentage; // in 1000 basis points
        uint256 penaltyPercentage;  // in 1000 basis points
        uint8 durationDays; // in Days
    }
    
    struct StakedData {
        address staker;
        uint256 stakeID;
        uint256 stakedAmount;
        uint256 startTimeStamp;
        uint256 initialStakedAmount;
        uint256 lastWithdrawTimestamp;
    }
    
    address public owner;

    RoyaleToken roya;
    USDC usdc;
        
    uint256 public  depositedStakesCount=0;
    
    uint256 public stakeOptionsCount=0;
    
    StakeOption[] public stakeOptions;

    mapping(address => StakedData[]) public stakes;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
    }
    
    constructor(RoyaleToken _roya, USDC _usdc) public{
          owner= msg.sender;

          roya = _roya;
          usdc = _usdc;

          StakeOption memory king = StakeOption("King",0,10000,5000,3);
          StakeOption memory queen = StakeOption("Queen",1,5000,2000,2);
          StakeOption memory royaleFlush = StakeOption("Flush",2,2000,1000,1);

          stakeOptions.push(king);
          stakeOptions.push(queen);
          stakeOptions.push(royaleFlush);
          
          stakeOptionsCount = 3;
    }

    function setRoyaContractAddress(RoyaleToken _roya) public onlyOwner {
         roya = _roya;
    }
    
    function setUSDCContractAddress(USDC _usdc) public onlyOwner {
         usdc = _usdc;
    }
    
    
    function addStakeOption(
        string memory name, 
        uint256 _interestPercentage,
        uint256 _penaltyPercentage,
        uint8 _duration
    ) public onlyOwner returns(bool) {
        StakeOption memory stake = StakeOption(
            name, 
            stakeOptionsCount, 
            _interestPercentage,
            _penaltyPercentage,
            _duration
        );

        stakeOptions.push(stake);
        stakeOptionsCount = stakeOptionsCount + 1;
        
        return stakeOptions.length == stakeOptionsCount;
    }

    
    function stakeRoya(uint256 _amount, uint256 _stakeOptionID) public returns(bool){
        require(_amount>0 , "Deposited amount can not be zero");
        require(_stakeOptionID > 0 && _stakeOptionID <= stakeOptionsCount , "Please choose valid stake");
        require(roya.balanceOf(msg.sender)>= _amount,"Insufficient balance");

        uint256 timestamp = block.timestamp;

        StakedData memory stake = StakedData(
            msg.sender,
            _stakeOptionID,
            _amount,
            timestamp,
            _amount,
            timestamp
        );

        bool result = roya.transferFrom(
            msg.sender, 
            address(this), 
            _amount
        );
        
        stakes[msg.sender].push(stake);
        depositedStakesCount++;

        return result;
    }
    
    function getStakesCount(address staker) public view returns(uint256){
        return stakes[staker].length;
    }
    
    function getAccumulatedRewards(
        address staker, 
        uint256 stakeIndex
    ) public view returns(uint256) {
        StakeOption memory stakeOption = stakeOptions[stakes[staker][stakeIndex].stakeID];
        uint256 currentDuration = (block.timestamp - stakes[staker][stakeIndex].lastWithdrawTimestamp) / 86400;
        uint256 totalDuration = (block.timestamp - stakes[staker][stakeIndex].startTimeStamp) / 86400;
        if(totalDuration > stakeOption.durationDays){
            currentDuration = currentDuration - (totalDuration - stakeOption.durationDays);
        }
        uint256 interest = stakes[staker][stakeIndex].stakedAmount * stakeOption.interestPercentage * currentDuration / 365000;
        return interest;
    }
    
    function claimRewards(
        address staker, 
        uint256 stakeIndex
    ) public returns(bool) {
        uint256 rewards = getAccumulatedRewards(staker, stakeIndex);
        usdc.transfer(staker,rewards);
        stakes[staker][stakeIndex].lastWithdrawTimestamp = block.timestamp;
    }
   
    
    function withdrawStakedRoya(uint256 _stakeIndex) public {
        uint256 _amount = stakes[msg.sender][_stakeIndex].stakedAmount;

        uint256 currentDuration = (block.timestamp - stakes[msg.sender][_stakeIndex].startTimeStamp) / 86400;
        require(currentDuration >= stakeOptions[stakes[msg.sender][_stakeIndex].stakeID].durationDays,"Stake duration not completed");
        
        uint256 rewards = getAccumulatedRewards(msg.sender, _stakeIndex);

        usdc.transfer(msg.sender,rewards);
        roya.transfer(msg.sender,_amount);
        
        for (uint i = _stakeIndex; i<stakes[msg.sender].length-1; i++){
            stakes[msg.sender][i] = stakes[msg.sender][i+1];
        }
        delete stakes[msg.sender][stakes[msg.sender].length-1];
        stakes[msg.sender].pop();
    }    
    
    
    function withdrawStakedRoyaWithPenalty(
        uint256 _amount,
        uint256 _stakeIndex
    ) public {
        require(stakes[msg.sender][_stakeIndex].stakedAmount >= _amount,"Not enough balance");

        uint256 currentDuration = (block.timestamp - stakes[msg.sender][_stakeIndex].startTimeStamp) / 86400;
        require(currentDuration >= stakeOptions[stakes[msg.sender][_stakeIndex].stakeID].durationDays,"Stake duration not completed");
                
        uint256 rewards = getAccumulatedRewards(msg.sender, _stakeIndex);
        uint256 penalty = _amount * stakeOptions[stakes[msg.sender][_stakeIndex].stakeID].penaltyPercentage / 1000;
        
        usdc.transfer(msg.sender,rewards);
        roya.transfer(msg.sender,_amount.sub(penalty));
        roya.transfer(owner,penalty);
        
        stakes[msg.sender][_stakeIndex].lastWithdrawTimestamp = block.timestamp;
        stakes[msg.sender][_stakeIndex].stakedAmount.sub(_amount);
    }    
}
    