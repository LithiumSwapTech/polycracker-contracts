pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../contracts/libs/IERC20.sol";
import "../contracts/libs/ERC20.sol";

// PLithToken
contract PLithToken is ERC20('PRE-LITHIUM', 'PLITHIUM'), ReentrancyGuard {

    address public constant feeAddress = 0x3a1D1114269d7a786C154FE5278bF5b1e3e20d31;

    uint256 public salePriceE35 = 435 * (10 ** 33);

    uint256 public constant plithMaximumSupply = 30 * (10 ** 3) * (10 ** 18);

    // We use a counter to defend against people sending plith back
    uint256 public plithRemaining = plithMaximumSupply;

    uint256 public constant maxPlithPurchase = 600 * (10 ** 18);

    uint256 oneHourMatic = 1800;
    uint256 oneDayMatic = oneHourMatic * 24;
    uint256 threeDaysMatic = oneDayMatic * 3;

    uint256 public startBlock;
    uint256 public endBlock;

    mapping(address => uint256) public userPlithTally;

    event plithPurchased(address sender, uint256 maticSpent, uint256 plithReceived);
    event startBlockChanged(uint256 newStartBlock, uint256 newEndBlock);
    event salePriceE35Changed(uint256 newSalePriceE5);

    constructor(uint256 _startBlock) {
        startBlock = _startBlock;
        endBlock   = _startBlock + threeDaysMatic;
        _mint(address(this), plithMaximumSupply);
    }

    function buyPLith() external payable nonReentrant {
        require(block.number >= startBlock, "presale hasn't started yet, good things come to those that wait");
        require(block.number < endBlock, "presale has ended, come back next time!");
        require(plithRemaining > 0, "No more plith remaining! Come back next time!");
        require(IERC20(address(this)).balanceOf(address(this)) > 0, "No more plith left! Come back next time!");
        require(msg.value > 0, "not enough bnb provided");
        require(msg.value <= 3e22, "too much bnb provided");
        require(userPlithTally[msg.sender] < maxPlithPurchase, "user has already purchased too much plith");

        uint256 originalPlithAmount = (msg.value * salePriceE35) / 1e35;

        uint256 plithPurchaseAmount = originalPlithAmount;

        if (plithPurchaseAmount > maxPlithPurchase)
            plithPurchaseAmount = maxPlithPurchase;

        if ((userPlithTally[msg.sender] + plithPurchaseAmount) > maxPlithPurchase)
            plithPurchaseAmount = maxPlithPurchase - userPlithTally[msg.sender];

        // if we dont have enough left, give them the rest.
        if (plithRemaining < plithPurchaseAmount)
            plithPurchaseAmount = plithRemaining;

        require(plithPurchaseAmount > 0, "user cannot purchase 0 plith");

        // shouldn't be possible to fail these asserts.
        assert(plithPurchaseAmount <= plithRemaining);
        assert(plithPurchaseAmount <= IERC20(address(this)).balanceOf(address(this)));
        IERC20(address(this)).transfer(msg.sender, plithPurchaseAmount);
        plithRemaining = plithRemaining - plithPurchaseAmount;
        userPlithTally[msg.sender] = userPlithTally[msg.sender] + plithPurchaseAmount;

        uint256 maticSpent = msg.value;
        uint256 refundAmount = 0;
        if (plithPurchaseAmount < originalPlithAmount) {
            // max plithPurchaseAmount = 6e20, max msg.value approx 3e22 (if 10c matic, worst case).
            // overfow check: 6e20 * 3e22 * 1e24 = 1.8e67 < type(uint256).max
            // Rounding errors by integer division, reduce magnitude of end result.
            // We accept any rounding error (tiny) as a reduction in PAYMENT, not refund.
            maticSpent = ((plithPurchaseAmount * msg.value * 1e24) / originalPlithAmount) / 1e24;
            refundAmount = msg.value - maticSpent;
        }
        if (maticSpent > 0) {
            (bool success, bytes memory returnData) = payable(address(feeAddress)).call{value: maticSpent}("");
            require(success, "failed to send matic to fee address");
        }
        if (refundAmount > 0) {
            (bool success, bytes memory returnData) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "failed to send matic to customer address");
        }

        emit plithPurchased(msg.sender, maticSpent, plithPurchaseAmount);
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;
        endBlock   = _newStartBlock + threeDaysMatic;

        emit startBlockChanged(_newStartBlock, endBlock);
    }

    function setSalePriceE35(uint256 _newSalePriceE35) external onlyOwner {
        require(block.number < startBlock - (oneHourMatic * 12), "cannot change price 12 hours before start block");
        require(_newSalePriceE35 >= 25 * (10 ** 34), "new price can't be below 2.5 matic");
        require(_newSalePriceE35 <= 100 * (10 ** 34), "new price can't be above 10 matic");
        salePriceE35 = _newSalePriceE35;

        emit salePriceE35Changed(salePriceE35);
    }
}