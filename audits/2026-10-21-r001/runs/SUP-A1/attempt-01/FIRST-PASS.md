# SUP-A1 — independent supplementary accounting and custody first pass

## Provenance and limits

- Review started: 2026-10-21 07:41:34 UTC. Completion and SHA-256 are recorded in the adjacent `SEAL.json`.
- Input root: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/clean-context`.
- Read only the five production Solidity files, `DESIGN.md`, and relevant exact dependency sources under that root. No repository tests, existing audit reports, peer outputs, scanner results, external research, or historical memory informed this report. No production file was edited.
- This is a supplementary source review, not execution of a named audit harness. Runner selection was described to this reviewer as `gpt-6-astra` with `ultra` reasoning; provider-returned model identity is unknown and was not verified.
- Methods: manual state/asset-flow review, function-by-function coverage, source-level adversarial traces, and a standalone arithmetic calculation over 10 boundary vectors and 384 abstract refund orders. No Solidity compilation, contract execution, fork, fuzzing, gas measurement, or deployed dependency verification was performed.
- Source references below are relative to the input root, never to a potentially changing checkout. `Raffle.sol`, `RaffleFactory.sol`, and the production interfaces/library abbreviate their paths beneath `packages/contracts/src/`.

## Result

No confirmed high- or medium-severity accounting defect was established under the source's stated canonical fee-free quote-token, canonical wrapper, and honest ERC-721 assumptions. Aggregate allocation conserves the funded principal, refunds preserve remaining liabilities, and the winner's bearer claim follows current ownership through settlement.

One informational custody edge case is established by source inspection: a sponsor recipient that later becomes a same-factory clone can receive and permanently strand the returned prize, because prize release does not repeat the runtime destination screening used for quote payouts. This requires the sponsor to select that future address; no arbitrary redirection of an ordinary sponsor recipient was found.

The clean design's description of arbitrary prize contracts as untrusted conflicts with the interface's explicit honest-ERC-721 assumption. An adversarial prize can make the NFT undeliverable while the sponsor still withdraws the settled sale proceeds. That is a high-impact conditional lead, not a demonstrated bypass against an honest supported prize. The distinction is material to any final assurance statement.

## Established informational observation

### SUP-A1-I1 — Future clone recipient bypasses the prize-return sink policy

**Severity:** Informational / configuration-dependent asset stranding. **Behavior confidence:** High from source; not executed. **Unauthorized-theft confidence:** No unauthorized theft established.

**Locations:** `RaffleFactory.sol:154-179`, particularly 163-166; `Raffle.sol:193-195`, `Raffle.sol:395-405`, `Raffle.sol:593-604`; comparison with the runtime quote check at `Raffle.sol:564-566`. `Clones.sol:47-61` uses ordinary `CREATE` for each new clone.

**Preconditions:** The sponsor deliberately or mistakenly selects the predictable address of a future same-factory clone B as A's immutable `sponsorRecipient` while B has no code and is not registered. The address is not A itself, the implementation, the factory, the quote token, the wrapper, or A's prize contract. A uses an otherwise honest transferable ERC-721. B is later created with a different configured prize.

**Concrete sequence:**

1. Calculate the factory's forthcoming clone addresses from its creation sequence. Create A with its sponsor recipient set to the subsequent address B. The factory and A's initializer accept B because B is currently unregistered and code-less.
2. Any caller with a suitable prize creates the next raffle at B, giving B ordinary configuration and a different prize. Nothing in this creation checks older raffles' recorded sponsor recipients.
3. Put A into `Refunding`—zero sales plus the sponsor's immediate `enableRefunds()` is sufficient—or let A resolve `CashWon`.
4. Any caller executes `A.releaseSponsorPrize()`. The function sets `prizeClaimed`, performs unsafe `transferFrom(A, B, tokenId)`, and accepts `ownerOf(tokenId) == B`. It does not call `_isProtocolDestination` at release time.
5. B now owns an unrelated NFT. B can release only its configured prize and has no rescue path, so A's returned NFT is stranded. B's restrictive `onERC721Received` is bypassed by the unsafe transfer.

**Impact and bounds:** This violates a literal global promise that prize assets never move between same-factory clones and defeats the apparent sink-prevention purpose of initialization. It does not steal another raffle's quote balance, alter winner selection, or reduce buyers' refunds. The sponsor selected the future sink; an adversary cannot turn an arbitrary existing EOA recipient into a clone at will. If A has sponsor quote proceeds after B's creation, `_transferQuote` rejects B and preserves those liabilities on revert instead of delivering them; the immutable recipient still makes them unavailable.

**Suggested response:** Repeat the current sink check in `releaseSponsorPrize` to prevent the actual cross-clone transfer. That change alone does not recover a fixed claim whose recipient has become a sink. Define the supported recipient requirement and explicitly document future-address limitations, or separately design a recipient recovery mechanism if desired. Do not describe a runtime rejection as complete recovery.

## Conditional and unresolved leads

### SUP-A1-L1 — Prize-delivery trust assumption changes the economic guarantee

**Potential severity:** High if arbitrary malicious prize contracts must not monetize an undeliverable prize; not promoted to a confirmed finding under the source's honest-prize restriction. **Behavior confidence:** High; **scope classification confidence:** Unresolved.

`DESIGN.md:2` calls arbitrary prize contracts untrusted. Conversely, `interfaces/IRaffle.sol:12-15` says supported prizes are honest, standards-compliant ERC-721s. The only admission checks are deployed code and self-reported ERC-721 support (`RaffleFactory.sol:154-177`), followed by the chosen token's own callback and `ownerOf` responses (`RaffleFactory.sol:127-133`, `Raffle.sol:416-430`). Neither establishes future deliverability or honesty.

**Adversarial sequence:** A sponsor controls a token contract that accepts the initial transfer and reports the expected escrow owner. Buyers fund a reserve-met raffle. After the accepted draw, anyone settles the winning ticket (`Raffle.sol:533-557`), allocating 95% to the sponsor and 5% to the treasury without touching the prize. The sponsor withdraws its amount (`375-381`). The token then reverts every outbound transfer from the raffle, or reports a wrong owner after pretending to transfer. Winner redemption reverts (`329-337`), but the completed earlier settlement and sponsor payment are separate transactions and cannot roll back. Terminal `NftWon` cannot enter refunds (`276-299`). The winner's ticket remains intact but cannot obtain either the prize or a replacement cash remedy.

This does not compromise other raffles, and malicious tokens can also lie about `ownerOf`, making the post-transfer verification appear successful. The source checks protect against inconsistent reported ownership, not an arbitrary token's dishonesty. A paused or administratively restricted prize can produce the same liveness shape without a reentrancy exploit.

**Needed resolution:** Decide whether the intended guarantee is honest-prize custody isolation or guaranteed economic delivery despite arbitrary token behavior. The latter is not established by these sources. A targeted malicious-prize execution trace and a threat-model decision are the next useful steps; neither was performed here. Simply delaying sponsor payment until one winner redeems would create its own winner-controlled liveness problem and is not presented as a complete fix.

### SUP-A1-L2 — Supported quote-token behavior and transfer availability remain deployment assumptions

**Severity:** Dependency/configuration risk; no in-scope accounting exploit established. **Confidence:** High about the conditional accounting result; deployed-token behavior unknown.

The factory validates code and six decimals only (`RaffleFactory.sol:65-78`). Purchases credit nominal `entryCount * ENTRY_PRICE` after SafeERC20 success without measuring a balance delta (`Raffle.sol:223-233`); payouts clear nominal claims after SafeERC20 success (`338-342`, `367-369`, `375-390`, `564-566`). A fee-on-transfer, rebasing, false-success, or later changed token can break solvency or delivery, but such behavior is expressly excluded by `interfaces/IRaffle.sol:12-15` and the clean design's canonical-token trust assumption.

A transfer-reverting recipient or frozen raffle preserves the corresponding claim on revert but has no guaranteed exit through these contracts. Winner/refund owners can ordinarily transfer their ticket to another eligible owner; immutable sponsor and treasury recipients cannot be changed. The actual canonical token implementation and administrative state were not supplied, so no current blacklist/pause behavior or deployment identity is asserted.

### SUP-A1-L3 — Safe receipt does not prove a contract can exercise its bearer claim

**Severity:** Informational integration limitation; not a confirmed protocol vulnerability. **Confidence:** High.

An arbitrary receiver may accept `_safeMint` or `safeTransferFrom` yet have no method to transfer or redeem the ticket. Such a ticket can remain unclaimable, including the final refund or winning ticket. Existing protocol sinks are rejected at `Raffle.sol:497-501`, but arbitrary recipients, foreign-factory clones reached via unsafe transfer, counterfactual addresses, and contracts that later change behavior are not comprehensively classified. The caller pays for its own chosen purchase recipient, and the legitimate owner controls normal transfers; no involuntary loss by an ordinary owner was found. This is a limit on claims of universal last-actor exit, not a balance-conservation failure.

## Independently derived properties and adversarial checks

Let `N = totalEntries`, `G = N * 1_000_000`, `U = unsettledPot`, `R = remainingRefundLiability`, `W = winnerProceeds`, `S = sponsorProceeds`, `F = protocolFees`, and `L = U + R + W + S + F`. Let `Paid` be the sum of successfully delivered protocol quote-token payouts and refunds, excluding arbitrary token donations. The following conclusions assume ordinary EVM transaction rollback, the frozen dependency behavior, and the stated canonical fee-free quote-token semantics.

1. **Nominal conservation:** After any completed protocol transaction, `L + Paid = G`. Successful purchases increase both `G` and `U` by the same positive amount (`223-235`). Enabling refunds moves all `U` into `R` once (`296-299`). Settlement moves all `U` into disjoint final liabilities once (`533-555`). A successful claim reduces exactly one liability by its transferred amount; a reverted transfer restores that liability.
2. **Balance relation:** With no unrelated transfers, actual quote balance equals `L`. With standard positive unsolicited donations, actual balance is at least `L`; donations do not increase `G`, probability, or any liability. Exact equality to raw balance is therefore not a universal invariant. There is no sweep function, so donated surplus remains unallocated.
3. **No legal rounding dust:** Every lawful pot is an integer multiple of 1,000,000. Consequently `F = 50_000*N`; cash results have `W = 800_000*N` and `S = 150_000*N`; NFT results have `S = 950_000*N`. The percentages are exact for every reachable `N`, despite the general floor/remainder comments. Splitting purchases or refund batches cannot improve these amounts. `Math.mulDiv` uses floor division (`Math.sol:199-215`).
4. **Representational bounds:** `N <= 2^128-1` by purchase admission (`219-220`), and every ticket contains at least one entry, so `ticketCount <= N`. The increment cannot overflow before the entry bound blocks another purchase. `G < 2^148` and even `G*8000 < 2^161`, safely within uint256. A valid refund batch contains only disjoint existing tickets, so its aggregate entries are at most `N`; the loop accumulator cannot overflow.
5. **Range partition:** Successful purchases allocate `[oldN+1, oldN+entryCount]` to a fresh sequential ticket (`226-233`). Historical ranges are immutable. They partition `[1,N]` without overlap. Burning does not make a historical range spendable again because ownership is checked separately for refunds/redemption. Callback selection is always in `[1,N]` after a request that required `N > 0` (`243`, `518`); nonexistent `(0,0)` ranges cannot prove the winning entry (`579-584`).
6. **Bearer ownership:** Permissionless settlement fixes a range, not an owner (`538-555`). Redemption reads the current `ownerOf`, requires that exact caller, burns before asset interaction, and pays that same owner (`320-342`). A transfer after draw or settlement carries the claim to the new owner. Former owners and approved operators cannot directly redeem/refund without first becoming owner, although an approved ERC-721 operator can transfer pursuant to its existing authority. Burns clear approvals in the inherited ERC-721.
7. **Duplicate refunds and replay:** A duplicate ID in one refund batch encounters a nonexistent token after its first burn; the entire call reverts, restoring previous burns. A foreign-owned or nonexistent later ID similarly restores earlier effects. A successfully refunded ID cannot be refunded again. The final valid refund subtracts the exact remaining principal to zero; no final-claimant arithmetic dust was found (`349-371`).
8. **Terminal exclusivity:** Full refunds can begin only from Active or Drawing. Settlement/redemption require NftWon/CashWon. A successful callback and a refund transition cannot both allocate the same `U`. At request deadline, new requests fail and refunds are permitted; at callback deadline, callbacks are ignored and refunds are permitted. There is no timestamp overlap where both terminal choices remain valid (`240-299`, `509-523`).
9. **Independent economic exits:** After settlement, sponsor and treasury can independently release their balances without the winner acting (`375-390`). Cash winner payment and sponsor prize return are independent. A reverting sponsor or prize transfer cannot globally revert a separate already-completed fee/refund transaction. Conversely, no later failed NFT redemption retroactively undoes previously paid sponsor proceeds; see L1.
10. **No cross-raffle balance authority:** Each clone holds its own storage and token balance. No production method names another raffle as a spending source. Known same-factory ticket recipients and quote destinations are checked at use time (`497-501`, `564-566`, `593-604`). This supports ledger isolation, but it is narrower than a universal prohibition on all asset movement between arbitrary clones; I1 is a concrete exception for returned prizes.
11. **Atomic purchase failure:** Quote transfer occurs before ticket/accounting writes, but the raffle's nonReentrant guard spans the operation. Failure of recipient screening, minting, or the receiver callback rolls back the token transfer and all counters. A receiver can transfer its newly minted ticket during its callback; the range and principal remain attached to the ticket, so this does not create unpaid entries. Reentrant guarded financial operations are rejected.
12. **Atomic redemption/refund failure:** Flags, burns, and decrements precede external delivery. Token revert, SafeERC20 false return, or wrong reported NFT ownership reverts all effects of that transaction. If settlement happened earlier, it remains earlier state; if settlement happened inside the failing redemption, it rolls back too. This distinction prevents overstating rollback guarantees.
13. **Atomic factory failure:** Clone creation, initialization, registration, prize transfer, escrow verification, and final Active check are one transaction (`RaffleFactory.sol:97-147`). A failure rolls back the clone, counters, registry, and token effects. Static metadata/ownership calls cannot mutate state. A malicious prize may invoke the activation callback then call into the clone before its outer transfer returns, but the final checks and transaction rollback still apply; no unpaid-principal or cross-clone spending path was found.
14. **Native funding conservation:** The wrapper's native helper returns the price it forwarded (`VRFV2PlusWrapperConsumerBase.sol:76-88`). A successful request requires `paidPrice <= msg.value` and refunds exactly `msg.value-paidPrice` (`249-269`), so it cannot consume a preexisting forced native balance to subsidize the caller. Refund rejection or wrapper failure reverts the entire wrapper request transaction. Ordinary direct native transfers are rejected; forced native balances have no sweep path.
15. **Callback isolation:** Only the immutable wrapper can invoke the inherited raw callback (`VRFV2PlusWrapperConsumerBase.sol:101-106`). In-flight, wrong-request, wrong-length, duplicate, and late callbacks cannot allocate liabilities (`509-523`). The callback performs no ownership lookup, ticket loop, or token transfer. `_requestInFlight` excludes synchronous resolution before request persistence. Exact callback gas sufficiency was not measured.
16. **Clone guard initialization:** Although clone storage does not run the constructor, the frozen ReentrancyGuard tests specifically for value `ENTERED == 2`; a fresh zero slot is accepted, set to 2 during the first guarded call, then set to 1 (`ReentrancyGuard.sol:88-113`). This is not an uninitialized-guard bypass. Implementation initialization is locked in its constructor (`Raffle.sol:164-165`); canonical clone initialization requires the immutable factory (`176-179`).

The standalone arithmetic calculation checked `N = 1,2,3,19,20,21,99,100,2^128-2,2^128-1`, exact allocations, sum conservation, and multiplication bounds. It also checked all six refund orders for each three-ticket vector with individual counts in `[1,4]` (64 vectors, 384 orders). These calculations corroborate arithmetic claims only; they do not constitute contract test coverage.

## Explicit production-file and function coverage

All five production files were read in full: 1,514 lines including declarations/comments. Coverage means source inspection, not executed line coverage.

### `Raffle.sol` — 614 lines

| Function / surface | Lines | Accounting/custody review |
| --- | --- | --- |
| constructor | 155-166 | Fixed factory/quote/wrapper, locked implementation, clone storage distinction |
| receive | 171-173 | Direct-native rejection; forced-balance limitation |
| initialize | 176-206 | One-time authority, immutable recipients, destination screening, AwaitingPrize |
| buyEntries | 209-237 | Transfer-to-liability equality, range partition, overflow, mint rollback/reentrancy |
| requestDraw | 240-273 | Sale/time admission, external funding, actual fee refund, cross-contract rollback |
| enableRefunds | 276-301 | Empty/sold/drawing deadlines, one-time pot reclassification |
| settleWinningTicket | 304-306 | Permissionless wrapper and guarded allocation |
| redeemWinningTicket | 309-346 | Current owner, atomic burn/payment, prior versus in-call settlement, NFT verification |
| refundTickets | 349-372 | Batch bounds, duplicates, foreign IDs, full principal, final claimant |
| releaseSponsorProceeds | 375-382 | Full current claim, zero-before-send, independent release, immutable destination |
| releaseProtocolFees | 385-392 | Full current claim, zero-before-send, independent release, immutable destination |
| releaseSponsorPrize | 395-407 | Eligible branches, one prize flag, transfer verification, future-sink observation I1 |
| onERC721Received | 416-431 | Exact token/id/sponsor/operator gating, activation, arbitrary-token trust boundary |
| getVrfRequestPrice | 436-438 | Immutable wrapper quote, no quote-pot spending |
| estimateVrfRequestPrice | 441-443 | Estimate-only wrapper interface |
| vrfWrapper | 446-448 | Immutable wrapper getter |
| ticketRange | 451-455 | Historical ranges, zero defaults, no ownership assertion |
| drawRequestDeadline | 458-460 | Widened timestamp addition, exclusive request bound |
| callbackDeadline | 463-465 | Zero-before-request, fixed request-relative bound |
| accountedQuoteBalance | 468-470 | Exactly the five current liabilities; donations intentionally absent |
| grossSales | 473-475 | Historical entries times fixed price, not outstanding liabilities |
| name; symbol | 479-481; 485-487 | Pure fixed metadata; clone constructor metadata not relied upon |
| _update | 497-502 | Mint/transfer/burn ownership route, sink checks, approvals inherited correctly |
| fulfillRandomWords | 509-524 | Authentication inherited, terminal exclusivity, bounded winner range |
| _settleWinningTicket | 533-558 | Once-only allocation, exact percentage/remainder, no owner or token interaction |
| _transferQuote | 564-567 | Current destination screen, SafeERC20 semantics, nominal-transfer assumption |
| _requireStatus | 573-575 | Lifecycle gating |
| _requireWinningTicket | 579-585 | Inclusive range proof; invalid historical/default ranges considered |
| _isProtocolDestination | 593-605 | Self/factory/quote/wrapper/prize/implementation/registered clone, future-address limit |
| _validatedVrfWrapper | 610-613 | Nonzero wrapper before inherited constructor |
| All generated getters | 43-136 | ENTRY_PRICE, callbackGasLimit, requestConfirmations, factory, quoteToken, sponsor, sponsorRecipient, protocolTreasury, prizeToken, prizeTokenId, raffleId, reserveEntries, endTime, totalEntries, ticketCount, unsettledPot, remainingRefundLiability, winnerRecipient, winnerProceeds, sponsorProceeds, protocolFees, vrfRequestId, drawRequestedAt, resolvedAt, winningEntry, winningTicketId, status, settlementComplete, winnerRedeemed, prizeClaimed, initialized |

### `RaffleFactory.sol` — 186 lines

| Function / surface | Lines | Review |
| --- | --- | --- |
| constructor | 65-92 | Code/decimal validation, trusted identity assumption, treasury exclusions, implementation deployment |
| createRaffle | 97-148 | Sale bounds, fresh clone, initialization, registry order, exact escrow/Active checks, atomic rollback |
| _validateCreateParams | 154-179 | ERC-721 self-report, recipient/prize exclusions, reserve > 0, future destinations |
| _requireContract | 183-185 | Code presence only; does not authenticate implementation semantics |
| All generated getters | 24-54 | callbackGasLimit, requestConfirmations, quoteToken, vrfWrapper, protocolTreasury, raffleImplementation, raffleCount, raffleById, idByRaffle, isRaffle |

### `interfaces/IRaffle.sol` — 521 lines

Read all enums, configuration fields, events, errors, and every function declaration. Cross-checked all ten declared mutation methods (`initialize`, `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) against their implementations. Activation is the separately implemented ERC-721 receiver rather than an IRaffle declaration. Cross-checked `getVrfRequestPrice`, `estimateVrfRequestPrice`, `ticketRange`, `drawRequestDeadline`, `callbackDeadline`, `accountedQuoteBalance`, `grossSales`, `vrfWrapper`, and every generated getter listed above. Particularly reviewed ownership/burn promises (`333-344`), permissionless allocation (`326-331`), historical ranges (`368-373`), and honest token assumptions (`12-15`). There is no executable logic in this interface.

