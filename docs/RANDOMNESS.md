# Chainlink VRF v2.5

Each sold raffle accepts one request in the half-open interval
`[endTime, drawRequestDeadline())`, where `drawRequestDeadline()` is exactly two days
after `endTime`. Any account may pay the request's ETH cost; the raffle pot does not
reimburse it. If no request succeeds before the deadline, anyone may move the sold
`Active` raffle into full refunds.

## Request

`requestDraw` reads the current native direct-funding price with:

```solidity
calculateRequestPriceNative(300_000, 1)
```

It requests one word with:

- callback gas limit: 300,000;
- request confirmations: 30;
- word count: 1;
- `ExtraArgsV1.nativePayment = true`.

The 300,000 value is a gas-unit ceiling for callback execution, not a gas-price
ceiling. Network gas-price spikes raise the wrapper's native request quote; they do
not shrink the callback's 300,000-unit allowance. The limit is fixed because the
callback code is fixed and deliberately storage-only, with measured headroom. Making
it mutable would add an administrator/configuration surface to every raffle without
protecting against gas-price volatility.

Only the live fee is forwarded. Any `msg.value` excess is returned in the same
transaction; if that return fails, the entire request rolls back. Direct ETH transfers
to a raffle revert.

`Raffle` inherits the official `VRFV2PlusWrapperConsumerBase` and uses
`IVRFV2PlusWrapper` plus `VRFV2PlusClient` from the exact-pinned
`@chainlink/contracts@1.5.0` package. The protocol does not deploy or reimplement a
coordinator or wrapper. Native direct funding pays the existing official wrapper per
request, so a raffle does not create or manage a VRF subscription and no application
operator signup is part of the contract flow. Deployment validation pins the official
wrapper for Ethereum mainnet or Sepolia and checks its code and configuration. Current
network addresses must still be reverified against Chainlink's official
supported-network page at release time.

## Callback

Before the wrapper call, the raffle enters `Drawing`, records
`drawRequestedAt`, and enables an in-flight guard. A synchronous callback cannot
settle before the wrapper returns the request ID.

The inherited `rawFulfillRandomWords` accepts only the immutable wrapper and forwards
ABI-decoded values to the raffle's `fulfillRandomWords` override. Resolution also
requires:

- `status == Drawing`;
- the returned request ID equals `vrfRequestId`;
- the request is no longer in flight;
- exactly one random word;
- `block.timestamp < callbackDeadline()`.

Only wrapper-authenticated calls whose calldata ABI-decodes reach the override checks.
Synchronous, wrong-ID, wrong-word-count, stale, duplicate, and deadline-expired calls
emit `VrfCallbackIgnored` and do not mutate settlement. Unauthorized callers revert,
and calldata that cannot ABI-decode reverts before the ignore logic.

The callback computes:

```text
winningEntry = (randomWord % totalEntries) + 1
```

It then records either `NftWon` or `CashWon`. It never searches tickets, loops
over entries, calls a user, or moves ERC-20/ERC-721 assets. Current tests measure both
branches below 80% of the fixed callback limit.

## Liveness and ordering

Let `D = endTime + 2 days` and `C = drawRequestedAt + 2 days`. Requests are valid only
before `D`; sold-`Active` refunds are valid at and after `D`. Matching callbacks are
valid only before `C`; `Drawing` refunds are valid at and after `C`. The equality cases
are deliberately disjoint: a callback at `C` is ignored even when no refund transaction
has yet executed. A valid earlier NFT or cash result is final and has no later refund
timeout. Winning-ticket settlement is transfer-free. The current ticket owner later
burns it while receiving the winner NFT or cash atomically; sponsor and protocol
assets use independent release calls.

A request included at `D - 1` gives Chainlink a fresh two-day callback window, placing
the last nominal callback/refund boundary just under four days after sale end. This is a
bounded liveness tradeoff, not an automatic state transition. Censorship or a
reorganization that removes a request or callback after its respective cutoff prevents
replay and leaves the refund path as the supported recovery outcome.

## Security assumptions

Thirty confirmations substantially reduces ordinary reorganization exposure and is
within Ethereum VRF's supported range, but no finite confirmation count guarantees an
arbitrarily high economic value. Chainlink availability, Ethereum inclusion and
censorship, wrapper correctness, and callback gas pricing remain external risks.

Modulo reduction has a mathematically nonzero bias whenever `totalEntries` does not
divide the 256-bit domain. With a `uint128`-bounded total, the bias is
cryptographically negligible, but the protocol does not describe it as perfect
uniformity.

Official references:

- [Ethereum VRF v2.5 networks](https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-mainnet)
- [native direct funding](https://docs.chain.link/vrf/v2-5/direct-funding/get-a-random-number)
- [VRF security considerations](https://docs.chain.link/vrf/v2-5/security)
