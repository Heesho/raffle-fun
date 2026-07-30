# Pyth Entropy v2 randomness

## Request

After the exclusive ticket-sale end and at least one sale, anyone calls
`requestDraw()` with the current oracle fee. The raffle:

1. requires `Active`, `now >= endTime`, `totalTickets > 0`, and no stored sequence;
2. reads `getFeeV2(callbackGasLimit)`;
3. moves to `DrawRequested` before calling the oracle;
4. calls `requestV2(callbackGasLimit)` and stores/emits its sequence;
5. credits excess native value to the requester for a pull refund.

The callback gas limit is captured at clone creation. Gas regression tests measure
actual mock callback use and require at least a 20% safety margin under the configured
300,000 limit. Production sizing must be rechecked against deployed bytecode and the
current oracle interface.

## Reveal and callback

Pyth Entropy combines provider and user-side commitments according to the Entropy v2
protocol. Provider reveal and callback delivery are not synchronous with the request.
Consult current Pyth network documentation and tooling during deployment; do not
assume a fixed reveal interval.

`IEntropyConsumer` authenticates the configured Entropy contract. `_entropyCallback`
then checks:

- raffle state is exactly `DrawRequested`;
- sequence equals the one stored by `requestDraw`;
- tickets are nonzero.

Unexpected callbacks emit `CallbackIgnored` and return so duplicate/replay delivery
cannot overwrite a valid result or create an avoidable liveness failure.

```text
winningTicketId = uint256(randomNumber) % totalTickets + 1
winner = ownerOf(winningTicketId) at callback time
```

The callback stores winner/outcome/claims, allocates the protocol fee and distributable
pot, zeroes the unsettled pot, and marks `Resolved`. It calls no ERC20, ERC721, user,
or oracle-provider contract.

## Failure and recovery

There is deliberately no second request, block-based fallback, admin-chosen result,
timeout refund, or alternate oracle. If delivery fails:

1. confirm the original sequence and callback transaction status;
2. diagnose callback gas, network, and provider reveal status;
3. use current official Pyth retry/replay tooling for the **same sequence**;
4. verify the callback emitted `RaffleResolved`;
5. refresh direct chain state and then the index.

Never deploy a custom recovery contract that submits a new random value or calls an
internal callback. A new protocol version may change future oracle strategy, but an
existing clone's sequence remains unique.

## Local tests

`MockEntropyV2` assigns deterministic sequences and fulfills chosen `bytes32` values
through the consumer entry point with the actual callback gas cap. Tests cover one
ticket, last ticket, arbitrary random words, wrong sequence, duplicate callback,
single request, refund accounting, storage-only behavior, and callback gas margin.

## Trust assumptions

- configured Entropy address and bytecode were verified for the target chain;
- provider commitments/reveals and callback services remain live;
- retry/replay remains available for the same sequence;
- Pyth's cryptographic and operational assumptions hold;
- Base supplies normal transaction ordering/finality.
