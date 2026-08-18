// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @dev Minimal callback surface implemented by Chainlink's direct-funding consumer base.
interface IVRFV2PlusConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

/// @title MockVRFV2PlusWrapper
/// @notice Deterministic local substitute for the Chainlink VRF v2.5 direct-funding wrapper.
contract MockVRFV2PlusWrapper {
    error InsufficientFee(uint256 requiredFee, uint256 suppliedFee);
    error UnknownRequest(uint256 requestId);

    event RequestRegistered(
        uint256 indexed requestId, address indexed consumer, uint32 callbackGasLimit, uint16 requestConfirmations
    );
    event RequestFulfilled(uint256 indexed storedRequestId, uint256 indexed callbackRequestId, uint256 randomWord);

    uint256 public fee = 0.001 ether;
    uint256 public latestRequestId;
    mapping(uint256 requestId => address consumer) public consumerByRequest;
    mapping(uint256 requestId => uint32 gasLimit) public gasLimitByRequest;
    mapping(uint256 requestId => uint16 confirmations) public confirmationsByRequest;
    mapping(uint256 requestId => uint32 wordCount) public wordCountByRequest;
    uint256 public lastCallbackGasUsed;
    bool public feeReadReverts;

    function setFee(uint256 newFee) external {
        fee = newFee;
    }

    function setFeeReadReverts(bool reverts_) external {
        feeReadReverts = reverts_;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256 requestPrice) {
        if (feeReadReverts) revert();
        requestPrice = fee;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256 requestPrice) {
        if (feeReadReverts) revert();
        requestPrice = fee;
    }

    function requestRandomWordsInNative(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes calldata
    ) external payable returns (uint256 requestId) {
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);
        requestId = ++latestRequestId;
        consumerByRequest[requestId] = msg.sender;
        gasLimitByRequest[requestId] = callbackGasLimit;
        confirmationsByRequest[requestId] = requestConfirmations;
        wordCountByRequest[requestId] = numWords;
        emit RequestRegistered(requestId, msg.sender, callbackGasLimit, requestConfirmations);
    }

    function fulfill(uint256 requestId, uint256 randomWord) external {
        fulfillAs(requestId, requestId, randomWord);
    }

    function fulfillAs(uint256 storedRequestId, uint256 callbackRequestId, uint256 randomWord) public {
        address consumer = consumerByRequest[storedRequestId];
        if (consumer == address(0)) revert UnknownRequest(storedRequestId);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        uint256 gasBefore = gasleft();
        IVRFV2PlusConsumer(consumer).rawFulfillRandomWords{ gas: gasLimitByRequest[storedRequestId] }(
            callbackRequestId, randomWords
        );
        lastCallbackGasUsed = gasBefore - gasleft();
        emit RequestFulfilled(storedRequestId, callbackRequestId, randomWord);
    }

    function link() external view returns (address) {
        return address(this);
    }
}
