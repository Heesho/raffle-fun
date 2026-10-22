# Money map

The transferable range ticket is the protocol's claim instrument. A purchase fixes its entry count forever; ownership determines who may redeem it. There is no floating exchange rate and no use of a live token balance as a conversion input.

| Value or claim | Creation / increase | Conversion or exit | Recipient |
| --- | --- | --- | --- |
| Sale USDC | `buyEntries`: `entryCount * 1,000,000` enters and increases `unsettledPot` by the same amount | `enableRefunds` reclassifies the whole pot as `remainingRefundLiability`; `_settleWinningTicket` reclassifies it as terminal proceeds | Ticket owners, the winning-ticket owner, sponsor recipient, and treasury according to outcome |
| Range-ticket claim | `buyEntries` creates one ticket covering `[totalEntries + 1, totalEntries + entryCount]`; `totalEntries` and `ticketCount` advance | `refundTickets` or `redeemWinningTicket` consumes the ticket once | Current ticket owner |
| Refund claim | `enableRefunds`: `remainingRefundLiability = old unsettledPot` | `refundTickets`: subtracts the ticket ranges' exact entry count times `ENTRY_PRICE` | Current owners of the consumed tickets |
| Cash-result claims | `_settleWinningTicket`: winner gets 80%, treasury gets 5%, sponsor gets the remainder | Independent winner, sponsor, and treasury releases zero their own buckets before payment | Winning-ticket owner, immutable sponsor recipient, immutable treasury |
| NFT-result claims | `_settleWinningTicket`: treasury gets 5% and sponsor gets the remainder; winning ticket continues to represent the NFT | Quote claims release independently; the winning owner separately consumes the ticket for the NFT | Winning-ticket owner, sponsor recipient, treasury |
| Prize NFT | `createRaffle` moves the selected NFT from sponsor to raffle and activation records custody | `redeemWinningTicket` sends it to the winner in `NftWon`; `releaseSponsorPrize` returns it in `CashWon` or `Refunding` | Winning-ticket owner or sponsor recipient |
| Native request value | `requestDraw` receives a caller-funded amount | Wrapper receives actual fee and the same caller receives all excess | Wrapper and requester |

Relevant aggregate writers are complete: `totalEntries`, `ticketCount`, and `_ticketRanges` only grow in `buyEntries`; `unsettledPot` grows in `buyEntries` and is zeroed only when identically reclassified by `enableRefunds` or `_settleWinningTicket`; `remainingRefundLiability` is created by `enableRefunds` and reduced by exact refunds; `winnerProceeds`, `sponsorProceeds`, and `protocolFees` are created at settlement and independently zeroed on payment. `raffleCount` and all three factory registry mappings are written atomically in `createRaffle`. Failed external calls revert their surrounding state writes.

The governing equations are:

- `G = totalEntries * 1,000,000` raw USDC units.
- Refund value for a ticket is `(lastEntry - firstEntry + 1) * 1,000,000`.
- Cash result: `W = floor(G * 8000 / 10000)`, `F = floor(G * 500 / 10000)`, `S = G - W - F`.
- NFT result: `F = floor(G * 500 / 10000)`, `S = G - F`.

Because `G` is always a multiple of 1,000,000, both percentage calculations are exact: every entry contributes 800,000 raw units to the cash winner, 50,000 to the treasury, and 150,000 to the sponsor in `CashWon`, or 50,000 to the treasury and 950,000 to the sponsor in `NftWon`. No raw-unit rounding residue exists.

[Model: createRaffle / onERC721Received] A sponsor gives one selected NFT and receives an active raffle whose sale proceeds will later go to the configured recipients. The factory's raffle count and registry advance, the raffle records the parties and prize, and custody changes from sponsor to raffle.

[Model: buyEntries] A buyer gives exactly 1 USDC per entry and receives one transferable ticket covering exact entry numbers. Lifetime entries, lifetime tickets, historical coverage, and unallocated sale money increase together.

[Model: _update] Moving a ticket changes only who owns the bearer claim. It does not change the represented entry count, the sale pot, or any outcome allocation.

