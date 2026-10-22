

===== RAW SPECIALIST LENS 1 =====

[Model: createRaffle]
A sponsor gives one prize NFT and receives an active, registered raffle. The factory’s raffle count rises by one, three registry records are created, and the raffle is expected to hold exactly one prize.

[Why: RaffleFactory.sol:129]
Why does the prize contract’s own ownership answer prove permanent custody? It assumes the sponsor-selected, untrusted collection reports ownership honestly and cannot later revoke ownership—neither belief is enforced.

[Defeat: createRaffle]
1. A sponsor-controlled collection transfers token 7 normally, then removes it through an added `forceTransfer` function after sales.
2. A pausable collection transfers token 7 into escrow, then the sponsor pauses all transfers before redemption.
3. A hostile collection calls the receiver with the expected addresses, returns the raffle from `ownerOf`, and performs no real ownership update. All three defeat interface and one-time ownership checks.

[Model: initialize]
The factory gives a fresh raffle its sponsor, recipients, prize identity, reserve, and deadline. No asset moves; the raffle moves from unused storage to waiting for its prize.

[Defeat: initialize]
An EOA at `0xBEEF` cannot initialize because it is not the factory; a second factory initialization fails the one-time flag; zero or known protocol destinations are rejected.

[Model: onERC721Received]
The configured collection is expected to give the raffle token 7. The raffle records no numerical prize balance; it changes from waiting for the prize to selling entries.

[Why: Raffle.sol:422]
Why are the supplied operator and prior-owner fields evidence of a transfer? Only the prize contract supplies them, so the check assumes the untrusted collection tells the truth.

[Defeat: onERC721Received]
An unrelated collection fails the caller check; the configured collection using token 8 fails the identifier check; the configured hostile collection can supply factory, sponsor, and token 7 without moving ownership and passes this guard.

[Model: buyEntries]
A buyer paying 10,000,000 raw USDC receives one ticket covering ten entries. Sold entries rise by ten, ticket count rises by one, and the unallocated sale pot rises by 10,000,000.

[Why: Raffle.sol:224]
Why is the requested payment credited rather than the observed receipt? The protocol explicitly trusts canonical, fee-free USDC to move the complete requested amount.

[Defeat: buyEntries]
A zero-entry purchase fails; a purchase beyond the remaining 128-bit entry capacity fails; a recipient contract rejecting its ticket makes the entire payment, accounting update, and mint revert atomically.

[Model: _update]
A ticket owner gives the bearer claim to another address. Sold entries, ticket count, and every USDC liability remain unchanged.

[Defeat: _update]
A transfer to the current raffle, factory, or quote token is rejected; a transfer to a registered sibling raffle is rejected; a transfer to a future or foreign-factory raffle can pass, but only the owner or an approved operator can strand that owner’s claim, leaving no involuntary victim.

[LastOut: buy / transfer]
Alice buys two entries, Bob three, and Carol five for 10,000,000 raw USDC total. Transfers change only ticket ownership. On a refund outcome, Bob, Alice, then Carol receive 3,000,000, 2,000,000, and 5,000,000; the last claimant is paid fully and the remaining liability reaches zero.

[Model: requestDraw]
A requester gives the current native fee and receives no protocol claim; the payment purchases randomness. The raffle records that drawing began, the request time, and the request identifier, while returning any excess native value.

[Why: Raffle.sol:257]
Why can the caller’s excess be computed from the returned price? The inherited Chainlink routine recomputes the price and forwards exactly that amount, rather than forwarding the whole call value.

[Defeat: requestDraw]
A zero-entry raffle cannot request; a request exactly at the two-day deadline fails; a contract that overpays and rejects its 0.005 ETH refund causes the whole request and wrapper payment to revert.

[Model: fulfillRandomWords]
The authenticated randomness service supplies one word. No asset moves; the raffle records one winning entry, a resolution time, and either the NFT or cash outcome.

[Defeat: fulfillRandomWords]
An EOA callback fails inherited wrapper authentication; the wrapper sending request identifier `expected + 1` is ignored; a callback exactly at the callback deadline is ignored and refunds become available.

[LastOut: successful draw]
If the current fee is 0.010 ETH and the requester supplies 0.015 ETH, the wrapper receives 0.010 ETH and the requester receives 0.005 ETH. All 100,000,000 raw USDC remains accounted for until terminal settlement; no claimant is short at this stage.

[Model: enableRefunds]
No new asset moves. The complete unallocated sale pot becomes the aggregate ticket-refund liability, the old pot becomes zero, and the raffle enters its refund outcome.

[Why: Raffle.sol:296]
Why is the refund liability copied from the unallocated pot rather than recomputed from tickets? Before any terminal transition, that pot exactly equals every sold entry’s purchase price.

[Defeat: enableRefunds]
An outsider cannot cancel an empty raffle before its end; the sponsor cannot cancel early after even one entry is sold; a drawing raffle cannot enter refunds one second before its callback deadline.

[Model: refundTickets]
An owner destroys selected tickets and receives their complete purchase price. The aggregate refund liability falls by exactly the represented entries’ value.

[Why: Raffle.sol:368]
Why is the liability reduced before payment? A failed payment reverts the reduction, while a successful payment leaves the recorded debt equal to the remaining live tickets.

[Defeat: refundTickets]
Submitting ticket 1 twice fails when its second ownership check sees the burn; nonexistent ticket 999 fails ownership lookup; mixing Alice’s ticket with Bob’s ticket reverts the whole batch without a partial debit.

[LastOut: timeout / refund]
For tickets worth 2,000,000, 3,000,000, and 5,000,000 raw USDC, the worst withdrawal order leaves liabilities of 8,000,000, 5,000,000, then zero. The last ticket owner receives the full 5,000,000; shortfall is zero.

[Model: settleWinningTicket]
A caller gives only a valid winning-range proof. No asset moves. With a 100,000,000 pot, the NFT outcome creates 95,000,000 for the sponsor and 5,000,000 for the treasury; the cash outcome creates 80,000,000 for the winner, 15,000,000 for the sponsor, and 5,000,000 for the treasury.

[Why: Raffle.sol:547]
Why does the sponsor receive subtraction’s remainder? This assigns every raw unit exactly once and prevents percentage-rounding residue from becoming ownerless.

[Defeat: _settleWinningTicket]
Ticket 0 has an empty range and cannot contain a nonzero winner; a real losing ticket fails the range proof; a second settlement fails the one-time completion flag.

[Model: redeemWinningTicket]
The current winning-ticket owner destroys the ticket and receives either the prize NFT or the 80% cash allocation. The winner identity is fixed at redemption, and the corresponding claim closes atomically on successful delivery.

[Why: Raffle.sol:335]
Why is asking the same untrusted prize contract who owns token 7 independent delivery verification? It is not; a hostile collection can make both the transfer and the ownership answer agree with a fabricated result.

[Defeat: redeemWinningTicket]
A non-owner cannot redeem; a different ticket cannot replace the already proven winning ticket; a sponsor-controlled prize can be removed, paused, or make transfer a no-op while fabricating the subsequent ownership answer.

[LastOut: settle / redeem NFT]
With an honest prize, sponsor and treasury can withdraw 95,000,000 and 5,000,000 raw USDC in either order, and the winner receives the one NFT. With the accepted hostile prize, those USDC claims still drain in full but the last claimant has one NFT claim backed by zero deliverable NFTs—a one-NFT shortfall.

[LastOut: settle / redeem cash]
From 100,000,000 raw USDC, sponsor and treasury may withdraw 15,000,000 and 5,000,000 first, leaving exactly 80,000,000 for the winner. The winner is paid fully, and the sponsor prize is independent of the quote-token balance.

[Model: releaseSponsorProceeds]
The fixed sponsor recipient gives nothing and receives the complete sponsor allocation. That allocation becomes zero; all other claims are unchanged.

[Model: releaseProtocolFees]
The fixed treasury gives nothing and receives the complete protocol allocation. That allocation becomes zero; all other claims are unchanged.

[Defeat: releaseSponsorProceeds / releaseProtocolFees]
A second release fails because the claim is zero; a reentrant attempt cannot enter another protected payout; known protocol sinks cannot be configured as recipients.

[Model: releaseSponsorPrize]
On a cash or refund outcome, the raffle gives the escrowed NFT back to the fixed sponsor recipient and closes the single prize claim.

[Defeat: releaseSponsorPrize]
An NFT-outcome call fails the status check; a second release fails the claimed flag; a hostile prize can block or fabricate delivery, but this sibling path primarily harms the sponsor rather than creating an additional buyer-loss mechanism.

[LastOut: create / escrow]
For an honest prize, any failed deposit rolls back the clone count and registry; an empty successful raffle later returns its sole NFT. For a hostile self-attesting prize, registration can finish with zero real custody, leaving the eventual NFT claimant short by one.

[LastOut: empty raffle]
No USDC was collected, so the quote-token shortfall is zero. With an honest prize, the sponsor recipient receives the one NFT; hostile-token failure is the same custody root cause already identified.

[LastOut: independent releases]
NFT result: 95,000,000 plus 5,000,000 equals the 100,000,000 pot. Cash result: 80,000,000 plus 15,000,000 plus 5,000,000 equals the pot. Every release order leaves enough for the last USDC claimant.

[Saturation: tracked quote totals]
Every increase, migration, allocation, and exit was paired across purchases, refunds, cash redemption, sponsor release, and treasury release. No sibling path omits a quote-liability decrement, uses a live token balance, or leaves percentage residue.

[Saturation: untrusted prize custody]
The complete sibling set is factory deposit and ownership checking, receiver activation, winner delivery, and sponsor return. Each relies on behavior reported by the same untrusted prize contract; the NFT-winning branch is the worst exploitable variant because buyer USDC can be released while the promised prize is absent.

[Saturation: numeric and temporal boundaries]
Entry counts 1 and `uint128.max`, ticket batches 1 and 100, one-before/exactly-at deadlines, both settlement branches, every payout ordering, duplicate burns, and repeated terminal calls were swept. Ticket count cannot exceed sold entries, all quote arithmetic remains below 256 bits, and the fixed entry price makes both percentages integral.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-erc721-custody | group_key: RaffleFactory | createRaffle | untrusted-erc721-custody
root_cause: At target/packages/contracts/src/RaffleFactory.sol:129, `createRaffle` treats `prize.ownerOf()` from the sponsor-selected prize contract as permanent custody proof and omits any restriction to collections that cannot later revoke or fabricate ownership.
internal_pre: A sponsor selects an ERC-721-reporting contract with a sponsor-controlled forced-transfer capability, 100 entries are sold against a reserve of 100, and the raffle reaches the NFT-winning outcome.
external_pre: None
path:
  1. Mallory creates a raffle for token 7 from a collection that reports ERC-721 support and also lets Mallory force-transfer any token; the normal initial transfer makes the raffle the reported owner and passes every creation check.
  2. Alice buys one ticket covering entries 1 through 100 for 100,000,000 raw USDC, making the NFT outcome certain once the draw resolves.
  3. After sales close, Mallory force-transfers token 7 from the raffle back to Mallory; the raffle remains Active and records no custody loss.
  4. The draw resolves NftWon, and settlement converts the 100,000,000 pot into 95,000,000 raw USDC for Mallory and 5,000,000 for the treasury.
  5. Permissionless releases transfer both allocations, leaving the raffle with zero USDC while Mallory retains token 7.
  6. Alice attempts to redeem the winning ticket, but the prize transfer from the raffle reverts because the raffle no longer owns token 7; NftWon has no refund transition.
impact: Alice paid 100,000,000 raw USDC but receives neither a refund nor token 7, while Mallory retains the NFT and receives 95,000,000 raw USDC. At redemption Alice has one NFT claim, the raffle has zero deliverable NFTs, and the shortfall held by Alice is exactly one NFT.
mitigation: Require `prizeToken` to belong to an immutable allowlist of audited, non-upgradeable ERC-721 collections without administrator seizure or sponsor-controlled transfer restrictions before creating the raffle.

COVERAGE | files: Raffle.sol—every asset movement, tracked-total write, lifecycle transition, ticket range, callback, and payout branch; RaffleFactory.sol—deployment, cloning, registry atomicity, parameter validation, and prize escrow; IRaffle.sol and IRaffleFactory.sol—every declaration, lifecycle promise, event, error, and getter against implementation behavior; RaffleConstants.sol—fees, prices, batch limits, durations, and callback settings; DESIGN.md—every stated economic split, deadline, custody, and trust-boundary property.

COVERAGE | properties: quote solvency and exact allocation, last-user payment, ticket-range conservation, one-shot settlement/redemption, deadline boundaries, native-fee pass-through, clone isolation, destination screening, untrusted-recipient rollback, and untrusted-prize custody.

===== RAW SPECIALIST LENS 2 =====

[Model: RaffleFactory.createRaffle] A sponsor gives one advertised NFT to a new raffle and receives the right to the sponsor portion of sales or the returned prize. The lifetime raffle count rises by one, the ID/address registries are populated, and the raffle opens only after the prize receipt is acknowledged.

[Model: Raffle.initialize] No asset moves. The new raffle records its sponsor, beneficiaries, prize, reserve, and deadline, then enters the waiting-for-prize state.

[Model: Raffle.onERC721Received] The sponsor gives the configured NFT to the raffle. The raffle records no numeric balance for it; successful receipt changes the lifecycle from waiting to active.

[Model: Raffle.buyEntries] A buyer gives `entryCount` USDC and the chosen recipient receives one bearer ticket covering exactly that many entries. Lifetime sold entries rise by `entryCount`, ticket count rises by one, and the unallocated pot rises by the purchase price.

[Model: Raffle._update] A current holder gives the entire ticket claim to another holder. The represented entry range, sold-entry total, and USDC pot do not change.

[Model: Raffle.requestDraw] The caller gives native currency to advance the raffle. The wrapper receives its exact fee, the caller receives any excess, and the raffle records that a draw and its callback window are pending.

[Model: Raffle.fulfillRandomWords] Nobody gives or receives an asset. One authenticated random value fixes an entry and converts the pending raffle into either an NFT result or a cash result.

[Model: Raffle.enableRefunds] No asset moves immediately. The whole unallocated USDC pot is relabeled as the aggregate amount owed to refundable tickets, and the raffle enters the refund state.

[Model: Raffle.settleWinningTicket/_settleWinningTicket] Nobody pays or receives value during settlement. The unallocated pot becomes mutually exclusive winner, sponsor, and treasury claims whose sum equals the old pot, and the proven winning ticket is recorded.

[Model: Raffle.redeemWinningTicket] The current winner gives up and burns the winning ticket. In exchange, that holder receives either the configured NFT or the entire cash-winner claim; the associated claim is consumed once.

[Model: Raffle.refundTickets] A holder burns selected tickets and receives exactly one entry price for every represented entry. The aggregate refund liability falls by the same amount.

[Model: Raffle.releaseSponsorProceeds] The caller contributes nothing; the immutable sponsor recipient receives its complete USDC claim. That claim is cleared atomically.

[Model: Raffle.releaseProtocolFees] The caller contributes nothing; the immutable treasury receives its complete USDC claim. That claim is cleared atomically.

[Model: Raffle.releaseSponsorPrize] After a cash or refund result, the sponsor recipient receives the escrowed NFT and the one-time prize claim is consumed.

[Why: RaffleFactory.sol:172] Why should a prize contract’s own assertion that it implements the NFT interface prove that its ownership rules cannot be upgraded, bypassed, or revoked? It should not; the sponsor controls which contract answers this query.

[Why: RaffleFactory.sol:129] Why does asking the same untrusted prize contract who owns the token independently prove durable custody? It does not; even genuinely correct ownership at creation says nothing about later privileged seizure.

[Why: Raffle.sol:254] Why reject a callback while the request call is in progress? The request identifier has not yet been persisted, so accepting a synchronous callback would resolve against incomplete request state.

[Why: Raffle.sol:297] Why clear the pot before any refund is paid? The exact amount is simultaneously migrated into the refund liability, preventing the same USDC from being counted twice.

[Why: Raffle.sol:325] Why burn the winning ticket before delivering its prize? Transaction rollback restores the ticket if delivery fails, while a successful delivery cannot leave a reusable claim.

[Why: Raffle.sol:335] Why does the prize contract’s reported owner prove enforceable delivery? It does not when the prize contract is adversarial; it can forge the answer or later revoke control.

[Why: Raffle.sol:533] Why can a non-owner settle the winning ticket? Settlement proves the unique historical range but does not consume the bearer claim; ownership is deliberately checked only at redemption.

[Why: Raffle.sol:553] Why clear the unallocated pot before beneficiaries withdraw? All of it is allocated into independently cleared claims in the same transaction, so total liability is preserved.

[Defeat: RaffleFactory.createRaffle] (1) An attacker’s `Fake721` can claim interface support for token `#7`. (2) It can genuinely escrow `#7` and later use an administrator-only seizure function. (3) An upgradeable prize proxy can behave normally during creation and replace its transfer rules after buyers enter. The current validation excludes none of these moves.

[Defeat: Raffle.buyEntries] (1) Buying zero entries is rejected. (2) Buying one more than the remaining `uint128` capacity is rejected. (3) A recipient contract attempting a nested purchase from its receipt callback is stopped by the reentrancy guard, and the original purchase remains atomic.

[Defeat: Raffle.requestDraw] (1) A request one second before sale end is rejected. (2) A request exactly at the draw deadline is rejected. (3) A requester that rejects its excess refund reverts the whole request, leaving another caller able to retry.

[Defeat: Raffle.fulfillRandomWords] (1) A callback with request ID `expected+1` is ignored. (2) A callback with zero or two words is ignored. (3) A callback exactly at the callback deadline is ignored, allowing refunds at that timestamp.

[Defeat: Raffle.enableRefunds] (1) The sponsor can close a zero-entry raffle before its end. (2) An outsider one second before the zero-entry end is rejected. (3) With sold entries, anyone can open refunds exactly at the missed request or callback deadline.

[Defeat: Raffle._settleWinningTicket] (1) Ticket `0` has range `[0,0]` and cannot contain a positive winning entry. (2) An adjacent losing ticket fails the range test. (3) A non-owner supplying the correct ticket succeeds only in allocating claims and cannot redeem it.

[Defeat: Raffle.redeemWinningTicket] (1) A non-owner cannot redeem ticket `3`. (2) If ticket `3` changes hands after settlement, only its new owner can redeem. (3) If the prize administrator has removed token `#7` from the raffle, redemption reverts while already allocated sponsor proceeds remain independently releasable.

[Defeat: Raffle.refundTickets] (1) Repeating ticket `4` in one batch reverts when the second occurrence is no longer owned. (2) Including another holder’s ticket reverts the entire batch. (3) A maximum-size batch of 100 distinct tickets debits exactly their combined entry count.

[Defeat: Raffle._update] (1) Sending a ticket to its own raffle is rejected. (2) Sending it to the canonical factory or implementation is rejected. (3) Sending it to a currently registered sibling raffle is rejected.

[Defeat: Raffle.releaseSponsorProceeds] (1) Calling before settlement finds no claim. (2) Calling twice fails after the first call clears the claim. (3) Calling after an NFT result succeeds even when an untrusted prize contract has revoked the raffle’s custody, which participates in the finding below.

[Defeat: Raffle.releaseSponsorPrize] (1) Release during an NFT result is rejected. (2) A second release is rejected. (3) A malicious prize contract can falsely report the sponsor recipient as owner, showing that the post-transfer check is not an independent trust boundary.

