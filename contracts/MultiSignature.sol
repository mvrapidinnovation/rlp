// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract MultiSig{
    uint8 constant public MAX_OWNER_COUNT = 50;

    mapping(address => bool) isOwner;
    address[]  owners;
    uint8  required;

    event ownerAdded(
        address owner
    );

    event ownerRemoved(
        address owner
    );

    event addedRequiredowner(
        address adder,
        uint numberOfowners
    );

    modifier ownerExists(address owner) {
        require(isOwner[owner],"owner not exist");
        _;
    }
    
    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner],"owner already added");
        _;
    }
    
     modifier notNull(address _address) {
        require(_address != address(0));
        _;
    }

     modifier validRequirement(uint ownerCount, uint8 _required) {
        require(ownerCount <=MAX_OWNER_COUNT
            && _required <= ownerCount
            && ownerCount != 0,"Not sufficient owners");
        _;
    }

    modifier ZeroOwner(uint ownerCount){
        require(ownerCount!=0,"owner can not be zero");
        _;
    }

      modifier ZeroRequired(uint8 _required){
        require(_required!=0,"requirement can not be zero");
        _;
    }

    constructor() public{
        isOwner[msg.sender] = true;
        owners.push(msg.sender);
    }

    function setRequiredowner(
        uint8 _required
    ) public ownerExists(msg.sender) ZeroRequired(_required) validRequirement(owners.length, _required) {
        required = _required;

        emit addedRequiredowner(msg.sender, required);
    }

   
    function addowner(address owner)
    public
    ownerDoesNotExist(owner) 
    ownerExists(msg.sender)
    validRequirement(owners.length + 1, required)
    notNull(owner)
    {
    
        isOwner[owner] = true;
        owners.push(owner);
        emit ownerAdded(owner);
    }
    
    function removeowner(address owner) 
    public 
    ownerExists(msg.sender) 
    ownerExists(owner) 
    ZeroOwner(owners.length - 1)
    {
        
        isOwner[owner] = false;
        for (uint i=0; i<owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
        
        if (required > owners.length) {
            required--;
        }

        emit ownerRemoved(owner);
    } 
    
    function checkOwner(address owner)public view returns(bool){
        return isOwner[owner];
    }
    
    function getRequired()public view returns(uint8){
        return required;
    }
    
    function getNumberOfOwner()public view returns(uint){
        return owners.length;
    }
    
    function getOwner(uint _index)public view returns(address){
        return owners[_index];
    }
}