[Model: requestDraw] A requester gives native currency for randomness. The wrapper receives its actual fee, the requester receives the entire excess, and the raffle records that a draw is pending.

[Model: fulfillRandomWords] No value moves. One sold entry becomes the winner and the result becomes either an NFT result or a cash result; the sale pot is still untouched.

[Model: enableRefunds] Nobody gives new value. The full unallocated sale pot becomes an equal debt to all still-existing tickets, with no haircut.

[Model: _settleWinningTicket] Nobody gives or receives value at this step. The complete sale pot becomes fixed winner, sponsor, and treasury claims, and the supplied historical range becomes the unique winning ticket.

[Model: redeemWinningTicket] The current winning owner consumes the ticket and receives either its cash allocation or the escrowed NFT. The winner's cash bucket or the NFT-delivery flag is consumed in the same transaction.

[Model: refundTickets] A current owner consumes one to 100 tickets and receives exactly 1 USDC for every represented entry. The aggregate refund debt falls by exactly the payment.

[Model: releaseSponsorProceeds] The sponsor recipient gives nothing new and receives its complete fixed USDC claim. That claim is set to zero in the same transaction.

[Model: releaseProtocolFees] The treasury gives nothing new and receives its complete fixed USDC claim. That claim is set to zero in the same transaction.

[Model: releaseSponsorPrize] In a cash or refund result, the sponsor recipient receives the escrowed NFT and the sole prize claim is consumed atomically.

[Why: Raffle.sol:528-555] Why may an NFT-result sale pot become freely releasable before the winning ticket has received the NFT? The code relies on the implicit belief that a prize which accepted escrow will remain transferable later, although the prize contract controls that future call.

[Why: RaffleFactory.sol:127-134] Why does checking `ownerOf` immediately after escrow prove future redemption will work? It proves only present reported custody; it does not prove that an untrusted token cannot pause, blacklist, upgrade, or selectively reject the later outbound transfer.

[Defeat: _validateCreateParams] (1) A sponsor uses a pausable NFT that truthfully reports ERC-721 support while unpaused, then pauses it after escrow. (2) A sponsor uses an upgradeable NFT that behaves normally during creation and changes transfer behavior after buyers enter. (3) A hostile NFT reports the raffle as owner during the factory check but later rejects every transfer whose sender is the raffle. All three pass the creation-time interface and ownership checks.

[Defeat: redeemWinningTicket] (1) With `status=NftWon` and a sole winning ticket, the prize rejects `transferFrom`, so the entire redemption reverts. (2) A prize blocks the winner address after settlement, again reverting the only delivery path. (3) A hostile prize returns from the transfer but lies from `ownerOf`; the post-transfer guard then reverts. Atomic rollback protects the ticket state, but none of these attacks restores a refund path or claws back quote proceeds already released.

[Defeat: refundTickets] (1) Repeating ticket 1 in `[1,1]` fails on its second ownership lookup and rolls back the first burn. (2) Alice including Bob's ticket after her own fails and rolls back the whole batch. (3) Refunding a 60-entry ticket before a 40-entry ticket changes only order: the liability goes 100,000,000 to 40,000,000 to zero. None creates value or makes the last owner absorb a deficit.

[Defeat: _settleWinningTicket] (1) Ticket ID zero has range `[0,0]` and cannot contain a one-based winner. (2) A non-winning historical ticket fails the range test. (3) Calling settlement a second time fails after the first call's completion flag. The range proof and single-use guard are sound; the exploitable edge is the missing delivery prerequisite for releasing NFT-result proceeds.

# Arithmetic and Last User Out

A three-entry purchase pays 3,000,000 raw units. If refunds open, consuming that ticket returns 3,000,000, so an immediate logical round trip has zero gain. With seven entries, a cash result allocates `5,600,000 + 350,000 + 1,050,000 = 7,000,000`; an NFT result allocates `350,000 + 6,650,000 = 7,000,000`. The maximum `uint128` entry count times 1,000,000 remains far below `uint256`, and disjoint ticket ranges keep any refund batch's represented entries no greater than lifetime entries.

