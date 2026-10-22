# SUP-A2 independent first pass

Review: supplementary source-only authority, lifecycle, and cross-contract composition review.

Requested runner selection: `gpt-6-astra`, `ultra`, highest local setting. Provider-returned model identity was not available to this reviewer. This report is not a named harness execution and does not attest that a provider returned a particular model.

The review used only `DESIGN.md`, the five production Solidity files, and relevant imported dependency source from this clean snapshot:

`/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/clean-context`

No tests, historical audit reports, scanner findings, other reviewer findings, production checkout source, or memory were consulted. No production edits, compilation, transaction simulation, fuzzing, live-chain verification, or scanner execution were performed. Findings below were independently derived before sealing. File citations below are relative to the clean snapshot's `packages/contracts/` directory, except `DESIGN.md`.

## Result and qualification

No confirmed unauthorized fund theft, initialization takeover, duplicate payout, callback forgery, deadline race, or accounting-loss issue was established under canonical quote-token/wrapper assumptions and honest transferable ERC-721 prize semantics.

One low-severity configuration/composition issue is established by source: a future same-factory clone can be configured as a sponsor recipient before it has code or registry membership; subsequent clone deployment can strand that recipient's claims, and prize return can move an NFT into the other clone. It requires the sponsor to select that destination; no attacker-only method of redirecting an already configured honest recipient was found.

One conditional medium-impact trust-model issue remains unresolved: `DESIGN.md:2` calls arbitrary prize contracts untrusted, whereas `src/interfaces/IRaffle.sol:14-15` explicitly supports honest, standards-compliant prizes. A malicious/restricted prize can permanently prevent the NFT winner from obtaining a prize while sponsor and treasury withdrawals remain available. That is demonstrated source behavior, but its classification as a vulnerability depends on which stated prize assumption governs. It is not counted here as a confirmed medium finding under the interface's honest-prize model.

## Architecture and independent properties

### Actors and trust boundaries

- The factory constructor fixes quote token, wrapper, treasury, and a freshly deployed implementation (`src/RaffleFactory.sol:65-92`). There is no owner, upgrade, pause, recovery, arbitrary-call, or mutable-configuration entry point in the five production files.
- The implementation fixes `factory`, `quoteToken`, and the inherited wrapper/LINK addresses in bytecode. Constructor storage is locked with `initialized=true`, `status=Refunding` (`src/Raffle.sol:155-166`). ERC-1167 delegates to this fixed address; each clone uses its own storage (`node_modules/@openzeppelin/contracts/proxy/Clones.sol:32-62`).
- Sponsors choose a recipient, prize, reserve, and end time. Their only special later authority is early cancellation while no entries exist (`src/Raffle.sol:279-288`). They cannot alter reserve, timing, recipients, request ID, or random result after initialization.
- Ticket owners control bearer claims. Approved ERC-721 operators can transfer tickets but cannot directly refund or redeem without becoming owner (`src/Raffle.sol:320-325,357-364`; inherited ERC721 authority at `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:93-135,164-185,216-245`).
- Anyone can fund the draw, activate deadline refunds, prove the winning ticket, or trigger fixed-recipient payouts. Permissionless callers cannot choose payout destinations (`src/Raffle.sol:240-301,304-306,375-407`).
- Only the immutable wrapper can invoke accepted randomness (`node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:101-107`). The request ID, phase, time window, array length, and in-flight flag add local acceptance conditions (`src/Raffle.sol:509-524`).
- Quote-token transfers are trusted to be fee-free, non-rebasing transfers of the requested quantity. Factory code/decimals checks do not authenticate canonical USDC. The wrapper implementation and actual deployed USDC implementation are not included, only the direct consumer dependency and interfaces. Their operational behavior remains an explicit external assumption.
- Prize contracts and ticket recipients can execute arbitrary calls. The implementation does not delegate to them. Recipient acceptance, prize transfer, and owner verification have distinct consequences explained below.

### State machine