[LastOut: refund lifecycle] With 100 one-entry tickets, the initial liability is `100,000,000` raw USDC. After 99 holders receive `99,000,000`, the last holder receives the remaining `1,000,000`; quote-token shortfall is zero.

[LastOut: CashWon lifecycle] From `100,000,000` raw USDC, the winner receives `80,000,000`, the sponsor receives `15,000,000`, and the treasury receives `5,000,000`. In every withdrawal order the last quote claimant is paid in full; quote-token shortfall is zero, and an honest prize returns to the sponsor recipient.

[LastOut: NftWon lifecycle] From `100,000,000` raw USDC, the sponsor and treasury receive `95,000,000` and `5,000,000`. With an honest prize the final winner also receives the NFT, but after privileged prize seizure the quote claims still empty the raffle while the last winner is short exactly one configured NFT and has no refund path.

[LastOut: native-fee lifecycle] If the required fee is `Q` and the requester sends `Q + 0.2 ether`, the wrapper receives `Q` and the requester receives `0.2 ether`; intended residual shortfall is zero.

[LastOut: empty-raffle lifecycle] No quote liability exists. After cancellation, an honest prize returns once to the sponsor recipient; asset shortfall is zero.

[Saturation: untrusted-prize-attestation] The sweep covered interface validation at `RaffleFactory.sol:172`, initial transfer and ownership verification at lines 128–129, activation in `Raffle.onERC721Received`, winner delivery at `Raffle.sol:334–335`, and sponsor return at lines 404–405. Every custody assertion ultimately comes from the sponsor-selected prize contract, and no later lifecycle step detects privileged removal.

[Saturation: claim-debit-siblings] Refund liability, cash-winner proceeds, sponsor proceeds, protocol fees, winning-ticket burns, and the one-time prize flag were checked across every exit. Each ordinary quote claim is cleared exactly once before its transfer and restored on failure; no sibling missing-decrement defect survived.

[Saturation: range-and-terminal-siblings] Ticket mint, transfer, winning proof, refund burn, winner burn, both result branches, both timeout branches, empty cancellation, and independent releases were checked. Ranges remain contiguous and uniquely cover `[1,totalEntries]`; no second redemption or refund route survived.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: revocable-prize-escrow | group_key: RaffleFactory | _validateCreateParams | revocable-prize-escrow
root_cause: RaffleFactory.sol:172 accepts a sponsor-selected prize using only that contract's self-reported ERC-721 interface support; the missing trusted-collection or immutable-implementation restriction permits a prize contract with an administrator seizure or upgrade path to revoke escrow after activation.
internal_pre: None; the attacker can create the required raffle from an empty protocol state.
external_pre: Buyers must purchase entries in the factory-registered Active raffle; no oracle, market-price, or chain condition is required.
path:
  1. Sponsor Mallory deploys an ERC-721-compatible `Evil721`, mints token `#7`, and retains an administrator function that can move `#7` without its current owner's approval.
  2. Mallory creates a raffle with `reserveEntries = 1`; `Evil721` genuinely transfers `#7` to the new raffle, reports interface support, and passes the factory's ownership and Active-status checks.
  3. Alice and 99 other buyers purchase one entry each for `1,000,000` raw USDC, producing `100` entries and a `100,000,000` raw-USDC pot.
  4. Mallory invokes the prize contract's administrator function and moves `#7` back from the raffle to herself; the raffle remains Active or Drawing because it has no custody-change notification or continuing custody invariant.
  5. The authenticated draw resolves `NftWon`, and a keeper settles the correct ticket. Settlement allocates `95,000,000` to Mallory's sponsor recipient and `5,000,000` to the treasury without checking prize custody.
  6. Mallory releases the `95,000,000` sponsor claim while retaining token `#7`. The winning holder's call reaches `Raffle.sol:334` and reverts because the raffle no longer owns the prize; `NftWon` has no transition to refunds.
impact: The 100 ticket purchasers lose `100,000,000` raw USDC without any prize being delivered; Mallory keeps the advertised NFT and extracts `95,000,000` raw USDC, while the winning-ticket owner is left holding an permanently unredeemable claim.
mitigation: Add an immutable trusted-prize address or exact-implementation allowlist check in `_validateCreateParams`, rejecting upgradeable or privileged-transfer collections instead of treating ERC-165 and `ownerOf` responses as a trust guarantee.

COVERAGE | files: `Raffle.sol`—all asset movements, tracked-total writes, ticket ranges, callbacks, settlement, redemption, refunds, releases, and sink checks; `RaffleFactory.sol`—configuration, cloning, registry ordering, validation, and escrow; `IRaffle.sol` and `IRaffleFactory.sol`—every lifecycle, claim, event, error, and generated-getter promise; `RaffleConstants.sol`—units, rates, rounding, limits, and deadlines; `DESIGN.md`—economics, custody, trust, and terminal-state requirements.

COVERAGE | properties: quote solvency and allocation conservation; last-user payment; range continuity and unique winner proof; transfer-bound bearer ownership; double-spend resistance; overflow and rounding boundaries; deadline exclusivity; native-fee pass-through; clone isolation; registry atomicity; untrusted prize and recipient behavior; prize custody and delivery liveness.

===== RAW SPECIALIST LENS 3 =====

[Model: RaffleFactory.constructor] The deployer supplies the quote token, randomness wrapper, and treasury addresses and receives a permanently configured factory and raffle implementation. No user asset or claim moves.

[Model: RaffleFactory.createRaffle] The sponsor supplies one advertised NFT and receives a raffle with future sponsor rights. The factory count and three registry mappings gain one entry, and the raffle is expected to gain custody of the NFT.

[Why: RaffleFactory.sol:129] Why does asking the sponsor-selected prize contract who owns the token prove escrow? It proves custody only if that same untrusted contract reports ownership honestly.

[Defeat: RaffleFactory.createRaffle] 1) A hostile prize reports ERC-721 support. 2) Its inbound transfer merely invokes the expected receiver hook without changing ownership. 3) Its ownership query reports the raffle only to the factory. All creation checks pass without genuine custody.

[Model: Raffle.initialize] The factory supplies the sponsor, recipients, prize identity, reserve, and end time. No asset moves; the raffle becomes configured and waits for the prize.

[Model: Raffle.onERC721Received] The sponsor is supposed to give the configured NFT to the raffle, and the raffle becomes active. No quote-token total changes.

[Defeat: Raffle.onERC721Received] 1) A different token contract is rejected. 2) A wrong token ID or previous owner is rejected. 3) The configured hostile token can fabricate all callback fields itself, so the callback authenticates the caller’s identity but not actual custody.

[LastOut: create / escrow] With a compliant prize, the sole NFT remains available to the eventual winner or sponsor. With a self-attesting hostile prize, the last claimant is short the entire NFT even though the raffle reports active.

[Model: Raffle.buyEntries] A buyer gives `entryCount * 1,000,000` USDC, and the recipient receives one ticket covering that many entries. Sold entries, ticket count, and the unsettled pot increase by the matching amounts.

[Defeat: Raffle.buyEntries] 1) A receiver tries to reenter while receiving a one-entry ticket; the raffle guard blocks its economic functions. 2) A buyer requests enough entries to exceed the entry-number limit; the overflow check rejects it. 3) A buyer attempts short payment; the trusted fee-free USDC either transfers the full amount or the purchase fails atomically.

[Model: Raffle._update] A current holder gives the bearer ticket to another address, which receives the complete associated claim. Sold-entry, ticket-count, and quote-token totals do not change.

[Why: Raffle.sol:497] Why can ownership change after the draw result is known? The design treats the ticket as the claim itself, so the current holder—not the holder at purchase or draw time—is intentionally entitled.

[Defeat: Raffle._update] 1) Sending to the current raffle is rejected. 2) Sending to an already registered raffle is rejected. 3) Sending to a predicted but not-yet-deployed raffle address bypasses the registry check, but only the authorized holder can do this, so the resulting loss is self-directed.

[LastOut: buy / transfer] Alice buying six entries and Bob buying four creates exactly ten backed entries. Any transfers merely move those claims; the final owners collectively retain claims over the same ten entries.

[Model: Raffle.requestDraw] A requester gives native currency; the randomness wrapper receives its exact recalculated fee, and any remainder returns to the requester. The raffle moves from active to drawing and records one request and callback window.

[Why: Raffle.sol:257] Why can the raffle return the excess after requesting randomness? The inherited helper forwards only its freshly calculated request price, leaving the difference available for the immediate refund.

[Defeat: Raffle.requestDraw] 1) A request one second before the end is rejected. 2) A request exactly at the request deadline is rejected while refunds become available. 3) A contract that refuses its excess refund only reverts its own request; another actor can request using the exact fee.

[Model: Raffle.fulfillRandomWords] No user gives or receives value. One authenticated random entry is recorded, and the fixed sold-entry total selects either the NFT or cash result.

[Defeat: Raffle.fulfillRandomWords] 1) The wrapper supplies the wrong request ID. 2) It supplies two words instead of one. 3) It supplies the correct word exactly at the callback deadline. Each is ignored without altering the result.

[LastOut: successful draw] The draw moves no asset and creates no new liability. The full pre-draw USDC pot and the prize remain available for the terminal path.

[Model: Raffle.enableRefunds] No new asset enters or leaves. The entire unsettled pot becomes the refund liability, and the raffle enters the refund state.

[Defeat: Raffle.enableRefunds] 1) The sponsor closes an empty raffle before its end, which creates no buyer loss. 2) The sponsor tries the same action after one entry was sold and before the deadline; it is rejected. 3) Anyone calls exactly at the applicable deadline; the full pot becomes refundable with no timing gap.

[Model: Raffle._settleWinningTicket/NftWon] At t0 Alice pays 6,000,000 USDC for six entries; at t1 Bob pays 4,000,000 for four. At t2 an Alice entry wins: Alice’s ticket is owed the NFT, the sponsor is allocated 9,500,000, and the treasury 500,000. Bob receives none of the earlier payment merely for joining later.

[Why: Raffle.sol:544] Why is the sponsor allocated the entire pot minus the fee? In the NFT result, the winner’s value is the NFT, so every USDC unit must go to the sponsor or treasury.

[Defeat: Raffle._requireWinningTicket] 1) Ticket zero has range `[0,0]` and cannot contain a positive winning entry. 2) A losing historical ticket cannot pass the range check. 3) A second settlement of the actual winning ticket is rejected by the one-shot flag.

[Model: Raffle.redeemWinningTicket] The current winning-ticket owner gives up and burns the ticket and receives either the NFT or the entire cash-winner balance. The winner flag and applicable prize liability are consumed exactly once.

[Why: Raffle.sol:335] Why does asking the prize contract whether the winner owns the token prove delivery? It does so only if the untrusted contract reports ownership consistently and supplies a usable token.

[Defeat: Raffle.redeemWinningTicket] 1) A non-owner supplies the winning ID and is rejected. 2) An owner attempts to redirect the ticket to known protocol plumbing and is rejected before redemption. 3) A hostile prize either performs no transfer and lies about ownership or rejects the outbound transfer; the first falsely completes redemption, while the second leaves sponsor proceeds independently releasable.

[Defeat: prize-custody-siblings] 1) In creation, a no-op inbound transfer plus false ownership activates an unbacked raffle. 2) In NFT redemption, a no-op outbound transfer plus false ownership burns the winner’s claim without delivery. 3) In sponsor-prize return, the same behavior only harms or benefits the sponsor-selected recipient, so the third-party-loss variants are the creation and NFT-winner paths.

[LastOut: settle / redeem NFT] With a compliant prize and a 10,000,000 pot, sponsor-first payment of 9,500,000 and treasury payment of 500,000 leave the NFT winner fully paid with the NFT. A hostile prize leaves the last claimant short one NFT; if it rejects delivery, no ticket refund path remains.

[Model: Raffle._settleWinningTicket/CashWon] At t0 Alice buys six entries for 6,000,000; at t1 Bob buys four for 4,000,000; at t2 the reserve is missed and a Bob entry wins. Bob receives 8,000,000, the sponsor 1,500,000, and the treasury 500,000. Bob’s payment purchased four winning chances, not a share of earlier accrual.

[LastOut: settle / redeem cash] In the worst order, the sponsor takes 1,500,000 and the treasury 500,000 before Bob claims. Exactly 8,000,000 remains, so the last claimant is paid in full and the raffle is short by zero.

[Model: Raffle.refundTickets] At t0 Alice pays 6,000,000 for six entries; at t1 Bob pays 4,000,000 for four; at t2 refunds open. Burning Alice’s ticket returns 6,000,000 and burning Bob’s returns 4,000,000, independent of order.

[Defeat: Raffle.refundTickets] 1) Alice repeats one ticket ID in a batch; the second ownership check fails and the whole attempt is undone. 2) Alice includes Bob’s ticket; the ownership check rejects it. 3) Alice supplies 101 tickets; the fixed batch limit rejects them without changing liability.

[LastOut: timeout / refund] Alice refunds 6,000,000 first, reducing liability from 10,000,000 to 4,000,000. Bob refunds last and receives the full 4,000,000; remaining liability and shortfall both become zero.

[Model: Raffle._transferQuote] The raffle gives one complete recorded USDC claim to its beneficiary. The calling path clears that exact claim first, and a failed payment restores all changes.

[Model: Raffle.releaseSponsorProceeds] The raffle gives the complete sponsor balance to the immutable sponsor recipient. Sponsor proceeds fall to zero.

[Model: Raffle.releaseProtocolFees] The raffle gives the complete fee balance to the immutable treasury. Protocol fees fall to zero.

[Model: Raffle.releaseSponsorPrize] After a cash result or refunds, the raffle gives the NFT back to the sponsor recipient and consumes the one prize claim. No USDC total changes.

[Defeat: independent releases] 1) The sponsor claim is released before the treasury claim. 2) The treasury claim is released before the cash winner. 3) The cash winner claims first. Because the three balances sum to the original pot and clear independently, order cannot make a compliant USDC claimant short.

[LastOut: empty raffle] No USDC was collected, so the only terminal asset is the prize. A compliant prize returns fully to the sponsor recipient; quote-token shortfall is zero.

[LastOut: independent releases] For a 10,000,000 cash-result pot, any ordering of 8,000,000 winner, 1,500,000 sponsor, and 500,000 treasury payments leaves the final claimant fully paid and the balance at zero.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation
root_cause: RaffleFactory.sol:129 treats `ownerOf` reported by the sponsor-selected prize contract as proof of escrow, while omitting any operation that authenticates a trusted prize implementation
internal_pre: The hostile-prize raffle reaches 10 sold entries against a reserve of 10
external_pre: The sponsor controls a prize contract that can self-report ERC-721 support and ownership and invoke the receiver hook without transferring a usable token
path:
  1. At t0 Mallory deploys `Hostile721`, which reports ERC-721 support; its inbound transfer invokes the raffle receiver with the expected factory, sponsor, and token ID but records no custody, while `ownerOf(1)` reports the clone to the factory
  2. Creation succeeds with `Active` status; at t1 Alice pays 6,000,000 USDC for entries 1-6 and Bob pays 4,000,000 for entries 7-10
  3. At t2 randomness selects entry 1, the raffle allocates 9,500,000 to Mallory’s sponsor recipient and 500,000 to the treasury
  4. Alice redeems; `Hostile721.transferFrom` performs no usable transfer and then reports Alice to the raffle’s ownership check, so Alice’s ticket is burned and `prizeClaimed` becomes true
  5. Mallory releases the 9,500,000 sponsor balance; Alice ends with no transferable prize after spending 6,000,000, while Bob ends with no claim after spending 4,000,000
impact: The winning-ticket owner loses the entire advertised NFT and all entrants finance an unbacked raffle; the malicious sponsor receives 95% of their 10,000,000 USDC pot, leaving the entry cohort—especially the burned winning claimant—holding the loss
mitigation: Before creation, require the prize address to be an immutable trusted allowlisted ERC-721 implementation rather than allowing a sponsor-selected contract to self-certify interface support, custody, and delivery

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: payout-before-prize-delivery | group_key: Raffle | releaseSponsorProceeds | payout-before-prize-delivery
root_cause: Raffle.sol:376 releases the `NftWon` sponsor allocation without requiring `winnerRedeemed`, so sponsor funds can leave before the untrusted prize has been delivered
internal_pre: The raffle is settled as `NftWon` with 10 sold entries, 9,500,000 sponsor proceeds, and an unredeemed winning ticket
external_pre: The configured prize genuinely permits inbound escrow but its sponsor-controlled administrator can make transfers out of the raffle fail
path:
  1. At t0 Mallory genuinely escrows token 1 from `Switchable721`, and Alice buys six entries for 6,000,000 USDC
  2. At t1 Bob buys four entries for 4,000,000, meeting the reserve; Mallory then disables transfers whose sender is the raffle
  3. At t2 randomness selects Alice’s entry and settlement allocates 9,500,000 to Mallory and 500,000 to the treasury before any prize delivery
  4. Mallory calls `releaseSponsorProceeds` and receives 9,500,000 even though `winnerRedeemed` is false
  5. Alice’s redemption always fails on the prize transfer; she receives neither the NFT nor a refund, and Bob likewise has no refund path because the raffle remains `NftWon`
impact: The malicious sponsor collects 95% of the 10,000,000 USDC pot while withholding the prize; Alice and Bob are left holding the loss, with Alice additionally denied the winning NFT
mitigation: In `NftWon`, require `winnerRedeemed` before releasing either sponsor proceeds or protocol fees

COVERAGE | Raffle.sol: purchase and range accounting, ticket transfers, request/callback deadlines, result selection, settlement splits, winner redemption, refunds, all quote releases, both prize exits, destination screening, one-shot flags, and last-user solvency checked; RaffleFactory.sol: immutable configuration, clone registry, creation, prize admission, escrow verification, and malicious-prize boundary checked; IRaffle.sol: lifecycle, bearer-claim, event, error, timing, and getter semantics checked against implementation; IRaffleFactory.sol: creation parameters, registry getters, events, and errors checked; RaffleConstants.sol: entry price, 80/15/5 and 95/5 allocations, deadlines, limits, units, and rounding checked; DESIGN.md: custody, cohort, settlement, refund, independence, and trust claims compared to source. Properties covered: solvency and exact allocation, contiguous ranges, late-join/early-exit fairness, current-owner entitlement, double consumption, empty-set behavior, deadline boundaries, Last User Out for every lifecycle, and saturation across every prize custody/delivery sibling.

===== RAW SPECIALIST LENS 4 =====

[Model: RaffleFactory.constructor] The deployer fixes the payment token, randomness service, treasury, and raffle implementation. No participant value moves and no mutable administrator is created.

[Model: Raffle.constructor] The shared implementation locks itself against initialization and records the factory, payment token, and randomness service. No participant value moves.

[Model: Raffle.initialize] The factory records the sponsor, payout destinations, advertised prize, reserve, and sale end. No asset moves; the raffle becomes ready to receive its prize.

[Model: RaffleFactory.createRaffle] The sponsor gives one advertised NFT and receives an active raffle whose future proceeds go to the chosen recipient. The lifetime raffle count rises, the ID/address registry gains one binding, and the new raffle is expected to become the prize custodian.

[Model: Raffle.onERC721Received] One advertised NFT is supposed to arrive from the sponsor. No monetary claim is created; the raffle merely changes from waiting for the prize to selling entries.

