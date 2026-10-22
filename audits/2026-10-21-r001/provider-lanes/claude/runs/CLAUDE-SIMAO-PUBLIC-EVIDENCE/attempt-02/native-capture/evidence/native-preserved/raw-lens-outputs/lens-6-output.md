# Lens 6: Rounding, Precision & Scale (0xSimao), raffle.fun

Scope: `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `libraries/RaffleConstants.sol`, `interfaces/*`, and `DESIGN.md`. Line numbers are on-disk source lines. I diffed the bundle copy against the on-disk source and they are byte-identical. Dependencies checked: OpenZeppelin 5.6.1 `Math.mulDiv` (3-argument form rounds down, with a 512-bit intermediate) and Chainlink 1.5.0 `VRFV2PlusWrapperConsumerBase.requestRandomnessPayInNative`.

## Result

- **FINDINGs: 0.** Every division, multiplication, subtraction, cast, decimal assumption, constant unit and time boundary in scope was checked, and none can be broken. The 5%/80%/remainder split is exact for every reachable pot, so the rounding direction never matters (see the evidence section).
- **LEADs: 2.** Both are outside Lens 6's arithmetic surface. They are recorded under the "never drop" rule so the orchestrator can deduplicate them against the owning lenses.

## FINDINGS

None survived verification.

## LEADS

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: cross-asset-payout-decoupling | group_key: Raffle | releaseSponsorProceeds | cross-asset-payout-decoupling
smell: In NftWon, _settleWinningTicket makes 95% of the pot claimable by sponsorRecipient (Raffle.sol:544, :554). releaseSponsorProceeds (Raffle.sol:375-382) pays it without checking prizeClaimed or winnerRedeemed. The NFT leg (redeemWinningTicket, Raffle.sol:334-335) depends on the prize contract, which DESIGN.md says is untrusted, and it has no fallback: releaseSponsorPrize is barred in NftWon (Raffle.sol:397), and enableRefunds rejects terminal states (Raffle.sol:279-294). Suppose the prize contract permanently blocks transfers out of the clone (an admin pause, or a transfer-validator or blocklist entry on the clone address). Then the winning-ticket holder gets nothing while sponsorRecipient (950,000*T raw) and the treasury (50,000*T raw) are paid in full. Example with T = 10,000 entries: 9,500 USDC go to sponsorRecipient, 500 USDC go to the treasury, and the winning ticket is worthless.
unverified: This is outside Lens 6 (no arithmetic defect). Unclear whether a sponsor can profit from it. Profit needs a prize contract where the sponsor controls an admin seizure or unfreeze path; otherwise it is only griefing. The IRaffle.sol NatSpec says "Supported prizes are honest, standards-compliant ERC-721s", which conflicts with DESIGN.md's untrusted-prize statement. Gating sponsor proceeds on prizeClaimed would create the opposite problem: proceeds held hostage by a winner who never redeems.
description: The sponsor and treasury USDC legs settle independently of NFT delivery, so an undeliverable prize leaves only the winner unpaid, with no refund path.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: reserve-threshold-self-funding | group_key: Raffle | fulfillRandomWords | reserve-threshold-self-funding
smell: The outcome test `totalEntries >= reserveEntries` (Raffle.sol:521) also counts entries the sponsor paid for. In NftWon, 95% of every entry, including the sponsor's own, returns to sponsorRecipient (Raffle.sol:544, :554). So the sponsor can flip a raffle that is below reserve from CashWon to NftWon for a 5% toll on the gap. Example: reserve 10,000 entries, 8,000 entries bought by other users. The sponsor buys 2,000 entries at endTime-1, which Raffle.sol:216 allows. Without the flip (CashWon), the winner gets 6,400 USDC and sponsorRecipient gets 1,200 USDC plus the NFT back. With the flip (NftWon), sponsorRecipient gets 9,500 USDC (net +7,500 after the 2,000 USDC outlay) and the sponsor's tickets have a 20% chance of winning the NFT. With the NFT worth 5,000 USDC: sponsor expected value rises from 6,200 to 8,500 (+2,300). The other buyers' expected value falls from 6,400 to 4,000 (-2,400). The treasury gains 100. The changes sum to zero.
unverified: This is outside Lens 6 (economic/MEV). DESIGN.md does not forbid sponsor participation, and any address can buy (Sybil), so this may be an accepted property of reserve auctions. The flip only pays when the sponsor values the NFT below 0.8 x the pot from other buyers (here, below 7,875 USDC). Buyers can see totalEntries and reserveEntries on-chain, but they cannot exit before the outcome except by selling the ticket, because refundTickets requires Refunding.
description: The sponsor can meet the reserve with their own entries, 95% of which come back to them, turning a cash raffle into an NFT raffle after buyers have committed.
```

## Public audit-evidence summaries

### Value movements

- **[Model: buyEntries, Raffle.sol:209-237]** The buyer pays `entryCount * 1,000,000` raw USDC (:223-224) and receives one ERC-721 ticket for the inclusive range `[totalEntries+1, totalEntries+entryCount]` (:226-232, :235). The function writes `totalEntries` (:230), `ticketCount` (:231), `_ticketRanges` (:232), and `unsettledPot += gross` (:233). The pot and the sum of all ticket ranges grow by the same integer amount.
- **[Model: enableRefunds → refundTickets, Raffle.sol:276-300, :349-372]** The whole `unsettledPot` moves 1:1 into `remainingRefundLiability` (:296-298). A refund burns the caller's tickets and pays `Σ(last-first+1) * 1e6` (:363-369). It reduces the liability by exactly that amount (:368).
- **[Model: _settleWinningTicket, Raffle.sol:533-558]** The pot is split once, guarded by `settlementComplete` (:534, :551):
  - fee = `mulDiv(pot,500,1e4)` (:540)
  - NftWon: sponsor = `pot - fee` (:544)
  - CashWon: cash = `mulDiv(pot,8000,1e4)` (:546) and sponsor = `pot - fee - cash` (:547)
  - It writes `winnerProceeds`, `sponsorProceeds` and `protocolFees`, and sets `unsettledPot = 0` (:548-555).
- **[Model: redeemWinningTicket / releaseSponsorProceeds / releaseProtocolFees]** Each one pays the full stored claim and sets it to zero (:340-342, :376-380, :386-390).
- **[Model: requestDraw native leg, Raffle.sol:240-273]** The caller sends `msg.value >= quote` (:249-250). The wrapper is paid `paidPrice`, which the consumer base computes in the same transaction. The excess `msg.value - paidPrice` goes back to the caller (:262-270). No native balance is tracked or read.

### Assumptions and why they hold

- **[Why: Raffle.sol:540, :546, the split is exact]**
  - The only write that increases `unsettledPot` is :233, with `gross = entryCount * 1e6` (:223). So `pot = T * 1e6`, where T is the number of entries sold.
  - `1e6*500/1e4 = 50,000` and `1e6*8000/1e4 = 800,000` are both integers, so rounding down gives the exact value for every T.
  - Result: fee = 50,000·T, cash = 800,000·T, sponsor = 150,000·T (CashWon) or 950,000·T (NftWon). The parts always add up to the pot.
  - Checked numerically for T = 1..200,000 and T = 2^128-1: no violations and no zero share.
  - DESIGN.md requires the fee to round down on the total and the remainder to be allocated without loss. That holds, and the remainder is always zero.
- **[Why: Raffle.sol:219, entry-number headroom]** The check `entryCount > type(uint128).max - totalEntries` ensures `lastEntry <= 2^128-1` and `firstEntry >= 1` (:226-227).
- **[Why: Raffle.sol:368, the subtraction cannot underflow]**
  - In Refunding, `remainingRefundLiability` always equals `1e6 * Σ(entries on unburned tickets)`. It starts as `pot = 1e6 * totalEntries` (:296-298).
  - No ticket can be burned before Refunding. The only other burn (:325) requires NftWon or CashWon (:312), and those states never move to Refunding, because enableRefunds accepts only Active or Drawing (:279-294).
  - A duplicate ID in one refund batch reverts at its second `ownerOf` call (:359).
  - So `amount <= liability` always holds, and a refund can never revert on this subtraction.
- **[Why: Raffle.sol:518, modulo and cast]**
  - The divisor `totalEntries` is never zero: the raffle enters Drawing only after the zero-entries check at :243 (status is set at :252), and `totalEntries` cannot change outside Active.
  - The result is in `[1,totalEntries]`, which is at most 2^128-1, so the `uint128` cast loses nothing.
- **[Why: RaffleFactory.sol:76, decimals]** `ENTRY_PRICE = 1,000,000` (RaffleConstants.sol:21) is correct only for a 6-decimal token. The factory constructor rejects any quote token that does not report 6 decimals, and the token address is immutable.
- **[Why: Raffle.sol:249-262, native fee arithmetic]**
  - The Raffle's quote (:249) and the consumer base's `requestPrice` are the same wrapper view (`calculateRequestPriceNative`), called at the same `tx.gasprice`.
  - So `paidPrice == quotedFee <= msg.value`. The check at :258 is redundant, and the subtraction at :262 cannot underflow.

### Adversarial checks

- **[Defeat: rounding direction / drive to zero]**
  - With T=1, the shares are fee 50,000, cash 800,000, and sponsor 150,000 (CashWon) or 950,000 (NftWon). None rounds to zero.
  - So the zero-claim reverts `NoWinnerProceeds` (:340), `NoSponsorProceeds` (:377) and `NoProtocolFees` (:387) cannot trigger after a settlement.
  - There is no repeatable rounding path: settlement happens once, and refunds are whole entry counts times a fixed price.
- **[Defeat: intermediate overflow]**
  - Worst-case sizes: gross `u128*1e6` is 148 bits (:223); a refund batch `100*u128*1e6` is 155 bits (:367); the mulDiv numerator `u128*1e6*8000` is 161 bits (and OZ `mulDiv` is 512-bit safe anyway).
  - All are far below 256 bits.
- **[Defeat: casts]**
  - `uint64(block.timestamp)` (:253, :520) is safe for about 5.8e11 years. The `uint128` cast at :518 is bounded (see above).
  - `uint64 endTime` and `uint128 reserveEntries` arrive as same-width ABI types, so the decoder rejects out-of-range values.
  - The factory's `endTime - now` subtraction (RaffleFactory.sol:101) is guarded by the check at :100.
- **[Defeat: units of constants]**
  - The timeouts use Solidity time units: `2 days`, `2 days`, `30 days` (RaffleConstants.sol:30-36).
  - 500, 8,000 and 10,000 bps match DESIGN.md's 5% and 80%. 1,000,000 raw units is 1 USDC at 6 decimals.
  - The values 30 and 300,000 are a block-confirmation count and a gas count, as their names say.
- **[Defeat: unconstrained divisor]** The only divisors are the constant `BPS` (inside mulDiv) and `totalEntries`, which is never zero. Users cannot supply a divisor.
- **[Defeat: modulo bias at Raffle.sol:518]**
  - For r uniform on [0,2^256), each entry's probability is skewed by at most 1/⌊2^256/T⌋.
  - That is 5.2e-67 at T=6e10 (about the whole USDC supply) and 2.9e-39 at T=2^128-1. It cannot be exploited.
- **[Defeat: time boundaries]**
  - Buying is allowed while `now < endTime` (:216).
  - Drawing is allowed in `[endTime, endTime+2d)` (:242, :245).
  - Refunds for a sold raffle that is still Active open at `endTime+2d` or later (:287).
  - The callback is accepted only while `now < drawRequestedAt+2d` (:512).
  - Refunds from Drawing open at `drawRequestedAt+2d` or later (:291).
  - Each pair compares `<` against `>=` on the same deadline, so the windows never overlap and leave no gap. This matches DESIGN.md.
- **[Defeat: live balance / donation]**
  - Neither Raffle.sol nor RaffleFactory.sol reads `balanceOf` or `address(this).balance`.
  - Donated USDC or ETH stays outside `accountedQuoteBalance` (:468-470) and cannot inflate any claim.
- **[Defeat: off-chain fee quote]**
  - `getVrfRequestPrice` (:436-438) depends on `tx.gasprice`, which the wrapper NatSpec says is not set during simulation.
  - An under-quote only reverts the caller's own `requestDraw` (:250), and any overpayment is refunded (:262-270). The caller can simply retry, and no third party loses anything.

### Last User Out by lifecycle

- **[LastOut: L3 NftWon]** Pot = 1e6·T. Claims are 950,000·T (sponsorRecipient) + 50,000·T (treasury) + 0 (winner cash) = pot. Each claim is released once and then set to zero, so both USDC claimants are paid in any order and the balance ends at 0 (plus any donations). The NFT leg is independent of the USDC legs (LEAD 1).
- **[LastOut: L3 CashWon]** Claims are 800,000·T + 150,000·T + 50,000·T = pot. The NFT goes back through releaseSponsorPrize (:395-407). Everyone is paid, in any order.
- **[LastOut: L4/L5 Refunding]** Liability = 1e6·T = 1e6·Σranges. Worst order with tickets of 5, 94 and 1 entries: liability goes 100,000,000 → 95,000,000 → 1,000,000 → 0. The last refunder is paid in full.
- **[LastOut: L6 Empty]** T=0: liability 0 and no tickets. The prize goes back through releaseSponsorPrize, and no USDC is owed.

## Saturation sweep (every arithmetic, cast, scale and boundary site)

| Site | Operation | Result |
| --- | --- | --- |
| Raffle.sol:219 | `type(uint128).max - totalEntries` headroom check | Safe |
| Raffle.sol:223 | `uint256(entryCount) * 1e6` | Safe (148 bits max) |
| Raffle.sol:226-227 | `totalEntries + 1` / `+ entryCount` | Safe (guarded at :219) |
| Raffle.sol:228, :231 | Ticket ID `+1` / `++ticketCount` (uint128) | Safe (limit cannot be reached) |
| Raffle.sol:233 | `unsettledPot += gross` | Safe; the pot stays a multiple of 1e6 |
| Raffle.sol:253, :520 | `uint64(block.timestamp)` | Safe |
| Raffle.sol:262 | `msg.value - paidPrice` | Safe (paidPrice equals the quote; guard at :258) |
| Raffle.sol:363 | `last - first + 1` | Safe (only minted ranges; `ownerOf` reverts for unminted IDs) |
| Raffle.sol:367 | `aggregateEntries * 1e6` | Safe (155 bits max) |
| Raffle.sol:368 | `remainingRefundLiability -= amount` | Safe (cannot underflow, shown above) |
| Raffle.sol:459, :464 | Deadline additions | Safe |
| Raffle.sol:470, :474 | View sums / `grossSales` | Safe |
| Raffle.sol:518 | `r % totalEntries + 1`, cast to `uint128` | Safe; divisor never zero; bias negligible |
| Raffle.sol:521 | `totalEntries >= reserveEntries` | Same units (entries); "met or exceeded" is correct. Economic issue → LEAD 2 |
| Raffle.sol:540 | `mulDiv(pot,500,1e4)` | Exact |
| Raffle.sol:544 | `pot - fee` | Exact, cannot underflow |
| Raffle.sol:546 | `mulDiv(pot,8000,1e4)` | Exact |
| Raffle.sol:547 | `pot - fee - cash` (85% ≤ 100%) | Exact, cannot underflow |
| Raffle.sol:582 | Inclusive range test | Correct; `winningEntry >= 1` excludes the `(0,0)` range of unminted IDs |
| RaffleFactory.sol:100-102 | `endTime - now`, ≤ 30 days | Safe (guarded) |
| RaffleFactory.sol:105 | `++raffleCount` | Safe |
| RaffleFactory.sol:76 | `decimals == 6` | Enforced; matches `ENTRY_PRICE` |

Conclusion: no rounding, precision or scale defect exists anywhere in scope, so there are no sibling sites to report.
