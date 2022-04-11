// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TAFInvoice.sol";


contract TAFInvoiceFactory{

    address immutable public owner;
    mapping(address => bool) public isAdmin;
    mapping(string => uint256) public amountForOrder;
    mapping(string => address) public tokenForOrder;
    mapping(string => bool) public isOrderPaid;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    constructor(){
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    function createNewInvoice(address token, uint256 amount, string memory order_id) public{
        require(isAdmin[msg.sender], "Only admin can create an Invoice");
        require(!isOrderPaid[order_id], "The order is already paid");
        amountForOrder[order_id] = amount;
        tokenForOrder[order_id] = token;
    }


    function withdraw(uint256 amount, address reciver, address token) onlyOwner public{
        require(IERC20(token).balanceOf(address(this)) >= amount, "Amount is more then balance");
        IERC20(token).transfer(reciver, amount);
    }

    function pay(string memory order_id) public{
        require(!isOrderPaid[order_id], "The order is already paid");
        require(IERC20(tokenForOrder[order_id]).transferFrom(msg.sender, address(this), amountForOrder[order_id]));
        isOrderPaid[order_id] = true;
    }

    function addNewAdmin(address user) onlyOwner public{
        isAdmin[user] = true;
    }

    function removeAdmin(address user) onlyOwner public{
        isAdmin[user] = false;
    }

}