[Model: Raffle.buyEntries] The buyer gives exactly one USDC per entry and the recipient receives one transferable ticket covering those entries. Sold entries, minted tickets, and the unallocated sale pot increase by matching amounts.

[Model: Raffle._update] A ticket claim is minted, transferred, or extinguished. Its represented entry range and all payment totals remain unchanged.

[Model: Raffle.requestDraw] The requester pays the randomness service’s native fee and receives any excess back. The USDC pot is unchanged; the raffle records one pending draw and its start time.

[Model: Raffle.fulfillRandomWords] No participant gives or receives value. An authenticated result records one winning entry and chooses either the NFT or cash outcome.

[Model: Raffle.enableRefunds] No token moves. The entire unallocated sale pot becomes an equal aggregate refund obligation and the raffle enters its refund state.

[Model: Raffle._settleWinningTicket] No asset moves. The unallocated sale pot becomes winner, sponsor, and treasury obligations whose sum exactly equals the former pot.

[Model: Raffle.redeemWinningTicket] The current winner gives up and destroys the winning ticket, receiving either the advertised NFT or the complete cash-winner obligation. Successful delivery clears the corresponding claim atomically.

[Model: Raffle.refundTickets] A ticket owner destroys selected tickets and receives exactly one USDC per represented entry. The aggregate refund obligation decreases by the same amount.

[Model: Raffle.releaseSponsorProceeds] The immutable sponsor recipient receives its complete recorded USDC claim and that claim becomes zero.

[Model: Raffle.releaseProtocolFees] The immutable treasury receives its complete recorded USDC claim and that claim becomes zero.

[Model: Raffle.releaseSponsorPrize] In a cash or refund outcome, the sponsor recipient receives the advertised NFT and the one-time prize claim is marked complete.

[Model: Raffle._transferQuote] One beneficiary receives one complete recorded USDC claim that the calling path has already cleared. Failed payment restores the cleared claim through transaction rollback.

[Why: RaffleFactory.sol:172] Why is the prize contract’s own interface-support answer evidence that an enforceable NFT exists? The implicit belief is that sponsor-selected prize code reports its behavior honestly.

[Why: RaffleFactory.sol:129] Why can asking the alleged asset who owns it independently prove custody? It cannot when the sponsor controls the contract answering the question.

[Why: Raffle.sol:422] Why do the supplied operator and prior-owner fields authenticate a prize deposit? The configured prize contract supplies both fields and can fabricate them without moving an NFT.

[Why: Raffle.sol:254] Why is a request-in-progress flag needed? It prevents a callback from resolving against a request identifier that has not yet been recorded.

[Why: Raffle.sol:544] Why does the NFT-result sponsor receive the pot minus the fee instead of a separately rounded 95% amount? This assigns every rounding remainder and preserves exact conservation.

[Why: Raffle.sol:554] Why does the sponsor’s USDC claim become payable before the NFT has reached the winner? The code assumes an escrowed prize will remain transferable after settlement.

[Why: Raffle.sol:335] Why does the prize contract’s post-transfer ownership report prove delivery? It only does so for trusted prize implementations; the same hostile contract can no-op the transfer and lie again.

[Why: Raffle.sol:368] Why is refund liability reduced before payment? It prevents repeated use of the claim, while a failed canonical-USDC payment restores both the ticket burn and liability reduction.

[Defeat: RaffleFactory._validateCreateParams] (1) A fake prize returns true for the ERC-721 interface; (2) it fabricates the receiver callback and reports the clone as owner; (3) a genuinely deposited but sponsor-controlled token later disables transfers. The first two defeat admission and custody verification; the third defeats the assumption of continuing deliverability.

[Defeat: RaffleFactory.createRaffle] (1) An EOA tries to initialize the clone first and fails because only the factory is accepted; (2) the prize contract reenters raffle creation and meets the factory’s reentrancy guard; (3) the prize contract fabricates deposit and ownership responses, which succeeds and produces the first finding.

[Defeat: Raffle.buyEntries] (1) Alice requests zero entries and is rejected; (2) Bob requests one entry beyond the remaining 128-bit capacity and is rejected; (3) a ticket receiver reenters to buy another entry and is stopped. Successful purchases preserve payment-to-pot equality.

[Defeat: Raffle.requestDraw] (1) Carol requests one second before the sale ends and is rejected; (2) Dave requests exactly at the request deadline and is rejected; (3) an overpaying contract rejects its excess refund and the whole request rolls back, leaving another caller able to request.

[Defeat: Raffle.fulfillRandomWords] (1) An EOA directly submits a word and fails inherited wrapper authentication; (2) the wrapper supplies the wrong request ID and it is ignored; (3) the wrapper calls exactly at the callback deadline and it is ignored while refunds become available.

[Defeat: Raffle._settleWinningTicket] (1) Ticket zero has range `[0,0]` and cannot contain a positive winning entry; (2) an adjacent losing ticket fails the range check; (3) a second settlement fails the one-shot guard. For a valid ticket, all USDC units remain allocated exactly once.

[Defeat: Raffle.redeemWinningTicket] (1) A prior owner calls after transferring the winning ticket and fails ownership checking; (2) the current owner supplies a different ticket after settlement and fails the recorded-ID check; (3) a sponsor-controlled prize disables transfers, causing redemption to revert while already released sponsor proceeds remain gone, producing the second finding.

[Defeat: Raffle.refundTickets] (1) Alice supplies the same ticket twice and the second ownership check reverts the entire batch; (2) Alice includes Bob’s ticket and the whole batch reverts; (3) Alice supplies 101 IDs and is rejected before any burn. Unique valid tickets debit exactly their covered entries.

[Defeat: Raffle._update] (1) A holder transfers a ticket to its raffle; (2) to the factory; (3) to a registered sibling raffle. All three destinations are rejected before the claim can become unreachable.

[Defeat: Raffle._transferQuote] (1) Sponsor proceeds are released before treasury fees; (2) treasury fees are released before the cash winner; (3) one beneficiary’s payment fails. The first two leave exact remaining liabilities, while the third rolls back without consuming another cohort’s funds.

[Defeat: Raffle.releaseSponsorPrize] (1) A caller tries to return the prize after an NFT result and is rejected; (2) a caller repeats a successful return and is rejected; (3) the prize refuses its first return and the claimed flag rolls back. The refusal does not impair quote-token claims but confirms the hostile-prize sibling pattern.

[LastOut: create-and-escrow] No USDC claimant exists yet. With a trustworthy prize, the single NFT remains available for exactly one final recipient; with sponsor-controlled prize code, custody is not established, as covered by the first finding.

[LastOut: buy-and-transfer] Alice buys two entries and Bob buys three, creating a 5,000,000-unit pot backed by 5,000,000 units held by the raffle. Ticket transfers change neither side, so there is no pre-resolution shortfall.

[LastOut: successful-draw] The draw moves no USDC or NFT and creates no additional claim. The full pre-draw pot remains available for settlement.

[LastOut: NFT-settlement] With 100 entries, 100,000,000 units split into 95,000,000 sponsor proceeds and 5,000,000 treasury fees. Either USDC beneficiary can leave last and receives its full claim, but the final NFT recipient is not guaranteed delivery because of the two reported prize-boundary defects.

[LastOut: cash-settlement] With 99 entries against a 100-entry reserve, 99,000,000 units split into 79,200,000 for the winner, 14,850,000 for the sponsor, and 4,950,000 for the treasury. In every withdrawal order, the last claimant receives the full recorded amount and the balance ends at zero.

[LastOut: timeout-and-refund] For tickets covering seven, two, and one entries, the 10,000,000-unit liability can be withdrawn in the worst order as 7,000,000, 2,000,000, then 1,000,000. The final ticket receives 1,000,000 in full and liability and balance both end at zero.

[LastOut: empty-raffle] No quote-token liability exists. The only claimant is the sponsor recipient for the NFT; a trustworthy prize transfers completely, while a hostile prize can block or fabricate that transfer without affecting another monetary cohort.

[LastOut: independent-releases] Winner, sponsor, and treasury claims are disjoint and cleared before payment. Under canonical fee-free USDC, every permutation leaves the final claimant fully paid and the accounted balance at zero.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: untrusted-prize-authentication | group_key: RaffleFactory | _validateCreateParams | untrusted-prize-authentication
root_cause: target/packages/contracts/src/RaffleFactory.sol:172 accepts a sponsor-selected contract solely because it self-reports ERC-721 support; the missing trusted-collection validation leaves the deposit callback, custody report, and later delivery report under the same attacker’s control.
internal_pre: None
external_pre: Entrants rely on the factory-created raffle's Active status and purchase entries without independently trusting the sponsor-selected prize implementation.
path:
  1. Mallory deploys `FakePrize` for token 1; it reports ERC-721 support, keeps Mallory's hidden control, and makes its transfer entry point call the raffle receiver with `operator = factory` and `from = Mallory`.
  2. Mallory creates a raffle with `reserveEntries = 100`, token 1, and Mallory as sponsor recipient. `FakePrize.ownerOf(1)` reports the new clone, so the fabricated callback, ownership check, and Active-status check all pass without enforceable custody.
  3. Alice and 99 other entrants each buy one entry, placing 100,000,000 raw USDC units in the raffle.
  4. The draw resolves `NftWon`; settlement allocates 95,000,000 units to Mallory and 5,000,000 units to the treasury.
  5. `FakePrize.transferFrom` can no-op, report the winner from `ownerOf`, and refuse every later operation by that winner. The raffle burns the winning ticket as if delivery succeeded, while Mallory receives 95,000,000 units.
impact: The 100 entrants lose 100 USDC collectively for a raffle with no enforceable prize; the winning ticket owner is left with neither a usable NFT nor a remaining ticket, Mallory captures 95 USDC, and the treasury receives the remaining 5 USDC.
mitigation: Require `prizeToken` to belong to an immutable trusted collection registry or equivalent authenticated set before cloning; ERC-165, receiver callbacks, and `ownerOf` responses from the candidate token cannot authenticate hostile token code.

FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: premature-proceeds-release | group_key: Raffle | _settleWinningTicket | premature-proceeds-release
root_cause: target/packages/contracts/src/Raffle.sol:554 credits `sponsorProceeds` in an `NftWon` result before the advertised NFT has been successfully transferred, so the sponsor's 95% sale claim can leave while prize delivery remains blocked.
internal_pre: A raffle holding its advertised NFT has sold at least its reserve, resolved NftWon, and has not yet redeemed the winning ticket.
external_pre: The sponsor or prize issuer can disable transfers after the initial escrow, such as through a pause or denylist.
path:
  1. Mallory creates a raffle with a transfer-pausable prize token, genuinely escrows token 7 while transfers are enabled, chooses Mallory as sponsor recipient, and sets `reserveEntries = 100`.
  2. Alice and 99 other entrants buy one entry each, supplying 100,000,000 raw USDC units.
  3. Mallory disables transfers from the raffle before redemption; the subsequent authenticated draw still resolves `NftWon`.
  4. A permissionless settler proves the winning ticket. The raffle immediately records 95,000,000 units for Mallory and 5,000,000 units for the treasury while `winnerRedeemed` remains false.
  5. Permissionless release calls send 95,000,000 units to Mallory and 5,000,000 units to the treasury.
  6. Alice, as the selected ticket owner, calls `redeemWinningTicket`; the paused prize transfer reverts, restoring her ticket but leaving no refund transition available from `NftWon`.
impact: The entrants' entire 100 USDC leaves as sponsor proceeds and fees although no prize can be delivered. Mallory captures 95 USDC, while Alice is left holding an unredeemable winning ticket and every entrant bears the cost of an unbacked raffle.
mitigation: In `NftWon`, make both sponsor proceeds and protocol fees unreleasable until `winnerRedeemed` confirms a successful NFT transfer; failed delivery must leave the sale pot unavailable to the sponsor.

COVERAGE | files: `Raffle.sol`—all asset movements, tracked-total writes, ticket ranges, payout orders, deadlines, callbacks, and destination checks; `RaffleFactory.sol`—constructor validation, cloning, initialization, registry ordering, reentrancy, and prize escrow; `IRaffle.sol` and `IRaffleFactory.sol`—all declared lifecycle, accounting, event, error, and getter semantics; `RaffleConstants.sol`—entry units, fee splits, timeouts, and execution bounds; `DESIGN.md`—all stated custody, solvency, liveness, and trust assumptions.

COVERAGE | properties: quote-token conservation, rounding, last-user solvency, refund partitioning, winner ownership, prize custody and delivery, one-shot settlement, payout independence, native-fee pass-through, callback authentication, cross-clone sinks, and all sibling transfer/ownership checks were saturated. No lending positions, health factors, liquidation bonuses, leverage, debt, or bad-debt machinery exists; their analogous raffle-solvency boundaries were covered.

===== RAW SPECIALIST LENS 5 =====

[Model: createRaffle] A sponsor gives one specified prize token and receives an active raffle. The factory’s raffle count rises by one, three registry records are created, and custody should move from the sponsor to the new raffle.

[Model: initialize] No asset moves. The factory records the sponsor, recipients, prize, reserve, and deadline, then places the new raffle in the waiting-for-prize state.

[Model: onERC721Received] The configured prize contract claims that the specified token moved from the sponsor through the factory. The raffle changes from waiting-for-prize to active; no cash total changes.

[Why: RaffleFactory.sol:129] Why is an answer from the sponsor-selected prize contract treated as independent proof of custody? The implicit belief is that an expressly untrusted contract will report ownership truthfully and will preserve that ownership afterward.

[Why: Raffle.sol:428] Why does the prize contract’s own callback activate the raffle? The check assumes its operator, sender, and token fields prove an actual transfer, although that contract chooses every reported field.

[Defeat: createRaffle] 1) `Fake721` reports ERC-721 support, calls the receiver for token 7, and reports the clone as owner without moving anything. 2) `Seizable721` genuinely moves token 7, passes the ownership check, then its issuer takes token 7 back after 100 USDC is sold. 3) `Pausable721` remains recorded as owned by the clone but blocks transfers from that clone when the winner redeems.

[Model: buyEntries] A buyer gives `entryCount * 1,000,000` raw USDC units and receives one bearer ticket covering that many consecutive entries. Lifetime entries, lifetime tickets, and the unallocated sale pot increase by matching amounts.

[Defeat: buyEntries] 1) Buying zero entries is rejected. 2) Buying one entry when the lifetime entry total is already the maximum is rejected. 3) Minting a ticket to the factory, prize contract, implementation, or a registered raffle is rejected before ownership changes.

[Model: _update] A ticket claim moves to another owner or is destroyed after payment. Lifetime entries, lifetime tickets, and cash liabilities do not change.

[Defeat: _update] 1) Sending ticket 1 to its own raffle is rejected. 2) Sending it to the canonical factory is rejected. 3) Sending it to another already-registered raffle is rejected.

[Model: requestDraw] A requester supplies native currency, the wrapper receives its exact request price, and any excess returns to that requester. The raffle enters drawing and records the request time and identifier; USDC totals remain unchanged.

[Model: requestRandomnessPayInNative] The raffle gives the calculated native fee to the authenticated wrapper and receives a request identifier. No ticket or USDC claim changes.

[Why: Raffle.sol:254] Why is an in-flight callback discarded? The request identifier is not known until the wrapper call returns, so the code assumes same-call delivery must be ignored; the configured 30-confirmation wrapper makes such delivery unreachable under the trusted dependency.

[Defeat: requestDraw] 1) With `endTime = 1,000,000`, Mallory’s call at `999,999` is rejected. 2) With sold entries, a call at the exact `1,172,800` request deadline is rejected. 3) A callback sent directly by Mallory rather than the immutable wrapper is rejected by inherited authentication.

[Model: fulfillRandomWords] The authenticated wrapper supplies one random value. No asset moves; the winning entry, resolution time, and NFT-or-cash result are fixed from the already-frozen entry total.

[Why: Raffle.sol:512] Why is a callback at the exact deadline ignored? The protocol defines the callback window as exclusive and opens refunds at that same timestamp, preventing both outcomes from succeeding.

[Defeat: fulfillRandomWords] 1) When request 77 is recorded, callback 76 is ignored. 2) Request 77 carrying two words is ignored. 3) Request 77 arriving exactly at its callback deadline is ignored and the full-refund path is available.

[Model: enableRefunds] No asset moves. The entire unallocated sale pot is reclassified, without rounding, as the aggregate amount owed to all refundable tickets.

[Defeat: enableRefunds] 1) A buyer calling one second before a sold raffle’s draw-request deadline is rejected. 2) Any caller at the exact deadline can move the complete pot into refunds. 3) A later wrapper callback sees the refund state and cannot overwrite it.

[Model: refundTickets] An owner destroys selected tickets and receives exactly their represented entries times 1,000,000 raw USDC units. The aggregate refund liability falls by the same amount.

[Defeat: refundTickets] 1) Supplying ticket 4 twice makes the second ownership check fail and rolls back the entire batch. 2) Supplying Alice’s ticket from Bob’s account rolls everything back. 3) Supplying 101 ticket identifiers is rejected before any ticket changes.

[Model: _settleWinningTicket] No asset moves. The unallocated pot becomes winner, sponsor, and treasury claims whose sum equals the old pot; the pot is then cleared and settlement becomes final.

[Defeat: _settleWinningTicket] 1) Ticket 0’s empty range cannot prove winning entry 37. 2) A ticket covering entries 1–10 cannot prove entry 37. 3) The valid ticket covering 31–40 can settle once, and every second settlement attempt is rejected.

[Model: redeemWinningTicket] The current winning-ticket owner gives up that ticket and receives either the prize token or the entire cash-winner claim. The winner flag is fixed, and either the prize flag or cash-winner liability changes exactly once.

[Why: Raffle.sol:334] Why is an outbound call to the untrusted prize contract the only way to satisfy the winning claim? The lifecycle assumes the contract will still recognize clone ownership and permit delivery, yet there is no refund or recovery transition if it does not.

[Defeat: redeemWinningTicket] 1) Bob cannot redeem Alice’s valid winning ticket. 2) Alice cannot substitute ticket 2 after ticket 1 was settled as the winner. 3) Alice can own the correct ticket while a seizable or paused prize rejects delivery; her transaction rolls back, but the terminal NFT result offers no alternate claim path.

[Model: _transferQuote] One complete recorded USDC claim leaves for its beneficiary. The calling function clears that liability first, while this helper changes no total itself.

[Model: releaseSponsorProceeds] The complete sponsor cash claim is cleared and the same amount goes to the immutable sponsor recipient.

[Model: releaseProtocolFees] The complete fee claim is cleared and the same amount goes to the immutable treasury.

[Model: releaseSponsorPrize] In a cash or refund result, the sponsor’s prize claim is marked complete and the configured token is sent to the immutable sponsor recipient.

[Defeat: releaseSponsorPrize] 1) Calling during an NFT result is rejected. 2) A second release is rejected by the claimed flag. 3) If the prize contract rejects transfer, the claimed flag rolls back, although the contract supplies no alternate delivery route.

[LastOut: create / escrow] There is no cash claimant during creation. With a trustworthy prize contract, the raffle holds exactly one configured token; with the admitted untrusted contract, the eventual sole prize claimant can receive nothing, as captured in the finding below.

[LastOut: buy / transfer] No claim is paid during the sale. Ticket ranges remain contiguous and collectively cover exactly entries 1 through the lifetime sold-entry total.

[LastOut: successful draw] No value leaves during request or callback. The sold-entry total is frozen before drawing, so the selected entry always maps to exactly one issued ticket.

