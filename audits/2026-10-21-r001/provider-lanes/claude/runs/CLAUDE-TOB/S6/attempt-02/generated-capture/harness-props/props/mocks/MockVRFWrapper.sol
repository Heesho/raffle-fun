// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IRawFulfill {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

/// @notice GENERATED SCRATCH MOCK (S6 attempt-02) of the Chainlink VRF v2.5 native direct-funding wrapper surface used by
///         Raffle. It mirrors the real wrapper's observable contract: a native price quote, `fee too low` rejection,
///         `checkPaymentMode` validation of ExtraArgsV1{nativePayment:true}, and callbacks that never bubble consumer
///         reverts (the real wrapper only emits WrapperFulfillmentFailed). An optional mode exercises the defensive
///         in-flight guard with a synchronous in-request callback.
contract MockVRFWrapper {
    bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

    address public immutable link = address(0x000000000000000000000000000000000000c0Fe);
    address public linkNativeFeed;
    uint256 public fee;
    bool public syncCallback;
    bool public lastSyncCallbackSucceeded;
    uint256 public nextRequestId = 1;
    uint256 public lastRequestId;
    uint256 public requestCount;

    struct Request {
        address consumer;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint32 numWords;
        uint256 paid;
    }

    mapping(uint256 requestId => Request request) public requests;

    function setFee(uint256 newFee) external {
        fee = newFee;
    }

    function setSyncCallback(bool enabled) external {
        syncCallback = enabled;
    }

    /// @dev Must be `view`: Raffle reaches it through the view-declared interface (STATICCALL). Real wrappers price from
    ///      tx.gasprice, which is constant inside one transaction, so the paid price always equals the first quote.
    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return fee;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return fee;
    }

    function calculateRequestPrice(uint32, uint32) external view returns (uint256) {
        return fee;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external view returns (uint256) {
        return fee;
    }

    function requestRandomWordsInNative(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes calldata extraArgs
    ) external payable returns (uint256 requestId) {
        // Real VRFV2PlusWrapper.checkPaymentMode(extraArgs, false): ExtraArgsV1 with nativePayment == true.
        require(extraArgs.length >= 36, "IncorrectExtraArgsLength");
        require(bytes4(extraArgs[0:4]) == EXTRA_ARGS_V1_TAG, "bad extraArgs tag");
        require(extraArgs[35] == 0x01, "LINKPaymentInRequestRandomWordsInNative");
        require(msg.value >= fee, "fee too low");
        requestId = nextRequestId++;
        lastRequestId = requestId;
        requestCount += 1;
        requests[requestId] = Request(msg.sender, callbackGasLimit, requestConfirmations, numWords, msg.value);
        if (syncCallback) {
            uint256[] memory words = new uint256[](1);
            words[0] = uint256(keccak256(abi.encode(requestId, block.timestamp)));
            (bool ok,) = msg.sender.call{ gas: callbackGasLimit }(
                abi.encodeWithSelector(IRawFulfill.rawFulfillRandomWords.selector, requestId, words)
            );
            lastSyncCallbackSucceeded = ok;
        }
    }

    /// @notice Delivers words like the real wrapper: exact callback gas budget, consumer reverts are not bubbled.
    function fulfill(address consumer, uint256 requestId, uint256[] calldata words)
        external
        returns (bool ok, uint256 gasUsed)
    {
        uint256 before = gasleft();
        (ok,) = consumer.call{ gas: 300_000 }(
            abi.encodeWithSelector(IRawFulfill.rawFulfillRandomWords.selector, requestId, words)
        );
        gasUsed = before - gasleft();
    }
}
