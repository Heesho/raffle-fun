# First-Pass Solidity Source Review

Review timestamp (UTC): `2026-10-21T08:14:11Z`

Status: **UNSEALED**. This report remains unsealed until the controller creates `SEAL.json`. No `SEAL.json` was created by this review.

No external reconciliation was seen. The authoritative and complete review input was `context.json`; `response.schema.json` was used only as the output schema. No original target tree, git history, tests, reports, scanner output, memories, peers, internet material, or paths outside this review directory were inspected.

## Identity and provenance

| Field | Value |
|---|---|
| Snapshot hash | `d83129631037ed19fefb66eadb36bdf7c5da94d44b08cbccd50ef569628c3727` |
| Context hash | `e0b633c7b0f3d58e5e39b5bbe8ba1b3663cbdf47c1a4f163a465e5335277dd5b` |
| Context schema version | `1` |
| Methodology in context | `native-review-v1` |
| Selected local model alias | `gpt-daybreak-blue-latest` |
| Cyber access program | `daybreak_blue` |
| Requested reasoning effort | `ultra` |
| Provider-returned identity | `unknown` |

No provider or underlying model identity is inferred from the local alias or from self-identification.

## Conclusion

This source-only pass records **two observations**: one high-severity issue at the expressly untrusted prize-contract boundary and one low-severity cross-clone isolation issue. The reviewed source otherwise implements the requested ticket partitioning, owner-only burn-and-claim behavior, exact time inequalities, lossless USDC allocation, independent fixed-recipient releases, authenticated one-request randomness flow, and timeout refunds coherently under the assumptions below.

| Severity | Count |
|---|---:|
| High | 1 |
| Medium | 0 |
| Low | 1 |
| Informational | 0 |

The principal unresolved design conflict is that an arbitrary prize contract is declared untrusted while the protocol can establish custody and delivery only from that contract's own callbacks, transfer behavior, and `ownerOf` reports. The principal isolation mismatch is that clone screening is scoped to the current factory's registry rather than all raffle-clone deployments.

## Requirements and review assumptions

The implementation was assessed against these clean requirements from the context:

- an immutable, ownerless factory deploys fixed-target ERC-1167 clones;
- each entry costs exactly 1,000,000 raw units of canonical six-decimal USDC;
- each purchase mints one transferable ERC-721 ticket for a contiguous inclusive entry range;
- one ERC-721 prize is escrowed atomically during creation;
- reserve met: NFT to the winner, 95% of gross sales to the sponsor recipient, and 5% to treasury;
- reserve missed: 80% of gross sales to the winner, 15% to the sponsor recipient, 5% to treasury, and the NFT returned;
- full-refund outcome: 100% per entry is refundable and the NFT is returned;
- aggregate percentage calculations floor, and every remainder is allocated without loss;
- draw requests are permitted in `[endTime,endTime + 2 days)`; callbacks are accepted strictly before `drawRequestedAt + 2 days`; refunds become available at the applicable deadline;
- the callback records only the result; settlement is permissionless and storage-only;
- redemption requires the current winning-ticket owner, burns the ticket atomically, prevents double claims, and reverts all local effects when delivery fails;
- sponsor and treasury quote claims are independently releasable after settlement;
- no administrator, mutable configuration, upgrade, or cross-clone asset movement exists;
- canonical USDC and the Chainlink wrapper are trusted; prize contracts and ticket recipients are untrusted; and
- every terminal or failure state has a bounded exit, while frontend discovery is advisory and transactions recheck current state.

The conclusions use the following explicit assumptions:

