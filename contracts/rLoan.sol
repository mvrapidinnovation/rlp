// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import '../Interfaces/Erc20Interface.sol';
import '../Interfaces/RoyaleInterface.sol';
import './MathLib.sol';
import '../Interfaces/MultisigInterface.sol';


contract rLoan is rNum{
    uint8 constant N_COINS = 3;
    
    Erc20[N_COINS] tokens;

    
    
    mapping(uint256 => Transaction) public transactions;
    mapping(address => mapping (uint256 => bool)) public confirmations;
    mapping(uint256 => Repayment) public gamingCompanyRepayment;
   
  
    mapping(address => uint[])public takenLoan;
    
    uint256 public transactionCount = 0;
   
    RoyaleInterface public royale;

     MultiSignatureInterface public multiSig;

    address public ownerAddress;

    uint256[N_COINS] public totalLoanTaken;
    uint256[N_COINS] public totalApprovedLoan;
    
    struct Transaction {
        uint256 transactionId;
        address iGamingCompany;
        bool isGamingCompanySigned;
        uint256[N_COINS] tokenAmounts;
        uint256[N_COINS] remAmt;
        bool approved;
        bool executed;
    }

    struct Repayment {
        uint256 transactionID;
        bool isRepaymentDone;
        uint256[N_COINS] remainingTokenAmounts;
    }


    /* Events */

    event loanRequested(
        address by,
        uint[N_COINS] amounts,
        uint loanID
    );

    event signed(
        address owner,
        uint loanID
    );

    event approved(
        uint loanID
    );

   

    

    event loanWithdrawn(
        address by,
        uint[N_COINS] requestedAmount,
        uint[N_COINS] remainingAmount,
        uint loanID
    );

    event loanFulfilled(
        address by,
        uint[N_COINS] requestedAmount,
        uint[N_COINS] remainingAmount,
        uint loanID
    );

    event loanRepayed(
        address by,
        uint[N_COINS] repayedAmount,
        uint[N_COINS] amountRemaining,
        uint loanID
    );

    event wholeLoanRepayed(
        address by,
        uint[N_COINS] repayedAmount,
        uint[N_COINS] amountRemaining,
        uint loanID
    );

    /* Modifiers */

    modifier onlyOwner {
        require(msg.sender == ownerAddress);
        _;
    }

    

    modifier transactionExists(uint _loanID) {
        require(_loanID > 0 && _loanID <= transactionCount);
        _;
    }

    modifier signeeExists(address signee) {
        require(multiSig.checkOwner(signee),"signee not exist");
        _;
    }

   

    modifier notConfirmed(address addr,uint _loanID) {
        require(!confirmations[addr][_loanID],"ALready confirmed");
        _;
    }


   


    constructor(address[N_COINS] memory _tokens , address _royale,address _multiSig) public {
        ownerAddress = msg.sender;
         multiSig=MultiSignatureInterface(_multiSig);
         royale = RoyaleInterface(_royale);
        // Set Tokens supported by Pool

        for(uint8 i=0; i<N_COINS; i++) {
            tokens[i] = Erc20(_tokens[i]);
           
        }
    }

    /* Internal Functions */

    function _addTransaction(
       uint256[N_COINS] memory amounts
    ) internal {
        uint256[N_COINS] memory zero;

        transactionCount++;
        transactions[transactionCount] = Transaction({
            transactionId: transactionCount,
            iGamingCompany: msg.sender,
            tokenAmounts: amounts,
            remAmt: zero,
            isGamingCompanySigned: false,
            approved: false,
            executed: false
        });
        
    }

    function _approveLoan(uint _loanID) internal {
        uint256[N_COINS] memory am=royale.getTotalPoolBalance();
        for(uint8 i=0;i<N_COINS;i++) {
            require(totalApprovedLoan[i]+transactions[_loanID].tokenAmounts[i]<am[i],"Can not approve that much amount");
        }

        transactions[_loanID].approved = true;
        transactions[_loanID].remAmt = transactions[_loanID].tokenAmounts;

        for(uint8 i=0;i<N_COINS;i++){
            totalApprovedLoan[i] +=transactions[_loanID].tokenAmounts[i];
        }
        takenLoan[transactions[_loanID].iGamingCompany].push(_loanID);
    }

     function _isConfirmed(
        uint _loanID
    ) internal view returns (bool) {
        uint count = 0;
        for (uint i=0; i<multiSig.getNumberOfOwner(); i++) {
            if (confirmations[multiSig.getOwner(i)][_loanID])
                count += 1;
            if (count == multiSig.getRequired() && transactions[_loanID].isGamingCompanySigned)
                return true;
        }
    }

  
    /* USER FUNCTIONS (exposed to frontend) */

    // Gaming platforms withdraw using this
    function requestLoan(
        uint256[N_COINS] calldata amounts
    ) external  {
     
       _addTransaction(amounts);

       emit loanRequested(msg.sender, amounts, transactionCount);
    }
    
    
    // Gaming Platforms signs using this
    function signTransaction(uint _loanID) public {
        require(transactions[_loanID].iGamingCompany == msg.sender);
        
        transactions[_loanID].isGamingCompanySigned = true;

        emit signed(msg.sender, _loanID);

        if(_isConfirmed(_loanID)) {
           _approveLoan(_loanID);
           emit approved(_loanID);
        }
    }
    
   // Signee signs using this
    function confirmLoan(uint _loanID) public
        signeeExists(msg.sender)
        transactionExists(_loanID)
        notConfirmed( msg.sender,_loanID) 
    {
        confirmations[msg.sender][_loanID] = true;
        
        emit signed(msg.sender, _loanID);

        if(_isConfirmed(_loanID)) {
           _approveLoan(_loanID);
           emit approved(_loanID);
        }
    }

    function checkLoanApproved(uint _loanID) external view returns(bool) {
        return transactions[_loanID].approved;
    }

    /* Admin Function */
    
   

    function withdrawLoan( 
        uint256[N_COINS] calldata amounts,
        uint _loanID
    ) external {

        require(transactions[_loanID].iGamingCompany == msg.sender, "company not-exist");
        require(transactions[_loanID].approved, "not approved for loan");
        uint256[N_COINS] memory loanAmount;
        for(uint8 i=0; i<N_COINS; i++) {
            require(
                transactions[_loanID].remAmt[i] >= amounts[i], 
                "amount requested exceeds amount approved"
            );
        }
        bool b = royale._loanWithdraw(amounts,transactions[_loanID].iGamingCompany);
        require(b, "Loan Withdraw not succesfull");

        uint8 check = 0;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
                totalLoanTaken[i] += amounts[i];
                transactions[_loanID].remAmt[i] =bsub(transactions[_loanID].remAmt[i], amounts[i]);
                loanAmount[i]=badd(gamingCompanyRepayment[_loanID].remainingTokenAmounts[i],amounts[i]);
            }
            if(transactions[_loanID].remAmt[i] == 0) {
                check++;
            }
        }
        gamingCompanyRepayment[_loanID] = Repayment({
                  transactionID: _loanID,
                  isRepaymentDone: false,
                  remainingTokenAmounts: loanAmount
        });


        emit loanWithdrawn(msg.sender, amounts, transactions[_loanID].remAmt, _loanID);

        if(check == 3) {
            // Loan fulfilled, company used all its loan
            transactions[_loanID].executed = true;
        }
    } 
    
    
    function repayLoan(uint256[N_COINS] calldata _amounts, uint _loanId) external {
        require(_loanId <= transactionCount, "invalid loan id");
        require(transactions[_loanId].iGamingCompany == msg.sender, "company not-exist");
        require(!gamingCompanyRepayment[_loanId].isRepaymentDone, "already repaid");
        for(uint8 i=0;i<N_COINS;i++){
            require(_amounts[i]<=gamingCompanyRepayment[_loanId].remainingTokenAmounts[i],"Don't have that much of remaining repayment");
        }
        bool b = royale._loanRepayment(_amounts,transactions[_loanId].iGamingCompany);
        require(b,"Loan Payment not succesfull");
        uint counter=0;
        for(uint i=0;i<N_COINS;i++) {
            if(_amounts[i]!=0) {
                totalLoanTaken[i] =bsub(totalLoanTaken[i],_amounts[i]);
                totalApprovedLoan[i]=bsub(totalApprovedLoan[i],_amounts[i]);
                gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] =bsub(gamingCompanyRepayment[_loanId].remainingTokenAmounts[i], _amounts[i]);
                if(gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] == 0) {
                    counter++;
                }
            }
        }

        emit loanRepayed(
            msg.sender,
            _amounts, 
            gamingCompanyRepayment[_loanId].remainingTokenAmounts,
            _loanId
        );

            if(counter==3){
                gamingCompanyRepayment[_loanId].isRepaymentDone=true;

                emit wholeLoanRepayed(
                    msg.sender,
                    _amounts, 
                    gamingCompanyRepayment[_loanId].remainingTokenAmounts,
                    _loanId
                );
            }       
    }

     function setMultiSig(address _multiSig)external onlyOwner{
        multiSig=MultiSignatureInterface(_multiSig);
    }
    
}