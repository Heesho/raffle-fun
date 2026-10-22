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