- The configured quote token is the intended canonical USDC and has standard, fee-free, non-rebasing transfer semantics. The source validates only code presence and six-decimal metadata.
- The configured wrapper is the intended canonical Chainlink VRF v2.5 native direct-funding wrapper, authenticates fulfillment as shown by the embedded base contract, returns a valid request identifier, and supplies an unpredictable word.
- EVM transaction rollback is atomic across the raffle, factory, quote token, prize token, wrapper, and recipient calls that participate in a reverting call tree.
- Ordinary operational timestamps fit in `uint64`; the source would stop accepting new `uint64 endTime` values before the theoretical timestamp wrap horizon.
- OpenZeppelin and Chainlink inherited behavior is the behavior of the embedded dependency source. Package metadata pins `@openzeppelin/contracts` 5.6.1 and `@chainlink/contracts` 1.5.0, but no build artifact or deployed-bytecode match was available.
- Observation 1 deliberately does **not** assume an honest prize implementation. If prize contracts are instead trusted to preserve ERC-721 ownership and transfer semantics, that observation's path is excluded, but that would narrow the clean trust model.

## System, state, asset, and authority map

### Components and fixed bindings

| Component | Persistent role | Binding and mutability | Relevant external calls |
|---|---|---|---|
| `RaffleFactory` | Creates, initializes, registers, and funds clones | USDC, wrapper, treasury, and implementation are constructor immutables; no owner or setter | quote `decimals`; prize `supportsInterface`, `safeTransferFrom`, `ownerOf`; clone `initialize` and `status` |
| `Raffle` implementation | Fixed delegate target for one factory | Constructor fixes `factory`, quote token, and wrapper in bytecode; implementation storage is locked with `initialized = true` | wrapper request/price; USDC transfers; prize transfers/ownership; factory registry views |
| `Raffle` clone | Isolated ticket ledger, prize escrow, USDC liability ledger, and lifecycle | One-time factory initialization populates clone storage; no post-initialization configuration setter | same fixed quote token and wrapper; one configured prize contract |
| Ticket ERC-721 | Transferable bearer claim over one stored entry interval | Ownership and approvals use inherited OpenZeppelin ERC-721 state in each clone | safe-mint acceptance callback to a contract recipient |
| Chainlink wrapper | Prices, accepts, and fulfills one native-funded request | Fixed for the implementation and clones | authenticated `rawFulfillRandomWords` entry inherited from the embedded base |

### Lifecycle

```text
fresh clone
   | factory-only initialize
   v
AwaitingPrize
   | exact configured safe-transfer callback + factory postchecks
   v
Active
   | requestDraw: entries > 0 and endTime <= now < endTime + 2 days
   v
Drawing
   | authenticated matching one-word callback and now < requestedAt + 2 days
   +-------------------------------> NftWon   (entries >= reserve)
   +-------------------------------> CashWon  (entries < reserve)

Active  -- sold and now >= endTime + 2 days ----------------------> Refunding
Drawing -- now >= requestedAt + 2 days ----------------------------> Refunding
Active  -- empty: sponsor at any time, anyone at/after endTime ----> Refunding
```

`NftWon`, `CashWon`, and `Refunding` remain authoritative terminal result states. Quote claims and prize claims are individually consumed by zeroing a balance, burning a ticket, or setting a one-way flag; the status itself is not rewritten after those claims.

### Assets and accounting

| Asset | Inflow/custody | Accounted exit | Authority |
|---|---|---|---|
| Configured prize NFT | Factory calls the prize's `safeTransferFrom`; clone accepts only the configured token/id, sponsor as `from`, and factory as operator | NFT winner in `NftWon`; sponsor recipient in `CashWon` or `Refunding` | Winner redemption requires exact ticket owner; sponsor-prize release is permissionless to a fixed recipient |
| Canonical USDC | Buyer pays `entryCount * 1,000,000` into one clone | winner, sponsor recipient, treasury, or ticket refunds | Purchases by payer; winner/refund only by current ticket owner; sponsor/treasury releases permissionless to fixed recipients |
| Native token | Draw requester supplies wrapper fee | actual fee to wrapper; excess returned atomically to requester | Any caller during the request window |
| Ticket NFT | One safe-minted token per purchase | transferable; burned once for winning redemption or refund | Standard owner/approval transfer; claim functions require `msg.sender` to be current owner, not merely approved |

Tracked quote liabilities are

`unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees`.

Direct token donations and forced native currency are not added to that ledger and have no rescue path.

