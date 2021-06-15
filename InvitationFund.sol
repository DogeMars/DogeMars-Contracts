// SPDX-License-Identifier: MIT
/**
 * InvitationFund:
 *  Bonus for those invite new people to meet DogeMars
 */

pragma solidity ^0.6.12;

import './interfaces/IERC20.sol';
import './interfaces/uniswap.sol';
import './libraries/SafeMath.sol';
import './libraries/Address.sol';
import './libraries/TransferHelper.sol';
import './libraries/Ownable.sol';

contract InvitationFund is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    event Invite(address indexed inviter, address indexed invitee);
    event Reward(address indexed inviter, uint value);

    address public immutable dogeMars;
    address public immutable dogecoin;
    address public pancakeRouter;
    address[] public swapPath;

    // map from invitee to inviter
    mapping (address => address) private _inviter;

    // map from inviter to invitees
    mapping (address => address[]) private _invitees;

    // map from invitee to rewarded value (DogeMars)
    mapping (address => uint256) private _rewardedFor;
    mapping (address => uint256) private _rewardedL2For;

    // map from inviter to rewarded value (Dogecoin)
    mapping (address => uint256) private _rewardedOf;

    uint256 public maxInviteesPerAddr = 1024;

    // rewarding ratio (percent)
    uint256 public rewardPercent = 10;
    uint256 public rewardL2Percent = 5;

    uint256 public rewardedCnt;
    uint256 public rewardedTotalDogeMars;
    uint256 public rewardedTotalDogecoin;

    constructor (address pancakeRouterAddr, address dogeMarsAddr, address dogecoinAddr) public {
        // For BSC Mainnet
        // dogeMars = IERC20(0xc691B95d84147FfFcd1094D0d2243b43b7C25817);
        
        require(IERC20(dogeMarsAddr).totalSupply() > 0);
        require(IERC20(dogecoinAddr).totalSupply() > 0);

        pancakeRouter = pancakeRouterAddr;
        dogeMars = dogeMarsAddr;
        dogecoin = dogecoinAddr;
        
        swapPath.push(dogeMarsAddr);
        swapPath.push(IUniswapV2Router02(pancakeRouter).WETH());
        swapPath.push(dogecoinAddr);
    
    }

    function calcRewardInDogeMars(address invitee) private view returns (uint256) {
        uint256 balance = (IERC20 (dogeMars)).balanceOf(invitee);
        uint256 rewardTotal = balance.mulDiv(rewardPercent, 100);
        uint256 rewarded = rewardedFor(invitee);
        return rewardTotal <= rewarded ? 0 : rewardTotal.sub(rewarded);
    }

    function calcRewardL2InDogeMars(address invitee) private view returns (uint256) {
        uint256 balance = (IERC20 (dogeMars)).balanceOf(invitee);
        uint256 rewardTotal = balance.mulDiv(rewardL2Percent, 100);
        uint256 rewarded = rewardedL2For(invitee);
        return rewardTotal <= rewarded ? 0 : rewardTotal.sub(rewarded);
    }
    
    function sumRewardInDogeMars(address inviter) private view returns (uint256) {
        uint256 sum;
        for (uint256 i=0; i<_invitees[inviter].length; i++) {
            address son = _invitees[inviter][i];
            uint256 r1 = calcRewardInDogeMars(son);
            sum = sum.add(r1);
            for (uint256 j=0; j<_invitees[son].length; j++) {
                address grandson = _invitees[son][j];
                uint256 r2 = calcRewardL2InDogeMars(grandson);
                sum = sum.add(r2);
            }
        }
        return sum;
    }

    function sumRewardInDogeMarsAndUpdate(address inviter) private returns (uint256) {
        uint256 sum;
        for (uint256 i=0; i<_invitees[inviter].length; i++) {
            address son = _invitees[inviter][i];
            uint256 r1 = calcRewardInDogeMars(son);
            sum = sum.add(r1);
            _rewardedFor[son] = _rewardedFor[son].add(r1);
            for (uint256 j=0; j<_invitees[son].length; j++) {
                address grandson = _invitees[son][j];
                uint256 r2 = calcRewardL2InDogeMars(grandson);
                sum = sum.add(r2);
                _rewardedFor[grandson] = _rewardedFor[grandson].add(r2);
            }
        }
        return sum;
    }

    /** Handling Inviter Relations & Reward */

    function inviterOf(address invitee) public view returns (address) {
        return _inviter[invitee];
    }

    function l2InviterOf(address invitee) public view returns (address) {
        address father = _inviter[invitee];
        return father == address(0) ? address(0) : _inviter[father];
    }

    function inviteesOf(address inviter) public view returns (address[] memory) {
        return _invitees[inviter];
    }

    function l2InviteesOf(address inviter) public view returns (address[] memory) {
        uint256 cnt;
        for (uint256 i=0; i<_invitees[inviter].length; i++) {
            cnt = cnt.add(_invitees[_invitees[inviter][i]].length);
        }
        address[] memory invitees = new address[](cnt);
        uint256 k = 0;
        for (uint256 i=0; i<_invitees[inviter].length; i++) {
            address son = _invitees[inviter][i];
            for (uint256 j=0; j<_invitees[son].length; j++) {
                invitees[k] = _invitees[son][j];
                k = k + 1;
            }
        }
        return invitees;
    }

    // already rewarded for such invitee (in dogemars)
    function rewardedFor(address invitee) public view returns (uint256) {
        return _rewardedFor[invitee];
    }

    // already rewarded for such invitee to its L2 inviter (in dogemars)
    function rewardedL2For(address invitee) public view returns (uint256) {
        return _rewardedL2For[invitee];
    }

    // rewarded dogecoin sent to the inviter
    function rewardedOf(address inviter) public view returns (uint256) {
        return _rewardedOf[inviter];
    }

    // estimate reward for such invitee address
    function estimateRewardFor(address invitee) public view returns (uint256) {
        uint256 dgmValue = calcRewardInDogeMars(invitee);
        if (dgmValue == 0) {
            return 0;
        }
        return IUniswapV2Router02(pancakeRouter).getAmountsOut(dgmValue, swapPath)[swapPath.length-1];
    }

    // estimate reward to L2 inviter for such invitee address
    function estimateRewardL2For(address invitee) public view returns (uint256) {
        uint256 dgmValue = calcRewardL2InDogeMars(invitee);
        if (dgmValue == 0) {
            return 0;
        }
        return IUniswapV2Router02(pancakeRouter).getAmountsOut(dgmValue, swapPath)[swapPath.length-1];
    }

    // estimate all reward to the inviter
    function estimateRewardAll(address inviter) public view returns (uint256) {
        uint256 dgmValue = sumRewardInDogeMars(inviter);
        if (dgmValue == 0) {
            return 0;
        }
        return IUniswapV2Router02(pancakeRouter).getAmountsOut(dgmValue, swapPath)[swapPath.length-1];
    }

    function invite(address invitee) public {
        require(invitee != address(0), "The invitee can't be zero address!");
        require(!invitee.isContract(), "The invitee can't be contract!");
        require((IERC20(dogeMars).balanceOf(invitee) == 0), "The invitee already has DogeMars!");
        require(_inviter[invitee] == address(0), "The invitee has been invited!");
        address inviter = _msgSender();
        require(_invitees[inviter].length < maxInviteesPerAddr, "Too many invitees!");
        _inviter[invitee] = inviter;
        _invitees[inviter].push(invitee);
        emit Invite(inviter, invitee);
    }

    function swapAndSendReward(uint256 dgmValue, uint256 minRecv) private {
        address inviter = _msgSender();
        uint256[] memory amounts = IUniswapV2Router02(pancakeRouter)
            .swapExactTokensForTokens(dgmValue, minRecv, swapPath, inviter, uint256(-1));
        uint256 rewardedDogecoin = amounts[amounts.length-1];
        _rewardedOf[inviter] = _rewardedOf[inviter].add(rewardedDogecoin);
        rewardedCnt = rewardedCnt.add(1);
        rewardedTotalDogeMars = rewardedTotalDogeMars.add(dgmValue);
        rewardedTotalDogecoin = rewardedTotalDogecoin.add(rewardedDogecoin);
        emit Reward(inviter, rewardedDogecoin);
    }

    function getRewardFor(address invitee, uint256 minRecv) public {
        address inviter = inviterOf(invitee);
        require(inviter == _msgSender(), "Only the inviter can get reward!");
        uint256 reward = calcRewardInDogeMars(invitee);
        require(reward > 0, "No reward available!");
        swapAndSendReward(reward, minRecv);
        _rewardedFor[invitee] = _rewardedFor[invitee].add(reward);
    }

    function getRewardL2For(address invitee, uint256 minRecv) public {
        address inviter = l2InviterOf(invitee);
        require(inviter == _msgSender(), "Only the L2 inviter can get L2 reward!");
        uint256 reward = calcRewardL2InDogeMars(invitee);
        require(reward > 0, "No reward available!");
        swapAndSendReward(reward, minRecv);
        _rewardedFor[invitee] = _rewardedFor[invitee].add(reward);
    }

    function getRewardAll(uint256 minRecv) public {
        address inviter = _msgSender();
        uint256 reward = sumRewardInDogeMarsAndUpdate(inviter);
        require(reward > 0, "No reward available!");
        swapAndSendReward(reward, minRecv);
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
        require(newPct <= 100);
        rewardPercent = newPct;
    }

    function setRewardL2Percent(uint256 newPct) public onlyOwner() {
        require(newPct <= 100);
        rewardL2Percent = newPct;
    }

    function setMaxInviteesPerAddr(uint256 cnt) public onlyOwner() {
        maxInviteesPerAddr = cnt;
    }

    function setRouter(address newRouter) public onlyOwner() {
        pancakeRouter = newRouter;
    }

    function setSwapPath(address[] calldata newPath) public onlyOwner() {
        require(newPath[0] == dogeMars, "Input should be DogeMars!");
        require(newPath[newPath.length-1] == dogecoin, "Output should be Dogecoin!");
        swapPath = newPath;
    }

}
