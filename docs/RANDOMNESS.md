# Pyth Entropy v2 randomness

## One bounded request

After at least one sale and `endTime`, anyone may call `requestDraw` before the fixed
three-day grace deadline. The raffle reads `getFeeV2(callbackGasLimit)`, records
`DrawRequested` and `drawRequestedAt` before the external call, then calls
`requestV2(callbackGasLimit)`. A reverting fee read/request reverts the attempted
transaction and leaves the raffle eligible for deterministic grace-expiry recovery.
Excess native value becomes a pull refund for the requester.

The in-flight guard ignores a malicious synchronous callback before the returned
sequence has been stored. There is never a second request, block-derived fallback,
administrator-selected value, or replacement oracle.

## Callback

Pyth's `IEntropyConsumer` wrapper authenticates the configured Entropy contract. The
internal callback additionally requires `DrawRequested`, the stored sequence, and no
in-flight request. Wrong, stale, late-after-failure, and duplicate callbacks emit
`EntropyCallbackIgnored` and change nothing.

```text
winningTicketId = uint256(randomNumber) % totalTickets + 1
winner = ownerOf(winningTicketId) at callback execution
```

The callback performs bounded storage work only: it snapshots the winner, calculates
the aggregate fee and branch, credits pull claims, assigns the prize claimant, and
sets `Resolved`. It calls no ERC-20, ERC-721, user, or provider contract.

## Liveness failure

There are two deterministic permissionless exits:

1. If no request successfully completes by `endTime + 3 days`,
   `finalizeUnrequestedDraw` enters `Refunding`.
2. If the accepted sequence is unresolved at `drawRequestedAt + 2 days`,
   `finalizeTimedOutDraw` enters `Refunding`.

Both paths select no winner, charge no fee, assign the prize to the fixed recovery
recipient, and conserve the entire gross pot as ticket refunds. The same-sequence
callback may still resolve after its nominal deadline until the timeout transaction
wins. This first-included-transaction rule is explicit: it avoids an administrator
ordering choice, but at the boundary searchers may influence which already-valid
transition lands first.

## Deployment checks

- verify the official Entropy v2 address and bytecode for the exact Base network;
- confirm SDK 2.2.1 `getFeeV2(uint32)` and `requestV2(uint32)` interfaces;
- size the configured 300,000 callback gas limit against production bytecode;
- monitor requests, deadlines, callbacks, ignored callbacks, and failure events;
- exercise successful callback, unrequested failure, and timeout failure on testnet.

The supported guarantee does not cover a halted/reorganized chain, compromised oracle
randomness, lost claimant keys, or censorship of every recovery transaction.
