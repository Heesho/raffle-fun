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