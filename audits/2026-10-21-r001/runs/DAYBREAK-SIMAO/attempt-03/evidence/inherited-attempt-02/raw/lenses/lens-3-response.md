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