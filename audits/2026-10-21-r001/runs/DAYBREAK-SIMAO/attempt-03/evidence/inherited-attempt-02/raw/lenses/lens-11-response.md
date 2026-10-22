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