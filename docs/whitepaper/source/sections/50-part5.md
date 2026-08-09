:::part id="part-v" no="Part V" title="Randomness and Deadlines"
One paid Pyth Entropy v2 request can resolve the raffle; two fixed deadlines bound
oracle-liveness failure.
- 19|Why an Oracle Is Needed
- 20|Pyth Entropy v2
- 21|Requesting the Draw
- 22|Callback Authentication
- 23|Selecting the Winner
- 24|Request Grace
- 25|Callback Timeout
- 26|The Boundary Race
:::

# Part V | Randomness and Deadlines

## 19. Why an Oracle Is Needed

Smart-contract execution is deterministic. Every validating computer must reach the
same result from the same transaction. A contract cannot privately roll dice.

raffle.fun does not let the sponsor, factory owner, frontend, or requester supply the
winning number. It does not use block timestamp, block hash, or `prevrandao` alone.
Those chain values can be visible or influenceable around inclusion and are not the
reviewed oracle design.

Pyth Entropy v2 separates the request from the later random callback. That separation
creates a liveness problem, so raffle.fun also defines what happens if the request or
callback never succeeds.

## 20. Pyth Entropy v2

Pyth Entropy is an external random-number service for EVM contracts. The raffle reads
the current fee for its immutable callback gas limit, pays that fee, and receives a
sequence number. A provider or keeper later submits a separate callback transaction
through the configured Entropy contract.

The protocol authenticates the wrapper and sequence, but oracle correctness is still
an external assumption. The default Entropy model, provider operation, fee policy,
keeper availability, and official deployment address must be independently verified
at deployment time.

:::figure src="diagrams/07-randomness-sequence.svg" num="7" title="Randomness request and callback" caption="The request and callback are separate Base transactions. The callback records only bounded settlement state and performs no token transfer."
:::

## 21. Requesting the Draw

`requestDraw` is payable and permissionless. It requires:

- `Active` status;
- at least one sold ticket;
- the sale to have ended;
- the current timestamp to be strictly before the request-grace deadline;
- native value at least equal to `getFeeV2(callbackGasLimit)`.

Before calling Entropy, the raffle enters `Drawing`, records `drawRequestedAt`, and
sets a private in-flight guard. It calls `requestV2(callbackGasLimit)` with exactly the
quoted fee, stores the returned sequence, and clears the guard.

If Alex supplies more native value than required, the raffle immediately calls Alex
with the exact excess. It does not keep a native pull claim. If Alex's account or
contract rejects the return, the entire request rolls back to `Active`; the raffle does
not consume its one request or retain the payment.

The USDC ticket pot never reimburses the requester. Request gas and Pyth's native fee
are separate operating costs.

## 22. Callback Authentication

The Pyth SDK exposes an external wrapper that authenticates the calling Entropy
contract before entering raffle.fun's internal callback. The raffle then accepts
settlement only if:

- the request is no longer in flight;
- status is exactly `Drawing`;
- the received sequence equals the stored sequence.

An in-flight, wrong-sequence, stale, duplicate, or post-refund callback emits
`EntropyCallbackIgnored` and returns without settlement. Ignoring instead of reverting
helps keep oracle delivery behavior observable without letting an obsolete callback
rewrite a terminal result.

The valid callback performs bounded storage work. It selects the ticket, calculates
fee and payout amounts, records quote liabilities, clears `unsettledPot`, and enters
`NftWon` or `CashWon`. It calls no USDC contract, prize contract, user, sponsor, or
treasury.

## 23. Selecting the Winner

:::figure src="diagrams/08-winner-selection.svg" num="8" title="Winner selection" caption="Modulo maps the authenticated 256-bit value into the complete one-based sold-ticket range."
:::

The formula is:

`(uint256(randomNumber) % totalTickets) + 1`

Modulo first returns a number from 0 through `totalTickets - 1`. Adding one maps it to
ticket IDs 1 through `totalTickets`.

- ticket 1 is reachable;
- the final sold ticket is reachable;
- a one-ticket raffle always selects ticket 1;
- no unsold ID is reachable;
- the formula is deterministic once the random value and sold count are known.

Modulo bias is negligible but nonzero unless the 256-bit input domain divides evenly
by the sold count. The contract does not attempt rejection sampling or a second oracle
request.

## 24. The Request Grace Period

The request-grace deadline is:

`endTime + {{REQUEST_GRACE_DAYS}} days`

At `endTime`, request is allowed. At the exact grace deadline, request is no longer
allowed and `enableRefunds` becomes allowed if tickets exist. This strict boundary
prevents a missing request from holding the prize and pot indefinitely.

Fee-read failure, changing fee, insufficient payment, Entropy request revert, or failed
native overpayment return leaves the raffle `Active`. Until the deadline, another
account may try again. At the deadline, failure finalization wins instead.

## 25. The Callback Timeout

The callback deadline is:

`drawRequestedAt + {{CALLBACK_TIMEOUT_DAYS}} days`

Before the deadline, `enableRefunds` reverts from `Drawing`. At the deadline, anyone
may call it. The function moves the entire `unsettledPot` into
`remainingRefundLiability`, enters `Refunding`, and emits whether a request had been
accepted.

The nominal deadline does not make a callback invalid by timestamp alone. The callback
checks status and sequence, not time. If no timeout transaction has been included yet,
a valid callback may still settle at or after the nominal deadline.

## 26. The Boundary Race

:::figure src="diagrams/13-timeout-refund.svg" num="9" title="Callback versus timeout" caption="At the exact callback deadline, both transactions may satisfy their own checks before inclusion. Base ordering determines which valid terminal transition executes first."
:::

At the callback deadline, two transactions can be valid against the same pre-state:

- Pyth's matching callback can enter `NftWon` or `CashWon`;
- any account's `enableRefunds` can enter `Refunding`.

The first transaction included against `Drawing` determines the result. If the callback
wins, timeout finalization later sees a terminal successful status and reverts. If
timeout wins, the later callback is ignored because status is no longer `Drawing`.

This is deterministic given transaction inclusion and order, but it does not remove
sequencer ordering, delay, censorship, or reorganization risk.

:::callout kind="risk" title="Oracle liveness is bounded, oracle trust is not removed"
Deadlines prevent indefinite waiting under normal chain inclusion. They do not prove
the random value correct, guarantee a callback, guarantee a refund transaction will be
included, or defeat a halted or universally censored chain.
:::
