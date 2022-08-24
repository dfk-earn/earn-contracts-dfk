// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Beneficial.sol";

contract ESwap is Beneficial, ReentrancyGuard, Pausable, ERC721Holder, ERC1155Holder {

    // Use SafeERC20 for best practice
    using SafeERC20 for IERC20;

    // Counter to separate swaps
    using Counters for Counters.Counter;
    Counters.Counter public _swapsCounter;
    // Native asset locked temporary storage - in wei
    uint256 private _native;
    // Native asset fee storage - in wei
    uint256 public offer1Fee;
    uint256 public offer2Fee;
    // uint256 booleans to save the boolean conversion gas cost
    uint256 private constant TRUEINT = 1;
    uint256 private constant FALSEINT = 2;
    enum Status { None, Open, Cancelled, Closed }

    // Storage mapping for swaps
    mapping (uint256 => Swap) public _swaps;

    // NFT struct to hold the data required to create and reference an ERC721/ERC1155 object
    struct Nft {
        address addr;
        uint256 amount;
        uint256 id;
    }

    // Coin struct to hold the data required to create and reference an ERC20 object
    struct Coin {
        address addr;
        uint256 amount;
    }

    // Offer struct to hold the data for a single participant's offer
    struct Offer {
        address payable addr;
        uint256 native;
        Nft[] nfts;
        Coin[] coins;
        uint256 fee;
    }

    // Swap struct to hold the data for a single swap transaction
    struct Swap {
        Offer initiator;
        Offer target;
        Status status;
    }

    event Created(uint256 indexed id);
    event Cancelled(uint256 indexed id);
    event Completed(uint256 indexed id, address bidder);
    event offer1FeeChanged(uint256 newFee, uint256 oldFee);
    event offer2FeeChanged(uint256 newFee, uint256 oldFee);

    // Sets the initial fee
    constructor(uint256 _offer1Fee, uint256 _offer2Fee) {
        offer1Fee = _offer1Fee;
        offer2Fee = _offer2Fee;
    }

    // set sell fee
    function setoffer1Fee(uint256 _fee) external onlyOwner {
        uint256 oldFee = offer1Fee;
        offer1Fee = _fee;
        emit offer1FeeChanged(offer1Fee, oldFee);
    }

    // set buy fee
    function setoffer2Fee(uint256 _fee) external onlyOwner {
        uint256 oldFee = offer2Fee;
        offer2Fee = _fee;
        emit offer2FeeChanged(offer2Fee, oldFee);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function create(Offer memory offer1, Offer memory offer2)
    external payable nonReentrant whenNotPaused returns(uint256) {
        requireNotEmpty(offer1);
        requireNotEmpty(offer2);
        require(msg.value >= offer1Fee, "DFKEarn: Sent amount needs to be greater than or equal to the application fee");
        _swapsCounter.increment();

        transferWithBalanceCheck(payable(msg.sender), address(this), offer1);

        Swap storage swap = _swaps[_swapsCounter.current()];

        swap.status = Status.Open;
        swap.initiator.addr = payable(msg.sender);
        swap.initiator.fee = offer1Fee;
        swap.target.fee = offer2Fee;

        for (uint256 i=0; i < offer1.nfts.length; i++) {
            swap.initiator.nfts.push(offer1.nfts[i]);
        }
        for (uint256 i=0; i < offer1.coins.length; i++) {
            swap.initiator.coins.push(offer1.coins[i]);
        }
        for (uint256 i=0; i < offer2.nfts.length; i++) {
            swap.target.nfts.push(offer2.nfts[i]);
        }
        for (uint256 i=0; i < offer2.coins.length; i++) {
            swap.target.coins.push(offer2.coins[i]);
        }
        swap.initiator.native = msg.value - offer1Fee;
        swap.target.native = offer2.native;
        _native += (swap.initiator.native + offer1Fee);

        emit Created(_swapsCounter.current());

        return _swapsCounter.current();
    }

    function accept(uint256 swapId) external payable nonReentrant whenNotPaused {
        require(_swaps[swapId].status == Status.Open, "DFKEarn: Swap closed.");
        require(msg.value >= _swaps[swapId].target.fee, "DFKEarn: Sent amount needs to be greater than or equal to the application fee");
        require((_swaps[swapId].target.native + _swaps[swapId].target.fee)  == msg.value, "DFKEarn: Native value minus fee do not equal to offer native requirement");

        _swaps[swapId].target.addr = payable(msg.sender);

        transferWithBalanceCheck(payable(msg.sender), address(this), _swaps[swapId].target);

        _native += _swaps[swapId].target.native;

        safeMultipleTransfersFrom(address(this), _swaps[swapId].initiator.addr, _swaps[swapId].target);
        safeMultipleTransfersFrom(address(this), _swaps[swapId].target.addr, _swaps[swapId].initiator);

        transferFee();
        transferNative(_swaps[swapId].initiator, _swaps[swapId].target);
        transferNative(_swaps[swapId].target, _swaps[swapId].initiator);


        _swaps[swapId].status = Status.Closed;
        emit Completed(swapId, msg.sender);
    }

    function cancel(uint256 swapId) external nonReentrant {
        require(_swaps[swapId].status == Status.Open, "DFKEarn: status not open");
        require(
            _swaps[swapId].initiator.addr == msg.sender,
            "DFKEarn: Can't cancel swap, must be swap participant"
        );


        safeMultipleTransfersFrom(address(this), _swaps[swapId].initiator.addr, _swaps[swapId].initiator);
        // revert fee for seller
        _swaps[swapId].initiator.native += _swaps[swapId].initiator.fee;
        transferNative(_swaps[swapId].initiator, _swaps[swapId].initiator);
        _swaps[swapId].status = Status.Cancelled;
        emit Cancelled(swapId);
    }

    // External Owner Functions

    // Internal Functions

    function requireNotEmpty(Offer memory offer) internal virtual {
        require(TRUEINT == isNotEmpty(offer),
            "DFKEarn: Can't accept offer, participant didn't add assets"
        );
    }

    function isNotEmpty(Offer memory offer) internal virtual returns(uint256) {
        uint256 empty = FALSEINT;
        if (offer.nfts.length != 0 || offer.coins.length != 0 || offer.native >= 0) {
            empty = TRUEINT;
        }
        return empty;
    }

    function isEmpty(Offer memory offer) internal virtual returns(uint256) {
        uint256 empty = FALSEINT;
        if (offer.nfts.length == 0 && offer.coins.length == 0 && offer.native == 0) {
            empty = TRUEINT;
        }
        return empty;
    }

    function transferWithBalanceCheck(address from, address to, Offer memory offer) internal virtual {
        for (uint256 i=0; i < offer.nfts.length; i++) {
            address addr = offer.nfts[i].addr;
            if (addr == address(0)) {
                continue;
            }
            if (offer.nfts[i].amount == 0) {
                IERC721(addr).safeTransferFrom(from, to, offer.nfts[i].id, "");
            } else {
                IERC1155 nft = IERC1155(addr);
                uint256 originalBalance = nft.balanceOf(address(this), offer.nfts[i].id);
                nft.safeTransferFrom(from, to, offer.nfts[i].id, offer.nfts[i].amount, "");
                uint256 newBalance = nft.balanceOf(address(this), offer.nfts[i].id);
                if (newBalance - originalBalance != offer.nfts[i].amount) {
                    offer.nfts[i].amount = newBalance - originalBalance;
                }
            }
        }
        for (uint256 i=0; i < offer.coins.length; i++) {
            address addr = offer.coins[i].addr;
            if (addr == address(0)) {
                continue;
            }
            IERC20 coin = IERC20(addr);
            uint256 originalBalance = coin.balanceOf(address(this));
            coin.safeTransferFrom(from, to, offer.coins[i].amount);
            uint256 newBalance = coin.balanceOf(address(this));
            if (newBalance - originalBalance != offer.coins[i].amount) {
                offer.coins[i].amount = newBalance - originalBalance;
            }
        }
    }

    function safeMultipleTransfersFrom(address from, address to, Offer memory offer) internal virtual {
        for (uint256 i=0; i < offer.nfts.length; i++) {
            address addr = offer.nfts[i].addr;
            if (addr == address(0)) {
                continue;
            }
            if (offer.nfts[i].amount == 0) {
                IERC721(addr).safeTransferFrom(from, to, offer.nfts[i].id, "");
            } else {
                IERC1155(addr).safeTransferFrom(from, to, offer.nfts[i].id, offer.nfts[i].amount, "");
            }
        }
        for (uint256 i=0; i < offer.coins.length; i++) {
            address addr = offer.coins[i].addr;
            if (addr == address(0)) {
                continue;
            }
            if (from == address(this)) {
                IERC20(addr).safeTransfer(to, offer.coins[i].amount);
            } else {
                IERC20(addr).safeTransferFrom(from, to, offer.coins[i].amount);
            }
        }
    }

    function transferNative(Offer storage from, Offer storage to) internal virtual {
        if (from.native > 0) {
            _native -= from.native;
            uint native = from.native;
            to.addr.transfer(native);
        }
    }

    function transferFee() internal {
        payable(beneficiary).transfer(offer2Fee + offer1Fee);
    }
}