| Source state | Operation and authority | Preconditions | Destination/effects |
|---|---|---|---|
| Fresh clone, default enum value | `initialize`, factory only | Not initialized; nonzero and screened recipients | `AwaitingPrize`; fixed per-clone data |
| `AwaitingPrize` | `onERC721Received`, configured prize token | Exact token ID, sponsor `from`, factory `operator` | `Active` |
| `Active` | `buyEntries`, anyone | `now < endTime`; positive count; uint128 capacity | USDC collected; contiguous range; safe-minted ticket |
| `Active` with entries | `requestDraw`, anyone paying fee | `endTime <= now < endTime+2 days` | `Drawing`; one timestamp and one request ID |
| `Active`, zero entries | `enableRefunds` | Sponsor at any time, or anyone at/after end | `Refunding`; zero liability |
| `Active`, positive entries | `enableRefunds`, anyone | `now >= endTime+2 days` | `Refunding`; full pot becomes refund liability |
| `Drawing` | Authenticated callback | Correct ID, one word, not in flight, `now < requestedAt+2 days` | `NftWon` iff reserve met, otherwise `CashWon`; winning entry stored |
| `Drawing` | `enableRefunds`, anyone | `now >= requestedAt+2 days` | `Refunding`; full pot becomes refund liability |
| `NftWon` / `CashWon` | `settleWinningTicket`, anyone | Valid inclusive winning range; not settled | Same state; liabilities allocated once |
| `NftWon` / `CashWon` | `redeemWinningTicket`, current owner only | Valid winner, not redeemed | Same state; burn and payout atomically; implicit settlement if needed |
| `Refunding` | `refundTickets`, each current owner | 1–100 owned, existing IDs | Burn submitted tickets; reduce liability; full refund |
| `CashWon` / `Refunding` | `releaseSponsorPrize`, anyone | Prize not yet claimed | Fixed sponsor recipient receives prize |

No transition leaves a terminal status. `settlementComplete`, `winnerRedeemed`, and `prizeClaimed` add one-time substate; they do not reopen sales or randomness. There is no terminal refund transition after `NftWon`/`CashWon`.

### Independently derived invariants

1. **Creation atomicity and registry consistency.** The factory validates, increments the ID, creates and initializes, registers, transfers the prize, and then verifies owner and Active status (`src/RaffleFactory.sol:97-147`). Any failure reverts deployment, registration, count, and token operations in the transaction. Registration is transiently observable before prize transfer completes; it is not proof of finalized creation inside an arbitrary NFT callback.
2. **Initialization exclusivity.** Every fresh clone can be initialized only by its immutable factory, once (`src/Raffle.sol:176-205`). Clone deployment and initialization occur in one factory call without an intervening untrusted call. Before initialization, default AwaitingPrize cannot be activated by a real sender because `prizeToken` is zero. Constructor locking prevents direct implementation initialization. Reserve/timing checks are deliberately in the sole authorized initializer's factory, not duplicated in the clone.
3. **Entry-range partition.** Successful purchase adds `[oldTotal+1,oldTotal+count]`, with positive count and checked uint128 capacity; therefore ranges are disjoint, contiguous, and cover `[1,totalEntries]` (`src/Raffle.sol:215-235`). `ticketCount <= totalEntries` follows because every ticket contains at least one entry. Lifetime ticket count cannot overflow before the entry bound is exhausted.
4. **Winner uniqueness.** Drawing requires positive total entries; the callback produces a value in `[1,totalEntries]`. Exactly one stored range contains it. Unknown IDs have `[0,0]` and cannot validate a positive winning entry (`src/Raffle.sol:243,451-455,518-521,579-584`). Ranges remain after burns, but burns before settlement can occur only in Refunding, which cannot later resolve; winner burns occur after settlement. Thus historical ranges do not admit a second payable winner.
5. **Conservation.** Immediately after each purchase, total tracked quote liability rises by `entryCount * 1_000_000`. Settlement moves the entire unsettled pot into sponsor plus protocol, plus winner on CashWon. Sponsor gets the remainder, so no rounding unit disappears (`src/Raffle.sol:223-233,533-557`). Refund activation moves exactly the unsettled pot to refund liability. Each payout reduces its liability by the same requested transfer amount; failed transfer reverts that reduction. This holds under the trusted USDC transfer semantics, not for fee-on-transfer/rebasing tokens. Donations/forced transfers are intentionally unaccounted surplus without a rescue path.
6. **Math bounds.** Maximum gross is `(2^128-1)*10^6`, below `2^148`; multiplication by 8,000 remains below `2^161`. BPS denominator is nonzero. Current entry-price granularity means the 5% and 80% allocations are exactly representable, while remainder allocation also handles the general flooring case. Imported `Math.mulDiv` floors (`node_modules/@openzeppelin/contracts/utils/math/Math.sol:206-216`).
7. **Exclusive deadlines.** At `endTime`, buying is closed and draw initiation opens. At request deadline, requests are closed and sold-raffle refunds open. At callback deadline, callbacks are ignored and refunds open. There is no equality instant at which both result and refund are valid (`src/Raffle.sol:216,242-246,287,291,512`). A callback strictly before deadline irrevocably chooses the result; transaction order cannot convert that result to refunds later.
8. **Claim authority follows current ownership.** Settlement does not capture an owner. Redemption obtains owner immediately before burn and requires exact caller equality. Refunds do likewise per ID. Transferring a ticket after resolution or settlement therefore transfers the claim. An operator may transfer to itself using its existing ERC-721 authorization; this is the standard bearer-token authority, not an owner-check bypass.
9. **No protocol-controlled cross-clone pooling.** No function reads or transfers another clone's quote balance. Same-factory registered clone destinations are blocked for tickets and quote payouts. This property is narrower than the design's unrestricted no-cross-clone-assets statement; future and other-factory destinations are discussed in SUP-A2-01.

