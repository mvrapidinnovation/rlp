// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './Interfaces/Erc20Interface.sol';
import './Interfaces/RoyaleInterface.sol';


contract multiSig {
    uint8 constant N_COINS = 3;
    
    Erc20[N_COINS] tokens;

    uint constant public MAX_SIGNEE_COUNT = 50;
    
    mapping(uint256 => Transaction) public transactions;
    mapping(address => mapping (uint256 => bool)) public confirmations;
    mapping(uint256 => Repayment) gamingCompanyRepayment;
    mapping(address => bool) public isSignee;
  
    mapping(address => uint[]) takenLoan;
    address[] public signees;
    uint256 public transactionCount = 0;
   
    uint256 public required;

    RoyaleInterface public royale;

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
        address signee,
        uint loanID
    );

    event approved(
        uint loanID
    );

    event addedRequiredSignee(
        address adder,
        uint numberOfSignees
    );

    event signeeAdded(
        address signee
    );

    event signeeRemoved(
        address signee
    );

    /* Modifiers */

    modifier onlyOwner {
        require(msg.sender == ownerAddress);
        _;
    }

    modifier signeeExists(address signee) {
        require(isSignee[signee]);
        _;
    }

    modifier transactionExists(uint _loanID) {
        require(_loanID > 0 && _loanID <= transactionCount);
        _;
    }

    modifier notConfirmed(address addr,uint _loanID) {
        require(!confirmations[addr][_loanID]);
        _;
    }

    modifier validRequirement(uint signeeCount, uint _required) {
        require(signeeCount <= MAX_SIGNEE_COUNT
            && _required <= signeeCount
            && _required != 0
            && signeeCount != 0);
        _;
    }


constructor( address[N_COINS] memory _tokens , address _royale)public{
        ownerAddress=msg.sender;
        // Set Tokens supported by Pool
        for(uint8 i=0; i<N_COINS; i++) {
            tokens[i] = Erc20(_tokens[i]);
            royale=RoyaleInterface(_royale);
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
        uint256[N_COINS] memory am=royale.getCurrentPoolBalance();
         for(uint8 i=0;i<N_COINS;i++){
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
        for (uint i=0; i<signees.length; i++) {
            if (confirmations[signees[i]][_loanID])
                count += 1;
            if (count == required && transactions[_loanID].isGamingCompanySigned)
                return true;
        }
    }

  

    /* USER FUNCTIONS (exposed to frontend) */

    // Gaming platforms withdraw using this
    function requestLoan(
        uint256[N_COINS] calldata amounts
    ) external returns(uint256) {
       require(signees.length >= required, "insufficient signees");
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

    

    function getTransactionDetail(
        uint _loanID
    ) public view returns(Transaction memory){
        return transactions[_loanID];
    }

    function checkLoanApproved(uint _loanID) external view returns(bool) {
        return transactions[_loanID].approved;
    }

    /* Admin Function */
    
    function setRequiredSignee(
        uint _required
    ) public onlyOwner validRequirement(signees.length, _required) {
        required = _required;

        emit addedRequiredSignee(msg.sender, required);
    }

    function addSignee(address signee) public onlyOwner {
        isSignee[signee] = true;
        signees.push(signee);

        emit signeeAdded(signee);
    }
    
    function removeSignee(address signee) public onlyOwner signeeExists(signee) {
        isSignee[signee] = false;
        for (uint i=0; i<signees.length - 1; i++) {
            if (signees[i] == signee) {
                signees[i] = signees[signees.length - 1];
                break;
            }
        }
        
        if (required > signees.length) {
            required--;
        }

        emit signeeRemoved(signee);
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
        bool b= royale._loanWithdraw(amounts,transactions[_loanID].iGamingCompany);
        require(b,"Loan Withdraw not succesfull");
        uint8 check = 0;
        for(uint8 i=0; i<N_COINS; i++) {
            if(amounts[i] > 0) {
            totalLoanTaken[i] +=amounts[i];
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
    
    
    function repaymentOfLoan(uint _loanId,uint256[N_COINS] calldata _amounts) external {
            require(_loanId<=transactionCount, "Enter Valid ID");
            require(transactions[_loanId].iGamingCompany==msg.sender, "you have not taken this loan");
            require(!gamingCompanyRepayment[_loanId].isRepaymentDone, "Already Repayment done");
            

            bool b= royale._loanRepayment(_amounts,transactions[_loanId].iGamingCompany);
            require(b,"Loan Payment not succesfull");
            uint counter=0;
            for(uint i=0;i<N_COINS;i++) {
                if(_amounts[i]!=0) {
                    totalLoanTaken[i] -=_amounts[i];
                    totalApprovedLoan[i]-=_amounts[i];
                    gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] -= _amounts[i];
                    if(gamingCompanyRepayment[_loanId].remainingTokenAmounts[i] == 0) {
                        counter++;
                    }
                }
            }

            if(counter==3){
                gamingCompanyRepayment[_loanId].isRepaymentDone=true;
            }       
    }
    
   

   /* functions for UI */

    function getTotalTakenLoan(uint8 _number)public view returns(uint){
        return totalLoanTaken[_number];
    }

    function getTotalApprovedLoan(uint8 _number)public view returns(uint){
        return totalApprovedLoan[_number];
    }
}