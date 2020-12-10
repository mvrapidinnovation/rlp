// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './MathLib.sol';

import './Erc20Interface.sol';
import './CurveInterface.sol';
import './RoyaleLPstorage.sol';
import './MultiSig.sol';

contract RoyaleLP is RoyaleLPstorage, multiSig, rNum {

    constructor(
        address[N_COINS] memory _tokens,
        address _rpToken
    ) public {
        // Set owner
        owner = msg.sender;

        for(uint8 i=0; i<N_COINS; i++) {
            tokens[i] = Erc20(_tokens[i]);
        }

        // Set RPT
        rpToken = Erc20(_rpToken);
    }
    
    /* INTERNAL FUNCTIONS */

    function _getBalances() internal view returns(uint256[N_COINS] memory) {
        uint256[N_COINS] memory balances;

        for(uint8 i=0; i<N_COINS; i++) {
            balances[i] = tokens[i].balanceOf(address(this));
        }

        return balances;
    }

    function _calcRptAmount(uint256[N_COINS] memory amounts, bool burn) internal view returns(uint256) {
        uint256 rptAmt;
        uint256 total = 0;
        uint256 decimal = 0;
        uint256 totalSuppliedTokens;
        uint256 totalRPTSupply;

        totalRPTSupply = bdiv(rpToken.totalSupply(), 10**18);
        
        for(uint8 i=0; i<N_COINS; i++) {
            decimal = tokens[i].decimals();
            total += bdiv(selfBalance[i], 10**decimal);
            totalSuppliedTokens += bdiv(amounts[i], 10**decimal);
        }

        rptAmt = bmul(bdiv(totalSuppliedTokens, total), totalRPTSupply);

        if(burn == true) {
            rptAmt = rptAmt + (rptAmt * fees) / 10000;
        }

        return rptAmt;
    }

    // functions related to deposit and supply

    // This function deposits the fund to 3POOL
    function _deposit(uint256[N_COINS] memory amounts) internal {
        yldOpt.deposit(amounts);
        
        for(uint8 i=0; i<N_COINS; i++) {
            YieldPoolBalance[i] += amounts[i];
        }
    }

    function _supply(uint256[N_COINS] memory amounts) internal {
        uint256 mintTokens;        
        mintTokens = _calcRptAmount(amounts, false);    
        
        bool result;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                result = tokens[i].transferFrom(
                    msg.sender, 
                    address(this), 
                    amounts[i]
                );
                require(result);
                selfBalance[i] += amounts[i];
                amountSupplied[msg.sender][i] += amounts[i];
            }
        }
    
        // rpToken.mint(msg.sender, mintTokens * 10**10);
        rpToken.mint(msg.sender, mintTokens);

        bool[N_COINS] memory falseArray;
        depositDetails memory d = depositDetails(amounts, amounts, now, falseArray);
        supplyTime[msg.sender].push(d);
    }

    // functions related to withdraw, withdraw queue and withdraw from curve pool

    function _takeBack(address recipient) internal {
        bool result;

        uint256 burnAmt;

        burnAmt = _calcRptAmount(amountWithdraw[recipient], true);
        rpToken.burn(recipient, burnAmt);

        for(uint8 i=0; i<N_COINS; i++) {
            if(
                amountWithdraw[recipient][i] > 0 
                && 
                amountSupplied[recipient][i] > 0
            ) {
                result = tokens[i].transfer(
                    recipient,  
                    amountWithdraw[recipient][i]
                );
                require(result);

                amountSupplied[recipient][i] -= amountWithdraw[recipient][i];
                totalWithdraw[i] -= amountWithdraw[recipient][i];
                selfBalance[i] -= amountWithdraw[recipient][i];

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

                isInQ[recipient] = false;
                recipientCount -= 1;
            }
        }
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
        yldOpt.withdraw(amounts);

        for(uint8 i=0; i<N_COINS; i++) {
            YieldPoolBalance[i] -= amounts[i];
        }
    }

    /* USER FUNCTIONS (exposed to frontend) */

    function supply(uint256[N_COINS] calldata amounts) external {
        require(
            _calcRptAmount(amounts, false) > 0,
            "tokens supplied cannot be zero"
        );
        
        _supply(amounts);
    }

    function requestWithdraw(uint256[N_COINS] calldata amounts) external {
        require(
            _calcRptAmount(amounts, false) > 0,
            "tokens requested cannot be zero"
        );

        uint256 burnAmt;
        burnAmt = _calcRptAmount(amounts, true);
        require(
            rpToken.balanceOf(msg.sender) >= burnAmt, 
            "Insufficient RPT"
        );
        
        uint256[N_COINS] memory poolBalance;
        poolBalance = _getBalances();

        uint256[N_COINS] memory availableWithdraw;
        
        bool checkTime = true;
        bool instant;
        
        // check if user is withdrawing before lock period
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                for(uint8 j=0; j<supplyTime[msg.sender].length; j++) {
                    if(
                        (now - supplyTime[msg.sender][j].time) 
                        > 
                        (0) // (24 * 60 * 60 * lock_period)
                        &&
                        supplyTime[msg.sender][j].withdrawn[i] != true
                    ) {
                        availableWithdraw[i] += supplyTime[msg.sender][j].remAmt[i];
                    }
                }

                if(availableWithdraw[i] < amounts[i]) {
                    checkTime = false;
                }
            }
        }
        require(checkTime, "cannot withdraw before lock period");

        // check if instant withdraw
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] < poolBalance[i]) {
                instant = true;
            }
        }

        if(instant) {
            rpToken.burn(msg.sender, burnAmt);
            bool result;
            for(uint8 i=0; i<N_COINS; i++) {
                if(amounts[i] > 0) {
                    result = tokens[i].transfer(msg.sender, amounts[i]);
                    require(result);
                    selfBalance[i] -= amounts[i];
                }
            }
        } else {
            _takeBackQ(amounts);
        }
    }

    function withdrawLoan( 
        uint256[N_COINS] calldata amounts,
        uint _loanID
    ) external {

        require(transactions[_loanID].iGamingCompany == msg.sender, "company not-exist");
        require(transactions[_loanID].approved, "not approved for loan");
        
        for(uint8 i=0; i<N_COINS; i++) {
            require(
                transactions[_loanID].remAmt[i] >= amounts[i], 
                "amount requested exceeds amount approved"
            );
        }

        _withdraw(amounts);

        uint8 check = 0;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                tokens[i].transfer(msg.sender, amounts[i]);
                transactions[_loanID].remAmt[i] -= amounts[i];
            }

            if(transactions[_loanID].remAmt[i] == 0) {
                check++;
            }
        }

        if(check == 3) {
            // Loan fulfilled, company used all its loan
            transactions[_loanID].executed = true;
            gamingCompanyRepayment[_loanID] = Repayment({
                  transactionID: _loanID,
                  isRepaymentDone: false,
                  remainingTokenAmounts: transactions[_loanID].tokenAmounts
            });
        }
    }

    function repayLoan(
        uint256[N_COINS] calldata _amounts, 
        uint _loanId
    ) external {
        require(_loanId <= transactionCount, "Enter Valid ID");
        require(transactions[_loanId].iGamingCompany == msg.sender, "not a valid user");
        require(!gamingCompanyRepayment[_loanId].isRepaymentDone, "repayment done");
        
        uint counter = 0;
        for(uint i=0; i<N_COINS; i++) {
            if(_amounts[i]!=0) {
                tokens[i].transferFrom(
                    msg.sender,
                    address(this),
                    _amounts[i]
                );
                gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] -= _amounts[i];
                
                if(gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] == 0) {
                    counter++;
                }
            }
        }

        if(counter == 3){
            gamingCompanyRepayment[_loanId].isRepaymentDone=true;
        }       
    }

    /* Some utility functions for front-end */

    function checkMintAmount(uint256[N_COINS] calldata amounts) external view returns(uint256) {
        uint256 result = _calcRptAmount(amounts, false);
        return result;
    }

    function checkBurnAmount(uint256[N_COINS] calldata amounts) external view returns(uint256) {
        uint256 result = _calcRptAmount(amounts, true);
        return result;
    }


    /* CORE FUNCTIONS (also exposed to frontend but to be called by owner only) */

    function deposit() onlyOwner external {
        uint256[N_COINS] memory amounts = _getBalances();
        uint256 decimal;

        for(uint8 i=0; i<N_COINS; i++) {
            decimal = tokens[i].decimals();
            if(amounts[i] > thresholdTokenAmount*10**decimal) {
                amounts[i] += YieldPoolBalance[i];
                amounts[i] = (amounts[i] * poolPart) / 100;
                amounts[i] = amounts[i] - YieldPoolBalance[i];
                tokens[i].transfer(address(yldOpt), amounts[i]);
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

    function withdraw() onlyOwner external {

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
    }

    /* ADMIN FUNCTIONS */

    function changePoolPart(uint128 _newPoolPart) external onlyOwner {
        poolPart = _newPoolPart;
    }

    function setThresholdTokenAmount(uint256 _newThreshold) external onlyOwner {
        thresholdTokenAmount = _newThreshold;
    }

    function setInitialDeposit() onlyOwner external {
        selfBalance = _getBalances();
    }

    function setYieldOpt(IYieldOpt _yldOpt) onlyOwner external {
        yldOpt = _yldOpt;
    }

}