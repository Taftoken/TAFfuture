pragma solidity ^0.8;

import "../../interface/IERC20.sol";
import "../../libs/DateTime.sol";

//counter address for number of restaking

contract TAFFlexibleStaking {

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint256 public apy;
    uint256 public totalSupply;
    uint256 public stakingFee;
    uint256 public rewardFee;
    uint256 public rollOverFee;
    uint256 public maxTotalStakingAmount;
    uint256 public maxUserStakingAmount;
    uint256 public minUserStakingAmount;
    uint256 public totalActiveUsers;

    address public owner;
    address public charityAddress;

    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewardsOut;
    mapping(address => uint256) public timestamp;
    mapping(address => uint256) public userStartedAt;
    mapping(address => bool) public isUserActive;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    constructor(uint256 _apy, address _stakingToken, address _rewardsToken){
        apy = _apy;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);

        stakingFee = 200;
        rollOverFee = 100;

        charityAddress = 0x4cede0F5CD88e3b01E30A5edf5503EE7B3d84Cde;
        owner = msg.sender;
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

    function updateAPY(uint256 _apy) onlyOwner public{
        apy = _apy;
    }

    function togglePause() onlyOwner public{
        paused = !paused;
    }

    function updateCharityAddress(address user) onlyOwner public{
        charityAddress = user;
    }

    function updateRewardFee(uint256 amount) onlyOwner public{
        rewardFee = amount;
    }

    function isForceUnstakeNeeded() public view returns(bool){
        return BokkyPooBahsDateTimeLibrary.diffHours(timestamp[msg.sender], block.timestamp) > 24;
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
        
        uint256 fee = (_amount * stakingFee) / 10000;
        
        totalSupply += _amount - fee;
        balances[msg.sender] += _amount - fee;

        safeTransferFrom(stakingToken, msg.sender, address(this), _amount);

        if(fee > 0)
            safeTransfer(stakingToken, owner, fee);

        timestamp[msg.sender] = block.timestamp;
        userStartedAt[msg.sender] = block.timestamp;
        rewardsOut[msg.sender] = 0;

        if(!isUserActive[msg.sender]){
            totalActiveUsers++;
            isUserActive[msg.sender] = true;
        }
    }

    function unstake(uint256 _amount) public{
        require(BokkyPooBahsDateTimeLibrary.diffHours(timestamp[msg.sender], block.timestamp) > 24, "Can only withdraw after 24 hours");
        
        require(balances[msg.sender] >= _amount, "Not have enough balance");

        if(_amount > 0)
            safeTransfer(stakingToken, msg.sender, _amount);


        if(earned() > 0)
            safeTransfer(rewardsToken, msg.sender, earned());

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        timestamp[msg.sender] = block.timestamp;

        if(balances[msg.sender] == 0){
            totalActiveUsers--;
            isUserActive[msg.sender] = false;
        }
    }

    function forceUnstake(uint256 _amount) public{
        unstake(_amount);
    }

    function compound() public{

        uint256 fee = (earned() * rollOverFee)/10000;

        if(fee > 0)
            safeTransfer(rewardsToken, owner, fee);

        uint256 afterFee = earned() - fee;
        
        totalSupply += afterFee;
        balances[msg.sender] += afterFee;
        timestamp[msg.sender] = block.timestamp;
    }


    function withdrawReward(uint256 pAmount) public{

        require(pAmount + rewardFee <= 10000, "Can only donate 100% of reward token");

        uint256 amount = earned();
        uint256 charity = 0;

        uint256 fee = (rewardFee * amount) / 10000;

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


    function earned() public view returns(uint256){

        uint256 dayDiff = BokkyPooBahsDateTimeLibrary.diffMinutes(timestamp[msg.sender], block.timestamp );

        uint256 reward = (apy * balances[msg.sender] * dayDiff ) / (365 * 24 * 60 * 10000);

        return reward - rewardsOut[msg.sender];
    }



    function depositRewardToken(uint256 _amount) public{
        safeTransferFrom(rewardsToken, msg.sender, address(this), _amount);
    }

    function withdrawRewardToken(uint256 _amount) onlyOwner public{
        safeTransfer(rewardsToken, msg.sender, _amount);
    }

    function timings() public view returns (uint256, uint256){
        uint256 oneDay = timestamp[msg.sender] + 1 days;
        return (timestamp[msg.sender], oneDay < block.timestamp ? oneDay : block.timestamp);
    }

    function userInfo() public view returns (uint256, uint256, uint256, uint256){
        (uint256 start, uint256 end) = timings();
        return (balances[msg.sender], earned(), start, end);
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