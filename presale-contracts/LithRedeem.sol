pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../contracts/libs/IERC20.sol";

import "./PLithToken.sol";

contract LithRedeem is Ownable, ReentrancyGuard {

    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    PLithToken public plith;
    address public lithAddress;

    uint256 public startBlock;

    bool public hasBurnedUnsoldPresale = false;

    event lithSwap(address sender, uint256 amount);
    event burnUnclaimedLith(uint256 amount);
    event startBlockChanged(uint256 newStartBlock);

    constructor(uint256 _startBlock, address _plithAddress, address _lithAddress) {
        require(_plithAddress != _lithAddress, "plith cannot be equal to lith");
        startBlock   = _startBlock;
        plith = PLithToken(_plithAddress);
        lithAddress  = _lithAddress;
    }

    function swapPLithForLith(uint256 swapAmount) external nonReentrant {
        require(block.number >= startBlock, "lith redemption hasn't started yet, good things come to those that wait ;)");
        require(IERC20(lithAddress).balanceOf(address(this)) >= swapAmount, "Not Enough tokens in contract for swap");
        plith.transferFrom(msg.sender, BURN_ADDRESS, swapAmount);
        IERC20(lithAddress).transfer(msg.sender, swapAmount);

        emit lithSwap(msg.sender, swapAmount);
    }

    function sendUnclaimedLithToDeadAddress() external onlyOwner {
        require(block.number > plith.endBlock(), "can only send excess lith to dead address after presale has ended");
        require(!hasBurnedUnsoldPresale, "can only burn unsold presale once!");

        require(plith.plithRemaining() <= IERC20(lithAddress).balanceOf(address(this)),
            "burning too much lithium, founders may need to top up");

        if (plith.plithRemaining() > 0)
            IERC20(lithAddress).transfer(BURN_ADDRESS, plith.plithRemaining());
        hasBurnedUnsoldPresale = true;

        emit burnUnclaimedLith(plith.plithRemaining());
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;

        emit startBlockChanged(_newStartBlock);
    }
}