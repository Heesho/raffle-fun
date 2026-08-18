# Chainlink VRF v2.5

Each sold raffle accepts one request any time after `endTime`. Any account may pay the
request's ETH cost; the raffle pot does not reimburse it. There is no request deadline,
so a nonempty raffle cannot fall into refunds merely because nobody has called yet.

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

The local interface and encoding match Chainlink's native VRF v2.5 wrapper surface.
Deployment validation pins the official wrapper for Ethereum mainnet or Sepolia and
checks its code and configuration. Current network addresses must still be reverified
against Chainlink's official supported-network page at release time.

## Callback

Before the wrapper call, the raffle enters `Drawing`, records
`drawRequestedAt`, and enables an in-flight guard. A synchronous callback cannot
settle before the wrapper returns the request ID.

`rawFulfillRandomWords` accepts only the immutable wrapper. Resolution also requires:

- `status == Drawing`;
- the returned request ID equals `vrfRequestId`;
- the request is no longer in flight;
- exactly one random word.

Wrong, malformed, synchronous, stale, late-after-another-transition, or duplicate
callbacks emit `VrfCallbackIgnored` and do not mutate settlement.

The callback computes:

```text
winningEntry = (randomWord % totalEntries) + 1
```

It then records either `NftWon` or `CashWon`. It never searches tickets, loops
over entries, calls a user, or moves ERC-20/ERC-721 assets. Current tests measure both
branches below 80% of the fixed callback limit.

## Liveness and ordering

If no matching callback settles within two days of an accepted request, anyone can
enable full refunds. A valid callback can still win the inclusion race at the timeout
boundary; once either transition executes, the other cannot overwrite it. A valid NFT
or cash result is final and has no later refund timeout. External settlement keeps all
ERC-20 and ERC-721 behavior out of the VRF callback.

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
