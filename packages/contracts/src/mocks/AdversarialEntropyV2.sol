// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

/// @notice Hostile-interface Entropy substitute used only to test integration failure modes.
contract AdversarialEntropyV2 {
    error FeeReadFailed();
    error RequestFailed();
    error InsufficientFee(uint256 requiredFee, uint256 suppliedFee);
    error UnknownSequence(uint64 sequence);

    uint128 public quotedFee = 0.001 ether;
    uint128 public requiredRequestFee = 0.001 ether;
    uint64 public nextSequence;
    uint64 public fixedSequence;
    bool public fixedSequenceEnabled;
    uint8 public synchronousCallbackCount;
    int64 public synchronousSequenceOffset;
    bytes32 public synchronousRandomNumber;
    bool public feeReadReverts;
    bool public requestReverts;
    bool public persistRequest = true;
    bool public attemptReentry;
    bool public lastReentrySucceeded;

    mapping(uint64 sequence => address consumer) public consumerBySequence;
    mapping(uint64 sequence => uint32 gasLimit) public gasLimitBySequence;

    function configureFees(uint128 quoted, uint128 required) external {
        quotedFee = quoted;
        requiredRequestFee = required;
    }

    function configureFailures(bool feeReadFails, bool requestFails, bool persists, bool reenters) external {
        feeReadReverts = feeReadFails;
        requestReverts = requestFails;
        persistRequest = persists;
        attemptReentry = reenters;
    }

    function configureSequence(uint64 sequence, bool enabled) external {
        fixedSequence = sequence;
        fixedSequenceEnabled = enabled;
    }

    function configureSynchronousCallbacks(uint8 count, int64 sequenceOffset, bytes32 randomNumber) external {
        synchronousCallbackCount = count;
        synchronousSequenceOffset = sequenceOffset;
        synchronousRandomNumber = randomNumber;
    }

    function getFeeV2(uint32) external view returns (uint128 fee) {
        if (feeReadReverts) revert FeeReadFailed();
        fee = quotedFee;
    }

    function requestV2(uint32 gasLimit) external payable returns (uint64 sequence) {
        if (requestReverts) revert RequestFailed();
        if (msg.value < requiredRequestFee) revert InsufficientFee(requiredRequestFee, msg.value);

        sequence = fixedSequenceEnabled ? fixedSequence : ++nextSequence;
        if (persistRequest) {
            consumerBySequence[sequence] = msg.sender;
            gasLimitBySequence[sequence] = gasLimit;
        }
        if (attemptReentry) {
            (lastReentrySucceeded,) = msg.sender.call(abi.encodeWithSignature("requestDraw()"));
        }
        for (uint256 index; index < synchronousCallbackCount; ++index) {
            uint64 callbackSequence = uint64(int64(uint64(sequence)) + synchronousSequenceOffset);
            IEntropyConsumer(msg.sender)._entropyCallback(callbackSequence, address(this), synchronousRandomNumber);
        }
    }

    function fulfill(uint64 sequence, bytes32 randomNumber) external {
        address consumer = consumerBySequence[sequence];
        if (consumer == address(0)) revert UnknownSequence(sequence);
        IEntropyConsumer(consumer)._entropyCallback(sequence, address(this), randomNumber);
    }

    function fulfillAs(address consumer, uint64 sequence, bytes32 randomNumber) external {
        IEntropyConsumer(consumer)._entropyCallback(sequence, address(this), randomNumber);
    }
}