## Callback, reentrancy, rollback, and liveness analysis

### Initialization and arbitrary prize escrow

`createRaffle` is guarded across token interface detection, initialization, registration, safe transfer, and postconditions. Calls to `supportsInterface` and `ownerOf` are Solidity view calls, hence static calls; they may lie, revert, or consume gas but cannot mutate state through that static context. During `safeTransferFrom`, the prize can run arbitrary code and can activate the clone through its exact receiver callback. After activation, arbitrary prize code can cause independent calls to the fresh clone before factory postconditions run. For example it can purchase entries with its own approved USDC for a permitted recipient. All such effects are reverted if factory creation later fails. Factory reentry cannot create a nested raffle while its guard is held.

The receiver authenticates the token contract, configured ID, sponsor, and operator. It does not independently prove ownership; the factory subsequently checks `ownerOf`. A malicious token can forge these values because it controls its own state and reported ownership. This is a prize-authenticity assumption, not something ERC-165 proves.

### Purchase and transferable tickets

`buyEntries` holds the clone guard over USDC transfer, range/accounting effects, and safe mint (`src/Raffle.sol:209-237`). The recipient callback sees a fully allocated ticket/range/pot. It cannot reenter guarded economic functions. It may approve or transfer tickets through inherited ERC-721 functions, including the freshly minted ticket, because those functions are intentionally unguarded. The returned purchase ID remains the same bearer instrument; event `recipient` identifies initial mint recipient, not necessarily final owner after recipient-controlled forwarding. An invalid selector or recipient revert reverses payment, mint, range, transfers, and accounting (`ERC721.sol:279-290`; `ERC721Utils.sol:25-48`).

Inherited safe-transfer receiver callbacks occur after ownership changes. They can redeem/refund as the new owner when the relevant phase permits. That is consistent with claim transfer. A receiver that later reverts causes the whole outer transfer and nested claim operation to revert. No finance invariant depends on a ticket retaining the same owner after a safe-transfer callback.

### Wrapper request and fulfillment

The inherited native request helper requotes price and forwards that actual amount directly to the immutable wrapper (`VRFV2PlusWrapperConsumerBase.sol:76-89`). `requestDraw` requires caller value to cover both initial quote and actual paid price, then refunds only `msg.value-paidPrice`. Forced native balance cannot authorize an underfunded request: insufficient actual caller value reverts even if the contract had enough forced ETH for the wrapper call (`src/Raffle.sol:249-269`).

State changes to Drawing and `_requestInFlight=true` occur before the wrapper call. Synchronous callbacks are ignored until request ID storage is complete. Wrong ID, duplicate, late, wrong-length but ABI-valid callbacks are ignored. Malformed ABI reverts before the handler. Native excess refund uses a low-level call with zero output-copy buffer, avoiding an attacker-controlled returndata-copy burden. A requester rejecting a refund reverts its own complete request, including wrapper state/payment; another payer can request while the window remains open. All-gas forwarding lets the requester waste its own transaction's gas, not permanently stop an already committed draw.

`rawFulfillRandomWords` is not guarded, but only the trusted wrapper can enter. The handler performs no external calls and no ownership search. A callback triggered after the in-flight flag clears during a requester's refund callback could validly resolve the already recorded request; the guard does not need to reject this authenticated storage-only operation. Actual canonical wrapper behavior was not independently inspected because its implementation is absent from the supplied closure.

### Settlement, prize delivery, and quote release

