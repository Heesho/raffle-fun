// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

/// @title MockEntropyV2
/// @notice Deterministic local substitute for Pyth Entropy v2 with explicit callback fulfillment.
contract MockEntropyV2 {
    /// @notice Raised when a request supplies less than the configured mock fee.
    error InsufficientFee(uint256 requiredFee, uint256 suppliedFee);
    /// @notice Raised when a sequence has no registered consumer.
    error UnknownSequence(uint64 sequenceNumber);

    /// @notice Emitted when a mock request records its consumer and callback limit.
    /// @param sequenceNumber Deterministic request identifier.
    /// @param consumer Requesting raffle.
    /// @param callbackGasLimit Requested callback limit.
    event RequestRegistered(uint64 indexed sequenceNumber, address indexed consumer, uint32 callbackGasLimit);

    /// @notice Emitted after a selected sequence is delivered to a consumer.
    /// @param requestSequence Stored request used to find the consumer.
    /// @param callbackSequence Sequence delivered to the callback.
    /// @param randomNumber Chosen deterministic random value.
    event RequestFulfilled(uint64 indexed requestSequence, uint64 indexed callbackSequence, bytes32 randomNumber);

    /// @notice Current deterministic mock fee.
    uint128 public fee = 0.001 ether;
    /// @notice Last issued deterministic sequence.
    uint64 public latestSequenceNumber;
    /// @notice Consumer registered for each sequence.
    mapping(uint64 sequenceNumber => address consumer) public consumerBySequence;
    /// @notice Callback gas limit registered for each sequence.
    mapping(uint64 sequenceNumber => uint32 gasLimit) public gasLimitBySequence;
    /// @notice Gas consumed by the most recently delivered callback including call overhead.
    uint256 public lastCallbackGasUsed;

    /// @notice Changes the mock fee for fee-refresh and overpayment tests.
    /// @param newFee Replacement native-currency fee.
    function setFee(uint128 newFee) external {
        fee = newFee;
    }

    /// @notice Returns the configured fee for any callback limit.
    /// @return feeAmount Current deterministic fee.
    function getFeeV2(uint32) external view returns (uint128 feeAmount) {
        feeAmount = fee;
    }

    /// @notice Registers a deterministic sequence for the calling consumer.
    /// @param callbackGasLimit Requested callback limit.
    /// @return assignedSequenceNumber Monotonic request identifier.
    function requestV2(uint32 callbackGasLimit) external payable returns (uint64 assignedSequenceNumber) {
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);
        assignedSequenceNumber = ++latestSequenceNumber;
        consumerBySequence[assignedSequenceNumber] = msg.sender;
        gasLimitBySequence[assignedSequenceNumber] = callbackGasLimit;
        emit RequestRegistered(assignedSequenceNumber, msg.sender, callbackGasLimit);
    }

    /// @notice Delivers chosen randomness using the stored sequence as the callback sequence.
    /// @param sequenceNumber Stored request and callback sequence.
    /// @param randomNumber Chosen test randomness.
    function fulfill(uint64 sequenceNumber, bytes32 randomNumber) external {
        fulfillAs(sequenceNumber, sequenceNumber, randomNumber);
    }

    /// @notice Delivers chosen randomness with an independently selected callback sequence.
    /// @param requestSequence Stored request used to find the consumer.
    /// @param callbackSequence Sequence delivered to the consumer.
    /// @param randomNumber Chosen test randomness.
    function fulfillAs(uint64 requestSequence, uint64 callbackSequence, bytes32 randomNumber) public {
        address consumer = consumerBySequence[requestSequence];
        if (consumer == address(0)) revert UnknownSequence(requestSequence);
        uint256 gasBefore = gasleft();
        IEntropyConsumer(consumer)._entropyCallback{ gas: gasLimitBySequence[requestSequence] }(
            callbackSequence, address(this), randomNumber
        );
        lastCallbackGasUsed = gasBefore - gasleft();
        emit RequestFulfilled(requestSequence, callbackSequence, randomNumber);
    }
}
