// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './MathLib.sol';
import './RoyaleLPstorage.sol';


contract RoyaleLP is RoyaleLPstorage, rNum {

  
    
    modifier ownerExists(address _caller) {
        require(multiSig.checkOwner(_caller),"owner not exist");
        _;
    }

    modifier onlyAuthorized(address _caller) {
        require(
            multiSig.checkOwner(_caller) || _caller == loanContract,
            "not authorized"
        );
        _;
    }

    constructor(
        address[N_COINS] memory _tokens,
        address _rpToken,
        address _multiSig
    ) public {
     
        for(uint8 i=0; i<N_COINS; i++) {
            tokens[i] = Erc20(_tokens[i]);
        }
        multiSig= MultiSignatureInterface(_multiSig);
        rpToken = Erc20(_rpToken);
    }
    
    /* EVENTS */
    event userSupplied(
        address user,
        uint[N_COINS] amounts
    );

    event userRecieved(
        address user,
        uint[N_COINS] amounts
    );

    event userAddedToQ(
        address user,
        uint[N_COINS] amounts
    );

    /* INTERNAL FUNCTIONS */

    function getBalances() public view returns(uint256[N_COINS] memory) {
        uint256[N_COINS] memory balances;

        for(uint8 i=0; i<N_COINS; i++) {
            balances[i] = tokens[i].balanceOf(address(this));
        }

        return balances;
    }



    // functions related to deposit and supply

    // This function deposits the fund to Yield Optimizer
    function _deposit(uint256[N_COINS] memory amounts) internal {
        controller.deposit(amounts);
        
        for(uint8 i=0; i<N_COINS; i++) {
            YieldPoolBalance[i] += amounts[i];
        }
    }


    // functions related to withdraw, withdraw queue and withdraw from Yield Optimizer
    function _takeBack(address recipient) internal {
        bool result;

        uint256 burnAmt;

        burnAmt = calcRptAmount(amountWithdraw[recipient]);
        rpToken.burn(recipient, burnAmt);

        for(uint8 i=0; i<N_COINS; i++) {
            if(
                amountWithdraw[recipient][i] > 0 
                && 
                amountSupplied[recipient][i] > 0
            ) {
                uint temp = amountWithdraw[recipient][i] - (amountWithdraw[recipient][i] * fees) / 10000;
                result = tokens[i].transfer(
                    recipient,  
                    temp
                );
                require(result);
                amountSupplied[recipient][i] -= amountWithdraw[recipient][i];
                totalWithdraw[i] -= amountWithdraw[recipient][i];
                selfBalance[i] -= temp;
                uint x = amountWithdraw[recipient][i];
                for(uint8 j=0; j<supplyTime[recipient].length; j++) {
                    if(supplyTime[recipient][j].withdrawn[i] != true && x > 0) {
                        if(x >= supplyTime[recipient][j].remAmt[i]) {
                            x = x - supplyTime[recipient][j].remAmt[i];
                            supplyTime[recipient][j].remAmt[i] = 0;
                            supplyTime[recipient][j].withdrawn[i] = true;
                        }
                        else {
                            supplyTime[recipient][j].remAmt[i] -= x;
                            x = 0;
                        }
                    }
                }

                amountWithdraw[recipient][i] = 0;
   
            }
        }
        isInQ[recipient] = false;
        recipientCount -= 1;
    }




    // this will fulfill withdraw requests from the queue
    function _giveBack() internal {
        
        uint32 counter = recipientCount;
        for(uint8 i=0; i<counter; i++) {
            address recipient = getFromQ();
            _takeBack(recipient);
        }

    }





    // this will add unfulfilled withdraw requests to the queue
    function _takeBackQ(uint256[N_COINS] memory amounts) internal {
        
        for(uint256 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                amountWithdraw[msg.sender][i] += amounts[i];
                totalWithdraw[i] += amounts[i];
            }
        }

        if(isInQ[msg.sender] != true) {
            recipientCount += 1;
            isInQ[msg.sender] = true;
            addToQ(msg.sender);
        }

    }




    // this will withdraw from Yield Optimizer into this contract
    function _withdraw(uint256[N_COINS] memory amounts) internal {
        controller.withdraw(amounts);

        for(uint8 i=0; i<N_COINS; i++) {
            YieldPoolBalance[i] -= amounts[i];
        }
    }



    //This function calculate RPT to be mint or burn
    function calcRptAmount(uint256[N_COINS] memory amounts) public view returns(uint256) {
        uint256 rptAmt;
        uint256 total = 0;
        uint256 decimal = 0;
        uint256 totalSuppliedTokens;
        uint256 totalRPTSupply;

        totalRPTSupply = bdiv(rpToken.totalSupply(), 10**18);
      
        for(uint8 i=0; i<N_COINS; i++) {
            decimal = tokens[i].decimals();
            total += bdiv(selfBalance[i]+loanGiven[i], 10**decimal);
            totalSuppliedTokens += bdiv(amounts[i], 10**decimal);
        }
     
        rptAmt = bmul(bdiv(totalSuppliedTokens, total), totalRPTSupply);        

        return rptAmt;
    }



    //function to check available amount to withdraw for user
    function availableWithdraw(address addr, uint coin) public view returns(uint256) {

        uint256 amount=0;
        for(uint8 j=0; j<supplyTime[addr].length; j++) {
            if(
                ((now - supplyTime[addr][j].time) 
                > 
                (/*24 * 60 * 60 **/ lock_period))
                &&
                supplyTime[addr][j].withdrawn[coin] != true
            ) {
                amount += supplyTime[addr][j].remAmt[coin];
            }
        }

        return amount;
    }




    /* USER FUNCTIONS (exposed to frontend) */

    function supply(uint256[N_COINS] calldata amounts) external {
        require(
            calcRptAmount(amounts) > 0,
            "zero tokens supply"
        );
        
        uint256 mintTokens;        
        mintTokens = calcRptAmount(amounts);    
        
        bool result;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                result = tokens[i].transferFrom(
                    msg.sender, 
                    address(this), 
                    amounts[i]
                );
                require(result, "coin transfer failed");
                selfBalance[i] += amounts[i];
                amountSupplied[msg.sender][i] += amounts[i];
            }
        }
        rpToken.mint(msg.sender, mintTokens);
        bool[N_COINS] memory falseArray;
        depositDetails memory d = depositDetails(amounts, amounts, now, falseArray);
        supplyTime[msg.sender].push(d);

        emit userSupplied(msg.sender, amounts);
    }

    function requestWithdraw(uint256[N_COINS] calldata amounts) external {
        require(
            calcRptAmount(amounts) > 0,
            "zero tokens supply"
        );

        uint256 burnAmt;
        burnAmt = calcRptAmount(amounts);
        require(
            rpToken.balanceOf(msg.sender) >= burnAmt, 
            "low RPT"
        );
        
        uint256[N_COINS] memory poolBalance;
        poolBalance = getBalances();
        
        bool checkTime = true;
        bool instant;
        
        // check if user is withdrawing before lock period
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                if(availableWithdraw(msg.sender, i) < amounts[i]) {
                    checkTime = false;
                }
            }
        }
        require(checkTime, "lock period | not supplied");

        // check if instant withdraw
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] < poolBalance[i] && amounts[i] != 0) {
                instant = true;
            }
        }

        if(instant) {
            rpToken.burn(msg.sender, burnAmt);
            bool result;
            for(uint8 i=0; i<N_COINS; i++) {
                if(amounts[i] > 0) {
                    uint temp = amounts[i] - (amounts[i] * fees) / 10000;
                    result = tokens[i].transfer(msg.sender, temp);
                    require(result);
                    amountSupplied[msg.sender][i] -= amounts[i];
                    selfBalance[i] -= temp;
                    
                    uint x = amounts[i];
                    for(uint8 j=0; j<supplyTime[msg.sender].length; j++) {
                        if(supplyTime[msg.sender][j].withdrawn[i] != true && x > 0) {
                            if(x >= supplyTime[msg.sender][j].remAmt[i]) {
                                x = x - supplyTime[msg.sender][j].remAmt[i];
                                supplyTime[msg.sender][j].remAmt[i] = 0;
                                supplyTime[msg.sender][j].withdrawn[i] = true;
                            }
                            else {
                                supplyTime[msg.sender][j].remAmt[i] -= x;
                                x = 0;
                            }
                        }
                    }

                }
            }

            emit userRecieved(msg.sender, amounts);
        } else {
            _takeBackQ(amounts);

            emit userAddedToQ(msg.sender, amounts);
        }
    }
 
    // Following two functions are called by rLoan Only
    function _loanWithdraw(
        uint256[N_COINS] memory amounts, 
        address _loanSeeker
    ) public onlyAuthorized(msg.sender) returns(bool) {
        _withdraw(amounts);

        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                loanGiven[i] += amounts[i];
                selfBalance[i] -= amounts[i];
                tokens[i].transfer(_loanSeeker, amounts[i]);
            }
        }
        return true;
    }

    //Function only called by multisig contract for transfering tokens
    function _loanRepayment(
        uint256[N_COINS] memory amounts, 
        address _loanSeeker
    ) public onlyAuthorized(msg.sender) returns(bool) {
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                loanGiven[i] -= amounts[i];
                selfBalance[i] += amounts[i];
                tokens[i].transferFrom(_loanSeeker, address(this), amounts[i]);
            }
        }
        return true;
    }

    // this function deposits without minting RPT
    function depsoitInRoyale(uint256[N_COINS] calldata amounts) external {
        for(uint8 i=0;i<N_COINS;i++){
            if(amounts[i]!=0){
             tokens[i].transferFrom(msg.sender,address(this),amounts[i]);
             selfBalance[i]+=amounts[i];
            }
        }
    }


    /* CORE FUNCTIONS (called by owner only) */

    //Deposit in the smart backed pool
    function deposit() ownerExists(msg.sender) external {
        uint256[N_COINS] memory amounts = getBalances();
        uint256 decimal;

        rStrategyI[3] memory strat = controller.getStrategies();

        for(uint8 i=0; i<N_COINS; i++) {
            decimal = tokens[i].decimals();
            if(amounts[i] > thresholdTokenAmount*10**decimal) {
                amounts[i] += YieldPoolBalance[i];
                amounts[i] = (amounts[i] * poolPart) / 100;
                amounts[i] = amounts[i] - YieldPoolBalance[i];
                tokens[i].transfer(address(strat[i]), amounts[i]);
            }
            else {
                amounts[i] = 0;
            }
        }

        uint8 counter = 0;
        for(uint8 i=0; i<N_COINS; i++) {
           if(amounts[i] != 0) {
               counter++;
               break;
           }
        }

        if(counter > 0){
            _deposit(amounts);
        }
    }

    //Withdraw from Pool
    function withdraw() ownerExists(msg.sender) external {

        uint8 counter = 0;
        for(uint8 i=0; i<N_COINS; i++) {
           if(totalWithdraw[i] != 0) {
               counter++;
               break;
           }
        }

        require(counter > 0, "withdraw queue empty");

        _withdraw(totalWithdraw);
        _giveBack();
        resetQueue();
    }

    //function for rebalancing pool(ratio)      
    function rebalance() ownerExists(msg.sender) external {
        uint256[N_COINS] memory currentAmount = getBalances();
        uint256[N_COINS] memory amountToWithdraw;
        uint256[N_COINS] memory amountToDeposit;

        rStrategyI[3] memory strat = controller.getStrategies();

        for(uint8 i=0;i<N_COINS;i++) {
           uint256 decimal=tokens[i].decimals();
           uint256 a = (selfBalance[i] * (100 - poolPart)) / 100;
           if(a > currentAmount[i]) {
              amountToWithdraw[i] = a - currentAmount[i];
              if(amountToWithdraw[i]<(50*(10**decimal))){
                  amountToWithdraw[i]=0;
              }
           }
           else if(a < currentAmount[i]) {
               amountToDeposit[i] = currentAmount[i] - a;
               if(amountToDeposit[i]<(50*(10**decimal))){
                   amountToDeposit[i]=0;
               }
               else{
                  tokens[i].transfer(address(strat[i]), amountToDeposit[i]);
               }
           }
           else {
               amountToWithdraw[i] = 0;
               amountToDeposit[i] = 0;
           }
        }

        bool check=false;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amountToDeposit[i] > 0) {
                  check = true;
                  break;
            }
        }

        if(check){
             _deposit(amountToDeposit);
             check = false;
        }

        for(uint8 i=0; i<N_COINS; i++) {
            if(amountToWithdraw[i] > 0) {
                  check = true;
                  break;
            }
        }
        
        if(check) {
            _withdraw(amountToWithdraw);
             check = false;
        }

    }


    /* ADMIN FUNCTIONS */

    
    function getTotalPoolBalance() external view returns(uint256[3] memory) {
        return selfBalance;
    }

    function getTotalLoanGiven() external view returns(uint256[3] memory) {
        return loanGiven;
    }

    function setLoanContract(address _loanContract)external ownerExists(msg.sender)returns(bool){
        loanContract=_loanContract;
    }

    function changePoolPart(uint128 _newPoolPart) external ownerExists(msg.sender) returns(bool) {
        poolPart = _newPoolPart;
        return true;
    }

    function getYieldProfit() external ownerExists(msg.sender){
        profitFromYield=controller.getTotalProfit();

        for(uint8 i=0;i<N_COINS;i++){
            selfBalance[i] += profitFromYield[i];
        }
    }

    function setThresholdTokenAmount(uint256 _newThreshold) external ownerExists(msg.sender) returns(bool) {
        thresholdTokenAmount = _newThreshold;
        return true;
    }

    function setInitialDeposit() ownerExists(msg.sender) external returns(bool) {
        selfBalance = getBalances();
        return true;
    }

    function setController(rControllerI _controller)ownerExists(msg.sender) external returns(bool) {
        controller = _controller;
        return true;
    }

    function setLockPeriod(uint128 lockperiod) ownerExists(msg.sender) external returns(bool) {
        lock_period = lockperiod;
        return true;
    }

    function setWithdrawFees(uint128 _fees) ownerExists(msg.sender) external returns(bool) {
        fees = _fees;
        return true;
    }

}