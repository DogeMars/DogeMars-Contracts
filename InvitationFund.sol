// SPDX-License-Identifier: MIT
/**
 * InvitationFund:
 *  Bonus for those invite new people to meet DogeMars
 */

pragma solidity ^0.6.12;

import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';
import './libraries/Address.sol';
import './libraries/TransferHelper.sol';
import './libraries/Ownable.sol';

contract InvitationFund is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    event Reward(address indexed invitee, address indexed inviter, uint value);

    address public immutable dogeMars;

    // map from invitee to inviter
    mapping (address => address) private _inviter;

    // map from invitee to whether rewarded for its inviter
    mapping (address => bool) private _rewarded;

    // rewarding ratio (percent)
    uint256 public rewardPercent = 10;

    uint256 public rewardedCnt;
    uint256 public rewardedTotal;

    constructor (address dogeMarsAddr) public {
        // For BSC Mainnet
        // dogeMars = IERC20(0xc691B95d84147FfFcd1094D0d2243b43b7C25817);
        
        require(IERC20(dogeMarsAddr).totalSupply() > 0);

        dogeMars = dogeMarsAddr;
    }

    /** Handling Inviter Relations & Reward */

    function inviterOf(address invitee) public view returns (address) {
        return _inviter[invitee];
    }

    function rewardedFor(address invitee) public view returns (bool) {
        return _rewarded[invitee];
    }

    function calcReward(address invitee) public view returns (uint256) {
        require(_inviter[invitee] != address(0), "No inviter for this address!");
        uint256 balance = (IERC20 (dogeMars)).balanceOf(invitee);
        require(balance > 0, "The invitee is not holding DogeMars!");
        return balance.mulDiv(rewardPercent, 100);
    }

    function invite(address invitee) public {
        require((IERC20(dogeMars).balanceOf(invitee) == 0), "The invitee already has DogeMars!");
        require(_inviter[invitee] == address(0), "The invitee has been invited by another address!");
        _inviter[invitee] = _msgSender();
    }

    function getReward(address invitee) public {
        address inviter = _inviter[invitee];
        require(inviter == _msgSender(), "Only the inviter can get reward!");
        require(!_rewarded[invitee], "Already rewarded!");
        uint256 reward = calcReward(invitee);
        rewardedCnt = rewardedCnt.add(1);
        rewardedTotal = rewardedTotal.add(reward);
        TransferHelper.safeTransfer(dogeMars, inviter, reward);
        _rewarded[invitee] = true;
        emit Reward(invitee, inviter, reward);
    }

    /** Handling Funds & Settings */

    function remainingToken() public view returns (uint256) {
        return IERC20(dogeMars).balanceOf(address(this));
    }

    function addToken(uint256 amount) public {
        TransferHelper.safeTransferFrom(dogeMars, _msgSender(), address(this), amount);
    }

    function withdrawToken(uint256 amount) public onlyOwner() {
        TransferHelper.safeTransfer(dogeMars, _msgSender(), amount);
    }

    function setRewardPercent(uint256 newPct) public onlyOwner() {
        require(newPct <= 10);
        rewardPercent = newPct;
    }

}
