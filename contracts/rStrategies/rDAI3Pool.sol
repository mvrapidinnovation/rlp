// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import '../../Interfaces/CurveInterface.sol';
import '../../Interfaces/ERC20Interface.sol';
import '../../Interfaces/UniswapInterface.sol';

contract rDAI3Pool {

    Erc20 Coin;
    Erc20 PoolToken;
    curvePool public Pool;
    PoolGauge public gauge;
    Minter public minter;

    bool public TEST = true;

    address rControllerAddress;
    address RoyaleLPaddr;

    uint256 depositBal;

    uint256 virtual_price;

    address public owner;

    uint8 public _perc=75;
    uint256 public stakedAmt;

    address public uniAddr  = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public crvAddr  = address(0x5dDBDBB1D1e691d2994d4A44470EB07dFCbd57C3);
    address public wethAddr = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


    modifier onlyAuthorized {
        require(msg.sender == owner || msg.sender == rControllerAddress,"not authorized");
        _;
    }

    constructor(
        address _controller, 
        address _crvpool,
        address _coin,
        address _crvtoken,
        address _royaLP,
        address _gauge
    ) public {
        owner=msg.sender;
        rControllerAddress = _controller;
        Pool = curvePool(_crvpool);
        Coin = Erc20(_coin);
        PoolToken = Erc20(_crvtoken);
        RoyaleLPaddr = _royaLP;
        gauge = PoolGauge(_gauge);
    }

    function set3CRVPercentage(uint8 _percentage3CRV)external onlyAuthorized{
        _perc=_percentage3CRV;
    }

    function deposit(uint amount) external onlyAuthorized {
        Coin.approve(address(Pool), amount);
        uint mintAmount = Pool.calc_token_amount([amount, 0, 0], true);
        mintAmount = (99 * mintAmount) / 100;
        Pool.add_liquidity([amount, 0, 0], mintAmount);
        virtual_price=Pool.get_virtual_price();
        depositBal += amount;
    }

    function withdraw(uint amount) external onlyAuthorized {

        uint256 max_burn = 0;
        uint256 decimal = 0;

        decimal = Coin.decimals();
        max_burn = amount / 10**decimal;

        max_burn = max_burn + (max_burn * 2) / 100;
        decimal = PoolToken.decimals();
        max_burn = max_burn * 10**decimal;

        Pool.remove_liquidity_imbalance([amount, 0, 0], max_burn);
        
        Coin.transfer(RoyaleLPaddr, Coin.balanceOf(address(this)));
        
        depositBal -= amount;
    }

    function withdrawAll() external onlyAuthorized {
        
        uint bal = PoolToken.balanceOf(address(this));

        uint min_amount = depositBal - (depositBal / 10);
        Pool.remove_liquidity_one_coin(bal, 0, min_amount);
        Coin.transfer(rControllerAddress, Coin.balanceOf(address(this)));
    }

    function stakeLP() external onlyAuthorized {
       uint depositAmt = ((PoolToken.balanceOf(address(this)) + stakedAmt) * _perc) / 100;
        depositAmt -= stakedAmt;
        if(depositAmt!=0){
           PoolToken.approve(address(gauge), depositAmt);
           gauge.deposit(depositAmt);
           stakedAmt += depositAmt;
        }
    }

    function unstakeLP(uint _amount) external onlyAuthorized {
        require(stakedAmt >= _amount,"You have not staked that amount");
       
        gauge.withdraw(_amount);
        stakedAmt -=_amount;
    }

    function _claimCRV() internal  {
        minter.mint(address(gauge));
    }

    function calculateProfit() external view onlyAuthorized returns(uint256) {
         uint current_virtual_price=Pool.get_virtual_price();
         uint profit=(PoolToken.balanceOf(address(this))*(current_virtual_price-virtual_price))/(10**18);
         return profit;
    }

    function sellCRV() external onlyAuthorized returns(uint256) {
        // _claimCRV();
        uint256 crvAmt = Erc20(crvAddr).balanceOf(address(this));
        uint256 prevCoin=Coin.balanceOf(address(this));

        require(crvAmt > 0, "insufficient CRV");

        Erc20(crvAddr).approve(uniAddr, crvAmt);

        address[] memory path; 

        if(TEST) {
            path = new address[](2);

            path[0] = crvAddr;
            path[1] = address(Coin);

        } else {
            path = new address[](3);

            path[0] = crvAddr;
            path[1] = wethAddr;
            path[2] = address(Coin);
        }


        UniswapI(uniAddr).swapExactTokensForTokens(
            crvAmt, 
            uint256(0), 
            path, 
            address(this), 
            now + 1800
        );
        uint256 postCoin=Coin.balanceOf(address(this));
        Coin.approve(rControllerAddress,postCoin-prevCoin);
        return (postCoin-prevCoin);
    }

}