[LastOut: NFT settlement / redemption] For 100 USDC of sales, paying the sponsor’s 95 USDC first leaves exactly 5 USDC for the treasury, and the last cash claimant is paid in full. The separate last prize claimant is not guaranteed payment because the prize contract can invalidate custody.

[LastOut: cash settlement / redemption] For 100 USDC of sales, the claims are exactly 80 USDC to the winner, 15 USDC to the sponsor, and 5 USDC to the treasury. In every release order, the last claimant receives the full remaining amount.

[LastOut: timeout / refund] With tickets covering 2, 3, and 5 entries, the initial liability is 10,000,000 raw units. Refunding the 5-entry and 3-entry tickets leaves 2,000,000, which pays the final 2-entry ticket in full.

[LastOut: empty raffle] No USDC liability exists. The sponsor recipient is the only prize claimant and receives the token if the untrusted prize contract cooperates.

[LastOut: independent releases] Winner, sponsor, and treasury liabilities are cleared independently and atomically. Under canonical fee-free USDC, releasing any two first leaves exactly the recorded third claim for the last recipient.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-custody | group_key: RaffleFactory | createRaffle | untrusted-prize-custody
root_cause: the defect at RaffleFactory.sol:129 is treating `ownerOf()` returned by the sponsor-selected prize contract as independent escrow proof while omitting trusted-provenance validation; the same adversarial contract controls activation at Raffle.sol:428 and later delivery behavior
internal_pre: None
external_pre: None
path:
  1. Mallory deploys `Seizable721`, which reports ERC-721 support, mints token 7 to Mallory, and permits its issuer to seize any token.
  2. Mallory creates a raffle for token 7 with `reserveEntries = 1` and Mallory as `sponsorRecipient`; token 7 genuinely enters the clone, its callback activates the raffle, and `ownerOf(7)` reports the clone.
  3. Alice buys 100 entries in one ticket for 100,000,000 raw USDC units, so ticket 1 contains every possible winning entry.
  4. Mallory invokes `Seizable721`’s issuer-seizure operation and moves token 7 from the clone back to Mallory; no raffle state records that custody disappeared.
  5. After the draw resolves `NftWon`, Mallory permissionlessly settles ticket 1, allocating 95,000,000 raw units to the sponsor recipient and 5,000,000 to the treasury, then releases the sponsor amount.
  6. Alice calls `redeemWinningTicket(1)`, but the prize transfer reverts because the clone no longer owns token 7; `NftWon` permanently excludes the refund path.
impact: Alice, the sole ticket holder and guaranteed winner, loses 100 USDC and receives neither the prize nor a refund; Mallory retains token 7 and 95 USDC, while the treasury receives the remaining 5 USDC, leaving Alice holding the entire missing-prize loss
mitigation: require `params.prizeToken` to belong to an immutable registry of vetted, non-upgradeable ERC-721 contracts that cannot seize or block escrowed tokens; self-reported interface support, callbacks, and ownership cannot validate an adversarial token

COVERAGE | Raffle.sol: initialization, prize activation, purchases, ticket movement, native request/callback ordering, deadlines, refunds, both settlement branches, all releases, tracked liabilities, sink checks, and external-call atomicity.
COVERAGE | RaffleFactory.sol: immutable setup, clone initialization and registration ordering, creation rollback, prize validation and escrow; IRaffle.sol and IRaffleFactory.sol: ABI, events, errors, lifecycle, and documented semantics; RaffleConstants.sol: units, rates, limits, and time windows; DESIGN.md: every custody, accounting, isolation, and timing claim compared with source.
COVERAGE | Properties: quote-token solvency, exact allocation, contiguous ranges, one-shot transitions, callback authentication/staleness/duplication, deadline races, last-user-out for refund/cash/NFT liabilities, clone isolation, and every prize interaction at `supportsInterface`, deposit, callback, ownership verification, winner delivery, and sponsor return. No cross-chain state or messages exist; the asynchronous surface is the VRF request/callback pair.

===== RAW SPECIALIST LENS 6 =====

[Model: implementation lock]
No participant gives or receives value. The reusable implementation is permanently marked unusable, preventing it from becoming an unbacked raffle.

[Model: clone initialization]
The factory supplies the sponsor, recipients, prize identity, reserve, and timing. No asset moves; the clone advances once to waiting for its configured prize.

[Model: raffle creation]
The sponsor gives one prize NFT and receives a future claim to proceeds or return of that NFT. The factory’s raffle count grows by one, its three registry records are created, and the new raffle becomes active only after custody is confirmed.

[Model: prize activation]
The sponsor’s configured NFT enters the raffle. Prize custody begins and the lifecycle changes from waiting for the prize to active.

[Model: entry purchase]
A buyer gives `entryCount × 1,000,000` raw USDC units; the recipient receives one transferable ticket covering exactly that many entries. Sold entries, tickets issued, and the unallocated sales total increase.

[Model: ticket ownership update]
A holder gives a ticket to another address, transferring its complete bearer claim. Entry counts, sales totals, and liabilities do not change.

[Model: draw funding]
The requester gives native currency; Chainlink receives the actual request price and the requester receives every excess unit. The raffle records one pending draw, but its USDC totals do not change.

[Model: refund activation]
No asset moves. The entire unallocated sales total is reclassified one-for-one as the outstanding refund total.

[Model: random resolution]
No asset moves. One entry from the fixed sold-entry population is selected, and the outcome becomes either NFT-won or cash-won.

[Model: permissionless winner settlement]
The caller gives no asset and receives no asset. The winning range is proved and the unallocated sales total is divided into winner, sponsor, and treasury claims.

[Model: terminal allocation]
For an NFT result, the sales total becomes 95% sponsor and 5% treasury claims. For a cash result, it becomes 80% winner, 15% sponsor, and 5% treasury claims.

[Model: winning redemption]
The current winning-ticket owner destroys the ticket and receives either the NFT or the complete cash-winner amount. The corresponding winner or prize claim is consumed exactly once.

[Model: ticket refund]
A holder destroys selected live tickets and receives `represented entries × 1,000,000` raw USDC units. The outstanding refund total decreases by exactly the payment.

[Model: sponsor cash release]
The sponsor recipient receives the complete sponsor claim. That claim is cleared atomically.

[Model: protocol fee release]
The treasury receives the complete protocol-fee claim. That claim is cleared atomically.

[Model: sponsor prize return]
After a cash result or refund transition, the sponsor recipient receives the escrowed NFT and the single prize claim is consumed.

[Model: quote payout helper]
A beneficiary receives one complete USDC claim whose corresponding liability has already been cleared. A failed payment restores all preceding state changes.

[Model: rejected native transfer]
A sender attempting an unrelated native-currency transfer receives no claim; the transaction rejects, so no value or tracked total changes.

[Why: Raffle.sol:223]
Why does multiplying a 128-bit entry count by `1,000,000` preserve scale and safety? Each entry is exactly `1,000,000` six-decimal units, and the maximum product occupies only 148 bits.

[Why: Raffle.sol:231]
Why is there no separate overflow guard for the ticket count? Every ticket contains at least one entry, so tickets issued can never exceed sold entries, whose 128-bit capacity is checked first.

[Why: Raffle.sol:253]
Why may the current timestamp be narrowed to 64 bits? Creation and request windows keep accepted timestamps near deployment time, relying on the realizable-chain assumption that timestamps remain below `2^64`.

[Why: Raffle.sol:254]
Why must an in-progress request temporarily reject resolution? The request identifier is not recorded until the external request returns, so accepting a synchronous response would compare against incomplete state.

[Why: Raffle.sol:258]
Why is the actual price checked after requesting randomness? The trusted wrapper reports the definitive price during the request, and transaction rollback restores the payment and lifecycle if it exceeds the supplied value.

[Why: Raffle.sol:363]
Why can refund arithmetic trust a stored historical range? Ownership is verified first, only a purchase creates the range, and a live ticket cannot previously have been destroyed.

[Why: Raffle.sol:368]
Why cannot subtracting a refund underflow the refund total? The total initially equals all ticket values, ranges are disjoint, and each live ticket can be destroyed only once.

[Why: Raffle.sol:459]
Why cannot adding two days overflow the request deadline? The end time is 64-bit and is widened before adding a small constant.

[Why: Raffle.sol:464]
Why is zero a safe “no callback deadline” sentinel? A valid draw records a practical nonzero chain timestamp before an asynchronous response can be accepted.

[Why: Raffle.sol:518]
Why are modulo-by-zero and narrowing excluded? Entering the draw requires at least one entry, sales are then frozen, and the selected value is at most the 128-bit sold-entry total.

[Why: Raffle.sol:542]
Why is the protocol fee rounded down? The specification assigns the aggregate floor to the treasury; moreover, every valid pot is a multiple of `1,000,000`, making the 5% result exact.

[Why: Raffle.sol:547]
Why is the sponsor amount calculated as the remainder? This assigns every raw unit exactly once even if percentage division could leave dust; at the configured entry scale, the result is exactly 15%.

[Why: RaffleFactory.sol:76]
Why does the factory check six decimals? It establishes the arithmetic scale; canonical token identity remains an explicit deployment trust boundary rather than something decimals metadata can prove.

[Why: RaffleFactory.sol:101]
Why is the duration subtraction ordered safely? A preceding strict comparison proves the supplied end time exceeds the current time.

[Why: RaffleFactory.sol:105]
Why is the raffle count increment not separately capped? Exhausting 256 bits would require `2^256` successful clone creations and is not a reachable economic state.

[Defeat: buyEntries]
1. Mallory buys one entry: she pays `1,000,000`, receives range `[1,1]`, and creates exactly that liability.
2. From an empty raffle she requests `2^128−1` entries: the `148`-bit gross amount and terminal range remain representable.
3. With `totalEntries = 2^128−2`, she requests two entries: the bounds check rejects the purchase; requesting one safely reaches the maximum.

[Defeat: requestDraw]
1. A requester supplies an exact `1,000`-wei price: all `1,000` wei go to the wrapper.
2. The requester supplies `1,001` wei for a `1,000`-wei actual price: exactly one wei returns.
3. If the actual price is `1,001` while only `1,000` was supplied, the transaction reverts atomically and retains nothing.

[Defeat: enableRefunds]
1. A sold raffle is finalized one second before its request deadline: the transition is rejected.
2. It is finalized exactly at the deadline: the entire pot moves into refund liability.
3. The sponsor closes an empty raffle before sale end: both quote-token totals remain zero and only the NFT-return path opens.

[Defeat: fulfillRandomWords]
1. With three entries, random word `0` selects entry `1`.
2. Word `1` selects entry `2`.
3. Word `2^256−1` selects entry `1`; modulo bias gives one bucket only one extra preimage out of `2^256`, and authenticated randomness is not caller-selectable.

[Defeat: _settleWinningTicket]
1. A one-entry cash raffle allocates `800,000` to the winner, `150,000` to the sponsor, and `50,000` to the treasury.
2. At `2^128−1` entries, the gross amount is 148 bits and even the largest rate numerator is only 161 bits.
3. A second settlement attempt is rejected before any allocation can repeat.

[Defeat: refundTickets]
1. Submitting `[1,1]` destroys the first occurrence and then fails ownership on the duplicate, reverting the entire operation.
2. Refunding 100 distinct tickets cannot aggregate more than the globally capped sold-entry count.
3. A final one-entry ticket against a `1,000,000` liability receives all `1,000,000`, leaving zero.

[Defeat: createRaffle]
1. An end time equal to the current timestamp is rejected.
2. An end time exactly 30 days later is accepted without truncation.
3. An end time 30 days and one second later is rejected before clone creation or prize movement.

[Defeat: terminal claim ordering]
1. From a `3,000,000` cash pot, the winner claims `2,400,000` first.
2. The treasury may then claim `150,000`.
3. The sponsor, claiming last, still receives the full remaining `450,000`; either other ordering yields the same result.

[Defeat: percentage granularity]
1. One entry produces exact 5%, 80%, 15%, and 95% amounts.
2. Splitting purchases across many tickets does not split settlement calculations because rates apply once to the aggregate pot.
3. Forced USDC donations do not enter the tracked pot and therefore cannot alter rates or claims.

[Defeat: deadline boundaries]
1. A draw at `endTime−1` is rejected as early.
2. A draw at `endTime` is accepted.
3. A draw or callback exactly at its exclusive deadline is rejected while refunds become available at that same timestamp.

[LastOut: create and escrow]
There is one NFT and one raffle custodian. No fractional claim is created; the NFT remains available for exactly one eventual winner delivery or sponsor return.

[LastOut: buy and transfer]
For tickets covering `[1,2]`, `[3,5]`, and `[6,6]`, six entries create `6,000,000` of backed claims. Transfers change claim ownership but not the total or range coverage.

[LastOut: successful draw]
The requester’s full excess is returned in the request transaction. The USDC pot remains untouched and fully backed while awaiting terminal allocation.

[LastOut: NFT settlement and redemption]
With three entries, the sponsor and treasury claims are `2,850,000` and `150,000`. Whichever claims last is paid in full, and the winning-ticket owner independently receives the NFT.

[LastOut: cash settlement and redemption]
With three entries, claims are `2,400,000`, `450,000`, and `150,000`. After any two claimants withdraw, the last receives its complete fixed balance; the raffle is short by zero.

[LastOut: timeout and refunds]
Alice’s two-entry ticket, Bob’s three-entry ticket, and Carol’s one-entry ticket start with `6,000,000` liability. After Alice and Bob receive `2,000,000` and `3,000,000`, Carol receives the final `1,000,000`; the shortfall is zero.

[LastOut: empty raffle]
There is no quote-token claimant. The sole escrowed NFT returns exactly once to the sponsor recipient.

[LastOut: independent releases]
Winner, sponsor, and treasury releases clear separate fixed claims. Every permutation ends with the final claimant paid in full and the accounted USDC balance at zero.

NO FINDINGS OR LEADS

Coverage: `Raffle.sol` — entry/range arithmetic, all liability migrations, percentage allocation, refund aggregation, native-fee subtraction, random modulo, timestamp/count casts, boundary ordering, and every payout order. `RaffleFactory.sol` — decimal scale, end-time subtraction, duration limits, raffle counter, registry sequencing, and escrow activation. `IRaffle.sol` and `IRaffleFactory.sol` — ABI widths, units, return types, lifecycle descriptions, and economic percentages against implementation behavior. `RaffleConstants.sol` — six-decimal price, basis-point denominator/rates, time units, batch cap, and gas/count widths. `DESIGN.md` — floor/remainder policy, terminal splits, exclusive deadlines, and full-refund requirements. Properties covered: zero/minimum/maximum inputs, division direction, remainder allocation, division-before-multiplication, intermediate overflow, narrowing casts, subtraction ordering, modulo bias, sibling arithmetic sites, saturation across both result branches, and the Last User Out test.