Settlement itself is storage-only and independent of recipient code, USDC liveness, and prize delivery. Redemption burns the ticket and marks the one-time states before external delivery. A prize transfer revert, wrong `ownerOf`, quote transfer failure, or out-of-gas reverts the entire redemption, including an implicit settlement, ticket burn, and all external subcall effects (`src/Raffle.sol:309-346`). A prior separate settlement remains committed when a later redemption fails, as it should. Sponsor/treasury withdrawals remain independent after that prior settlement.

Prize delivery uses unsafe `transferFrom`, not ERC-721 safe transfer. This avoids mandatory recipient receiver acceptance; it does not stop the prize implementation from calling arbitrary hooks. The clone guard blocks every economic reentry. Current winning ticket is already burned; inherited transfers of other owned/approved tickets remain possible but do not duplicate claims. Post-transfer `ownerOf` is a static call and verifies reported final ownership, not honesty or future transferability of the token.

Sponsor prize release sets `prizeClaimed` before calling the token and verifies ownership afterward; revert restores its flag. Release is available immediately after CashWon, before quote settlement, without changing quote liabilities. Refund-mode prize release similarly does not consume refund balances. Sponsor and protocol quote functions clear only their own balance before transfer, so one failing recipient cannot consume or block another liability. Immutable blocked recipients may nevertheless have no alternate payout route.

### Bounded execution and external limits

- Purchases, callbacks, settlement proofs, individual redemption, and sponsor/protocol releases have no entry-count-dependent loop.
- A refund processes 1–100 ticket IDs. Each range can represent any permitted number of entries, so huge entry holdings do not force iteration over entries. A user may choose smaller batches. A duplicate ID is burned once then fails `ownerOf` on repetition, reverting the complete batch and preventing double refunds.
- The callback requests 300,000 gas and only reads/writes a bounded amount of local state. Source inspection indicates constant execution cost; exact compiled gas, compiler settings, wrapper overhead, and target-chain callback configuration were not measured. This review does not certify 300,000 gas by experiment.
- Arbitrary prize calls and recipient callbacks have no universal gas-success guarantee. Their failure is local and atomic, except that a permanently unavailable prize can permanently block terminal NFT delivery under the conditional trust-model issue below.
- Underpayment, wrapper disablement, invalid wrapper configuration, withholding, and missed callbacks ultimately permit full refund at the relevant deadline. A successfully accepted result has no later timeout or refund escape.

## Findings and unresolved issues

### SUP-A2-01 — Low: future clone recipients bypass destination screening and can strand claims

**Status:** Source-demonstrated configuration/composition issue. **Confidence:** High for behavior; medium for practical security relevance. **Attack authority:** A sponsor must select the destination, or an existing owner/approved operator must intentionally transfer a ticket to a future address. No method was found for an unauthenticated attacker to change someone else's fixed recipient.

**Locations:** `src/RaffleFactory.sol:163-168`; `src/Raffle.sol:193-195,395-406,564-566,593-604`; `Clones.sol:47-61`.

Destination safety is assessed using current address/code/registry state. A future same-factory clone has no code and is not yet in `isRaffle`, so a previously created raffle can store it as sponsor recipient. Clone addresses created with CREATE are determined by the factory address and nonce. Later creation of that clone does not revalidate recipient references held by older raffles. `releaseSponsorPrize` performs no fresh protocol-destination screen and uses unsafe transfer.

Concrete sequence using honest ordinary ERC-721 prizes:

1. Predict factory F's clone address B after creation of clone A. Configure A's sponsor recipient to the not-yet-deployed B and create A with prize P. B passes all checks because it differs from A/factory/implementation/token/wrapper and has no code/registry entry.
2. Create B through F with a different prize Q and ordinary permitted configuration. B is now a registered clone. Neither factory creation nor B initialization inspects A's fixed recipient.
3. With no entries in A, its sponsor calls `enableRefunds` immediately. Anyone then calls A's `releaseSponsorPrize`.
4. P is transferred from A to B using `transferFrom`; honest `ownerOf(P)==B` passes. A marks the prize claimed. B only knows its configured Q and exposes no rescue/arbitrary transfer route. P is permanently stranded in B. This directly contradicts `DESIGN.md:2`'s unrestricted “Never move assets between raffle clones.”

If A instead resolves with sponsor proceeds, quote release subsequently rejects B through the current registry, preserving the liability but making it unreachable because A's recipient is immutable. A similar counterfactual transfer of a ticket can leave its claim owned by B with no calling route.

An already deployed clone from a different factory also bypasses the local registry, broadening the restriction's limits. That case is an extension of the same scope issue, not a separate finding. It requires an additional factory and does not establish cross-clone draining.

