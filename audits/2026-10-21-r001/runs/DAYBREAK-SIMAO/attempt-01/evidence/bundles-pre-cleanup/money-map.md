# Money map — raffle.fun

Scope: `Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`, `IRaffle.sol`,
`IRaffleFactory.sol`, and `DESIGN.md`. The two interfaces are intentionally in scope.

## Plain-English model

A sponsor escrows one ERC-721 prize into a newly cloned raffle. Buyers pay exactly
1,000,000 raw six-decimal USDC units per entry and receive transferable range tickets.
After the sale, a caller separately funds a Chainlink VRF request in native currency.
Randomness chooses one entry. If the reserve was met, the current winning-ticket owner
gets the NFT and sale USDC is split 95% sponsor / 5% treasury. If it was missed, the
winner gets 80%, the sponsor gets the remainder after a 5% protocol fee, and the NFT
returns to the sponsor recipient. If liveness deadlines expire, tickets receive full
USDC refunds and the NFT returns to the sponsor recipient.

## Assets and movement

| Asset | Enters | Leaves | Claimant / sink |
| --- | --- | --- | --- |
| Canonical six-decimal USDC | `Raffle::buyEntries` pulls `entryCount * ENTRY_PRICE` from buyer | `refundTickets` | current owners of burned tickets |
| Canonical six-decimal USDC | same sale pot | `redeemWinningTicket` in `CashWon` | current winning-ticket owner |
| Canonical six-decimal USDC | same sale pot | `releaseSponsorProceeds` | immutable `sponsorRecipient` |
| Canonical six-decimal USDC | same sale pot | `releaseProtocolFees` | immutable `protocolTreasury` |
| Configured ERC-721 prize | `RaffleFactory::createRaffle` transfers sponsor's token; `Raffle::onERC721Received` activates | `redeemWinningTicket` in `NftWon` | current winning-ticket owner |
| Configured ERC-721 prize | same escrow | `releaseSponsorPrize` in `CashWon` or `Refunding` | immutable `sponsorRecipient` |
| Native currency | `requestDraw` receives caller-funded request value | inherited wrapper request call pays `paidPrice`; excess raw-call refund | Chainlink wrapper and same requester |
| Forced/unrelated assets | unsafe ERC-721 transfer or forced native value may arrive | no protocol path | no protocol claimant; deliberately outside accounting |

USDC and the wrapper are trusted canonical dependencies. Prize contracts, ticket
recipients, payout recipients, purchasers, callers, and settler inputs are adversarial.
Native request value is caller-funded passthrough, not part of the raffle sale pot.

## Tracked totals and every write

