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