**Suggested treatment:** At minimum, screen sponsor-prize destinations at delivery consistently with quote transfers to prevent an actual same-factory clone-to-clone transfer. That alone still leaves an immutable recipient's claim blocked. Decide explicitly whether future/noncanonical contract sinks are outside the guarantee; if they are supported, a recipient-authorized redirection mechanism or a different destination model is needed. Any redirection design must retain the originally entitled party's authority rather than introduce arbitrary-caller payout routing.

### SUP-A2-U01 — Conditional medium impact: untrusted prize can defeat final NFT delivery after proceeds become payable

**Status:** Unresolved specification/trust-boundary issue, not counted as a confirmed medium vulnerability under the honest-prize assumption. **Confidence:** High for source sequence; medium for classification. **Severity if arbitrary malicious prize issuers are in scope:** Medium, potentially all value for affected raffle participants; isolated to that configured prize/raffle.

**Locations:** `DESIGN.md:2`; `src/interfaces/IRaffle.sol:14-15`; `src/RaffleFactory.sol:127-134,171-178`; `src/Raffle.sol:329-337,375-391,533-557,279-294`.

Concrete adversarial-token sequence:

1. Sponsor supplies a prize contract P that reports ERC-721 support and correctly implements the initial escrow/owner checks. At creation it allows transfer to the clone and reports the clone as owner.
2. Buyers purchase enough entries to meet reserve, and an authenticated callback yields NftWon.
3. Anyone settles the valid winning ticket. Sponsor and treasury can immediately withdraw 95% and 5% of sales without prize transfer (`_settleWinningTicket` is deliberately storage-only).
4. P now reverts whenever the clone transfers to the winner, or its issuer activates a transfer restriction/removes the escrowed token. Every redemption reverts. Rollback correctly preserves the winner's ticket but does not provide a successful delivery path. NftWon cannot enter Refunding and previously withdrawn proceeds cannot be recovered.

No callback reentrancy is needed, and the honest wrapper/USDC remain uncompromised. ERC-165 and ownership checks cannot establish that an arbitrary contract will continue honoring transfers. Conversely, if the supported-prize model requires honest, continuously transferable tokens, the sequence violates that assumption and should be documented as an external limitation rather than advertised as a confirmed exploit.

**Resolution needed:** Reconcile the design's untrusted-prize wording with the interface assumption. Clarify whether “untrusted” means arbitrary callbacks under honest token ownership/transfer semantics, or also includes adversarial issuer semantics. A guarantee against dishonest prize semantics requires restricting supported prizes or changing economic settlement/recovery policy; generic ownerOf verification alone cannot prove it.

### External evidence gaps (not findings)

- Canonical deployed USDC and wrapper addresses/code/configuration are not established by constructor metadata or the provided interfaces. Six decimals plus code cannot prove token identity (`src/RaffleFactory.sol:65-91`).
- Actual callback gas consumption, wrapper gas forwarding/configuration, and confirmation feasibility were not measured. Source bounds are not a deployed-gas proof.
- USDC administrative freezes/pauses, wrapper outages, and immutable recipient incapacity can affect liveness. No privileged rescue exists; the code intentionally trades rescue authority for immutability. A blocked ticket owner can transfer a ticket only if the owner has an executable transfer route; fixed sponsor/treasury recipients cannot change themselves.
- Modulo selection introduces the usual finite-word modulo bias. With at most `2^128-1` entries and a 256-bit word, this is negligible and was not classified as a practical exploit.

## Per-file and function coverage

### Production

