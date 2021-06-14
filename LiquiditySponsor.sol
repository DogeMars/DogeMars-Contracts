/**
 * LiquiditySponsor:
 * Lock your Pancake-LP to get DogeMars, send DogeMars back to unlock your Pancake-LP
 */

pragma solidity ^0.6.12;
// SPDX-License-Identifier: MIT

import './interfaces/IERC20.sol';
import './interfaces/uniswap.sol';
import './libraries/SafeMath.sol';
import './libraries/Address.sol';
import './libraries/TransferHelper.sol';
import './libraries/Ownable.sol';

contract LiquiditySponsor is Context, Ownable {
    using SafeMath for uint256;
    using Address for address;

    event Sponsor(address indexed to, address indexed cake, uint value);
    event Payback(address indexed from, address indexed cake, uint value);

    // [cake address][user address]
    mapping (address => mapping (address => uint256)) private _lockedLPs;
    mapping (address => mapping (address => uint256)) private _sponsoredTokens;

    address public immutable dogeMars;

    IUniswapV2Router02 public uniswapV2Router;
    
    constructor (address pancakeRouterAddr, address dogeMarsAddr) public {

        // For BSC Mainnet
        // dogeMars = IERC20(0xc691B95d84147FfFcd1094D0d2243b43b7C25817);
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        require(IERC20(dogeMarsAddr).totalSupply() > 0);

        dogeMars = dogeMarsAddr;
        uniswapV2Router = IUniswapV2Router02(pancakeRouterAddr);
    }

    function remainingToken() public view returns (uint256) {
        return IERC20(dogeMars).balanceOf(address(this));
    }

    function lockedLP(address pairedToken) public view returns (uint256) {
        address pairAddr = IUniswapV2Factory(uniswapV2Router.factory())
            .getPair(dogeMars, pairedToken);
        return _lockedLPs[pairAddr][_msgSender()];
    }

    function lockedLPBnbPair() public view returns (uint256) {
        return lockedLP(uniswapV2Router.WETH());
    }

    function sponsoredAmount(address pairedToken) public view returns (uint256) {
        address pairAddr = IUniswapV2Factory(uniswapV2Router.factory())
            .getPair(dogeMars, pairedToken);
        return _sponsoredTokens[pairAddr][_msgSender()];
    }

    function sponsoredAmountBnbPair() public view returns (uint256) {
        return sponsoredAmount(uniswapV2Router.WETH());
    }

    function sponsorTokenPair(address pairedToken, uint256 cakeLPs) public {
        address pairAddr = IUniswapV2Factory(uniswapV2Router.factory())
            .getPair(dogeMars, pairedToken);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        // Transfer cakeLPs to this
        TransferHelper.safeTransferFrom(pairAddr, _msgSender(), address(this), cakeLPs);
        // Calculate Sponsor Value
        (uint112 reserve1, uint112 reserve2, uint32 ts) = pair.getReserves();
        bool isToken0 = (pair.token0() == dogeMars);
        uint256 reservedTotal = uint256(isToken0 ? reserve1 : reserve2);
        uint256 cakeSupply = pair.totalSupply();
        // uint256 sponsorValue = cakeLPs.mul(reservedTotal).div(cakeSupply);
        uint256 sponsorValue = cakeLPs.mulDiv(reservedTotal, cakeSupply);
        // Sponsor DogeMars to the sender
        TransferHelper.safeTransfer(dogeMars, _msgSender(), sponsorValue);
        _lockedLPs[pairAddr][_msgSender()] = _lockedLPs[pairAddr][_msgSender()].add(cakeLPs);
        _sponsoredTokens[pairAddr][_msgSender()] = _sponsoredTokens[pairAddr][_msgSender()].add(sponsorValue);
        emit Sponsor(_msgSender(), pairAddr, sponsorValue);
    }

    function sponsorBnbPair(uint256 cakeLPs) public {
        sponsorTokenPair(uniswapV2Router.WETH(), cakeLPs);
    }

    function paybackTokenPair(address pairedToken, uint256 amount) public {
        address pairAddr = IUniswapV2Factory(uniswapV2Router.factory())
            .getPair(dogeMars, pairedToken);
        require(amount <= _sponsoredTokens[pairAddr][_msgSender()], "Amount should not be larger then the sponsored value");
        require(amount > 0, "Amount should be > 0");
        TransferHelper.safeTransferFrom(dogeMars, _msgSender(), address(this), amount);
        // uint256 returnCakes = amount == _sponsoredTokens[pairAddr][_msgSender()] ? _lockedLPs[pairAddr][_msgSender()] : 
        //     amount.mul(_lockedLPs[pairAddr][_msgSender()]).div(_sponsoredTokens[pairAddr][_msgSender()]);
        uint256 returnCakes = amount.mulDiv(_lockedLPs[pairAddr][_msgSender()], _sponsoredTokens[pairAddr][_msgSender()]);
        TransferHelper.safeTransfer(pairAddr, _msgSender(), returnCakes);
        _lockedLPs[pairAddr][_msgSender()] = _lockedLPs[pairAddr][_msgSender()].sub(returnCakes);
        _sponsoredTokens[pairAddr][_msgSender()] = _sponsoredTokens[pairAddr][_msgSender()].sub(amount);
    }

    function paybackBnbPair(uint256 amount) public {
        paybackTokenPair(uniswapV2Router.WETH(), amount);
    }

    function saveToken(uint256 amount) public onlyOwner() {
        TransferHelper.safeTransferFrom(dogeMars, _msgSender(), address(this), amount);
    }

    function withdrawToken(uint256 amount) public onlyOwner() {
        TransferHelper.safeTransfer(dogeMars, _msgSender(), amount);
    }

    function setRouterAddress(address newRouter) public onlyOwner() {
        uniswapV2Router = IUniswapV2Router02(newRouter);
    }

}
