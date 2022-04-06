// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TAFTokenVesting{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // ERC20 basic token contract being held
    IERC20 private immutable _token;

    // beneficiary of tokens after they are released
    address private immutable _beneficiary;


    constructor(address token_) {
        _token = IERC20(token_);
        _beneficiary = msg.sender;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

     
    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release(uint256 _amount) public virtual {
        require(msg.sender == _beneficiary, "You can not use this function");
        
        uint256 amount = token().balanceOf(address(this));
        
        require(amount >= _amount, "No tokens to release");

        token().safeTransfer(beneficiary(), _amount);
    }
}