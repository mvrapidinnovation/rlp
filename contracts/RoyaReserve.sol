// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

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

    address[] stakersRoya;
    mapping(address => bool) hasStakedRoya;
    mapping(address => bool) isStakingRoya;

    address[] stakersBPT;
    mapping(address => bool) hasStakedBPT;
    mapping(address => bool) isStakingBPT;

    uint256 mRoyaPerBlock = 1 * 10**18;
    
    struct stakerRData {
        uint256 stakedRoya;
        uint256 initialStakedRoya;
        uint256 startTimestamp;
        uint256 blockNumber;
    }

    struct stakerBData {
        uint256 stakedBPT;
        uint256 initialStakedBPT;
        uint256 startTimestamp;
        uint256 blockNumber;
    }
    
    mapping(address => stakerRData) public stakerRoya;
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
    
    
    function updateRoyaAddress(RoyaleToken _royaT) public onlyOwner returns (bool){
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

        stakerRoya[msg.sender].stakedRoya += _amount;
        stakerRoya[msg.sender].initialStakedRoya += _amount;
        stakerRoya[msg.sender].startTimestamp = now;
        stakerRoya[msg.sender].blockNumber = block.number;

        if(!hasStakedRoya[msg.sender]) {
            stakersRoya.push(msg.sender);
        }

        hasStakedRoya[msg.sender] = true;
        isStakingRoya[msg.sender] = true;
    }
    
        
    function stakeBPT(uint _amount) public {
        require(_amount > 0, "amount can not be 0");

        bptToken.transferFrom(msg.sender, address(this), _amount);

        stakerBPT[msg.sender].stakedBPT += _amount;
        stakerBPT[msg.sender].initialStakedBPT += _amount;
        stakerBPT[msg.sender].startTimestamp = now;
        stakerBPT[msg.sender].blockNumber = block.number;

        if(!hasStakedBPT[msg.sender]) {
            stakersBPT.push(msg.sender);
        }

        hasStakedBPT[msg.sender] = true;
        isStakingBPT[msg.sender] = true;
    }


    
    
    function calculateMRoyaRoya(address recipient) public view returns (uint){
        uint256 stakedRoyaAmount = stakerRoya[recipient].stakedRoya;
        
        uint256 duration = block.number.sub(stakerRoya[recipient].blockNumber);
        uint256 totalRoya = royaT.balanceOf(address(this)); // getting total staked Roya Amount
        
        require(totalRoya > 0, 'No Roya available');
    
        uint256 mRoyaG = duration * stakedRoyaAmount * 10**18 / totalRoya;

        return mRoyaG * mRoyaPerBlock / 10**18;
    }
    
    
    function calculateMRoyaBPT(address recipient) public view returns (uint){
        uint256 stakedBPTAmount = stakerBPT[recipient].stakedBPT;
        uint256 duration = block.number.sub(stakerBPT[recipient].blockNumber);
        uint256 totalBPT = bptToken.balanceOf(address(this)); // getting total staked BPT Amount
        
        require(totalBPT > 0, 'No BPT available');
    
        uint256 mRoyaG = duration * stakedBPTAmount * 10**18 / totalBPT;

        return mRoyaG * mRoyaPerBlock / 10**18;
    }

    
    function calculateMRoyaTotal(address recipient) public view returns (uint){
        return calculateMRoyaBPT(recipient).add(calculateMRoyaRoya(recipient));
    }


    function _claimRewardsRoya(address recipient) internal returns (bool) {
        uint256 balance = stakerRoya[recipient].stakedRoya;
        
        require(balance > 0, 'Staking balance cannot be 0');

        uint256 rewards = calculateMRoyaRoya(recipient);
            

        if(rewards > 0) {

                mRoya.mint(recipient, rewards);

                //stakerRoya[msg.sender].stakedRoya = balance;
                stakerRoya[recipient].startTimestamp = now;
                stakerRoya[recipient].blockNumber = block.number;
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

                //stakerBPT[msg.sender].stakedBPT = balance;
                stakerBPT[recipient].startTimestamp = now;
                stakerBPT[recipient].blockNumber = block.number;
                return true;
            }
        
        return false;

    }


    function claimRewardsRoya() public returns (bool) {
        return _claimRewardsRoya(msg.sender);
    }

    function claimRewardsBPT() public returns (bool) {
        return _claimRewardsBPT(msg.sender);
    }
    
    
    function claimRewardsTotal() public returns (bool){
            bool b = _claimRewardsBPT(msg.sender);
            bool r = _claimRewardsRoya(msg.sender);
            return r && b;
    }


    function unstakeRoya() public {
        uint256 balance = stakerRoya[msg.sender].stakedRoya;
        uint256 duration = stakerRoya[msg.sender].startTimestamp.sub(now) / 86400;
        
        //require (isStaking[msg.sender],'Not staking any Roya');

        require(balance > 0, 'Staking balance cannot be 0');
        require(duration > 10, 'Should stake at least 10 days');

        royaT.transfer(msg.sender, balance);
        
        uint256 rewards = calculateMRoyaRoya(msg.sender);
            

        if(rewards > 0) {
                mRoya.mint(msg.sender, rewards);
            }

        stakerRoya[msg.sender].stakedRoya = 0;
        stakerRoya[msg.sender].startTimestamp = 0;
        stakerRoya[msg.sender].blockNumber = 0;

        isStakingRoya[msg.sender] = false;
    }

    function unstakeBPT() public {
        uint256 balance = stakerBPT[msg.sender].stakedBPT;
        uint256 duration = stakerBPT[msg.sender].startTimestamp.sub(now) / 86400;
        
        //require (isStaking[msg.sender],'Not staking any Roya');

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
        for(uint i=0; i<stakersRoya.length; i++) {
            uint256 balance = stakerRoya[stakersRoya[i]].stakedRoya;
            uint256 deductionAmount = balance * deductionPercent / 10000;
            stakerRoya[stakersRoya[i]].stakedRoya = balance.sub(deductionAmount);
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

library SafeMath { 
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
      require(b > 0);
      uint256 c = a / b;
      // assert(a == b * c + a % b); // There is no case in which this doesn't hold
      return c;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }


}