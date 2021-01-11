// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../../Interfaces/ERC20Interface.sol';
import '../../Interfaces/MultisigInterface.sol';
import '../../Interfaces/CurveInterface.sol';
import '../../Interfaces/UniswapInterface.sol';
import '../MathLib.sol';

contract CurveStrategy is rNum{

    address royaleAddress;
    
    MultiSignatureInterface multiSig;
    Erc20 PoolToken;
    Erc20[3] Coins;
    curvePool public Pool;
    PoolGauge public gauge;
    Minter public minter;
    
    uint256 totalProfit;
    
    uint256 public foundationProfit;
    
    uint256 profitBreak=75;
    
    uint256[3] public depositBal;

    uint256 totalDeposited;

    uint256 virtual_price;

    bool public TEST = true;

    uint8 public _perc=75;

    uint256 public stakedAmt;

    address public uniAddr  = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public crvAddr  = address(0x5dDBDBB1D1e691d2994d4A44470EB07dFCbd57C3);
    address public wethAddr = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


     modifier onlyAuthorized(address _caller) {
        require(
             multiSig.checkOwner(_caller) || _caller == royaleAddress, 
            "not authorized"
        );
        _;
    }

    modifier onlyRoyaleLP(address _caller) {
        require(
              _caller == royaleAddress, 
            "not authorized"
        );
        _;
    }

     constructor(
        Erc20[3] memory coins, 
        address _crvpool,
        address _pooltoken,
        address _royaleaddress,
        address _gauge,
        address _minter,
        address _multiSig) public {
    
        Pool = curvePool(_crvpool);
        PoolToken = Erc20(_pooltoken);
        gauge = PoolGauge(_gauge);
        minter=Minter(_minter);
        multiSig= MultiSignatureInterface(_multiSig);
        royaleAddress =_royaleaddress;
        for(uint8 i=0; i<3; i++) {
            Coins[i] = coins[i];
        }
    }

    function setProfitBreak(uint8 _profitBreak) public onlyAuthorized(msg.sender) {
        profitBreak = _profitBreak;
    }

    function updateRoyalePool(address _royale) public onlyAuthorized(msg.sender){
       royaleAddress = _royale;
    }

    function set3CRVPercentage(uint8 _percentage3CRV)external onlyAuthorized(msg.sender){
        _perc=_percentage3CRV;
    }

    function deposit(uint[3] calldata amounts) external onlyAuthorized(msg.sender) {
        for(uint8 i=0; i<3; i++) {
            if(amounts[i] > 0) {
                uint decimal;
                decimal=Coins[i].decimals();
               Coins[i].approve(address(Pool), amounts[i]); 
               depositBal[i] += amounts[i];
               totalDeposited+=bdiv(amounts[i],10**decimal);
            }
        }
        totalProfit +=calculateProfit();
        uint mintAmount = Pool.calc_token_amount(amounts, true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity(amounts, mintAmount);
        virtual_price=Pool.get_virtual_price();   
    }

    function withdraw(uint[3] calldata amounts) external onlyRoyaleLP(msg.sender) {
       uint256 max_burn = 0;
        uint256 decimal = 0;
        for(uint8 i=0;i<3;i++){
            decimal = Coins[i].decimals();
            max_burn+=amounts[i]/10**decimal;
            depositBal[i] -= amounts[i];
            totalDeposited-=bdiv(amounts[i],10**decimal);
        }
        max_burn = max_burn + (max_burn * 2) / 100;
        decimal = PoolToken.decimals();
        max_burn = max_burn * 10**decimal;
        Pool.remove_liquidity_imbalance(amounts, max_burn);
        for(uint8 i=0;i<3;i++){
            if(amounts[i]!=0){
               Coins[i].transfer(royaleAddress, Coins[i].balanceOf(address(this)));
            }
        }
        
        
    }

    function withdrawAll() external onlyRoyaleLP(msg.sender){
        uint256[3] memory amounts;
        uint256 poolTokenBalance=0;
        Pool.remove_liquidity(poolTokenBalance,amounts);
         for(uint8 i=0;i<3;i++){
            if(Coins[i].balanceOf(address(this))!=0){
                depositBal[i] =0;
                 Coins[i].transfer(royaleAddress, Coins[i].balanceOf(address(this)));
            }
        }
        totalDeposited=0; 
    }

    function stakeLP() external onlyAuthorized(msg.sender) {
       uint depositAmt = ((PoolToken.balanceOf(address(this)) + stakedAmt) * _perc) / 100;
        if(depositAmt>stakedAmt){
            depositAmt-=stakedAmt;
            if(depositAmt!=0){
                 PoolToken.approve(address(gauge), depositAmt);
                 gauge.deposit(depositAmt);
                 stakedAmt += depositAmt;
            }
        }
    }

    function unstakeLP(uint _amount) external onlyAuthorized(msg.sender) {
        require(stakedAmt >= _amount,"You have not staked that amount");
        gauge.withdraw(_amount);
        stakedAmt -=_amount;
    }

    function unstakeAll()public onlyAuthorized(msg.sender){
        gauge.withdraw(stakedAmt);
        stakedAmt=0;
    }

    function checkClaimableToken()public onlyAuthorized(msg.sender) returns(uint256){
        uint256 a=gauge.claimable_tokens(address(this));
        return a;
    }

    function _claimCRV() internal  {
        minter.mint(address(gauge));
    }

    function sellCRV(uint8 _index) public onlyAuthorized(msg.sender) returns(uint256) {  //here index=0 means convert crv into DAI , index=1 means crv into USDC , index=2 means crv into USDT
        uint256 crvAmt = Erc20(crvAddr).balanceOf(address(this));
        uint256 prevCoin = Coins[_index].balanceOf(address(this));
        require(crvAmt > 0, "insufficient CRV");
        Erc20(crvAddr).approve(uniAddr, crvAmt);

        address[] memory path; 

        if(TEST) {
            path = new address[](2);

            path[0] = crvAddr;
            path[1] = address(Coins[_index]);

        } else {
            path = new address[](3);
            path[0] = crvAddr;
            path[1] = wethAddr;
            path[2] = address(Coins[_index]);
        }


        UniswapI(uniAddr).swapExactTokensForTokens(
            crvAmt, 
            uint256(0), 
            path, 
            address(this), 
            now + 1800
        );
        uint256 postCoin=Coins[_index].balanceOf(address(this));
        Coins[_index].transfer(royaleAddress, (postCoin-prevCoin));
        return (postCoin-prevCoin);
    }

    function getTotalProfit(uint8 _index) external onlyRoyaleLP(msg.sender) returns(uint256[3] memory) {
        _claimCRV();
        uint256 crvProfit;
        crvProfit = sellCRV(_index);
        uint decimal;
        decimal=Coins[_index].decimals();
        totalProfit+=bdiv(crvProfit,10**(decimal));
        uint256[3] memory tokenProfit;
        uint256 royaleLPProfit;
        royaleLPProfit = bdiv(bmul(totalProfit,profitBreak),100);
        totalProfit = bsub(totalProfit,royaleLPProfit);
        foundationProfit =badd(foundationProfit,totalProfit);
        totalProfit=0;
        for(uint8 i=0;i<3;i++){
            tokenProfit[i]=bdiv(bmul(royaleLPProfit,depositBal[i]),totalDeposited);
            
        }
        return tokenProfit;
    }


    function calculateProfit() public view onlyAuthorized(msg.sender) returns(uint256) {
         uint current_virtual_price=Pool.get_virtual_price();
         uint profit=(PoolToken.balanceOf(address(this))+stakedAmt)*(current_virtual_price-virtual_price);
         return profit;
    }

    function transferCRV(address _address)external onlyAuthorized(msg.sender){
         Erc20(crvAddr).transfer(_address ,Erc20(crvAddr).balanceOf(address(this)));
    }
}