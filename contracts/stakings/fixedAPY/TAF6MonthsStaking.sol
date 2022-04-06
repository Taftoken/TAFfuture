pragma solidity ^0.8;

import "../../interface/IERC20.sol";
import "../../libs/DateTime.sol";

//counter address for number of restaking

contract TAF7DaysStaking {

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint256 public apy;
    uint256 public totalSupply;
    uint256 public withdrawFee;
    uint256 public rollOverFee;
    uint256 public maxTotalStakingAmount;

    address public owner;

    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public timestamp;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    modifier onlyAfter6Months {
      require(BokkyPooBahsDateTimeLibrary.diffDays(timestamp[msg.sender], block.timestamp ) >= 190);
      _;
   }

    constructor(uint256 _apy, address _stakingToken, address _rewardsToken, uint256 _maxTotalStakingAmount){
        apy = _apy;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        maxTotalStakingAmount = _maxTotalStakingAmount;

        withdrawFee = 200;
        rollOverFee = 100;

        owner = msg.sender;
    }

    function updateMaxStakingAmount(uint256 amount) onlyOwner public{
        maxTotalStakingAmount = amount;
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

    function updateAPY(uint256 _apy) onlyOwner public{
        apy = _apy;
    }

    function togglePause() onlyOwner public{
        paused = !paused;
    }

    function stake(uint _amount) public{
        require(!paused, "Staking contract is paused!");

        if(maxTotalStakingAmount > 0)
            require(totalSupply + _amount <= maxTotalStakingAmount, "Max Staking amount reached");
        
        totalSupply += _amount;
        balances[msg.sender] += _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        timestamp[msg.sender] = block.timestamp;
    }

    function unstake() public{
        require(BokkyPooBahsDateTimeLibrary.diffHours(timestamp[msg.sender], block.timestamp) > 24, "Can only withdraw after 24 hours");
        
        uint256 _amount = balances[msg.sender];
        uint256 fee = (_amount * withdrawFee)/10000;

        if(_amount > 0)
            stakingToken.transfer(msg.sender, _amount - fee);

        if(fee > 0)
            stakingToken.transfer(owner, fee);

        if(earned() > 0)
            rewardsToken.transfer(msg.sender, earned());

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = 0;
    }


    function earned() public view returns(uint256){

        uint256 dayDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp );

        if(dayDiff > 183 * 24 * 60){
            dayDiff = 183 * 24 * 60;
        }

        uint256 reward = (apy * balances[msg.sender] * dayDiff ) / (365 * 24 * 60 * 10000);

        return reward;
    }


    function depositRewardToken(uint256 _amount) public{
        rewardsToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawRewardToken(uint256 _amount) onlyOwner public{
        rewardsToken.transfer(msg.sender, _amount);
    }

    function timings() public view returns (uint256, uint256){
        return (timestamp[msg.sender], timestamp[msg.sender] + 190 days);
    }
}