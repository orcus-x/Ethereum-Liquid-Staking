// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingDelegate is ReentrancyGuard, Ownable {
    mapping(address => uint256) private _delegatedAmounts;
    mapping(address => uint256) private _rewards;
    uint256 private _totalStaked;
    uint256 private _rewardRate = 100; // 1% per year, adjust as needed
    mapping (address => uint256) private lastUpdateTime;

    event Delegated(address indexed delegator, uint256 amount);
    event Undelegated(address indexed delegator, uint256 amount);
    event Withdrawn(address indexed delegator, uint256 amount);
    event RewardsClaimed(address indexed delegator, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function getDelegatedAmount(address _address) external view returns (uint256) {
        return _delegatedAmounts[_address];
    }

    function delegate() external payable nonReentrant returns (bool success) {
        require(msg.value > 0, "Must delegate a non-zero amount");
        _delegatedAmounts[msg.sender] += msg.value;
        _totalStaked += msg.value;
        lastUpdateTime[msg.sender] = block.timestamp;
        emit Delegated(msg.sender, msg.value);
        return true;
    }

    function undelegate(uint256 amount) external nonReentrant returns (bool success) {
        require(_delegatedAmounts[msg.sender] >= amount, "Insufficient delegated amount");
        _delegatedAmounts[msg.sender] -= amount;
        _totalStaked -= amount;
        lastUpdateTime[msg.sender] = block.timestamp;
        emit Undelegated(msg.sender, amount);
        return true;
    }

    function withdraw() external nonReentrant returns (bool success) {
        uint256 amount = _delegatedAmounts[msg.sender];
        require(amount > 0, "No funds to withdraw");
        _delegatedAmounts[msg.sender] = 0;
        _totalStaked -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
        lastUpdateTime[msg.sender] = block.timestamp;
        emit Withdrawn(msg.sender, amount);
        return true;
    }

    function claimRewards() external nonReentrant returns (bool success) {
        uint256 reward = calculateRewards(msg.sender);
        require(reward > 0, "No rewards to claim");
        _rewards[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: reward}("");
        require(sent, "Failed to send rewards");
        lastUpdateTime[msg.sender] = block.timestamp;
        emit RewardsClaimed(msg.sender, reward);
        return true;
    }

    function calculateRewards(address delegator) public view returns (uint256) {
        uint256 stakedAmount = _delegatedAmounts[delegator];
        uint256 timeStaked = block.timestamp - lastUpdateTime[delegator];
        return (stakedAmount * _rewardRate * timeStaked) / (365 days * 10000);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Rate too high"); // Max 10%
        _rewardRate = newRate;
    }

    receive() external payable {
        // Allow contract to receive Ether
    }
}
