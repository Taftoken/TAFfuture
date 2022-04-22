pragma solidity ^0.8;

import "../interface/IERC20.sol";
import "../libs/DateTime.sol";

contract TAFYearlyStaking{

    IERC20 public immutable rewardsToken;
    IERC20 public immutable stakingToken;

    uint256 public immutable lockingPeriodInYears;
    uint256 public totalSupply;
    uint256 public withdrawFee;
    uint256 public rollOverFee;
    uint256 public unstakePenalty;
    uint256 public maxTotalStakingAmount;
    uint256 public maxUserStakingAmount;
    uint256 public minUserStakingAmount;

    address public owner;
    address public charityAddress;

    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewardsOut;
    mapping(address => uint256) public timestamp;
    mapping(uint256 => uint256) public apyOnYear;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    constructor(address _stakingToken, address _rewardsToken, uint256 _lockingPeriodInYears){
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        lockingPeriodInYears = _lockingPeriodInYears;

        withdrawFee = 200;
        rollOverFee = 100;

        owner = msg.sender;
    }

    function setYearApy(uint256 year, uint256 _apy) onlyOwner public{
        apyOnYear[year] = _apy;
    }

    function updateUnstakePenalty(uint256 amount) onlyOwner public {
        unstakePenalty = amount;
    }

    function updateCharityAddress(address user) onlyOwner public{
        charityAddress = user;
    }

    function updateMaxStakingAmount(uint256 amount) onlyOwner public{
        maxTotalStakingAmount = amount;
    }

    function updateMinUserStakingAmount(uint256 amount) onlyOwner public{
        minUserStakingAmount = amount;
    }

    function updateMaxUserStakingAmount(uint256 amount) onlyOwner public{
        maxUserStakingAmount = amount;
    }

    function updateWithdrawFee(uint256 amount) onlyOwner public{
        withdrawFee = amount;
    }

    function updateRollOverFee(uint256 amount) onlyOwner public{
        rollOverFee = amount;
    }

    function updateOwner(address user) onlyOwner public{
        owner = user;
    }

    function togglePause() onlyOwner public{
        paused = !paused;
    }

    function depositRewardToken(uint256 _amount) public{
        rewardsToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawRewardToken(uint256 _amount) onlyOwner public{
        rewardsToken.transfer(msg.sender, _amount);
    }

    function timings() public view returns (uint256, uint256){
        return (timestamp[msg.sender], BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears));
    }

    function userInfo() public view returns (uint256, uint256, uint256, uint256){
        (uint256 start, uint256 end) = timings();
        return (balances[msg.sender], earned(), start, end);
    }

    function isForceUnstakeNeeded() public view returns(bool){
        return block.timestamp < BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears);
    }

    function stake(uint _amount) public{
        require(!paused, "Staking contract is paused!");

        if(minUserStakingAmount > 0)
            require(_amount >= minUserStakingAmount, "Must be above min user staking amount");

        if(maxUserStakingAmount > 0)
            require(balances[msg.sender] + _amount <= maxUserStakingAmount, "Must be less then max user staking amount");

        if(maxTotalStakingAmount > 0)
            require(totalSupply + _amount <= maxTotalStakingAmount, "Max Staking amount reached");

        if(balances[msg.sender] > 0){
            totalSupply += earned();
            balances[msg.sender] += earned();
        }
        
        totalSupply += _amount;
        balances[msg.sender] += _amount;

        safeTransferFrom(stakingToken, msg.sender, address(this), _amount);
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;
    }

    function unstake(uint256 _amount) public{
        require(block.timestamp > BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears), "Can only withdraw once the time is right");
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        uint256 fee = (_amount * withdrawFee)/10000;

        if(_amount > 0)
            safeTransfer(stakingToken, msg.sender, _amount - fee);

        if(fee > 0)
            safeTransfer(stakingToken, owner, fee);

        if(earned() > 0)
            safeTransfer(rewardsToken, msg.sender, earned());

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;
    }

    function forceUnstake(uint256 _amount) public{
        require(block.timestamp < BokkyPooBahsDateTimeLibrary.addYears(timestamp[msg.sender], lockingPeriodInYears), "Can only withdraw once the time is right");
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        uint256 minDiff =  BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp);

        uint256 fee = 0;

        if(unstakePenalty > 0)
            fee = (minDiff * unstakePenalty * _amount) / (lockingPeriodInYears * 52560000);

        if(earned() > 0)
            safeTransfer(rewardsToken, msg.sender, earned());

        if(_amount - fee > 0)
            safeTransfer(stakingToken, msg.sender, _amount - fee);

        if(fee > 0)
            safeTransfer(stakingToken, owner, fee);


        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;
    }

    function earned() public view returns(uint256){

        uint256 reward = 0;

        uint256 yearDiff = BokkyPooBahsDateTimeLibrary.diffYears(timestamp[msg.sender], block.timestamp);

        uint256 thisYearMinDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp) - (yearDiff * 525600);

        for(uint i = 1; i<= yearDiff; i++){
            reward += (apyOnYear[i] * balances[msg.sender]) / 10000;
        }

        if(thisYearMinDiff > 0)
            reward += (apyOnYear[yearDiff + 1] * balances[msg.sender] * thisYearMinDiff ) / (365 * 24 * 60 * 10000);

        return reward;
    }

    function withdrawReward(uint256 pAmount) public{

        require(pAmount + withdrawFee <= 10000, "Can only donate 100% of reward token");

        uint256 amount = earned();

        uint256 charity = 0;

        uint256 fee = (withdrawFee * amount) / 10000;

        if(pAmount > 0){
            charity = (pAmount * amount) / 10000;

        if(charity > 0)
            safeTransfer(rewardsToken, charityAddress, charity);

        }

        safeTransfer(rewardsToken, msg.sender, amount - (fee + charity));


        if(fee > 0)
            safeTransfer(rewardsToken, owner, fee);


        rewardsOut[msg.sender] += amount;
    }


    function safeTransfer(IERC20 token, address to, uint256 amount) private{
        uint256 maxTransfer = 100000 * (10 ** 18);

        uint256 quotient = amount / maxTransfer;
        uint256 remainder = amount - maxTransfer * quotient;

        for(uint i = 0; i < quotient; i++){
            token.transfer(to, maxTransfer);
        }

        if(remainder > 0)
            token.transfer(to, remainder);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) private{
        uint256 maxTransfer = 100000 * (10 ** 18);

        uint256 quotient = amount / maxTransfer;
        uint256 remainder = amount - maxTransfer * quotient;

        for(uint i = 0; i < quotient; i++){
            token.transferFrom(from, to, maxTransfer);
        }

        if(remainder > 0)
            token.transferFrom(from, to, remainder);
    }
}