### Authority map

| Action | Authorized actor |
|---|---|
| Initialize clone | Immutable canonical factory only, once |
| Deposit/activate prize | Configured prize contract callback with factory operator, configured sponsor, exact token ID, and `AwaitingPrize` status |
| Buy | Anyone before exclusive sale end; ticket may be minted to a supplied safe recipient |
| Request draw | Anyone in the exclusive request window with sufficient native value |
| Fulfill randomness | Immutable wrapper only; request ID, word count, status, in-flight flag, and deadline are rechecked |
| Enable sold-raffle refunds | Anyone at the applicable request or callback deadline |
| Cancel empty raffle | Sponsor before end; anyone at or after end |
| Settle winning ticket | Anyone who supplies the unique ticket range containing `winningEntry` |
| Redeem winner/refund ticket | Exact current ticket owner only |
| Release sponsor/treasury quote claims | Anyone, but funds go only to fixed recipients |
| Release returned prize | Anyone, but NFT goes only to fixed sponsor recipient |

## Production-file coverage

All five production files embedded in `context.json` were reviewed in full. Source spans below are 1-based and refer to the representations in the context.

| Production file | Span reviewed | Coverage focus | Result |
|---|---:|---|---|
| `packages/contracts/src/Raffle.sol` | 1-614 | Initialization, state machine, entry/ticket ledger, transfers, requests/callbacks, settlement, every claim path, accounting, sink checks, reentrancy ordering | Reviewed; Observation 1 and Observation 2 |
| `packages/contracts/src/RaffleFactory.sol` | 1-186 | Immutable configuration, implementation deployment, clone atomicity/registration, prize validation and escrow postchecks, recipient filtering | Reviewed; Observation 1 and Observation 2 |
| `packages/contracts/src/interfaces/IRaffle.sol` | 1-521 | Full external ABI, status meanings, events/errors, stated claim/timing/accounting semantics, getters | Reviewed; declarations align with implementation ABI; comments were treated as untrusted data |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 1-150 | Creation parameters, registry ABI, immutable getter ABI, event/error contract | Reviewed; declarations align with implementation ABI; comments were treated as untrusted data |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 1-43 | Price, rates, deadlines, batch bound, maximum duration, VRF gas and confirmations | Reviewed; constants match the clean numerical requirements |

Relevant embedded dependencies were followed where inherited behavior matters: OpenZeppelin `Clones`, `ERC721`, `ERC721Utils`, `SafeERC20`, `ReentrancyGuard`, and `Math`, plus Chainlink `VRFV2PlusWrapperConsumerBase`, `IVRFV2PlusWrapper`, and `VRFV2PlusClient`. The embedded Foundry configuration specifies Solidity 0.8.36, Cancun, optimizer enabled with 200 runs, and no IR; `package.json` and `pnpm-lock.yaml` agree on the direct OpenZeppelin and Chainlink versions. This is metadata review only, not a compilation or dependency/runtime attestation.

## Property assessment

