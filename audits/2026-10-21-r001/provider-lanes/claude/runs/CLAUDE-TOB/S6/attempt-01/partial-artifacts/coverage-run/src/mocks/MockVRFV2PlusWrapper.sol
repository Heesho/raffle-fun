// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

/// @notice Native-payment VRF v2.5 wrapper stand-in. Fulfillment mirrors VRFV2PlusWrapper: the callback receives exactly
///         the requested callback gas and a failing callback does not revert the wrapper.
contract MockVRFV2PlusWrapper {
    address public constant link = address(0x1111);
    uint256 public priceNative = 0.01 ether;
    uint256 public nonce;
    uint256 public lastRequestId;
    bool public syncCallback;
    mapping(uint256 => address) public consumerOf;
    mapping(uint256 => uint32) public gasLimitOf;

    event Requested(uint256 indexed requestId, address indexed consumer, uint32 callbackGasLimit, uint16 confirmations);

    function setPrice(uint256 price) external {
        priceNative = price;
    }

    function setSyncCallback(bool enabled) external {
        syncCallback = enabled;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return priceNative;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256 gasPriceWei) external view returns (uint256) {
        return priceNative + gasPriceWei;
    }

    function calculateRequestPrice(uint32, uint32) external view returns (uint256) {
        return priceNative;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external view returns (uint256) {
        return priceNative;
    }

    function linkNativeFeed() external pure returns (address) {
        return address(0);
    }

    function requestRandomWordsInNative(uint32 callbackGasLimit, uint16 confirmations, uint32 numWords, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        require(msg.value >= priceNative, "fee too low");
        require(numWords == 1, "numWords");
        requestId = uint256(keccak256(abi.encode(address(this), ++nonce)));
        consumerOf[requestId] = msg.sender;
        gasLimitOf[requestId] = callbackGasLimit;
        lastRequestId = requestId;
        emit Requested(requestId, msg.sender, callbackGasLimit, confirmations);
        if (syncCallback) {
            uint256[] memory words = new uint256[](1);
            words[0] = 42;
            (bool ok,) = msg.sender.call(abi.encodeCall(VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords, (requestId, words)));
            ok;
        }
    }

    /// @notice Delivers the recorded request's callback with exactly the requested gas (like `_callWithExactGas`).
    function fulfill(uint256 requestId, uint256[] memory words) external returns (bool ok, uint256 gasUsed) {
        address consumer = consumerOf[requestId];
        require(consumer != address(0), "request not found");
        delete consumerOf[requestId];
        uint256 before = gasleft();
        (ok,) = consumer.call{ gas: gasLimitOf[requestId] }(
            abi.encodeCall(VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords, (requestId, words))
        );
        gasUsed = before - gasleft();
    }

    /// @notice Delivers an arbitrary (possibly wrong-id or wrong-length) authenticated callback.
    function fulfillRaw(address consumer, uint256 requestId, uint256[] memory words) external returns (bool ok) {
        (ok,) = consumer.call{ gas: 300_000 }(
            abi.encodeCall(VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords, (requestId, words))
        );
    }
}