| File/function(s) | Lines | Coverage/result |
|---|---:|---|
| Raffle constructor, receive | 155-173 | Immutable authority; implementation lock; direct native rejection; forced ETH considered |
| initialize | 176-206 | One-time factory auth; rollback; destination checks; default clone state |
| buyEntries | 209-237 | Phase/time/overflow; payment; partition; mint callback and reentrant ticket transfers |
| requestDraw | 240-273 | Fee requote; in-flight protection; request capture; exact refund; revert propagation |
| enableRefunds | 276-301 | Sponsor exception; zero-entry handling; deadline equality; liability movement |
| settleWinningTicket / _settleWinningTicket | 304-306,533-558 | Permissionless proof; unique range; storage-only allocations; exact conservation |
| redeemWinningTicket | 309-346 | Current-owner auth; implicit settlement; burn-before-call; failed-delivery rollback |
| refundTickets | 349-372 | Bounded 1–100 loop; duplicates; own-ticket auth; full atomic rollback |
| releaseSponsorProceeds / releaseProtocolFees | 375-392 | Fixed destinations; independent liabilities; effects before external transfer |
| releaseSponsorPrize | 395-407 | Valid terminal states; one-time release; arbitrary token calls; missing dynamic destination check |
| onERC721Received | 416-431 | Exact configured deposit; phase transition; transient factory context |
| getVrfRequestPrice / estimateVrfRequestPrice / vrfWrapper | 436-448 | Trusted wrapper boundary; view-only behavior; price dependence |
| ticketRange / drawRequestDeadline / callbackDeadline | 451-465 | Historical data; unknown zero range; uint256 deadline arithmetic; unset request semantics |
| accountedQuoteBalance / grossSales / name / symbol | 468-487 | Accounting sum; bounded multiplication; clone metadata avoids constructor-storage reliance |
| _update | 497-502 | Inherited auth composition; transfer/burn behavior; current destination checks |
| fulfillRandomWords | 509-524 | Authenticated caller inherited; ID/length/time/in-flight gates; constant-work result |
| _transferQuote | 564-567 | Destination check; trusted token semantics; SafeERC20 failure propagation |
| _requireStatus / _requireWinningTicket | 573-585 | Phase gates; inclusive proof; zero/nonexistent ranges; burn reachability |
| _isProtocolDestination / _validatedVrfWrapper | 593-613 | Registry scope, code-less future addresses, static factory reads; nonzero wrapper |
| Generated Raffle getters/constants/state declarations | 33-142 | Layout purpose; phase vs terminal flags; no setter/upgrade route; isolated clone storage |
| Factory constructor | 65-92 | Code/decimal checks; immutable recipient checks; freshly deployed fixed implementation |
| Factory createRaffle | 97-148 | End duration bounds; CREATE; clone initialization; registration; arbitrary escrow call; postconditions/rollback |
| Factory _validateCreateParams / _requireContract | 154-185 | ERC-165 limitation; nonzero reserve; current registry checks; configured sinks |
| Factory getters/registry declarations | 24-54 | Monotonic successful IDs; current-only membership; no mutation outside atomic creation |
| IRaffle | 1-521 | All enums, params, errors, events, externally declared operations and getters; authority/liveness documentation; honest-prize assumption |
| IRaffleFactory | 1-150 | All params, events, errors, methods/getters; canonical-token deployment assumption |
| RaffleConstants | 1-43 | All economics, timeout, max batch/duration, callback gas, confirmations values |

### Imported behavior inspected

| Dependency | Relevant coverage |
|---|---|
| Chainlink `VRFV2PlusWrapperConsumerBase.sol` | Entire file: immutable dependency capture; native price/payment request; inherited raw callback sender auth; balance/LINK getters; unused LINK helper distinguished |
| Chainlink `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol` | Entire interfaces/library: native API, fee estimation, link getter, tagged native-payment args |
| OpenZeppelin `ERC721.sol` | Entire file: ownership/approval authority, transfer-before-receiver callback, update/mint/burn ordering, metadata/supportsInterface; no external burn API |
| OpenZeppelin `ERC721Utils.sol` | Entire file: code-length receiver check, magic value, revert propagation |
| OpenZeppelin `ReentrancyGuard.sol` | Entire file: namespace slot; entered=2 test; constructor initializes only implementation but clone zero is safe; first call writes 2 then 1; no reachable slot setter |
| OpenZeppelin `StorageSlot.sol` | Exact slot-return implementation including guard-used `getUint256Slot` at 93-97 |
| OpenZeppelin `SafeERC20.sol` | Public transfer wrappers and transfer/transferFrom assembly: token failure propagation, optional boolean return, code check; unrelated allowance/1363 helpers not used by production |
| OpenZeppelin `Clones.sol` | Actual CREATE clone overloads at 32-62; fixed implementation bytecode; deployment failure; no deterministic/immutable-args path used |
| OpenZeppelin `Math.sol` | Used `mulDiv` at 206-277 and its reachable bounded non-overflow branch; no generic audit of unused numerical APIs claimed |
| OpenZeppelin `Context.sol`, `ERC165.sol` | Entire files: caller equals `msg.sender`; interface-only behavior |

Imported interfaces and transitive utility source existed in the provided closure, but this report does not claim a standalone audit of every unused OpenZeppelin routine or the absent deployed dependency implementations. The review is a manual supplementary pass, bounded to the assigned first-pass window; source-derived properties are not substitutes for executable adversarial tests or deployment verification.