===== RAW SPECIALIST LENS 7 =====

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `RaffleFactory.createRaffle`: the sponsor gives one prize collectible and receives an active raffle; the raffle count rises by one and the ID/address registry gains one binding.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.initialize`: no asset moves; the factory records the sponsor, beneficiaries, prize, reserve, and timing, then marks the raffle as waiting for its prize.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.onERC721Received`: the configured prize is expected to arrive from its sponsor, and the raffle becomes active; quote-token totals remain zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.buyEntries`: the buyer gives `entryCount * 1,000,000` quote units, the recipient gets one range ticket, and sold entries, ticket count, and the unallocated pot increase correspondingly.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle._update`: a holder gives the bearer ticket to another holder; the ticket owner changes but its represented entries and all quote liabilities remain unchanged.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.requestDraw`: the requester gives native currency, Chainlink receives the current fee, excess returns to the requester, and the raffle records one pending draw and its time.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.fulfillRandomWords`: nobody gives or receives an asset; one sold entry becomes the winner and the result becomes either NFT-won or cash-won.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.enableRefunds`: no asset moves; the entire unallocated pot is reclassified as the amount owed to refundable tickets.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle._settleWinningTicket`: no asset moves; the unallocated pot becomes winner, sponsor, and treasury claims whose sum remains exact.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.redeemWinningTicket`: the current winner gives up and burns the winning ticket, receiving either the prize NFT or the complete cash-winner claim.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.refundTickets`: the owner burns selected tickets, receives exactly one USDC per represented entry, and the aggregate refund amount falls by the same value.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseSponsorProceeds`: the immutable sponsor recipient receives its complete quote-token claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseProtocolFees`: the immutable treasury receives its complete fee claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseSponsorPrize`: after a cash or refund result, the sponsor recipient receives the configured prize and the one-prize claim is closed.

[Why: RaffleFactory.sol:129] Why is the prize contract’s current ownership report treated as proof of durable escrow? The implicit belief is that an arbitrary ERC-721 cannot later revoke custody or lie about it, despite that contract being untrusted.

[Why: Raffle.sol:254] Why is an in-flight request flagged before calling the wrapper? The request identifier is not recorded until the wrapper returns, so accepting a synchronous callback would validate randomness against incomplete state.

[Why: Raffle.sol:498] Why may holder-to-holder transfers continue while the draw is pending? The design assumes transferability remains information-neutral, but a pending fulfillment can reveal the winner to the transaction-ordering layer before the state transition lands.

[Why: Raffle.sol:512] Why is a callback rejected exactly at its deadline? This makes callback acceptance and refund availability mutually exclusive at the boundary.

[Why: Raffle.sol:538] Why does settlement not inspect ticket ownership? Settlement only allocates liabilities; ownership is deliberately deferred until redemption so the bearer claim follows the ticket.

[Why: Raffle.sol:378] Why may sponsor proceeds leave before successful NFT delivery? The implementation assumes the escrowed prize remains durably transferable; an untrusted prize contract invalidates that assumption.

[Defeat: Raffle.initialize] (1) An EOA calling a fresh clone fails because only the immutable factory is accepted. (2) A caller targeting the implementation fails because it is already initialized. (3) A malicious prize callback attempting reinitialization fails because clone initialization already completed atomically.

[Defeat: RaffleFactory.createRaffle] (1) An unrelated address invoking the receiver callback fails the configured-token check. (2) A token callback with the wrong ID, sponsor, or operator fails. (3) A sponsor-controlled ERC-721 can genuinely deposit, pass every check, and later seize the prize through a privileged transfer; this succeeds and is reported below.

[Defeat: Raffle.buyEntries] (1) A purchase at `endTime` fails. (2) A zero-entry purchase fails. (3) A recipient callback trying to buy again is blocked and rolls back, but removal of the prize by its own contract is not checked before payment.

[Defeat: Raffle.requestDraw] (1) A frontrunner may pay the fee and request first, but cannot choose the VRF result or receive protocol value. (2) Buying entries in the same block at `timestamp == endTime` fails. (3) A request at `endTime + 2 days` fails while refunds become available.

[Defeat: Raffle.fulfillRandomWords] (1) A direct callback from a non-wrapper address fails inherited authentication. (2) A wrong request ID or wrong word count is ignored. (3) A genuine pending fulfillment can be simulated and ordered around an already-authorized ticket transfer; callback authentication does not bind ticket ownership.

[Defeat: Raffle._update] (1) An attacker without ownership or approval cannot transfer ticket 42. (2) An approved transfer to the factory or a registered same-factory raffle fails. (3) A marketplace executing the owner’s valid fixed-price order can transfer ticket 42 to a searcher while status is `Drawing`; this succeeds and is reported below.

[Defeat: Raffle.enableRefunds] (1) A sold raffle cannot enter refunds before the request deadline. (2) A valid callback landing before its deadline changes status and makes the refund transaction fail. (3) At the exact deadline, the callback is rejected and refunds succeed, so there is no ambiguous timestamp.

[Defeat: Raffle._settleWinningTicket] (1) A ticket outside the winning range fails. (2) Frontrunning settlement with the correct ticket cannot redirect its claim. (3) Repeating settlement fails, although settlement still permits sponsor funds to leave before an untrusted prize is delivered.

[Defeat: release paths] (1) Frontrunning sponsor release still pays the immutable sponsor recipient. (2) Frontrunning fee release still pays the immutable treasury. (3) A second prize release fails, but an already-seized prize can make winner delivery fail after sponsor and treasury quote claims have left.

[LastOut: create / escrow] With an honest prize, exactly one NFT enters and remains for one terminal recipient. With a sponsor-seizable prize, the eventual NFT winner is last out and receives zero of the one NFT owed: the raffle is short exactly one prize.

[LastOut: buy / transfer] For 100 one-entry tickets, the clone receives exactly `100,000,000` quote units and records the same unallocated pot. Ticket transfers do not alter this balance; no quote shortfall appears.

[LastOut: successful draw] The callback moves no asset and creates no additional liability. The full pot and one prize remain available, although pending-result ordering can change which economic cohort owns the winning ticket.

[LastOut: settle / redeem NFT] From a `100,000,000`-unit pot, sponsor and treasury claims are `95,000,000` and `5,000,000`; either can be paid last in full. With honest custody, the winning owner also receives one NFT. Under the revocable-prize path, the winner receives no NFT and holds the entire one-prize shortfall.

[LastOut: settle / redeem cash] From a `100,000,000`-unit pot, winner, sponsor, and treasury receive `80,000,000`, `15,000,000`, and `5,000,000`. In every release order, the last claimant is paid in full and the remaining quote liability reaches zero.

[LastOut: timeout / refund] For tickets representing 40, 35, and 25 entries, sequential refunds pay `40,000,000`, `35,000,000`, and `25,000,000`. The final holder receives all `25,000,000`; the clone is short by zero.

[LastOut: empty raffle] No quote claim exists. With an honest prize, the sponsor recipient is the only claimant and receives the one escrowed NFT in full.

[LastOut: independent releases] Winner, sponsor, treasury, and sponsor-prize releases debit distinct claims. Reordering them creates no quote deficit; only loss of external prize custody breaks the final-claimant result.

[Saturation: ticket-transfer-ordering] Checked minting at `Raffle.sol:235`, inherited approvals and transfers through `Raffle.sol:497-502`, burns at `Raffle.sol:325` and `Raffle.sol:364`, current-owner selection at `Raffle.sol:320`, and every `Drawing`, `NftWon`, `CashWon`, and `Refunding` branch. NFT- and cash-winner sniping share the same missing lifecycle transfer lock and are one finding.

[Saturation: prize-custody] Checked interface admission at `RaffleFactory.sol:172`, initial transfer and ownership verification at `RaffleFactory.sol:128-132`, receipt at `Raffle.sol:416-430`, winner delivery at `Raffle.sol:334-336`, sponsor return at `Raffle.sol:404-405`, and all settlement/release paths. Every check ultimately trusts the same prize contract, so fake escrow, later seizure, and false delivery reports share one admission defect and mitigation.

[Saturation: totals-and-ordering] Checked every write to sold entries, ticket count, unallocated pot, refund liability, winner proceeds, sponsor proceeds, fees, raffle count, registry state, winning entry, settlement flags, and prize flags. Initialization, sale, request, callback/refund boundary, rounding, duplicate claims, and release ordering produced no additional surviving candidate.

FINDING | contract: Raffle | function: _update | bug_class: vrf-reveal-front-running | group_key: Raffle | _update | vrf-reveal-front-running
root_cause: Raffle.sol:498 checks only whether the destination is protocol plumbing and omits a lifecycle transfer lock, so holder-to-holder transfers remain executable while the authenticated fulfillment revealing the winning entry is pending and after it lands.
internal_pre: The raffle is Drawing with 100 one-entry tickets, reserveEntries is 100, and ticket 42 is approved to a marketplace.
external_pre: Ticket 42 has an executable fixed-price signed order for 100 USDC, and a searcher or block builder can observe or simulate the pending VRF fulfillment before ordering transactions.
path:
  1. One hundred buyers pay 100,000,000 raw USDC in total for a raffle whose prize has a 10,000 USDC market value; Alice owns ticket 42 and lists it for 100,000,000 raw USDC before resolution.
  2. A requester starts the draw, leaving the raffle in Drawing while Alice’s order remains executable.
  3. The pending authenticated fulfillment yields random word 41, so `(41 % 100) + 1` reveals that entry and ticket 42 will win.
  4. A searcher orders a marketplace fill before the fulfillment, pays Alice 100 USDC plus gas, and receives ticket 42 because `_update` has no Drawing-state restriction.
  5. The fulfillment records entry 42 as the winner; the searcher settles and redeems ticket 42 for the 10,000 USDC NFT.
impact: Alice, the stale-order seller, loses 9,900 USDC of revealed winning-claim value; the searcher captures approximately 9,900 USDC minus gas even though Alice had no opportunity to react to the pending fulfillment.
mitigation: In `_update`, reject holder-to-holder transfers while status is Drawing, NftWon, or CashWon, while continuing to permit protocol burns.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: revocable-prize-custody | group_key: RaffleFactory | _validateCreateParams | revocable-prize-custody
root_cause: RaffleFactory.sol:172 accepts a sponsor-selected prize solely from its self-reported ERC-721 interface support; the missing trusted-token or irrevocable-custody admission check lets a token with privileged seizure pass the one-time ownership check at RaffleFactory.sol:129 and later remove the prize.
internal_pre: An Active raffle has reserveEntries of 10,000, 9,999 entries have sold, and the attacker is both the prize-token administrator and sponsor recipient.
external_pre: The configured ERC-721 exposes a sponsor-controlled privileged transfer or upgrade that can move an escrowed token without raffle approval; draw and transaction costs are below the 9,500 USDC sponsor allocation.
path:
  1. The attacker genuinely deposits a 20,000 USDC NFT from an ERC-721 that reports interface support and truthful ownership, so creation and the one-time custody check succeed.
  2. Buyers purchase 9,999 entries for 9,999,000,000 raw USDC; Alice broadcasts a final one-entry purchase that would meet the 10,000-entry reserve.
  3. The attacker frontruns Alice with the token’s privileged transfer, moving the NFT from the raffle back to itself while the raffle remains Active.
  4. Alice’s purchase still transfers 1,000,000 raw USDC because `buyEntries` never detects the lost prize; the pot becomes 10,000,000,000 raw USDC and the reserve is met.
  5. The attacker funds the draw, the result becomes NftWon, and settlement allocates 9,500,000,000 raw USDC to the attacker’s sponsor recipient and 500,000,000 to the treasury; both amounts can be released.
  6. The winning buyer calls `redeemWinningTicket`, but prize transfer reverts because the raffle no longer owns the NFT, leaving the ticket permanently unredeemable with no refund transition.
impact: Entrants collectively lose 10,000 USDC, of which the attacker captures 9,500 USDC while retaining the 20,000 USDC prize; the winning-ticket owner is left holding an unbacked claim and the treasury holds the remaining 500 USDC.
mitigation: Add an immutable trusted-prize registry check in `_validateCreateParams` and admit only vetted, non-upgradeable ERC-721 contracts without privileged seizure; self-reported interface and ownership answers cannot establish this property.

[Coverage: files] `Raffle.sol`—all asset movements, ticket ownership paths, totals, deadlines, callback, settlement, refunds, and releases; `RaffleFactory.sol`—constructor trust, atomic clone initialization, registry ordering, prize admission, and escrow; `IRaffle.sol`—all lifecycle, ownership, accounting, timing, event, and error promises; `IRaffleFactory.sol`—creation parameters and registry guarantees; `RaffleConstants.sol`—entry price, fee splits, limits, timeouts, and VRF configuration; `DESIGN.md`—all stated custody, transferability, deadline, and independent-claim properties.

[Coverage: properties] Quote solvency and rounding, ticket-range continuity, initialization races, sale and deadline ordering, VRF authentication and reveal ordering, cancellation grief, last-user-out for every terminal branch, one-shot settlement, current-owner redemption, untrusted prize custody, protocol-destination filtering, cross-clone movement, native-fee pass-through, and absence of swaps, price oracles, signatures, shares, or cross-chain accounting were covered.

===== RAW SPECIALIST LENS 8 =====

[Model: createRaffle] A sponsor gives one prize and receives an active raffle. The lifetime raffle count rises by one, and the registry binds one new identifier to one new raffle; buyer-money totals remain zero.

[Model: initialize] The factory supplies the sponsor, beneficiaries, prize identity, reserve, and closing time. The raffle moves from unused to waiting for its prize; no asset or liability moves.

[Model: onERC721Received] The configured prize contract presents the sponsor’s prize. The raffle opens entry sales; no USDC total changes.

[Model: buyEntries] A buyer gives 1 USDC per entry, and the chosen recipient receives one ticket covering those entries. Lifetime entries, lifetime tickets, and the unallocated sale pot increase by the corresponding amounts.

[Model: _update] A ticket owner gives the same bearer claim to another address. Entry coverage and every USDC total remain unchanged.

[Model: requestDraw] A caller gives the randomness service its native-currency fee and receives any excess back. The raffle records the request and enters the drawing state; USDC liabilities do not change.

[Model: fulfillRandomWords] Nobody gives or receives value. Authenticated randomness selects one sold entry and fixes either the NFT or cash result.

[Model: enableRefunds] No new money enters. The complete unallocated sale pot becomes the aggregate refund liability, preserving the total amount owed.

[Model: settleWinningTicket] Nobody receives assets yet. The unallocated pot becomes the winner, sponsor, and treasury claims, whose sum equals the old pot.

[Model: redeemWinningTicket-nft] The winning owner burns the winning ticket and should receive the escrowed prize. The prize changes from unclaimed to claimed; USDC totals are unchanged.

[Model: redeemWinningTicket-cash] The winning owner burns the winning ticket and receives the complete cash-winner claim. That claim falls to zero.

[Model: refundTickets] An owner burns up to 100 tickets and receives exactly 1 USDC per represented entry. The aggregate refund liability decreases by the same amount.

[Model: releaseSponsorProceeds] The immutable sponsor recipient receives the complete sponsor claim, which becomes zero.

[Model: releaseProtocolFees] The immutable treasury receives the complete fee claim, which becomes zero.

[Model: releaseSponsorPrize] After a cash or refund result, the sponsor recipient receives the prize. The prize becomes claimed; buyer-money liabilities are independent.

[Model: _transferQuote] One named beneficiary receives one complete USDC claim after its matching liability has been reduced. A failed payment restores the entire transaction.

[Why: RaffleFactory.sol:129] Why does one ownership answer prove escrow? Because the design assumes the sponsor-selected prize contract truthfully describes and preserves custody, even though that same contract supplies both the transfer behavior and the answer.

[Why: Raffle.sol:235] Why is the ticket-recipient call made after recording the purchase? Because any rejection must undo the payment and all totals atomically; it does.

[Why: Raffle.sol:254] Why is an in-flight flag needed? Because the code assumes the trusted randomness service normally answers later and deliberately refuses a callback arriving before the request identifier is stored.

[Why: Raffle.sol:267] Why must excess native currency be returned synchronously? Because the raffle keeps no native-currency claim ledger; a rejecting requester therefore cancels only its own request attempt.

[Why: Raffle.sol:298] Why is the entire pot copied into refund liability? Because every live ticket remains entitled to its full purchase price, with no other USDC cohort sharing that branch.

[Why: Raffle.sol:315] Why may redemption settle first without reading ownership? Because the ticket remains transferable after allocation and ownership is checked immediately before burning it.

[Why: Raffle.sol:334] Why can failed NFT delivery only revert? Because there is no terminal deadline or alternate state transition; the code assumes every accepted prize remains transferable forever.

[Why: Raffle.sol:335] Why check reported ownership after delivery? It catches an honest no-op transfer, but still assumes the untrusted prize contract answers truthfully.

[Why: Raffle.sol:368] Why reduce refund liability before paying? Because transaction rollback restores both the ticket and liability if payment fails, preventing repeat claims.

[Why: Raffle.sol:375] Why may sponsor proceeds leave before NFT delivery? Because settlement is treated as economically final, implicitly assuming the prize handoff cannot fail permanently.

[Why: Raffle.sol:404] Why does sponsor-prize return use the same untrusted token calls? Because the sponsor selected that asset; failure does not obstruct buyer refunds or cash-winner payment.

[Why: Raffle.sol:511] Why are malformed, early, late, and mismatched callbacks ignored? Because reverting a trusted callback could consume its only delivery attempt, while timeout refunds supply the recovery path.

[Why: Raffle.sol:544] Why does the sponsor receive the arithmetic remainder? Because this allocates every raw USDC unit and prevents last-claimant dust shortfalls.

[Why: Raffle.sol:602] Why are code-less destinations skipped during the registry check? Because they cannot be registered raffles yet, implicitly accepting that a predictable future raffle address can receive a ticket before deployment.

[Defeat: _validateCreateParams] (1) Mallory’s prize contract returns true for the NFT interface; (2) it permits token 1 to enter the raffle but rejects every later exit; (3) an upgradeable prize behaves normally during creation and changes behavior after buyers pay. All three pass the interface check.

[Defeat: createRaffle] (1) EvilNFT directly produces the expected receiver callback; (2) it reports the raffle as token owner during the factory check; (3) it later permanently disables transfers from the raffle. Creation detects none of the future-delivery failure.

[Defeat: buyEntries] (1) Alice buys at exactly the closing timestamp and is rejected; (2) Mallory names the factory as recipient and the sink check rejects it; (3) a recipient contract rejects its ticket and the payment plus all totals roll back. None creates shared unavailability.

[Defeat: requestDraw] (1) Eve requests one second before closing and is rejected; (2) a requester overpays by 1 wei but rejects the refund, cancelling only its own transaction; (3) Eve directly forges a callback and the inherited sender check rejects her. Another caller remains able to request.

[Defeat: enableRefunds] (1) A nonsponsor tries to close an empty raffle before its end and is rejected; (2) Eve tries to refund a sold raffle one second before the request deadline and is rejected; (3) a callback arriving at the exact callback deadline is ignored while refunds become available. No gap traps buyer money.

[Defeat: fulfillRandomWords] (1) An external account sends a callback and fails authentication; (2) an authenticated callback supplies request ID 999 instead of the recorded ID and is ignored; (3) the correct callback arrives at the exclusive deadline and is ignored in favor of timeout refunds.

[Defeat: settleWinningTicket] (1) Mallory supplies nonexistent ticket 999 and its zero range fails; (2) Mallory supplies a real losing ticket and its range fails; (3) Mallory repeats the correct ticket after settlement and the one-shot guard fails. Allocation cannot be poisoned.

[Defeat: redeemWinningTicket] (1) Mallory submits Alice’s winning ticket but is not its owner; (2) Mallory submits ticket 2 after ticket 1 was recorded as winner; (3) EvilNFT permanently rejects the raffle-to-Alice prize transfer. The first two fail safely; the third permanently blocks the only NFT redemption path.

[Defeat: refundTickets] (1) Alice supplies 101 ticket IDs and is rejected before iteration; (2) she repeats ticket 7 and the entire batch rolls back; (3) she includes Bob’s ticket and the entire batch rolls back. Alice can retry with batches of at most 100, so no shared queue can be poisoned.

[Defeat: releaseSponsorProceeds] (1) An arbitrary caller cannot redirect the payment from the immutable recipient; (2) a recipient cannot reenter through canonical USDC delivery; (3) Mallory releases the 95-USDC sponsor claim before the blocked NFT winner receives anything. The third move amplifies the surviving delivery defect.

[Defeat: releaseSponsorPrize] (1) The prize contract reverts; (2) it lies about returned ownership; (3) the sponsor recipient cannot manage the received NFT. These affect the sponsor-selected asset and do not poison buyer refunds or cash payout, so they do not create a separate cross-user finding.

[Defeat: _isProtocolDestination] (1) Sending a ticket to the factory is rejected; (2) sending it to an already registered raffle is rejected; (3) sending it to the predictable address of the next undeployed raffle passes and becomes trapped after deployment. The third path requires the payer or authorized owner to strand its own claim, so it is excluded as self-harm.

[Defeat: _transferQuote] (1) A payout to a current protocol raffle is rejected; (2) a malicious recipient contract cannot invoke a receipt hook because canonical USDC has none; (3) a blocked cash winner can transfer the still-live ticket to another address before redemption. No shared USDC withdrawal is poisoned.

[LastOut: create/escrow] With a stable compliant prize, the raffle holds exactly one prize before accepting buyers. With a mutable hostile prize, the factory’s initial check cannot guarantee later delivery; this survives as the terminal-delivery finding.

[LastOut: buy/transfer] Ten sold entries produce exactly 10 USDC in the unallocated pot and ranges covering entries 1 through 10. Ticket transfers change no backing; the eventual last claimant remains fully funded.

[LastOut: successful draw] The native fee leaves for the trusted randomness service and excess returns in the same transaction. No USDC leaves; if no callback arrives, all 10 USDC can become refundable at the deadline.

[LastOut: settle/redeem NFT] For 10 entries, 9.5 USDC goes to the sponsor and 0.5 USDC to the treasury; both are fully payable in either order. With a compliant prize, the winner receives the NFT. With EvilNFT blocking line 334, the last claimant receives no prize and has no refund path: the shortfall is the entire promised NFT.

[LastOut: settle/redeem cash] For 10 entries, the cash winner receives 8 USDC, the sponsor 1.5 USDC, and the treasury 0.5 USDC. In every release order the last claimant receives the full amount; USDC shortfall is zero.

[LastOut: timeout/refund] Tickets covering 7, 2, and 1 entries can refund in that worst order: liability moves from 10 to 3 to 1 to 0 USDC. The final one-entry owner receives the full 1 USDC; shortfall is zero.

[LastOut: empty raffle] No USDC claimant exists. The sponsor recipient receives the prize after cancellation; with a compliant prize, the last asset leaves and nothing remains owed.

[LastOut: independent releases] Winner, sponsor, and treasury claims are fixed before any release. Paying any two first cannot consume the third’s backing; the final USDC claimant is paid in full.

FINDING | contract: Raffle | function: redeemWinningTicket | bug_class: permanent-prize-delivery-dos | group_key: Raffle | redeemWinningTicket | permanent-prize-delivery-dos
root_cause: Raffle.sol:334 in Raffle.redeemWinningTicket makes the sole NftWon exit depend on a sponsor-selected prize-contract call and omits a timeout transition from NftWon to Refunding when that call can never succeed.
internal_pre: A raffle using the attacker-controlled prize has sold 100 entries, totalEntries is at least reserveEntries, and the authenticated draw has set status to NftWon.
external_pre: The prize contract accepts the initial sponsor-to-raffle transfer but can later make every raffle-to-winner transfer permanently revert; honest buyers participate. No market, oracle, or chain condition is required.
path:
  1. Mallory deploys EvilNFT with token 1 and creates a raffle with reserveEntries = 1 and Mallory as sponsorRecipient; outbound transfers are initially enabled, so factory escrow succeeds.
  2. Alice and Bob collectively buy 100 entries for 100 USDC.
  3. Mallory irreversibly disables transfers whenever EvilNFT token 1 is sent from the raffle.
  4. After closing, the draw resolves NftWon because 100 entries exceed the reserve.
  5. Mallory calls settleWinningTicket with the winning ticket, allocating 95 USDC to Mallory and 5 USDC to the treasury, then releases both claims.
  6. The winning owner calls redeemWinningTicket; the call at line 334 reverts permanently. The ticket burn rolls back, but NftWon has no refund or alternate-delivery exit.
impact: For only deployment gas and an optional randomness fee, Mallory receives 95 USDC from an undeliverable raffle while the treasury receives 5 USDC. The entrants funded 100 USDC without any prize being delivered, and the winning-ticket owner is permanently left holding the failed prize claim; no ticket can obtain a refund.
mitigation: Keep all NftWon USDC proceeds unreleasable until prize delivery succeeds, and add a fixed post-resolution deadline that atomically moves the full untouched pot into remainingRefundLiability if delivery has not succeeded.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: self-attested-prize-escrow | group_key: RaffleFactory | createRaffle | self-attested-prize-escrow
smell: RaffleFactory.sol:128-132 treats a callback and ownerOf response controlled by the same sponsor-selected prize contract as proof of escrow.
unverified: Ownership of an arbitrary NFT exists only through that contract’s own state and answers, so no token-independent fact distinguishes forged custody from a genuine NFT; absent later non-delivery, a separate loss beyond the reported finding could not be established.
description: If factory registration is intended to attest prize authenticity rather than merely identify the selected contract, the protocol needs a vetted immutable prize-token policy.

COVERAGE | files: Raffle.sol—creation, sales, transfers, request/callback, settlement, both redemption branches, refunds, all releases, sink screening, and every prize/USDC call; RaffleFactory.sol—constructor assumptions, cloning, registry ordering, escrow, and parameter validation; IRaffle.sol—lifecycle, claim, deadline, and ABI promises; IRaffleFactory.sol—creation and registry ABI; RaffleConstants.sol—economic, timing, callback-gas, and batch bounds; DESIGN.md—money-map invariants and untrusted-boundary requirements.

COVERAGE | properties: USDC solvency and allocation conservation; worst-order last claimant; range coverage and refund batching; callback authentication and timeout recovery; reentrancy and batch poisoning; untrusted prize and recipient liveness; protocol-sink reachability; clone isolation; one-shot transitions; ingress/egress sibling saturation.

===== RAW SPECIALIST LENS 9 =====

[Model: gpt-daybreak-blue-latest]
`RaffleFactory.createRaffle`: the sponsor gives one named NFT to a new raffle and receives an active sale. `raffleCount` and all three registry records grow by one.

[Model: gpt-daybreak-blue-latest]
`Raffle.initialize`: no asset moves. The factory installs the sponsor, recipients, prize, reserve, identifier, and deadline, then places the raffle in `AwaitingPrize`.

[Model: gpt-daybreak-blue-latest]
`Raffle.onERC721Received`: the sponsor is meant to give the configured NFT to the raffle; the raffle records that the prize arrived and becomes `Active`.

[Model: gpt-daybreak-blue-latest]
`Raffle.buyEntries`: the buyer gives `entryCount` USDC; the recipient receives one ticket covering that many entries. `totalEntries`, `ticketCount`, and `unsettledPot` increase.

[Model: gpt-daybreak-blue-latest]
Ticket transfers give the complete bearer claim to the new owner. Entry coverage and all USDC totals remain unchanged.

[Model: gpt-daybreak-blue-latest]
`Raffle.requestDraw`: the requester gives native currency; the wrapper receives its exact fee and the requester receives any excess. Status, request time, and request identifier advance.

[Model: gpt-daybreak-blue-latest]
`Raffle.fulfillRandomWords`: no financial asset moves. The authenticated random word fixes `winningEntry`, `resolvedAt`, and either `NftWon` or `CashWon`.

[Model: gpt-daybreak-blue-latest]
`Raffle.enableRefunds`: no new asset enters. The entire `unsettledPot` becomes `remainingRefundLiability`, and the raffle becomes `Refunding`.

[Model: gpt-daybreak-blue-latest]
`Raffle._settleWinningTicket`: no asset moves. `unsettledPot` is divided into winner, sponsor, and treasury claims, and settlement becomes final.

[Model: gpt-daybreak-blue-latest]
`Raffle.redeemWinningTicket`: the current winner gives up and burns the winning ticket; they receive either the prize NFT or `winnerProceeds`.

[Model: gpt-daybreak-blue-latest]
`Raffle.refundTickets`: the owner gives up selected tickets and receives exactly one USDC per represented entry. `remainingRefundLiability` falls by the same amount.

[Model: gpt-daybreak-blue-latest]
`Raffle.releaseSponsorProceeds`: the sponsor recipient receives the complete `sponsorProceeds` claim, which is cleared atomically.

[Model: gpt-daybreak-blue-latest]
`Raffle.releaseProtocolFees`: the treasury receives the complete `protocolFees` claim, which is cleared atomically.

[Model: gpt-daybreak-blue-latest]
`Raffle.releaseSponsorPrize`: after a cash or refund outcome, the sponsor recipient receives the escrowed NFT and `prizeClaimed` becomes true.

[Model: gpt-daybreak-blue-latest]
`Raffle._transferQuote`: one already-recorded USDC claim leaves the raffle for its fixed or owner-derived recipient; the calling path clears the matching liability first.

[Why: RaffleFactory.sol:172]
Why can a prize contract’s own declaration establish that it will honor ownership and transfers? It cannot; this relies on a sponsor-selected contract reporting honestly.

[Why: RaffleFactory.sol:129]
Why does `ownerOf` independently prove escrow after the transfer? It does so only if the same untrusted contract truthfully reports the result of its own behavior.

[Why: Raffle.sol:422]
Why does equality with the configured prize address authenticate a deposit? The configured address is itself sponsor-selected and can invoke the receiver with forged transfer fields.

[Why: Raffle.sol:335]
Why may the prize contract certify that its own outgoing transfer succeeded? This is sound only when the prize implementation is trusted, contrary to the stated trust boundary.

[Why: Raffle.sol:376]
Why can sponsor proceeds leave before the winner receives the NFT? The lifecycle assumes an escrowed prize remains deliverable after settlement.

[Why: Raffle.sol:254]
Why is an in-flight request callback ignored? The request identifier is not yet persisted, so accepting a synchronous callback would resolve against incomplete request state.

[Why: Raffle.sol:314]
Why may settlement run before ticket ownership is checked during redemption? Any later ownership failure reverts the entire transaction, including settlement.

[Why: Raffle.sol:603]
Why is only the canonical factory’s raffle registry queried? The code assumes only same-factory clones are unsafe destinations, although foreign and future clones have the same inability to exercise received claims.

[Defeat: _validateCreateParams]
(1) A sponsor-controlled `Fake721` returns true for the ERC-721 interface and passes. (2) A pausable collection behaves normally during validation and is frozen after buyers pay. (3) a ticket contract from factory A passes factory B’s local `isRaffle` check.

[Defeat: createRaffle]
(1) Mallory cannot pull Alice’s approved NFT because the recorded previous owner is fixed to Mallory. (2) Reentry into the same factory through the prize transfer is stopped. (3) A fake prize can nevertheless call the receiver without transferring and return the expected owner, passing both post-transfer checks.

[Defeat: onERC721Received]
(1) An EOA cannot call successfully because it is not the configured token. (2) An unrelated NFT fails the token-address check. (3) The configured malicious token can supply the exact factory, sponsor, and token ID without performing any ownership change.

[Defeat: buyEntries]
(1) Buying zero entries fails. (2) A recipient that reenters during ticket receipt cannot enter another protected money path. (3) A recipient can transfer the freshly received ticket during its callback, but the complete claim follows the ticket and totals remain unchanged.

[Defeat: requestDraw]
(1) An underfunded request fails. (2) A front-runner paying the full fee only advances the raffle and bears the fee. (3) A requester reentering through the excess refund is stopped by the shared guard.

[Defeat: rawFulfillRandomWords]
(1) A direct EOA callback fails the inherited wrapper-only check. (2) The wrapper supplying request ID `999` instead of the stored ID is ignored. (3) A callback at the exact deadline is ignored and refunds are then available.

[Defeat: refundTickets]
(1) Alice submitting Bob’s ticket fails ownership verification. (2) Repeating ticket `1` in one batch makes the second lookup fail and rolls back the first burn. (3) A 101-ticket batch fails before any ticket is changed.

[Defeat: _settleWinningTicket]
(1) A range not containing `winningEntry` fails. (2) A second settlement fails. (3) A non-owner may settle the unique correct range, but receives no asset and cannot choose a different beneficiary.

[Defeat: redeemWinningTicket]
(1) A non-owner supplying the correct ticket reaches the ownership check, then all provisional settlement changes roll back. (2) An approved operator still cannot redeem unless it first lawfully becomes owner. (3) A malicious prize can perform no transfer and then report the expected winner, defeating the delivery check.

[Defeat: releaseSponsorProceeds]
(1) The sponsor pauses an initially valid prize before winner redemption. (2) The collection administrator makes transfers from the raffle selectively revert. (3) The collection is upgraded after escrow to disable transfers; in all three cases the 95% sponsor claim remains releasable first.

[Defeat: _isProtocolDestination]
(1) A current same-factory clone is rejected. (2) The implementation address is rejected. (3) A clone belonging to another factory, or an own-factory clone address before deployment, passes.

[LastOut: create-and-escrow]
With an honest NFT, any failed initialization, transfer, callback, or ownership verification rolls back the clone count and registry. With `Fake721`, creation completes while custody is short by one genuine prize.

[LastOut: timeout-refunds]
For tickets covering 40 and 60 entries, the liability begins at 100 USDC. Paying the 60-entry owner first leaves 40 USDC; the last owner receives all 40. Reversing the order gives the same result and leaves zero liability.

[LastOut: cash-result]
For 100 entries, the claims are 80 USDC to the winner, 15 to the sponsor, and 5 to the treasury. Paying sponsor and treasury first still leaves the last claimant’s full 80 USDC; every order ends at zero.

[LastOut: nft-result-honest-prize]
For 100 entries, sponsor and treasury may take 95 and 5 USDC before the winner acts. With an honest transferable prize, the last claimant still receives the NFT and the raffle finishes fully paid.

[LastOut: nft-result-frozen-prize]
For the same 100 entries, if the sponsor freezes the prize after settlement, sponsor and treasury can empty the 100 USDC first. The winner acting last receives nothing; the lifecycle is short by one NFT and has no refund branch.

[LastOut: nft-result-forged-prize]
If the prize contract forged escrow and later certifies a no-op delivery, the 100 USDC is fully paid out while the final ticket owner receives no usable NFT. The terminal obligation is short by one prize.

[LastOut: empty-raffle]
No USDC liability exists. Once refunds are enabled, the only remaining claimant is the sponsor recipient, who receives the NFT in full if the prize contract remains transferable.

[LastOut: native-fee-pass-through]
The wrapper receives the actual request fee and the requester receives all excess in the same transaction. No intended native-currency claimant remains afterward.

[LastOut: numeric-saturation]
At one entry, cash claims are exactly 800,000, 150,000, and 50,000 raw units; no rounding dust remains. At `uint128` maximum entries, the gross multiplication remains below `uint256`, `ticketCount` cannot exceed `totalEntries`, and the allocation sum remains exact.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: untrusted-prize-authentication | group_key: RaffleFactory | _validateCreateParams | untrusted-prize-authentication
root_cause: RaffleFactory.sol:172 accepts a caller-selected prize contract solely from its self-reported ERC-721 interface support and omits any trusted collection or code-identity check; the later callback and `ownerOf` checks therefore authenticate statements made by the same adversarial contract.
internal_pre: An attacker sponsors a raffle using a prize contract they control, victims purchase 100 entries, and the 100-entry reserve is met.
external_pre: None
path:
  1. Mallory deploys `Fake721`, which reports ERC-721 support, and creates a raffle for token ID 1 with a 100-entry reserve.
  2. When the factory requests escrow, `Fake721` performs no ownership transfer but calls `onERC721Received` with Mallory as the previous owner and the factory as operator; it reports the clone from `ownerOf`, so the raffle becomes `Active`.
  3. Alice buys all 100 entries for 100,000,000 raw USDC units.
  4. The authenticated draw resolves `NftWon`, and settlement allocates 95,000,000 units to Mallory’s recipient and 5,000,000 units to the treasury.
  5. During Alice’s redemption, `Fake721.transferFrom` performs no usable transfer and conditionally reports Alice from `ownerOf`; the raffle burns Alice’s ticket and records the prize as delivered.
  6. Mallory releases the 95,000,000-unit sponsor claim.
impact: Alice loses 100 USDC and receives no usable prize; Mallory walks away with 95 USDC, the treasury receives 5 USDC, and Alice is left holding the entire loss.
mitigation: Require `prizeToken` to belong to a trusted immutable collection registry or approved code identity before cloning; self-reported interface support, callbacks, and ownership cannot establish custody for an arbitrary contract.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-nft-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-nft-proceeds-release
root_cause: Raffle.sol:376 reads and releases an allocated `NftWon` sponsor balance without requiring `winnerRedeemed`; the sibling protocol-fee release has the same missing delivery-success gate, so all sale proceeds can leave before the untrusted prize transfer succeeds.
internal_pre: A genuinely escrowed prize supports a sponsor-controlled pause or transfer restriction; 100 entries are sold against a 100-entry reserve, the raffle resolves `NftWon`, and settlement occurs before redemption.
external_pre: None
path:
  1. Mallory escrows token ID 7 from a pausable ERC-721 collection they control and sets a 100-entry reserve.
  2. Alice buys all 100 entries for 100,000,000 raw USDC units and is therefore the eventual winning-ticket owner regardless of the selected entry.
  3. Mallory pauses prize transfers, after which the draw resolves `NftWon`.
  4. Settlement allocates 95,000,000 units to Mallory and 5,000,000 units to the treasury despite no successful prize delivery.
  5. Mallory calls `releaseSponsorProceeds` and receives 95,000,000 units; the protocol fee can also be released.
  6. Alice calls `redeemWinningTicket`, but the paused prize transfer reverts. `NftWon` has no transition to refunds, while the USDC has already left.
impact: Alice loses 100 USDC and cannot receive the prize; Mallory receives 95 USDC, the treasury can receive 5 USDC, and Alice is left holding the loss.
mitigation: In `NftWon`, require `winnerRedeemed` before either sponsor proceeds or protocol fees can be released, so failed prize delivery preserves the complete sale pot.

LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: incomplete-protocol-destination-detection | group_key: Raffle | _isProtocolDestination | incomplete-protocol-destination-detection
smell: Raffle.sol:603 and RaffleFactory.sol:159 only recognize raffles registered by the current factory, so a clone from another factory can be accepted as a prize or recipient; a code-less future clone address also passes until deployment.
unverified: No non-consensual path with a third-party victim was established because the current asset owner, buyer, or sponsor must select the foreign or counterfactual address, and eventual prize release can return a nested claim.
description: A raffle ticket can move between clones and remain temporarily or permanently unusable by the receiving clone, contradicting the stated cross-clone isolation property.

COVERAGE | Raffle.sol | Covered initialization, all sale/draw/refund/settlement/redemption/release paths, ticket ownership and approvals, receiver and VRF callbacks, native refunds, reentrancy, protocol-sink checks, every tracked-total write, and inherited public entry points.
COVERAGE | RaffleFactory.sol | Covered constructor trust assumptions, clone initialization, registry ordering, caller-bound NFT pulls, malicious prize callbacks, post-transfer verification, recipient checks, and counterfactual/foreign-clone cases.
COVERAGE | IRaffle.sol | Checked every state-changing and view declaration, event/error semantics, bearer-owner authorization, permissionless operations, and documented lifecycle against implementation behavior.
COVERAGE | IRaffleFactory.sol | Checked creation authorization, immutable getters, registry mappings, and interface/implementation consistency.
COVERAGE | RaffleConstants.sol | Checked entry units, percentage sums, rounding, batch bound, sale and draw deadlines, callback limit, and maximum-value arithmetic.
COVERAGE | DESIGN.md | Checked custody, payout, timeout, atomicity, independent-claim, trust-boundary, and no-cross-clone requirements against source behavior.
PROPERTY COVERAGE | Solvency and Last User Out pass for canonical USDC in refund and cash branches; caller and target authorization pass except for prize-contract self-authentication; callback authentication and CEI/reentrancy pass; prize custody/delivery and pre-delivery proceeds release fail as reported.
SATURATION SWEEP | Mined every `supportsInterface`, prize transfer, `ownerOf`, receiver callback, `prizeClaimed`, `winnerRedeemed`, proceeds-release, `isRaffle`, and protocol-destination sibling site; tested zero, one, and maximum entries plus every exact deadline boundary.

===== RAW SPECIALIST LENS 10 =====

[Model: gpt-daybreak-blue-latest] `createRaffle`: the sponsor gives one NFT and receives a contingent sponsor claim; the factory increments its raffle count, binds the new clone in all three registry views, and activates the raffle after reported custody.

[Model: gpt-daybreak-blue-latest] `initialize`: no asset moves; the clone records the sponsor, beneficiaries, prize, reserve, and deadline, then becomes ready to receive the prize.

[Model: gpt-daybreak-blue-latest] `onERC721Received`: the sponsor gives the configured NFT, the raffle is meant to gain custody, and its state changes from waiting for the prize to selling entries.

[Model: gpt-daybreak-blue-latest] `buyEntries`: the buyer gives exactly one USDC per entry, the recipient gets a transferable ticket covering those entries, and sold entries, ticket count, and the unallocated pot increase by matching amounts.

[Model: gpt-daybreak-blue-latest] `_update`: the current owner gives a ticket claim to a recipient; ownership changes but sold entries and all USDC liabilities remain unchanged.

[Model: gpt-daybreak-blue-latest] `requestDraw`: the caller gives the Chainlink native fee, receives any excess back, and the raffle records that a draw is pending together with its request identifier and time.

[Model: gpt-daybreak-blue-latest] `fulfillRandomWords`: nobody gives or receives an asset; one sold entry becomes the winner and the raffle records either the NFT or cash result.

[Model: gpt-daybreak-blue-latest] `enableRefunds`: no new asset moves; the entire unallocated USDC pot becomes an equal aggregate refund obligation.

[Model: gpt-daybreak-blue-latest] `_settleWinningTicket`: no asset moves; the unallocated pot becomes winner, sponsor, and treasury claims whose sum equals the prior pot.

[Model: gpt-daybreak-blue-latest] `redeemWinningTicket`: the current winner gives up and burns the winning ticket, receiving either the configured NFT or the entire recorded cash-winner claim.

[Model: gpt-daybreak-blue-latest] `refundTickets`: the caller burns owned tickets, receives one USDC per represented entry, and the aggregate refund obligation decreases by exactly that payment.

[Model: gpt-daybreak-blue-latest] `releaseSponsorProceeds`: the sponsor beneficiary receives its entire recorded USDC claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest] `releaseProtocolFees`: the treasury receives its entire recorded fee claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest] `releaseSponsorPrize`: after a cash or refund result, the sponsor beneficiary receives the escrowed NFT and the prize is marked released.

[Why: RaffleFactory.sol:172] Why does the collection’s own claim that it implements ERC-721 establish safe ownership semantics? It does not; the check assumes an expressly untrusted collection reports its capabilities honestly and has no privileged seizure path.

[Why: RaffleFactory.sol:129] Why is `ownerOf` an independent escrow proof? It is not: the same prize contract controls the transfer behavior, receiver call, and ownership answer.

[Why: Raffle.sol:254] Why ignore a callback during the request call? The code assumes the official Chainlink wrapper is asynchronous; a synchronous wrapper would spend the fee but have its only callback discarded.

[Why: Raffle.sol:258] Why compare the actual fee only after requesting? The inherited call recomputes and sends the fee first; safety rests on reverting the entire wrapper interaction if it exceeded this caller’s payment.

[Why: Raffle.sol:334] Why deliver the prize without recipient acceptance? The code assumes a contract that can own and redeem the ticket can also control any arbitrary prize deposited into it.

[Why: Raffle.sol:566] Why does a correctly debited claim imply it remains payable? It assumes canonical USDC will not freeze the immutable clone or payout address.

[Why: Raffle.sol:602] Why skip the registry query for an address without code? It assumes every unsafe raffle destination already has code; this excludes current same-factory clones but not future or foreign-factory clone addresses.

[Defeat: createRaffle] 1) Mallory’s `AdminSeizablePrize721` genuinely transfers token 7 and passes both checks, then Mallory seizes it after buyers pay. 2) `SpoofPrize721` calls the receiver with Mallory, factory, and token 7 without transferring and reports the clone from `ownerOf`. 3) A malicious prize reenters during escrow and buys ten entries; it must pay ten USDC, so accounting remains exact. Moves 1 and 2 defeat durable-custody verification.

[Defeat: buyEntries] 1) Alice submits zero entries and is rejected. 2) At `totalEntries = 2^128-1`, Alice submits one more and is rejected before payment. 3) A ticket receiver transfers the freshly minted ten-entry ticket during its callback; only claim ownership changes and the ten-USDC pot remains exact.

[Defeat: _update] 1) Sending ticket 1 to the current factory is rejected. 2) Sending it to a registered same-factory clone is rejected. 3) Sending it to a foreign-factory clone or a code-less future clone address is accepted, but every demonstrated loss requires the ticket owner to choose that sink.

[Defeat: requestDraw] 1) A caller supplies one wei less than the quote and is rejected. 2) A contract overpays by one wei and rejects its refund; the entire request reverts. 3) Forced ETH in the clone cannot subsidize a caller whose payment is below the actual fee because the post-request comparison reverts the whole transaction.

[Defeat: fulfillRandomWords] 1) The wrapper supplies request ID 8 when 7 is recorded. 2) It supplies two words instead of one. 3) It supplies the correct word exactly at the callback deadline. All three callbacks are ignored and refunds become available without corrupting the pot.

[Defeat: enableRefunds] 1) Mallory calls one second before the sold-raffle request deadline and is rejected. 2) Alice calls exactly at that deadline and migrates the full pot. 3) Bob calls exactly at a pending draw’s callback deadline and migrates the same full pot; no callback/refund overlap exists.

[Defeat: _settleWinningTicket] 1) Mallory supplies nonexistent ticket 0 and its zero range fails. 2) Mallory supplies the adjacent losing range and fails. 3) Mallory supplies the correct 100-entry range without owning it; settlement succeeds as intended but leaves redemption to the current owner.

[Defeat: redeemWinningTicket] 1) Alice sells the settled winning ticket to Bob, and only Bob can redeem. 2) An honest prize transfer reverts, rolling back the burn and all redemption flags. 3) An admin-seizable or lying prize makes delivery permanently unavailable even though sponsor proceeds can already leave; this defeats the external-asset guarantee.

[Defeat: refundTickets] 1) Alice supplies ticket 1 twice and the second ownership lookup reverts the whole batch. 2) Alice mixes Bob’s ticket into her batch and the entire batch reverts. 3) Alice submits the final one-entry ticket after every other refund; the remaining 1,000,000-unit liability pays in full.

[Defeat: _transferQuote] 1) Circle blacklists only a winning owner, who can transfer the still-live ticket to an unblocked address. 2) Circle blacklists the immutable sponsor beneficiary, permanently blocking that fixed claim absent unblacklisting. 3) Circle blacklists the raffle clone itself, blocking every winner, refund, sponsor, and treasury transfer. Moves 2 and 3 defeat payout liveness.

[Defeat: releaseSponsorPrize] 1) A caller tries during `NftWon` and is rejected. 2) A second release after successful delivery is rejected. 3) The prize administrator seizes or freezes the token after escrow; release reverts atomically, but no recovery branch restores durable custody.

[LastOut: Create / escrow] With an immutable honest ERC-721, the clone holds exactly one prize for one terminal recipient. With `AdminSeizablePrize721`, the last rightful claimant is short one NFT because the collection administrator can remove it after the point-in-time factory check.

[LastOut: Buy / transfer] After tickets of 40, 30, and 30 entries are sold, the raffle holds 100,000,000 raw USDC against exactly 100 entries. Transfers only move bearer ownership; there is no shortfall before the terminal branch.

[LastOut: Successful draw] Selecting one entry moves no USDC and creates no additional claim. The 100,000,000-unit pot remains intact for settlement, so last-out payment is deferred without drift.

[LastOut: Settle / redeem NFT] From 100,000,000 units, the sponsor can take 95,000,000 and the treasury 5,000,000 in either order; the last USDC claimant is paid in full. The NFT winner is nevertheless short one prize if the untrusted collection seized or disabled it.

[LastOut: Settle / redeem cash] From 100,000,000 units, the winner receives 80,000,000, the sponsor 15,000,000, and the treasury 5,000,000. In every withdrawal order, the last claimant receives its full amount and the balance reaches zero.

[LastOut: Timeout / refund] Refund 40-entry and 30-entry tickets first, leaving 30,000,000 units; the final 30-entry owner receives all 30,000,000. If Circle blacklists the clone, every attempted refund instead reverts and all 100,000,000 units remain unavailable despite remaining on balance.

[LastOut: Empty raffle] No USDC claim exists. With an honest collection the sponsor beneficiary receives the sole prize in full; with a collection-controlled seizure, it may already be absent.

[LastOut: Independent releases] Winner, sponsor, and treasury claims clear independently and sum exactly to the pot. Under transferable, fee-free USDC the last claim is fully paid; a sender blacklist turns this from a solvency invariant into an unreachable balance.

[LastOut: Native fee pass-through] If the wrapper price is 0.015 ETH and the requester supplies 0.020 ETH, 0.015 ETH reaches the wrapper and 0.005 ETH returns atomically. A failed refund reverts the request, leaving no retained requester liability.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: untrusted-prize-seizure | group_key: RaffleFactory | _validateCreateParams | untrusted-prize-seizure
root_cause: RaffleFactory.sol:172 substitutes a prize contract’s self-reported ERC-721 support for the missing restriction to collections with trusted, durable custody semantics; the point-in-time `ownerOf` check at line 129 cannot prevent a collection administrator from later seizing or disabling the escrowed prize.
internal_pre: None
external_pre: Third parties buy 100 entries in the attacker’s raffle and the normal VRF callback resolves before its deadline.
path:
  1. Mallory deploys `AdminSeizablePrize721`, mints token 7, and creates a raffle with reserve 100 and Mallory as sponsor beneficiary; the token genuinely transfers token 7 to the clone and reports the clone as owner.
  2. Alice and 99 other entrants each buy one entry, transferring 100,000,000 raw USDC into the raffle while token 7 is visibly escrowed.
  3. After sales close, Mallory invokes the token’s privileged seizure operation and moves token 7 out of the raffle.
  4. Chainlink resolves `NftWon`; Mallory supplies the correct ticket to settlement, allocating 95,000,000 units to Mallory and 5,000,000 units to the treasury without checking or delivering the prize.
  5. Mallory releases the 95,000,000-unit sponsor claim. When winning-ticket owner Alice calls `redeemWinningTicket`, the prize transfer reverts because the raffle no longer owns token 7.
impact: Mallory retains the purported prize and receives 95 USDC. Alice is left holding a winning ticket that cannot deliver its NFT, while the entrants collectively funded Mallory’s 95-USDC proceeds and the treasury’s 5-USDC fee.
mitigation: Restrict `prizeToken` to an immutable, vetted collection allowlist whose transfer, upgrade, pause, burn, and seizure controls satisfy the protocol’s custody requirements.

FINDING | contract: Raffle | function: _transferQuote | bug_class: freezable-usdc-payout-lock | group_key: Raffle | _transferQuote | freezable-usdc-payout-lock
root_cause: Raffle.sol:566 makes every quote claim collectible only through an outgoing transfer from the immutable raffle address and is missing any supported recovery mechanism for canonical USDC’s sender-blacklist behavior.
internal_pre: The raffle holds 100,000,000 raw USDC and has two live 50-entry refund tickets.
external_pre: Circle’s blacklister blacklists the raffle clone in Ethereum mainnet USDC at `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`.
path:
  1. Alice and Bob each buy 50 entries, putting 100 USDC into the clone.
  2. No draw is requested before the deadline, so Alice enables refunds and the 100-USDC pot becomes the refund liability.
  3. Circle blacklists the clone address, causing every USDC transfer whose sender is the clone to revert.
  4. Alice submits her 50-entry ticket for a 50-USDC refund; the final transfer reverts, rolling back the burn and liability debit.
  5. Bob’s refund and every cash-winner, sponsor, or treasury release fail identically until Circle removes the blacklist.
impact: Alice and Bob lose access to 50 USDC each, and the corresponding claimant cohort is left holding the liquidity loss while the entire backed balance remains frozen in the raffle.
mitigation: If unconditional onchain collectability is required, use a non-freezable quote asset; no raffle-side fallback can move USDC after Circle has blacklisted the sender.

COVERAGE | Raffle.sol: Checked every USDC, NFT, native-token, and ticket movement; every tracked-total write; all status transitions; callback authentication and deadlines; destination screening; settlement, redemption, refund, and release ordering.

COVERAGE | RaffleFactory.sol: Checked dependency construction, clone initialization, registry ordering, prize receiver authentication, ERC-165 validation, point-in-time custody verification, and external-call reentrancy.

COVERAGE | IRaffle.sol: Matched lifecycle, claim, event, error, getter, deadline, and bearer-ticket semantics against implementation behavior.

COVERAGE | IRaffleFactory.sol: Matched creation parameters, registry getters, immutable configuration, errors, and event promises against the factory.

COVERAGE | RaffleConstants.sol: Checked six-decimal units, entry price, 5%/80% splits, refund batch bound, sale and callback windows, gas limit, and confirmation count.

COVERAGE | DESIGN.md: Tested quote solvency, exact terminal allocation, durable prize custody, one-shot transitions, no cross-clone movement, permissionless progress, and last-user collectability.

COVERAGE | properties: Quote accounting remains exact under fee-free transferable USDC; ticket ranges are contiguous and exhaustive; deadline boundaries do not overlap; winner ownership follows the ticket; the two surviving failures are external-asset custody and freeze-dependent payout reachability.

COVERAGE | saturation: Mined the prize defect across interface admission, receiver activation, factory ownership verification, both NFT exits, and sponsor-release ordering; mined USDC freezing across purchases, refunds, cash redemption, sponsor proceeds, and protocol fees. Reachable Chainlink and OpenZeppelin inheritance semantics were confirmed; no tests, history, reports, scanner output, or peer conclusions were read.

===== RAW SPECIALIST LENS 11 =====

[Model: factory construction] The deployer supplies the shared payment token, randomness service, and treasury. The factory creates one locked raffle template; no participant funds move, and all configuration remains fixed.

[Defeat: constructor] 1) A payment-token address with no code is rejected. 2) A token reporting five rather than six decimals is rejected. 3) A treasury equal to the factory, payment token, randomness service, or raffle template is rejected.

[Model: createRaffle] A sponsor gives one advertised prize and receives an active raffle plus the future sponsor proceeds or returned prize. The factory count rises by one, all three registry records are created, and the raffle moves from waiting-for-prize to active.

[Why: RaffleFactory.sol:172] Why can the prize contract’s own “yes, I am an ERC-721” answer establish that it is trustworthy collateral? It cannot; the check assumes the expressly untrusted prize contract truthfully implements stable, enforceable ownership.

[Why: RaffleFactory.sol:129] Why is `ownerOf` an independent custody proof when the prize contract being verified supplies the answer? It is not independent; the same adversarial contract controls the transfer, callback, and reported owner.

[Why: Raffle.sol:428] Why does a receiver callback prove a prize moved? That belief holds for an honest token, but an adversarial configured token can call the receiver directly with fabricated transfer fields.

[Defeat: createRaffle] 1) `FakePrize` reports ERC-721 support, fabricates the expected receiver callback, and reports the clone as owner without creating an enforceable transfer; all existing guards pass. 2) A token can genuinely escrow token 7 and later use an administrator seizure function to remove it; no continuous-custody check exists. 3) A prize callback that recursively calls `createRaffle` is stopped by the factory’s reentrancy guard, but that guard does not address either custody attack.

[Model: initialize] No value moves. A fresh clone records its sponsor, beneficiaries, prize, threshold, identifier, and end time, then waits for the prize. Initialization and lifecycle state change once.

[Defeat: initialize] 1) Alice directly initializing a fresh canonical clone is rejected because only the factory is accepted. 2) The factory attempting a second initialization is rejected. 3) Supplying the factory, payment token, randomness service, prize token, template, or an existing same-factory raffle as a beneficiary is rejected.

[Model: onERC721Received] The sponsor is intended to give the configured prize and receive an activated sale. Only lifecycle state changes; no payment-token total changes.

[Model: buyEntries] A buyer paying 3,000,000 USDC gives the recipient one ticket covering three contiguous entries. Lifetime entries rise by three, lifetime tickets rise by one, and the unallocated pot rises by 3,000,000.

[Defeat: buyEntries] 1) Buying zero entries is rejected. 2) From five below the largest entry count, buying exactly five succeeds and a further one-entry purchase reverts without wrapping. 3) A ticket recipient attempting a nested purchase during receipt is stopped, and the original payment and accounting revert together if receipt fails.

[Model: ticket transfer] The old owner gives the complete bearer claim to the new owner; entry coverage and aggregate liabilities do not change.

[Defeat: _update] 1) Sending a ticket to its own raffle is rejected. 2) Sending it to the factory or an already registered same-factory raffle is rejected. 3) A code-less future clone address can pass, but only the ticket owner can make that self-harming transfer; no path lets an attacker redirect another owner’s claim.

[LastOut: buy/transfer] Transfers neither create nor extinguish value. The final owner retains exactly the same entry count and downstream refund or winning claim, so the transfer lifecycle introduces a zero-USDC shortfall.

[Model: requestDraw] A caller gives native currency; the randomness service receives its exact price and the caller receives every excess unit. The raffle changes from active to drawing and records the request and time.

[Why: Raffle.sol:254] Why are synchronous callbacks ignored? The request identifier has not yet been recorded, so correctness relies on the trusted randomness service delivering asynchronously after the request returns.

[Defeat: requestDraw] 1) A request one second before sale end is rejected, while one exactly at sale end is accepted. 2) A request one second before the two-day deadline is accepted, while one exactly at the deadline is rejected. 3) A requester that rejects an excess refund reverts its own request atomically and cannot strand native currency from other users.

[Model: fulfillRandomWords] Nobody gives value. One authenticated random result fixes a single entry and changes the raffle to the NFT or cash outcome; the winning entry and resolution time are written once.

[Defeat: fulfillRandomWords] 1) The correct service supplying the wrong request identifier is ignored. 2) Zero or two random words are ignored. 3) A callback one second before its deadline resolves, while one exactly at the deadline is ignored and refunds become available.

[Model: enableRefunds] Nobody receives funds immediately. The complete unallocated pot is reclassified as ticket-refund liability, the old pot becomes zero, and the raffle enters refunding.

[Defeat: enableRefunds] 1) Before sale end, a non-sponsor cannot close an empty raffle. 2) With one sold entry, refunds cannot open until the draw-request deadline, including for the sponsor. 3) While drawing, a caller one second before the callback deadline is rejected, while a caller exactly at the deadline succeeds.

[Model: refundTickets] An owner gives up each selected ticket and receives exactly 1,000,000 USDC per represented entry. The aggregate refund liability falls by the paid amount.

[Defeat: refundTickets] 1) Empty and 101-ticket batches revert without burning anything; exactly 100 are accepted. 2) Supplying the same ticket twice reverts the entire batch after the second ownership check, restoring the first burn. 3) A ticket representing the largest remaining entry range multiplies safely, and its payment cannot exceed the liability established from the same ranges.

[LastOut: timeout/refund] With tickets worth 5,000,000, 3,000,000, and 2,000,000 USDC, refunding them in that worst order changes liability from 10,000,000 to 5,000,000 to 2,000,000 to zero. The last owner receives the full 2,000,000; shortfall is zero.

[Model: settleWinningTicket] Nobody gives or receives an asset. The unallocated pot becomes winner, sponsor, and treasury claims: 80/15/5 for cash or 95/5 for an NFT, with the sponsor receiving any remainder.

[Why: Raffle.sol:538] Why can a non-owner settle a ticket? Settlement transfers nothing, only the unique range containing the selected entry passes, and the current owner is checked when value is delivered.

[Defeat: _settleWinningTicket] 1) Ticket zero has range `[0,0]` and cannot contain a positive winning entry. 2) Either adjacent losing ticket is rejected at the inclusive range boundary. 3) At reserve minus one the result is cash; exactly at reserve and one above it the result is NFT, matching the specification.

[Model: redeemWinningTicket] The current winning-ticket owner gives up and burns that ticket, receiving either the advertised prize or the complete 80% cash claim. The winner record is set, and either the prize-delivered flag or cash liability is cleared atomically.

[Why: Raffle.sol:335] Why does the prize’s post-transfer owner report prove the winner received an enforceable asset? It assumes the same untrusted token both tells the truth and cannot later revoke ownership.

[Defeat: redeemWinningTicket] 1) A non-owner presenting the correct ticket is rejected. 2) After settlement, the owner presenting another ticket is rejected. 3) An adversarial prize can make creation’s custody checks pass and later reject delivery; sponsor and treasury claims remain independently releasable, leaving the winner with no refund branch.

[Model: releaseSponsorProceeds] A permissionless caller gives nothing; the immutable sponsor recipient receives the complete sponsor claim, and that claim becomes zero.

[Model: releaseProtocolFees] A permissionless caller gives nothing; the immutable treasury receives the complete fee claim, and that claim becomes zero.

[Model: releaseSponsorPrize] In a cash or refund outcome, the sponsor recipient receives the advertised prize and the prize-delivered flag becomes final.

[Defeat: terminal releases] 1) Repeating a successful quote release is rejected because its claim is zero. 2) Releasing sponsor, treasury, and cash-winner claims in any order preserves the same total. 3) The prize’s own fabricated transfer and ownership reports defeat both winner and sponsor delivery verification for the same reason they defeat creation.

[LastOut: NFT settlement] For 10,000,000 USDC of sales backed by an honest prize, sponsor and treasury claims are 9,500,000 and 500,000. Either release order leaves the last claimant fully paid and quote-token shortfall zero; the untrusted-prize case instead has a full prize shortfall.

[LastOut: cash settlement] For 10,000,000 USDC of sales, winner, sponsor, and treasury claims are 8,000,000, 1,500,000, and 500,000. Paying sponsor and treasury first leaves exactly 8,000,000 for the winner; shortfall is zero.

[LastOut: empty raffle] No quote-token liability exists. After sponsor cancellation or sale expiry, the sponsor recipient receives the one honest prize; payment-token shortfall is zero.

[LastOut: independent releases] Across both terminal outcomes, every quote claim clears before its transfer and a failed transfer restores it. The last quote claimant receives the full recorded balance; shortfall is zero.

[LastOut: native-fee pass-through] The randomness service receives the recomputed request price and the requester receives `msg.value - price` in the same transaction. The intended retained native balance and last-caller shortfall are both zero.

[Defeat: saturation boundaries] 1) Lifetime entries can reach exactly the largest supported count without wrapping, and the next positive purchase reverts. 2) Lifetime ticket count cannot overflow first because every ticket adds at least one entry. 3) Maximum entry value times 1,000,000, all percentage products, and a 100-ticket refund sum remain below the payment arithmetic limit.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: untrusted-prize-attestation | group_key: RaffleFactory | _validateCreateParams | untrusted-prize-attestation
root_cause: RaffleFactory.sol:172 accepts an attacker-controlled prize solely from its self-reported ERC-721 interface support; `_validateCreateParams` omits a trusted-address or code-identity check, so the later callback and `ownerOf` checks are attestations from the same untrusted contract rather than proof of enforceable custody
internal_pre: None; the attacker creates a fresh raffle and the path itself reaches the reserve
external_pre: None; ordinary draw fulfillment is sufficient
path:
  1. Mallory deploys `FakePrize` for token 7; it reports ERC-721 support, makes `safeTransferFrom` call the clone with `operator = factory`, `from = Mallory`, and `tokenId = 7`, and reports the clone from `ownerOf(7)` without granting the clone an enforceable token
  2. Mallory creates a raffle with `reserveEntries = 10`, token 7 as the prize, and Mallory as sponsor recipient
  3. The receiver callback changes the clone to `Active`, and the factory's attacker-controlled `ownerOf` check accepts the phantom escrow
  4. Alice buys the only ticket with 10 entries for 10,000,000 USDC, making her the guaranteed eventual winner and meeting the reserve
  5. After sale end, an ordinary request and callback select one of Alice's entries and set `NftWon`
  6. Mallory settles ticket 1, changing the pot into 9,500,000 USDC of sponsor proceeds and 500,000 USDC of protocol fees
  7. Mallory releases the 9,500,000 sponsor claim, and the treasury claim can also be released
  8. Alice calls `redeemWinningTicket(1)`; `FakePrize.transferFrom` reverts because no enforceable prize was escrowed, while the terminal `NftWon` state provides no refund path
impact: Alice, the guaranteed winning-ticket owner, loses 10,000,000 USDC and receives neither the advertised prize nor a refund; Mallory receives 9,500,000 USDC and Alice is left holding the entire prize-collateral loss
mitigation: In `_validateCreateParams`, require `params.prizeToken` to belong to an immutable, pre-vetted prize-token allowlist or match an approved code identity; do not treat `supportsInterface`, receiver callbacks, or `ownerOf` reports from an arbitrary prize contract as custody proof

COVERAGE | file: Raffle.sol | Covered initialization, purchase and ticket movement, draw request/callback, all exact deadlines, settlement, both redemption branches, refunds, all releases, callback reentrancy, sink screening, zero/one/last/maximum states, and quote/prize atomicity.
COVERAGE | file: RaffleFactory.sol | Covered constructor boundaries, first and maximum creation counters, atomic registry rollback, prize validation/escrow, malicious callbacks, and all configured-address combinations.
COVERAGE | file: IRaffle.sol | Matched every scoped state getter, lifecycle promise, event, error, deadline, ownership rule, and payout description against implementation behavior.
COVERAGE | file: IRaffleFactory.sol | Matched creation parameters, registry guarantees, errors, getters, and advertised atomic escrow semantics.
COVERAGE | file: RaffleConstants.sol | Checked zero, exact, one-below, one-above, 100/101 batch, 30-day sale, both two-day windows, fee percentages, entry price, and saturation arithmetic.
COVERAGE | file: DESIGN.md | Checked custody isolation, 100% refunding, 80/15/5 and 95/5 allocation, rounding, terminal independence, callback timing, immutability, and the explicit untrusted-prize boundary.

===== RAW SPECIALIST LENS 12 =====

[Model: gpt-daybreak-blue-latest] `RaffleFactory.constructor` / `Raffle.constructor` — The deployer supplies the payment-token, randomness-service, and treasury addresses and receives an ownerless factory plus a locked raffle template. No participant value enters; configuration becomes fixed and the template is unusable as a live raffle.

[Defeat: RaffleFactory.constructor] (1) A payment-token or wrapper address with no code is rejected. (2) A token reporting 18 decimals is rejected. (3) A treasury equal to the factory, payment token, wrapper, or deployed template is rejected.

[Model: gpt-daybreak-blue-latest] `Raffle.initialize` — The canonical factory supplies the sponsor, recipients, prize identity, reserve, identifier, and deadline. No asset moves; the new raffle becomes configured and waits for its prize.

[Defeat: initialize] (1) Alice calling directly is rejected because she is not the factory. (2) The factory calling a second time is rejected because initialization is one-shot. (3) Supplying the payment token, prize contract, or a registered raffle as a recipient is rejected.

[Model: gpt-daybreak-blue-latest] `RaffleFactory.createRaffle` — The sponsor gives one purported NFT and receives a registered, active raffle plus the future sponsor claim. The raffle count and all three registry directions advance once.

[Why: RaffleFactory.sol:123] Why is the raffle registered before its prize transfer finishes? Registration makes the new clone recognizable as a forbidden protocol destination during the untrusted prize call; a later failure rolls every registry write back atomically.

[Why: RaffleFactory.sol:129] Why does the sponsor-selected prize contract’s own ownership report prove escrow? It only does if that contract honestly implements ERC-721; the implicit belief conflicts with the stated boundary that prize contracts are untrusted.

[Defeat: createRaffle] (1) Prize address `0x1234` with no code is rejected. (2) A contract returning `false` for ERC-721 support is rejected. (3) A sponsor-controlled contract returning `true`, fabricating the receiver call, and reporting the clone as owner passes every check despite creating no enforceable NFT claim.

[Model: gpt-daybreak-blue-latest] `Raffle.onERC721Received` — The sponsor is meant to give the configured NFT through the factory; the raffle records that the prize arrived and opens ticket sales. Quote-token totals remain unchanged.

[Defeat: onERC721Received] (1) A call from a different token is rejected. (2) The configured token supplying token ID `8` instead of `7`, or the wrong sponsor, is rejected. (3) The configured malicious token can directly supply all expected fields without actually transferring an enforceable NFT, so the guard is defeated.

[LastOut: create / escrow] No quote claimant exists yet. With an honest ERC-721, the sole prize remains available for its eventual recipient; with the counterfeit contract above, the last prize claimant has no backed asset.

[Model: gpt-daybreak-blue-latest] `Raffle.buyEntries` — A buyer gives `entryCount × 1 USDC`; the chosen recipient gets one ticket covering that many entries. Sold entries, ticket count, the ticket’s range, and the unallocated pot increase together.

[Why: Raffle.sol:224] Why is payment collected before entry totals advance? The design relies on canonical fee-free USDC and transaction rollback, so a failed payment or failed ticket receipt restores both asset and accounting state.

[Model: gpt-daybreak-blue-latest] `Raffle._update` — A ticket owner gives the bearer claim to another address, or the raffle destroys it during payout. Lifetime entry and ticket totals intentionally do not decrease.

[Defeat: buyEntries] (1) Buying zero entries is rejected. (2) Buying past the largest representable cumulative entry is rejected. (3) A recipient reverting during ticket acceptance reverts the payment and every total update.

[Defeat: _update] (1) Sending a ticket to its own raffle is rejected. (2) Sending it to the payment token, prize contract, wrapper, factory, or template is rejected. (3) Sending it to any already-registered sibling raffle is rejected.

[LastOut: buy / transfer] This is not terminal: no ticket holder can withdraw while sales remain active. Every live ticket remains backed by exactly its range length multiplied by 1 USDC, and transfers neither create nor destroy backing.

[Model: gpt-daybreak-blue-latest] `Raffle.requestDraw` — A permissionless caller gives the randomness-service fee, receives any excess native currency back, and advances the raffle from sales to drawing. The request time and identifier are recorded; USDC claims do not change.

[Why: Raffle.sol:254] Why ignore a response while the request call is still executing? The request identifier cannot be recorded until that call returns, so the code assumes the trusted service fulfills asynchronously and prevents an early response from resolving against identifier zero.

[Why: Raffle.sol:267] Why return excess with an unrestricted native-currency call? The caller funded that exact excess; the raffle’s entry lock prevents nested economic actions, and a failed return reverts the request and wrapper payment atomically.

[Defeat: requestDraw] (1) A request one second before sale end is rejected. (2) A request exactly at `endTime + 2 days` is rejected while refunds become available. (3) A synchronous service response is ignored while the request is in flight; under the trusted service’s asynchronous semantics, the later authenticated response remains available.

[Model: gpt-daybreak-blue-latest] `Raffle.fulfillRandomWords` — The trusted randomness service supplies one word. No asset moves; one entry is selected and the final NFT-or-cash outcome is fixed.

[Defeat: fulfillRandomWords] (1) Request ID `12` when `13` is recorded is ignored. (2) Two random words instead of one are ignored. (3) A response exactly at the callback deadline is ignored, after which full refunds are available.

[LastOut: successful draw] No claimant exits during resolution. For a 100 USDC pot, all 100 USDC remains recorded as unallocated until settlement; the selected entry is covered by exactly one existing ticket range.

[Model: gpt-daybreak-blue-latest] `settleWinningTicket` / `_settleWinningTicket` — A caller gives no asset and receives no protocol value. The 100 USDC example moves from one unallocated pot into either `95 sponsor + 5 treasury`, or `80 winner + 15 sponsor + 5 treasury`.

[Why: Raffle.sol:538] Why prove only the winning range and not ownership during settlement? Settlement allocates fixed liabilities without consuming the bearer claim; the current owner is checked later when that ticket is destroyed for payout.

[Why: Raffle.sol:539] Why allocate from the recorded pot instead of the live token balance? This excludes donations and preserves exact correspondence between sold entries and participant liabilities.

[Defeat: settleWinningTicket] (1) Unminted ticket `0` has range `[0,0]` and cannot contain a positive winning entry. (2) A real losing ticket is rejected. (3) Mallory may settle Alice’s correct winning ticket, but receives nothing and cannot redeem it.

[Model: gpt-daybreak-blue-latest] `Raffle.redeemWinningTicket` — The current winner gives up and destroys the winning ticket. They receive either the prize NFT or the entire recorded 80% cash claim; the winner and prize completion flags advance once.

[Why: Raffle.sol:315] Why may settlement occur before checking the caller owns the ticket? This permits settlement and redemption in one action; if ownership later fails, the entire action, including settlement, is rolled back.

[Why: Raffle.sol:334] Why is receiver acknowledgement omitted for an NFT sent to a contract winner? The code equates a reported ownership change with usable delivery, implicitly assuming every contract ticket owner can manage an NFT received without its receiver hook.

[Why: Raffle.sol:335] Why does the same untrusted prize contract’s post-transfer ownership report verify delivery? It is sound only for an honest ERC-721 and is defeated by the same self-attesting contract accepted during creation.

[Defeat: redeemWinningTicket] (1) Bob calling with Alice’s winning ticket is rejected. (2) Alice supplying a different ticket after settlement is rejected. (3) A malicious prize contract can make `transferFrom` a no-op, report Alice as owner, and cause the ticket to burn and all completion flags to finalize without a usable prize.

[LastOut: NFT settlement / redemption] With 100 USDC and an honest prize, sponsor-first then treasury-last pays exactly 95 and 5 USDC, leaving zero quote liability, while the winner receives the escrowed NFT. Against the accepted counterfeit prize, the quote claimants are paid but the final winner receives no enforceable NFT.

[LastOut: cash settlement / redemption] For 100 entries, pay sponsor 15 USDC and treasury 5 USDC first; the last winner still receives the full 80 USDC and the balance reaches zero. Reversing the order produces the same result.

[Model: gpt-daybreak-blue-latest] `Raffle.enableRefunds` — No caller contributes value. The complete unallocated pot becomes the refund balance owed to all still-live tickets, and the raffle enters its refund outcome.

[Defeat: enableRefunds] (1) A sold active raffle cannot enter refunds before `endTime + 2 days`. (2) A drawing raffle cannot enter refunds before its callback deadline. (3) At the exact applicable deadline, refunds open while draw initiation or fulfillment is no longer accepted, leaving no time gap.

[Model: gpt-daybreak-blue-latest] `Raffle.refundTickets` — An owner gives up and destroys one to 100 tickets and receives 1 USDC per represented entry. The refund balance falls by exactly the paid amount.

[Defeat: refundTickets] (1) `[ticket 1, ticket 1]` fails on the second ownership lookup and rolls the whole batch back. (2) Including Bob’s ticket in Alice’s batch rolls every burn back. (3) A 101-ticket batch is rejected before any ticket changes.

[LastOut: timeout / refund] With tickets covering 40, 35, and 25 entries and a 100 USDC refund balance, refunding 40 then 35 leaves 25; the last owner burns the final ticket, receives the full 25 USDC, and leaves zero liability and zero shortfall.

[Model: gpt-daybreak-blue-latest] `Raffle.releaseSponsorPrize` — A permissionless caller contributes nothing; after a cash or refund result, the configured prize is sent to the fixed sponsor recipient and marked released once.

[Why: Raffle.sol:404] Why is the prize recipient not asked to acknowledge receipt? The code assumes reported ownership is sufficient even when the fixed recipient is a contract.

[Defeat: releaseSponsorPrize] (1) Release while sales are active is rejected. (2) A second release is rejected. (3) A malicious prize contract can no-op the transfer and return the expected recipient from `ownerOf`, falsely finalizing release.

[LastOut: empty raffle] There is no quote claimant and therefore no quote shortfall. With an honest prize, the sponsor recipient receives the sole NFT; the same counterfeit-prize defect can falsely mark that return complete.

[Model: gpt-daybreak-blue-latest] `releaseSponsorProceeds`, `releaseProtocolFees`, and `_transferQuote` — A permissionless caller contributes nothing. Each fixed beneficiary receives its complete recorded USDC claim, and that one claim falls to zero; a failed payment restores it.

[Defeat: independent releases] (1) Releasing the sponsor claim twice fails on the second zero balance. (2) Releasing treasury before sponsor changes neither amount. (3) A failed token payment rolls the cleared claim back, so it cannot disappear without payment.

[LastOut: independent releases] In the NFT result, either `95 then 5` or `5 then 95` pays the last quote claimant in full. In the cash result, every ordering of `80`, `15`, and `5` totals exactly 100 USDC; no rounding dust or order-dependent shortfall remains.

[Saturation: counterfeit-prize-self-attestation] The full bundled source was mined for `supportsInterface`, prize receiver calls, `safeTransferFrom`, `transferFrom`, `ownerOf`, and `prizeClaimed`. The same trust defect appears at initial escrow (`RaffleFactory.sol:128-132`), winner delivery (`Raffle.sol:334-335`), and sponsor return (`Raffle.sol:404-405`); these are one root cause because one trusted-prize restriction removes every instance.

[Saturation: flow-completeness] Every write to sold entries, ticket count, unallocated pot, refund balance, winner proceeds, sponsor proceeds, protocol fees, prize completion, settlement completion, winner completion, status, and the three factory registries was matched against all inverse and sibling paths. No unmatched USDC increment, decrement, branch allocation, or terminal release survived the sweep.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: counterfeit-prize-escrow | group_key: RaffleFactory | createRaffle | counterfeit-prize-escrow
root_cause: RaffleFactory.sol:129 wrongly treats `prize.ownerOf(prizeTokenId)`—a return value supplied by the sponsor-selected prize contract—as independent escrow proof; the missing operation is restricting `params.prizeToken` to trusted prize code before accepting its receiver call and self-reported ownership
internal_pre: None
external_pre: None
path:
  1. Mallory deploys `Counterfeit721` for token ID 7; it reports ERC-721 support, makes `safeTransferFrom` call the raffle receiver with the expected factory, sponsor, and ID without creating an enforceable token, and reports whichever destination the protocol expects from `ownerOf`.
  2. Mallory creates a raffle with reserve 1 and herself as sponsor recipient. The clone becomes `Active` because the counterfeit contract fabricates the receiver call and reports the clone as owner.
  3. Alice buys 60 entries for 60,000,000 raw USDC and Bob buys 40 for 40,000,000 raw USDC. The authenticated draw selects entry 10 on Alice’s ticket and resolves `NftWon`.
  4. A keeper settles Alice’s ticket, allocating 95,000,000 raw USDC to Mallory and 5,000,000 to the treasury; Mallory releases her 95 USDC.
  5. Alice redeems. `Counterfeit721.transferFrom` does not give her transferable control but reports Alice from `ownerOf`, so the raffle burns her ticket and permanently records the prize as delivered.
impact: Alice and Bob fund a 100 USDC raffle with no enforceable prize; Mallory extracts 95 USDC while retaining control of the purported NFT, and the selected winner is left holding the entire missing-prize loss after her ticket is burned
mitigation: Restrict `params.prizeToken` during creation to an immutable allowlist or trusted registry of reviewed, non-upgradeable ERC-721 implementations; ERC-165, receiver callbacks, and `ownerOf` reported by arbitrary prize code cannot authenticate that code

LEAD | contract: Raffle | function: redeemWinningTicket | bug_class: unsafe-contract-nft-delivery | group_key: Raffle | redeemWinningTicket | unsafe-contract-nft-delivery
smell: Raffle.sol:334 and sibling Raffle.sol:404 use `transferFrom` rather than `safeTransferFrom`, so a contract winner or sponsor recipient never acknowledges or accounts for the incoming prize before the raffle finalizes delivery
unverified: No in-scope recipient implementation establishes that such a recipient cannot recover an unsafely received NFT; without that external behavior, the path may reduce to recipient-specific misconfiguration or self-harm
description: A contract that accepts raffle tickets but relies on its ERC-721 receiver hook to record the eventual prize can become the reported NFT owner without recording or exposing that NFT to its beneficiary.

[Coverage: files] `Raffle.sol` — all value entries/exits, tracked writes, status branches, ticket movement, deadlines, callbacks, settlement, redemption, refunds, releases, and destination checks; `RaffleFactory.sol` — deployment validation, clone creation, registry atomicity, escrow, and untrusted-token calls; `IRaffle.sol` and `IRaffleFactory.sol` — signatures, lifecycle promises, events, errors, getters, and documented trust assumptions; `RaffleConstants.sol` — price, percentages, bounds, timing, gas, and confirmations; `DESIGN.md` — every economic split, deadline, one-shot promise, custody promise, and trust boundary.

[Coverage: properties] Quote solvency and exact allocation; contiguous entry coverage; mint/burn and forward/inverse symmetry; last-ticket and last-liability payout; prize custody and both prize exits; one-shot initialization/request/resolution/settlement/redemption; factory registry consistency; deadline boundary equality; reentrancy and external-call rollback; interface/implementation agreement; complete sibling-site saturation.