| Variable / aggregate | Meaning | Writers and direction |
| --- | --- | --- |
| `RaffleFactory.raffleCount` | lifetime successful clones / latest ID | `createRaffle`: `+1` before atomic clone flow |
| `RaffleFactory.raffleById` | ID → clone registry | `createRaffle`: set once |
| `RaffleFactory.idByRaffle` | clone → ID registry | `createRaffle`: set once |
| `RaffleFactory.isRaffle` | canonical-clone membership | `createRaffle`: `false → true` once |
| `Raffle.totalEntries` | lifetime sold entries / last global entry | `buyEntries`: `+entryCount`; intentionally never decremented |
| `Raffle.ticketCount` | lifetime range tickets / latest ID | `buyEntries`: `+1`; intentionally never decremented |
| `Raffle._ticketRanges[id]` | historical inclusive entry coverage | `buyEntries`: set once; intentionally retained after burn |
| `Raffle.unsettledPot` | collected USDC not yet allocated | `buyEntries`: `+grossAmount`; `enableRefunds`: set `0`; `_settleWinningTicket`: set `0` |
| `Raffle.remainingRefundLiability` | USDC owed to unrefunded tickets | `enableRefunds`: set from old `unsettledPot`; `refundTickets`: `-amount` |
| `Raffle.winnerProceeds` | cash-winner USDC liability | `_settleWinningTicket` in `CashWon`: set `cashAmount`; `redeemWinningTicket`: set `0` |
| `Raffle.sponsorProceeds` | sponsor-recipient USDC liability | `_settleWinningTicket`: set remainder; `releaseSponsorProceeds`: set `0` |
| `Raffle.protocolFees` | treasury USDC liability | `_settleWinningTicket`: set floor fee; `releaseProtocolFees`: set `0` |
| `Raffle.accountedQuoteBalance()` | sum of all current USDC liabilities | derived: `unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees` |
| `Raffle.grossSales()` | lifetime USDC sold | derived: `totalEntries * ENTRY_PRICE` |
| `Raffle.status` | lifecycle/result | constructor → `Refunding`; clone `initialize` → `AwaitingPrize`; `onERC721Received` → `Active`; `requestDraw` → `Drawing`; `fulfillRandomWords` → `NftWon`/`CashWon`; `enableRefunds` → `Refunding` |
| `Raffle.settlementComplete` | terminal quote allocation consumed | `_settleWinningTicket`: `false → true` |
| `Raffle.winnerRedeemed` | winning ticket/prize claim consumed | `redeemWinningTicket`: `false → true` |
| `Raffle.prizeClaimed` | escrowed NFT delivered/returned | `redeemWinningTicket` NFT branch or `releaseSponsorPrize`: `false → true` |
| `Raffle.vrfRequestId` | accepted request | `requestDraw`: set returned ID |
| `Raffle.drawRequestedAt` | request timestamp | `requestDraw`: set once |
| `Raffle.winningEntry` | selected one-based entry | `fulfillRandomWords`: set once |
| `Raffle.resolvedAt` | resolution timestamp | `fulfillRandomWords`: set once |
| `Raffle.winningTicketId` | proven winning range ticket | `_settleWinningTicket`: set once |

## Asymmetry table

| Value/state movement | Required counterpart | Source result |
| --- | --- | --- |
| USDC enters in `buyEntries` | `unsettledPot += grossAmount`, range and entry totals advance | present at `Raffle.sol:230-233`; safe mint failure rolls all back |
| Pot becomes refunds | zero pot and create equal refund liability | present at `Raffle.sol:296-299` |
| Pot becomes terminal claims | zero pot; winner + sponsor + protocol equals old pot | present at `Raffle.sol:539-555`; sponsor receives rounding remainder |
| Refund USDC exits | burn each owned ticket and decrement liability by exact represented entries | present at `Raffle.sol:356-369`; transfer failure rolls back burns/decrement |
| Cash-winner USDC exits | zero `winnerProceeds` once and burn winning ticket | present at `Raffle.sol:320-342`; transfer failure rolls all back |
| Sponsor USDC exits | zero `sponsorProceeds` | present at `Raffle.sol:375-380` |
| Protocol USDC exits | zero `protocolFees` | present at `Raffle.sol:385-390` |
| Prize NFT enters | exact token/from/operator callback activates; factory verifies owner/status | present across `Raffle.sol:416-430` and `RaffleFactory.sol:127-134`; all atomic |
| Prize NFT exits to winner | consume winner/ticket/prize flags; verify post-owner | present at `Raffle.sol:320-337`; all effects revert on failure |
| Prize NFT exits to sponsor | consume `prizeClaimed`; verify post-owner | present at `Raffle.sol:395-406`; all effects revert on failure |
| Native request value enters | pay actual wrapper price and return entire excess | present at `Raffle.sol:249-270`; refund failure reverts request atomically |
| Historical entry/ticket totals remain after value exits | no decrement: IDs and coverage are lifetime facts, not current liabilities | intentional; current claims live in tickets and liability buckets |
| Direct/forced asset arrival | no aggregate and no rescue | unrelated forced assets are outside documented ownership; check as robustness lead only |

No intended value-moving branch lacks an obvious matching liability write in this map.
The adversarial review must still test malicious external-call semantics, terminal states,
timestamp boundaries, predicted addresses, and every branch for a concrete break.

## Core invariants

