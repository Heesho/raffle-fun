# Pyth Entropy v2

Each sold raffle accepts one request after `endTime` and before its three-day request
grace deadline. The contract obtains the dynamic fee with
`getFeeV2(callbackGasLimit)` and submits the same gas limit to
`requestV2(callbackGasLimit)`.

The caller may supply more than the current fee. Only the exact fee is forwarded and
the excess is returned immediately in the same transaction. If that return fails, the
whole request rolls back; the raffle does not retain native refund balances.

Before the external request call, the raffle enters `Drawing` and sets an in-flight
guard. A callback is accepted only from the immutable Entropy address, after the
request call has completed, for the stored sequence, and while status remains
`Drawing`. Wrong, in-flight, stale, late, or duplicate callbacks emit an ignored event
and return without changing settlement.

The callback performs bounded storage work only:

1. choose `(uint256(random) % totalTickets) + 1`;
2. calculate the 5% protocol fee for either successful branch;
3. record sponsor claims and, for cash fallback, the winning-ticket liability;
4. enter `NftWon` or `CashWon`.

It never calls an ERC-20, an ERC-721, or a user. The configured callback gas limit must
be measured against production bytecode with safety margin. The Foundry suite asserts
the local callback remains below 80% of that limit.

If no request succeeds by the grace deadline, or no callback succeeds within two days
of an accepted request, anyone calls the same `enableRefunds` function. This terminal
path charges no fee. A callback and timeout transaction may race at the deadline; the
first included valid transition determines the outcome.

The winner mapping has negligible but nonzero modulo bias whenever `totalTickets` does
not evenly divide the 256-bit random domain; it is not described as perfectly
unbiased. Entropy's default security model also assumes its provider and blockchain
validator/sequencer do not collude. The refund deadlines bound withholding and callback
liveness, but they cannot prevent Base transaction ordering or censorship. Sequence
zero, repeated sequences, changing/zero/extreme fees, synchronous callbacks, and
withheld callbacks are covered by the adversarial Entropy harness.

Official references:

- [request variants and dynamic fees](https://docs.pyth.network/entropy/request-callback-variants)
- [custom callback gas limits](https://docs.pyth.network/entropy/set-custom-gas-limits)
- [EVM integration](https://docs.pyth.network/entropy/generate-random-numbers-evm)
- [chain addresses](https://docs.pyth.network/entropy/chainlist)
- [callback debugging](https://docs.pyth.network/entropy/debug-callback-failures)