| Required property | Status | Source-only reasoning |
|---|---|---|
| Initialization and clone/factory binding | Satisfied | The implementation fixes `factory = msg.sender` when the factory deploys it, locks its own storage, and each fresh clone permits one initialization only from that immutable factory. Creation, registration, transfer, owner postcheck, active-status postcheck, and event occur in one reverting transaction. |
| Authorization and callback origin | Satisfied | Winner and refund functions require exact current ownership; settlement and fixed-recipient releases are intentionally permissionless. The embedded Chainlink base permits `rawFulfillRandomWords` only from the immutable wrapper, and the raffle rechecks status, request ID, length, in-flight state, and deadline. |
| Exact lifecycle/timestamp boundaries | Satisfied with one noted source extension | Sales require `now < endTime`; draw requires `endTime <= now < endTime + 2 days`; callback requires `now < drawRequestedAt + 2 days`; refund activation uses `now >=` the applicable deadline. The sponsor-only empty-raffle pre-end cancellation is an additional source behavior discussed under unresolved leads. |
| Prize custody and delivery atomicity | **Not satisfied under the stated trust model** | Factory and redemption postchecks are atomic against reverts, and effects roll back when a transfer/check fails. They nevertheless depend entirely on the untrusted prize contract continuing to honor its own state and transfers. Sponsor quote proceeds can leave before winner delivery. See Observation 1. |
| Ticket ranges and total accounting | Satisfied | Each positive purchase checks `uint128` headroom, assigns `[totalEntries + 1,totalEntries + entryCount]`, increments a sequential ticket ID, and stores the range. Positive range size also keeps `ticketCount <= totalEntries`, preventing independent ticket-counter exhaustion. |
| Ticket transfer and ownership | Satisfied, qualified by isolation issue | Inherited ERC-721 authorization governs transfers, while `_update` screens known protocol sinks. Current owner—not an approved operator—must redeem or refund. A foreign/future clone can evade the local registry screen; see Observation 2. |
| Winner selection | Satisfied subject to VRF assumption | A nonzero fixed `totalEntries` is closed before request; the callback maps one authenticated word to `[1,totalEntries]`; the winning range proof is unique because purchase ranges are contiguous and nonoverlapping. Modulo reduction has cryptographically negligible but nonzero mathematical bias unless `totalEntries` divides `2^256`. |
| Mint, burn, and double-claim prevention | Satisfied | Purchase accounting precedes safe mint under `nonReentrant`, and a rejecting recipient reverts the transaction. Winner/refund burns occur before delivery, but EVM rollback restores them on failure. One-way flags, recorded winning ID, burned ownership, and zeroed quote balances prevent repeat claims. |
| USDC solvency ledger | Satisfied under canonical-USDC assumption | Every sale adds exactly the requested gross after `safeTransferFrom`; every branch moves the full pot into mutually exclusive liabilities; each payout reduces its liability before transfer. Direct donations may make actual balance exceed accounted balance, but cannot create a tracked deficit under the assumed token semantics. |
| Reserve-met arithmetic | Satisfied | For gross `G`, treasury receives `floor(G*500/10000)` and sponsor receives `G-fee`; the sum is exactly `G`. Since `G = entries*1,000,000`, the valid-sale result is exactly 5%/95% with no fractional raw-unit remainder. |
| Reserve-missed arithmetic | Satisfied | Winner receives `floor(G*8000/10000)`, treasury receives `floor(G*500/10000)`, and sponsor receives the subtraction remainder. For valid `G`, the amounts are exactly 80%/5%/15%; in a generalized non-divisible amount both floors' remainders go to sponsor and no unit is lost. |
| Refund arithmetic | Satisfied | Refund activation moves the entire unsettled pot into refund liability. Each existing owner burns tickets, sums each inclusive range as `last-first+1`, receives exactly that entry count times 1,000,000, and reduces liability by the same amount. Duplicate/nonexistent/foreign IDs revert the whole batch. |
| Sponsor and treasury independent claims | Satisfied | Settlement writes separate balances. Each release independently reads and zeroes its own balance before a `SafeERC20` transfer to its fixed recipient; failure reverts that release without consuming the other claim. |
| Reentrancy and checks-effects-interactions | Satisfied for same-clone state, qualified by Observation 1 | All asset-moving public raffle functions and factory creation are guarded. Burns, flags, and liability zeroing precede outgoing interactions; failed interactions revert. Safe mint invokes an untrusted recipient only after purchase accounting. Request state is marked drawing and in-flight before the wrapper call. The untrusted prize can still deny or falsify the asset semantics themselves. |
| Randomness request, callback, and liveness | Satisfied at source level | Only one request can be accepted because status leaves `Active`; synchronous fulfillment is ignored while in flight; a valid callback records only entry/time/result; wrong, late, duplicate, or wrong-length callbacks are ignored; and anyone can open refunds at the callback deadline. Live gas/fulfillment adequacy remains a gap. |
| Cross-clone asset isolation | **Not satisfied** | Sink checks query only one factory registry. Foreign-factory clones and addresses that become clones later are not globally recognized. See Observation 2. |
| Configuration immutability | Satisfied, subject to deployment binding | Factory addresses and implementation are immutable; clone configuration is writable only during one initialization; no owner, setter, delegate target change, upgrade, pause, or rescue function is present. The source cannot authenticate that supplied dependency addresses are canonical. |
| Bounded exits for terminal/failure states | Partially satisfied | Active sold raffles and Drawing raffles reach permissionless deadline refunds; empty raffles can close; refund batches are capped at 100 tickets; result settlement is O(1); sponsor/treasury/prize claims are separate. An uncooperative prize contract can indefinitely block the NFT winner after sponsor proceeds leave (Observation 1), and foreign-clone destinations can strand assets (Observation 2). |
| Frontend discovery is advisory | Satisfied | Every state-changing path rechecks current status, timestamp, ownership, ranges, balances, and/or request identity in the transaction; no frontend-supplied discovery result is trusted. |