1. `accountedQuoteBalance() <= quoteToken.balanceOf(address(this))`; equality holds after intended flows absent unsolicited USDC.
2. While `Active` or `Drawing`, `unsettledPot == totalEntries * ENTRY_PRICE` absent unsolicited USDC, and other quote liabilities are zero.
3. Settlement preserves quote value: `winnerProceeds + sponsorProceeds + protocolFees == pre-settlement unsettledPot`.
4. In `NftWon`, `winnerProceeds == 0`; sponsor plus protocol equals the gross pot.
5. In `CashWon`, winner is floor 80%, protocol is floor 5%, and sponsor is the exact remainder; no raw unit is lost.
6. In `Refunding`, `remainingRefundLiability` equals the entry value represented by every unburned ticket, and each represented entry is debited exactly once.
7. Historical ranges are non-overlapping, contiguous, one-based, and partition `[1,totalEntries]`.
8. `winningEntry` lies in `[1,totalEntries]`, and exactly one historical ticket range contains it.
9. A terminal winning-ticket settlement happens at most once; a winning ticket or refund ticket burns at most once.
10. The configured prize is held by the raffle from activation until exactly one successful winner delivery or sponsor return; failed delivery reverts every claim-state change.
11. Only the authenticated wrapper callback for the stored request, strictly before its deadline and after request persistence, may resolve.
12. Factory registry maps are a bijection for every successfully created clone, and failed creations leave no count or registry residue.
13. No operation moves assets between registered raffle clones.

## Lifecycles and touched state

1. Create → escrow → activate: factory `raffleCount`/registry; clone configuration/`initialized`/`status`; NFT custody; `status=Active`.
2. Buy → hold/transfer ticket: USDC custody; `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`; ERC-721 ownership.
3. Sale ends → request → callback: `status`, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId`; native fee; then `winningEntry`, `resolvedAt`, result status.
4. NFT result → settle → redeem/release: `unsettledPot` → `sponsorProceeds` + `protocolFees`; `settlementComplete`, `winningTicketId`; winning ticket burn; `winnerRedeemed`, `prizeClaimed`; NFT to winner; quote releases.
5. Cash result → settle → redeem/release: `unsettledPot` → `winnerProceeds` + `sponsorProceeds` + `protocolFees`; ticket burn and cash; NFT sponsor return; independent quote releases.
6. Request/callback timeout → refunds: `unsettledPot` → `remainingRefundLiability`, `status=Refunding`; batched owner burns/decrements/transfers; NFT sponsor return.
7. Empty raffle cancellation: `Active` → `Refunding`, zero quote liability; NFT sponsor return.

## Cohorts and obligations

- Sponsor/prize depositor: supplies NFT; may close an empty raffle early.
- Sponsor recipient: owed 95% on NFT result, 15% plus allocation remainders on cash result, and NFT on cash/refund.
- Entry payer: supplies USDC but may name another initial ticket owner.
- Current ticket owner: bearer of refund rights; if its range wins, bearer of cash or NFT right.
- Winning-ticket owner at redemption: only actor authorized to burn and receive the winner asset.
- Early and last refunders: each is owed exact represented entry value independent of order.
- Protocol treasury: owed aggregate floor 5% fee after settlement.
- Draw requester: pays only the wrapper's native fee and is owed immediate excess refund.
- Permissionless settler/releaser: triggers allocation/delivery but receives nothing merely for calling.
- Canonical factory/wrapper/USDC: trusted plumbing; registered clones must never be asset recipients.

## Last-user-out balance checks

- Refund lifecycle: N entries create `N * ENTRY_PRICE`; arbitrary ticket-refund order removes exactly each range value; last ticket receives its full value and liability/balance reach zero.
- Cash-win lifecycle: for gross G, `floor(.80G) + floor(.05G) + remainder == G`; any release order pays all three cohorts, with last quote claimant fully paid.
- NFT-win lifecycle: `floor(.05G) + (G - floor(.05G)) == G`; winner receives the one NFT and both quote claimants are paid in either order.
- Empty lifecycle: no quote claimant exists; sponsor recipient receives the sole prize.