### `interfaces/IRaffleFactory.sol` — 150 lines

Read all configuration, event/error declarations, `createRaffle`, and all ten generated getter declarations: `quoteToken`, `vrfWrapper`, `protocolTreasury`, `callbackGasLimit`, `requestConfirmations`, `raffleImplementation`, `raffleCount`, `isRaffle`, `raffleById`, `idByRaffle`. Compared configured destinations and timing/escrow promises to the implementation. There is no executable logic in this interface.

### `libraries/RaffleConstants.sol` — 43 lines

Read and used all eleven constants: `BPS`, `PROTOCOL_FEE_BPS`, `CASH_WINNER_BPS`, `ENTRY_PRICE`, `QUOTE_TOKEN_DECIMALS`, `MAX_REFUND_TICKET_BATCH_SIZE`, `MAX_SALE_DURATION`, `DRAW_REQUEST_TIMEOUT`, `DRAW_CALLBACK_TIMEOUT`, `VRF_REQUEST_CONFIRMATIONS`, and `VRF_CALLBACK_GAS_LIMIT`. Reconciled their arithmetic/timing use at every production reference. The library has no functions.

## Exact dependency coverage and exclusions

- OpenZeppelin `token/ERC721/ERC721.sol`: full 433-line file; public ownership/approval/transfer/metadata interfaces, `_update`, `_safeMint`, `_mint`, `_burn`, `_transfer`, `_safeTransfer`, `_approve` overloads, `_setApprovalForAll`, `_requireOwned`, and authorization helpers reviewed. Unused `_increaseBalance` was read but is not called by the raffle. Default metadata URI has no asset effect.
- OpenZeppelin `token/ERC721/utils/ERC721Utils.sol`: full receiver-check implementation; receiver failures propagate and code-less recipients skip callbacks.
- OpenZeppelin `token/ERC20/utils/SafeERC20.sol`: reachable `safeTransfer`, `safeTransferFrom`, `_safeTransfer`, and `_safeTransferFrom` reviewed, including true/empty/false/revert handling. Other read approval/relaxed-transfer helpers are not exercised by production.
- OpenZeppelin `utils/ReentrancyGuard.sol`: full guard implementation reviewed, including initial-zero clone behavior and storage slot use. The `StorageSlot` helper names/location were inspected; this is not a separate audit of all storage-slot helpers.
- OpenZeppelin `proxy/Clones.sol`: exact used `clone(address)` and `clone(address,uint256)` paths reviewed; deterministic alternatives were read incidentally but are not production entry points.
- OpenZeppelin `utils/math/Math.sol`: exact used `mulDiv(uint256,uint256,uint256)` and its `mul512` helper reviewed; this is not a review of the whole math library.
- OpenZeppelin `utils/Context.sol` and `utils/introspection/ERC165.sol`: complete small implementations read; ordinary `msg.sender` and interface reporting checked.
- Chainlink `VRFV2PlusWrapperConsumerBase.sol`: complete file read; constructor/link immutable setup, used native request helper, raw callback authority, and inherited `getBalance`/`getLinkToken` covered. LINK-funded `requestRandomness` is internal and not invoked by production.
- Chainlink `VRFV2PlusClient.sol`: complete file read; native `ExtraArgsV1` encoding checked.
- Chainlink `IVRFV2PlusWrapper.sol`: complete interface read; native price/estimate/request ABI checked. The actual wrapper implementation is absent from this source-only context and was not audited.
- Other imported declaration/utility files were not independently audited in full. No assurance is claimed for unused dependency paths, compiler internals, deployed USDC/wrapper administration, gas sufficiency, frontend decisions, or live deployment identity.

## Input hashes

| Frozen input | SHA-256 |
| --- | --- |
| DESIGN.md | `25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1` |
| packages/contracts/src/Raffle.sol | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| packages/contracts/src/RaffleFactory.sol | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| packages/contracts/src/interfaces/IRaffle.sol | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| packages/contracts/src/interfaces/IRaffleFactory.sol | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |
| packages/contracts/src/libraries/RaffleConstants.sol | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |

This first pass is independent and bounded. Unresolved leads are retained as such; their presence is not evidence that the described production deployment or unsupported dependency behavior exists.
