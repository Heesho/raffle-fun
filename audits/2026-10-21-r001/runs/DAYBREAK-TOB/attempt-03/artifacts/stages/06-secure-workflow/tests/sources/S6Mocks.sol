// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";

interface IRawVrfConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockQuoteToken is IERC20Metadata {
    string public constant name = "S6 Quote";
    string public constant symbol = "S6Q";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    uint256 public feeBps;
    bool public returnFalse;
    address public callbackTarget;
    bytes public callbackData;
    bool public callbackOnTransferFrom;
    bool public callbackAttempted;
    bool public callbackSucceeded;
    bool private _insideCallback;

    mapping(address account => uint256 amount) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setFeeBps(uint256 newFeeBps) external {
        require(newFeeBps <= 10_000, "fee");
        feeBps = newFeeBps;
    }

    function setReturnFalse(bool enabled) external {
        returnFalse = enabled;
    }

    function configureCallback(address target, bytes calldata data, bool enabled) external {
        callbackTarget = target;
        callbackData = data;
        callbackOnTransferFrom = enabled;
        callbackAttempted = false;
        callbackSucceeded = false;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return !returnFalse;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (returnFalse) return false;
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (returnFalse) return false;
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }

        if (callbackOnTransferFrom && !_insideCallback) {
            _insideCallback = true;
            callbackAttempted = true;
            (callbackSucceeded,) = callbackTarget.call(callbackData);
            _insideCallback = false;
        }

        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) private {
        require(to != address(0), "zero");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "balance");
        balanceOf[from] = fromBalance - amount;
        uint256 fee = amount * feeBps / 10_000;
        uint256 received = amount - fee;
        balanceOf[to] += received;
        if (fee != 0) totalSupply -= fee;
        emit Transfer(from, to, received);
        if (fee != 0) emit Transfer(from, address(0), fee);
    }
}

contract MockVrfWrapper is IVRFV2PlusWrapper {
    address public immutable linkToken;
    uint256 public price = 1 wei;
    uint256 public nextRequestId = 1;
    uint256 public override lastRequestId;
    address public lastConsumer;
    bool public synchronousCallback;
    uint256 public synchronousWord;

    constructor(address linkToken_) {
        linkToken = linkToken_;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

    function configureSynchronousCallback(bool enabled, uint256 word) external {
        synchronousCallback = enabled;
        synchronousWord = word;
    }

    function calculateRequestPrice(uint32, uint32) external view returns (uint256) {
        return price;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return price;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external view returns (uint256) {
        return price;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return price;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32 numWords, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        require(msg.value == price, "price");
        require(numWords == 1, "words");
        requestId = nextRequestId++;
        lastRequestId = requestId;
        lastConsumer = msg.sender;
        if (synchronousCallback) {
            uint256[] memory words = new uint256[](1);
            words[0] = synchronousWord;
            IRawVrfConsumer(msg.sender).rawFulfillRandomWords(requestId, words);
        }
    }

    function fulfill(address consumer, uint256 requestId, uint256 word) external {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        IRawVrfConsumer(consumer).rawFulfillRandomWords(requestId, words);
    }

    function fulfillWords(address consumer, uint256 requestId, uint256[] calldata words) external {
        IRawVrfConsumer(consumer).rawFulfillRandomWords(requestId, words);
    }

    function link() external view returns (address) {
        return linkToken;
    }

    function linkNativeFeed() external pure returns (address) {
        return address(0xfeed);
    }
}

contract HonestPrize is ERC721 {
    constructor() ERC721("S6 Prize", "S6P") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NoCallbackPrize is HonestPrize {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) public override {
        transferFrom(from, to, tokenId);
    }
}

contract LyingPrize is IERC721 {
    address public actualOwner;
    address public reportedOwner;
    uint256 public immutable tokenId;
    mapping(uint256 id => address operator) private _approvals;
    mapping(address owner => mapping(address operator => bool approved)) private _operatorApprovals;

    constructor(address owner_, uint256 tokenId_) {
        actualOwner = owner_;
        reportedOwner = owner_;
        tokenId = tokenId_;
        emit Transfer(address(0), owner_, tokenId_);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId;
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "zero");
        return reportedOwner == owner ? 1 : 0;
    }

    function ownerOf(uint256 id) external view returns (address) {
        require(id == tokenId, "id");
        return reportedOwner;
    }

    function approve(address to, uint256 id) external {
        require(id == tokenId, "id");
        require(msg.sender == actualOwner || msg.sender == reportedOwner, "owner");
        _approvals[id] = to;
        emit Approval(reportedOwner, to, id);
    }

    function getApproved(uint256 id) external view returns (address) {
        require(id == tokenId, "id");
        return _approvals[id];
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 id) public {
        require(id == tokenId, "id");
        require(reportedOwner == from, "from");
        require(
            msg.sender == from || msg.sender == _approvals[id] || _operatorApprovals[from][msg.sender], "auth"
        );
        reportedOwner = to;
        delete _approvals[id];
        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        safeTransferFrom(from, to, id, "");
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) public {
        transferFrom(from, to, id);
        if (to.code.length != 0) {
            bytes4 selector = IERC721Receiver(to).onERC721Received(msg.sender, from, id, data);
            require(selector == IERC721Receiver.onERC721Received.selector, "receiver");
        }
        // Deliberately never changes actualOwner.
    }
}

contract ReentrantPrize is ERC721 {
    MockQuoteToken public immutable quote;
    address public prebuyer;
    bool public armed;

    constructor(MockQuoteToken quote_) ERC721("S6 Reentrant Prize", "S6RP") {
        quote = quote_;
    }

    function mint(address to) external {
        _mint(to, 1);
    }

    function arm(address prebuyer_) external {
        prebuyer = prebuyer_;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        super.safeTransferFrom(from, to, tokenId, data);
        if (armed) {
            quote.approve(to, 1_000_000);
            IRaffle(to).buyEntries(prebuyer, 1);
        }
    }
}

contract AcceptingReceiver is IERC721Receiver {
    uint256 public callbacks;

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        ++callbacks;
        return IERC721Receiver.onERC721Received.selector;
    }

    function redeem(IRaffle raffle, uint256 ticketId) external {
        raffle.redeemWinningTicket(ticketId);
    }
}

contract RejectingReceiver { }

contract TicketOnlyReceiver is IERC721Receiver {
    address public acceptedTicketContract;
    uint256 public callbacks;

    function configure(address ticketContract) external {
        acceptedTicketContract = ticketContract;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == acceptedTicketContract, "prize not accepted");
        ++callbacks;
        return IERC721Receiver.onERC721Received.selector;
    }

    function redeem(IRaffle raffle, uint256 ticketId) external {
        raffle.redeemWinningTicket(ticketId);
    }
}

contract ReentrantTicketReceiver is IERC721Receiver {
    address public target;
    address public reentryRecipient;
    bool public attempted;
    bool public succeeded;

    function configure(address target_, address recipient_) external {
        target = target_;
        reentryRecipient = recipient_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        attempted = true;
        (succeeded,) = target.call(abi.encodeCall(IRaffle.buyEntries, (reentryRecipient, uint128(1))));
        return IERC721Receiver.onERC721Received.selector;
    }
}