## Arithmetic derivation

Let `n = totalEntries` and `G = n * 1,000,000` raw USDC units.

- Protocol fee: `floor(G * 500 / 10,000) = n * 50,000`.
- Reserve met sponsor amount: `G - fee = n * 950,000`.
- Reserve missed winner amount: `floor(G * 8,000 / 10,000) = n * 800,000`.
- Reserve missed sponsor amount: `G - fee - winner = n * 150,000`.
- Refund for any ticket range of length `k`: `k * 1,000,000`.

Because 1,000,000 is divisible by 10,000, every reachable sale pot divides exactly for both percentages. The subtraction-based sponsor allocation would also absorb any floor remainder if the pot were generalized. In every branch, allocated quote liabilities sum exactly to the prior `unsettledPot`.

## Observations

The records below align exactly with `review.json` in title, description, severity, confidence, source, and assumptions.

### 1. Self-reported ERC-721 state cannot enforce prize custody or delivery against an untrusted prize contract

Severity: **high**  
Confidence: **high**

The factory accepts any contract that self-reports IERC721 support, activates the clone when that same configured contract calls onERC721Received with the expected arguments, and treats that contract's ownerOf response as escrow proof. After an NFT result, settleWinningTicket allocates the pot without rechecking prize custody, and releaseSponsorProceeds can pay the sponsor before the winner attempts delivery. A sponsor-controlled prize contract can therefore pass creation (or genuinely transfer the token and later pause, seize, or block it), allow sales, permit settlement and sponsor withdrawal, and then make transferFrom or ownerOf fail during redeemWinningTicket. The failed redemption atomically rolls back its local burn and flags, but it cannot roll back sponsor proceeds released in an earlier transaction. Under the stated untrusted-prize model, the winning bearer claim can be left without a bounded delivery path while 95% of gross sales has already left the raffle.

Source spans:

- `packages/contracts/src/RaffleFactory.sol:127-134`
- `packages/contracts/src/RaffleFactory.sol:154-178`
- `packages/contracts/src/Raffle.sol:304-345`
- `packages/contracts/src/Raffle.sol:375-381`
- `packages/contracts/src/Raffle.sol:416-430`
- `packages/contracts/src/Raffle.sol:533-557`

Assumptions:

- The clean requirement's untrusted-prize boundary includes sponsor-controlled transfer pausing or seizure, or false ERC-165 and ownerOf responses; if prizes are instead trusted to preserve standard ERC-721 ownership and transfer semantics, this path is excluded.
- At least one purchase occurs, reserveEntries is met, the correct winning ticket is settled, and sponsor proceeds are released before the winner's failed redemption.
- The canonical quote token and VRF wrapper behave according to the trusted-dependency assumptions.

### 2. Clone-isolation checks recognize only current clones of the same factory

Severity: **low**  
Confidence: **high**

