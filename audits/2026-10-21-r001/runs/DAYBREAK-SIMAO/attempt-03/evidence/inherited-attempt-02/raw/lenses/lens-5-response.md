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