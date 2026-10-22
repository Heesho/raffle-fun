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