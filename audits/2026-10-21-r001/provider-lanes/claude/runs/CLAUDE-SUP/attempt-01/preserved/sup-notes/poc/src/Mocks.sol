// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Scratch mocks for the CLAUDE-SUP supplementary review. Not part of the audited scope.

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface Vm {
    function warp(uint256) external;
    function roll(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    function txGasPrice(uint256) external;
    function getNonce(address) external view returns (uint64);
    function assume(bool) external pure;
    function label(address, string calldata) external;
    function addr(uint256) external pure returns (address);
}

/// @dev Minimal six-decimal ERC20 with USDC-like blacklist (canonical-dependency stand-in).
contract MockUSDC {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public blacklisted;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function setBlacklisted(address account, bool value) external {
        blacklisted[account] = value;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 current = allowance[from][msg.sender];
        if (current != type(uint256).max) {
            require(current >= amount, "allowance");
            allowance[from][msg.sender] = current - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(!blacklisted[from] && !blacklisted[to], "blacklisted");
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @dev Behavioural model of the VRF v2.5 native direct-funding wrapper: prices from tx.gasprice, stores
///      callback address per request, deletes the callback before fulfilment, calls back with exact gas, and
///      swallows consumer failures (emits nothing, records result).
contract MockVRFWrapper {
    address public constant link = address(0x1111);
    address public constant linkNativeFeed = address(0x2222);
    uint256 public flatFee = 0.001 ether;
    uint256 public nextId = 7_000;
    uint256 public lastRequestId;
    bool public syncCallback;
    bool public disabled;

    struct Callback {
        address callbackAddress;
        uint32 callbackGasLimit;
    }

    mapping(uint256 => Callback) public callbacks;
    uint256 public lastCallbackGasUsed;
    bool public lastCallbackSuccess;
    uint256 public requestCount;

    function setSyncCallback(bool value) external {
        syncCallback = value;
    }

    function setDisabled(bool value) external {
        disabled = value;
    }

    function calculateRequestPriceNative(uint32 callbackGasLimit, uint32) public view returns (uint256) {
        require(!disabled, "wrapper disabled");
        return flatFee + tx.gasprice * (uint256(callbackGasLimit) + 150_000);
    }

    function estimateRequestPriceNative(uint32 callbackGasLimit, uint32, uint256 gasPrice)
        external
        view
        returns (uint256)
    {
        return flatFee + gasPrice * (uint256(callbackGasLimit) + 150_000);
    }

    function calculateRequestPrice(uint32, uint32) external pure returns (uint256) {
        return 0;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external pure returns (uint256) {
        return 0;
    }

    function requestRandomWordsInNative(
        uint32 callbackGasLimit,
        uint16,
        uint32 numWords,
        bytes calldata extraArgs
    ) external payable returns (uint256 requestId) {
        require(msg.value >= calculateRequestPriceNative(callbackGasLimit, numWords), "fee too low");
        require(extraArgs.length == 36 && extraArgs[35] == 0x01, "LINKPaymentInRequestRandomWordsInNative");
        requestId = ++nextId;
        lastRequestId = requestId;
        ++requestCount;
        callbacks[requestId] = Callback(msg.sender, callbackGasLimit);
        if (syncCallback) {
            uint256[] memory words = new uint256[](1);
            words[0] = 42;
            (bool ok,) = msg.sender.call{ gas: callbackGasLimit }(
                abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words)
            );
            lastCallbackSuccess = ok;
        }
    }

    function fulfill(uint256 requestId, uint256[] memory words) public returns (bool ok) {
        Callback memory cb = callbacks[requestId];
        require(cb.callbackAddress != address(0), "request not found");
        delete callbacks[requestId];
        uint256 before = gasleft();
        (ok,) = cb.callbackAddress.call{ gas: cb.callbackGasLimit }(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words)
        );
        lastCallbackGasUsed = before - gasleft();
        lastCallbackSuccess = ok;
    }

    function fulfillOne(uint256 requestId, uint256 word) external returns (bool) {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        return fulfill(requestId, words);
    }

    /// @dev Models a wrapper-authenticated call for an arbitrary (e.g. foreign) request id.
    function rawCall(address target, uint256 requestId, uint256[] memory words) external returns (bool ok) {
        (ok,) = target.call(abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words));
    }
}

/// @dev Honest OpenZeppelin ERC721 prize with an (honest) admin pause, as found in many real collections.
contract MockNFT is ERC721 {
    bool public paused;

    constructor() ERC721("Prize", "PRZ") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setPaused(bool value) external {
        paused = value;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        require(!paused, "paused");
        return super._update(to, tokenId, auth);
    }
}

/// @dev Non-compliant ERC721: per-token approval survives transfers (violates EIP-721 "approval reset").
contract StickyApprovalNFT {
    mapping(uint256 => address) internal _owner;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function mint(address to, uint256 tokenId) external {
        _owner[tokenId] = to;
        balanceOf[to]++;
    }

    function ownerOf(uint256 tokenId) public view returns (address o) {
        o = _owner[tokenId];
        require(o != address(0), "nonexistent");
    }

    function approve(address to, uint256 tokenId) external {
        require(msg.sender == ownerOf(tokenId), "not owner");
        getApproved[tokenId] = to;
    }

    function setApprovalForAll(address op, bool v) external {
        isApprovedForAll[msg.sender][op] = v;
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        address o = ownerOf(tokenId);
        require(o == from, "wrong from");
        require(msg.sender == o || getApproved[tokenId] == msg.sender || isApprovedForAll[o][msg.sender], "auth");
        _owner[tokenId] = to; // BUG (deliberate): getApproved[tokenId] is NOT cleared
        balanceOf[from]--;
        balanceOf[to]++;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "receiver"
            );
        }
    }
}

/// @dev Simple ERC721 receiver used as a contract ticket holder.
contract ReceiverWallet is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function exec(address target, bytes calldata data) external payable returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{ value: msg.value }(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return ret;
    }

    receive() external payable { }
}