Both creation-time validation and runtime destination screening consult only the current factory's isRaffle registry. A Raffle clone from another factory is absent from that registry while still reporting IERC721 support through inheritance. Concretely, factory B can accept existing clone A as a prize-token contract; transfer of an A ticket to the new B clone passes A's local destination screen, and B's expected-prize callback activates, moving an asset directly between raffle clones. A foreign clone can also be selected as sponsorRecipient or protocolTreasury, after which _transferQuote sends USDC into that clone as an unaccounted balance. The reviewed clone exposes no generic execute or rescue path for such USDC. These paths violate the absolute cross-clone isolation requirement and can strand assets, although they require a sponsor, deployer, or ticket owner to select or approve the foreign clone.

Source spans:

- `packages/contracts/src/RaffleFactory.sol:154-178`
- `packages/contracts/src/Raffle.sol:28-28`
- `packages/contracts/src/Raffle.sol:416-430`
- `packages/contracts/src/Raffle.sol:497-502`
- `packages/contracts/src/Raffle.sol:564-567`
- `packages/contracts/src/Raffle.sol:593-604`
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:44-49`

Assumptions:

- Two independently deployed reviewed factories and their clones exist, and neither factory registers the other's clones.
- A sponsor, factory deployer, or ticket owner deliberately selects or approves a foreign clone address; no external global registry reconciliation is assumed.
- For the payout-lock consequence, the foreign clone receives standard USDC and exposes only the reviewed code, with no separate control or rescue path.

## Unresolved leads not elevated to observations

- **ERC-721 receiver acceptance on outbound prize delivery.** Winner and sponsor prize delivery uses `transferFrom`, not `safeTransferFrom`, so a contract recipient is not asked to accept the NFT. The current winning-ticket owner must itself call redemption, the configured sponsor recipient was selected at creation, and the post-transfer `ownerOf` check establishes address-level delivery. Whether recipient-hook rejection must count as “delivery failure” is not explicit enough to elevate separately; OpenZeppelin's interface nevertheless warns that unsafe delivery can strand NFTs at incapable contracts.
- **Empty-raffle cancellation before `endTime`.** The sponsor can enter `Refunding` before the configured sale end only while `totalEntries == 0`; anyone can do so at `endTime`. This is a concrete source extension beyond the general “refunds open at deadline” wording, but no buyer liability exists in that branch. It was not elevated without an explicit requirement that an empty sale remain irrevocably available through its end.
- **Modulo reduction.** `randomWord % totalEntries` is not perfectly uniform unless the entry count divides `2^256`. With `totalEntries <= 2^128`, adjacent outcome probabilities differ by at most one preimage out of `2^256`; no practical manipulation path is visible under the trusted uniform-VRF assumption.
- **Forced or donated assets.** Direct ERC-20 donations, forced native currency, and unrelated NFTs sent with unsafe `transferFrom` are outside protocol accounting and unrecoverable because there is intentionally no rescue authority. They do not reduce tracked claim solvency under the trusted-token assumption, so this was treated as an explicit design consequence rather than an observation.

## Gaps and source-only limitations

These entries are identical to the `review.json` gaps:

- Source-only review: no assessed code was run; no compilation, tests, deployment, exploit, prover, scanner, or measured coverage evidence was produced or inspected.
- The context contains no deployment address manifest or runtime bytecode. Canonical-USDC, canonical-Chainlink-wrapper, treasury identity, and correct-chain binding therefore remain operator or deployment assumptions; the factory itself checks only code presence and six-decimal metadata for the quote token.
- Embedded package metadata pins OpenZeppelin 5.6.1 and Chainlink 1.5.0, but no build artifact or deployed-bytecode correspondence is available; inherited behavior was assessed only from dependency source embedded in context.json.
- The 300,000-gas callback limit and live wrapper request and fulfillment behavior were not measured. Source inspection shows a storage-only callback and timeout-to-refund path, but operational adequacy remains unverified.
- No original target tree, git history, tests, reports, scanner output, memories, peers, internet material, or external reconciliation was inspected.

No execution, compiler, test, prover, scanner, exploit, deployment, gas measurement, or measured property-coverage claim is made. The tables document source-review attention and reasoning only.

This report is unsealed until the controller creates `SEAL.json`; no external reconciliation was seen.
