// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IERC20.sol";
import "./libs/DateTime.sol";

contract TAFTokenVesting{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BokkyPooBahsDateTimeLibrary for uint;

    // ERC20 basic token contract being held
    IERC20 private immutable _token;

    // beneficiary of tokens after they are released
    address private immutable _beneficiary;

    // timestamp when token release is enabled
    uint256 private _nextReleaseTime;
    
    //number of terms periods
    uint256 private _termsToGo;
    
    //seconds for a month
    uint256 constant internal _aMonth = 2629743;

    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 nextReleaseTime_,
        uint256 termsToGo_
    ) {
        require(nextReleaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
        _token = token_;
        _beneficiary = beneficiary_;
        _nextReleaseTime = nextReleaseTime_;
        _termsToGo = termsToGo_;
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
    function nextReleaseTime() public view virtual returns (uint256) {
        return _nextReleaseTime;
    }
    
    /**
     * @return how many terms to go to finalized vesting.
     */
     function termsToGo() public view virtual returns (uint256) {
         return _termsToGo;
     }
     
     function tokensToBeReleasedOnNexReleaseDate() public view virtual returns (uint256) {
         return token().balanceOf(address(this)).div(_termsToGo);
     }
     
     function addMonths(uint timestamp, uint _months) internal pure returns (uint newTimestamp) {
        newTimestamp = BokkyPooBahsDateTimeLibrary.addMonths(timestamp, _months);
    }
     
    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        require(block.timestamp >= nextReleaseTime(), "TokenTimelock: current time is before release time");
        
        uint256 amount = token().balanceOf(address(this)).div(_termsToGo);
        
        require(amount > 0, "TokenTimelock: no tokens to release");

        token().safeTransfer(beneficiary(), amount);
        
        _nextReleaseTime = addMonths(_nextReleaseTime, 1);
        _termsToGo = _termsToGo.sub(1);
        
        if(_termsToGo == 0)
        { 
            _nextReleaseTime = 0; 
        }
    }
}