[LastOut: refunds] Consider tickets covering entries 1-2, 3-5, and 6-7. They are owed 2,000,000, 3,000,000, and 2,000,000. In the worst order, the first two owners withdraw 5,000,000 and the last owner still receives the full 2,000,000; liability and intended USDC balance finish at zero. Splitting more than 100 tickets across transactions does not change the sum.

[LastOut: cash result] For seven entries, let sponsor and treasury withdraw first. They remove 1,050,000 and 350,000, leaving exactly 5,600,000 for the winning owner. Reversing the order leaves exactly 1,400,000 for sponsor and treasury. Every last quote claimant is fully paid.

[LastOut: NFT result] With a transfer-live prize and seven entries, sponsor and treasury can withdraw in either order and exhaust exactly 7,000,000 while the winner receives the single NFT. With an adversarial prize, however, the quote claimants can exhaust all 7,000,000 first while the winner's later NFT redemption returns nothing because it reverts. The last claimant is then the winning-ticket owner, and the protocol is short one promised NFT; this is the finding below.

[LastOut: empty raffle] No quote claim exists. The only intended exit is the single NFT back to the sponsor recipient; a failed transfer harms that sponsor cohort rather than shifting a balance shortfall to entrants.

# Saturation result

The premature-release pattern exists in both quote exits: `releaseSponsorProceeds` and `releaseProtocolFees` have no successful-prize-delivery prerequisite after `NftWon`. They are one root cause and one finding. The sibling branches do not create the same third-party loss: cash redemption uses the trusted canonical USDC and its fixed bucket remains fully backed regardless of sponsor/treasury release order; refund burns and payment revert together; failure of `releaseSponsorPrize` in `CashWon` or `Refunding` leaves the sponsor's own NFT claim intact without consuming ticket-owner USDC. The post-transfer ownership check also cannot restore proceeds that were released in earlier transactions.

FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: premature-proceeds-release | group_key: Raffle | _settleWinningTicket | premature-proceeds-release
root_cause: In the `NftWon` branch at Raffle.sol:543-555, settlement converts the entire pot into immediately releasable sponsor and treasury balances before the only prize-delivery attempt at Raffle.sol:334; the independent exits at Raffle.sol:375-390 require neither `prizeClaimed` nor `winnerRedeemed`.
internal_pre: A sponsor-selected ERC-721 allows the initial escrow but can later reject transfers from the raffle; one entry is sold, the reserve is met, and the authenticated callback resolves `NftWon`.
external_pre: None
path:
  1. Mallory deploys a pausable ERC-721, mints token 1, leaves transfers enabled, and creates a raffle with `reserveEntries = 1`, herself as `sponsorRecipient`, and token 1 as the prize; factory escrow and its immediate ownership check succeed.
  2. Alice buys the sole entry for 1,000,000 raw USDC units. After the sale, randomness necessarily selects entry 1 and `totalEntries >= reserveEntries` produces `NftWon`.
  3. Mallory disables outbound transfers in the prize contract. A permissionless caller settles ticket 1: `protocolFees = 1,000,000 * 500 / 10,000 = 50,000`, `sponsorProceeds = 950,000`, and `unsettledPot = 0`.
  4. `releaseSponsorProceeds` pays Mallory 950,000 raw units, and `releaseProtocolFees` can pay the remaining 50,000 to the treasury. The full sale pot has left the raffle.
  5. Alice calls `redeemWinningTicket(1)`. The prize rejects the transfer at Raffle.sol:334, so Alice's redemption transaction reverts, but the earlier settlement and releases persist. `NftWon` has no transition to `Refunding`, so Alice can receive neither the NFT nor her 1,000,000-unit payment back.
impact: The winning-ticket owner is left holding an unredeemable claim and loses the full 1 USDC purchase while a malicious sponsor extracts 0.95 USDC and the treasury may extract 0.05 USDC. At larger sales the loss scales linearly with the entire pot.
mitigation: Do not make the `NftWon` sponsor and treasury balances releasable until successful prize delivery; keep that pot uncommitted and route it to ticket refunds after a bounded delivery failure instead.
