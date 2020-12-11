// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './Interfaces/Erc20Interface.sol';
import './RoyaleLPstorage.sol';

contract multiSig is RoyaleLPstorage {

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
        require(msg.sender == owner);
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
        transactions[_loanID].approved = true;
        transactions[_loanID].remAmt = transactions[_loanID].tokenAmounts;
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
            setRequiredSignee(signees.length);
        }

        emit signeeRemoved(signee);
    } 
}