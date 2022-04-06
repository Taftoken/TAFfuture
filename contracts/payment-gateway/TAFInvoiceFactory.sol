// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TAFInvoice.sol";


contract TAFInvoiceFactory{

    address immutable public owner;
    mapping(address => bool) public isAdmin;
    mapping(uint256 => uint256) public amountForOrder;
    mapping(uint256 => address) public tokenForOrder;
    mapping(uint256 => bool) public isOrderPaid;

    constructor(){
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    function createNewInvoice(address token, uint256 amount, uint256 order_id) public{
        require(isAdmin[msg.sender], "Only admin can create an Invoice");
        require(!isOrderPaid[order_id], "The order is already paid");
        amountForOrder[order_id] = amount;
        tokenForOrder[order_id] = token;
    }


    function withdraw(uint256 amount, address reciver, address token) public{
        require(msg.sender == owner, "Only Owner Can Withdraw Tokens");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Amount is more then balance");
        IERC20(token).transfer(reciver, amount);
    }

    function pay(uint256 order_id) public{
        require(!isOrderPaid[order_id], "The order is already paid");
        require(IERC20(tokenForOrder[order_id]).transferFrom(msg.sender, address(this), amountForOrder[order_id]));
        isOrderPaid[order_id] = true;
    }

    function addNewAdmin(address user) public{
        require(msg.sender == owner, "Only Owner Can Add new admin");
        isAdmin[user] = true;
    }

    function removeAdmin(address user) public{
        require(msg.sender == owner, "Only Owner Can Add new admin");
        isAdmin[user] = false;
    }

}