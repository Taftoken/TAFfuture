// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libs/DateTime.sol";

contract TAFTokenVesting{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BokkyPooBahsDateTimeLibrary for uint;

    // ERC20 basic token contract being held
    IERC20 private immutable _token;

    // timestamp when token release is enabled
    uint256 private _releaseDate;

    // beneficiary of tokens after they are released
    address private immutable _beneficiary;


    constructor(address token_) {
        _token = IERC20(token_);
        _beneficiary = msg.sender;
        _releaseDate = BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, 8);
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
     * @return the time when the tokens are released.
     */
    function releaseTime() public view virtual returns (uint256) {
        return _releaseDate;
    }

     
    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        require(block.timestamp >= _releaseDate, "TokenTimelock: current time is before release time");
        require(msg.sender == _beneficiary, "You can not use this function");
        
        uint256 amount = token().balanceOf(address(this));
        
        require(amount > 0, "No tokens to release");

        token().safeTransfer(beneficiary(), amount);
    }
}