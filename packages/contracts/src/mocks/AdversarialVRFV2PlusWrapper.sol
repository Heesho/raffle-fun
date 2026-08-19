// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVRFV2PlusConsumer } from "./MockVRFV2PlusWrapper.sol";

/// @notice Hostile-interface VRF wrapper used only to test integration failure modes.
contract AdversarialVRFV2PlusWrapper {
    error FeeReadFailed();
    error RequestFailed();
    error InsufficientFee(uint256 requiredFee, uint256 suppliedFee);
    error UnknownRequest(uint256 requestId);

    uint256 public quotedFee = 0.001 ether;
    uint256 public drawingQuotedFee;
    uint256 public requiredRequestFee = 0.001 ether;
    uint256 public nextRequestId;
    uint256 public fixedRequestId;
    bool public fixedRequestIdEnabled;
    uint8 public synchronousCallbackCount;
    int256 public synchronousRequestIdOffset;
    uint256 public synchronousRandomWord;
    bool public synchronousEmptyWords;
    bool public feeReadReverts;
    bool public drawingQuoteEnabled;
    bool public requestReverts;
    bool public persistRequest = true;
    bool public attemptReentry;
    bool public lastReentrySucceeded;
    uint32 public lastGasLimit;
    uint16 public lastConfirmations;
    uint32 public lastNumWords;

    mapping(uint256 requestId => address consumer) public consumerByRequest;
    mapping(uint256 requestId => uint32 gasLimit) public gasLimitByRequest;

    function configureFees(uint256 quoted, uint256 required) external {
        quotedFee = quoted;
        requiredRequestFee = required;
        drawingQuoteEnabled = false;
    }

    function configureQuoteDrift(uint256 activeQuote, uint256 drawingQuote, uint256 required) external {
        quotedFee = activeQuote;
        drawingQuotedFee = drawingQuote;
        requiredRequestFee = required;
        drawingQuoteEnabled = true;
    }

    function configureFailures(bool feeReadFails, bool requestFails, bool persists, bool reenters) external {
        feeReadReverts = feeReadFails;
        requestReverts = requestFails;
        persistRequest = persists;
        attemptReentry = reenters;
    }

    function configureRequestId(uint256 requestId, bool enabled) external {
        fixedRequestId = requestId;
        fixedRequestIdEnabled = enabled;
    }

    function configureSynchronousCallbacks(uint8 count, int256 requestIdOffset, uint256 randomWord, bool emptyWords)
        external
    {
        synchronousCallbackCount = count;
        synchronousRequestIdOffset = requestIdOffset;
        synchronousRandomWord = randomWord;
        synchronousEmptyWords = emptyWords;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256 fee) {
        if (feeReadReverts) revert FeeReadFailed();
        fee = quotedFee;
        if (drawingQuoteEnabled) {
            (bool success, bytes memory result) = msg.sender.staticcall(abi.encodeWithSignature("status()"));
            if (success && result.length >= 32 && abi.decode(result, (uint256)) == 2) fee = drawingQuotedFee;
        }
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256 fee) {
        if (feeReadReverts) revert FeeReadFailed();
        fee = quotedFee;
    }

    function requestRandomWordsInNative(uint32 gasLimit, uint16 confirmations, uint32 numWords, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        lastGasLimit = gasLimit;
        lastConfirmations = confirmations;
        lastNumWords = numWords;
        if (requestReverts) revert RequestFailed();
        if (msg.value < requiredRequestFee) revert InsufficientFee(requiredRequestFee, msg.value);

        requestId = fixedRequestIdEnabled ? fixedRequestId : ++nextRequestId;
        if (persistRequest) {
            consumerByRequest[requestId] = msg.sender;
            gasLimitByRequest[requestId] = gasLimit;
        }
        if (attemptReentry) {
            (lastReentrySucceeded,) = msg.sender.call(abi.encodeWithSignature("requestDraw()"));
        }
        for (uint256 index; index < synchronousCallbackCount; ++index) {
            uint256 callbackRequestId = uint256(int256(requestId) + synchronousRequestIdOffset);
            _callback(msg.sender, callbackRequestId, synchronousRandomWord, synchronousEmptyWords);
        }
    }

    function fulfill(uint256 requestId, uint256 randomWord) external {
        address consumer = consumerByRequest[requestId];
        if (consumer == address(0)) revert UnknownRequest(requestId);
        _callback(consumer, requestId, randomWord, false);
    }

    function fulfillAs(address consumer, uint256 requestId, uint256 randomWord) external {
        _callback(consumer, requestId, randomWord, false);
    }

    function fulfillEmpty(address consumer, uint256 requestId) external {
        _callback(consumer, requestId, 0, true);
    }

    function link() external view returns (address) {
        return address(this);
    }

    function _callback(address consumer, uint256 requestId, uint256 randomWord, bool emptyWords) private {
        uint256[] memory randomWords = new uint256[](emptyWords ? 0 : 1);
        if (!emptyWords) randomWords[0] = randomWord;
        IVRFV2PlusConsumer(consumer).rawFulfillRandomWords(requestId, randomWords);
    }
}
