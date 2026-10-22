# raffle.fun money map

Scope: `Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`,
`RaffleConstants.sol`, and `DESIGN.md`. The quote token and Chainlink wrapper
are trusted canonical dependencies. Prize contracts and ticket recipients are
untrusted. Each clone has isolated storage and custody.

## Plain-English model

A sponsor escrows one NFT through the immutable factory. Buyers pay exactly
1,000,000 raw six-decimal USDC units per entry and receive transferable ERC-721
tickets representing contiguous entry ranges. An authenticated VRF callback
chooses one entry. If the reserve is met, its ticket owner receives the NFT and
the USDC pot is split 95% sponsor / 5% treasury; otherwise the owner receives
80% of gross USDC, the sponsor 15%, and the treasury 5%. If the draw is not
requested or fulfilled by the deadlines, every ticket can be burned for its
full entry price and the NFT returns to the sponsor recipient.

## Assets and movement

| Asset | Enters | Leaves | Custodian / receiver |
| --- | --- | --- | --- |
| Canonical 6-decimal USDC | `Raffle::buyEntries`: buyer -> clone, `entryCount * ENTRY_PRICE` | `refundTickets`; cash branch of `redeemWinningTicket`; `releaseSponsorProceeds`; `releaseProtocolFees` | One raffle clone; ticket owner, winner, sponsor recipient, treasury |
| Configured prize ERC-721 | `RaffleFactory::createRaffle`: sponsor -> clone via `safeTransferFrom` | `redeemWinningTicket` after `NftWon`; `releaseSponsorPrize` after `CashWon` or `Refunding` | One raffle clone; winning-ticket owner or sponsor recipient |
| Native ETH | `requestDraw` call value | exact wrapper request price to Chainlink; excess synchronously returned to requester | Pass-through only; no intended retained balance |
| Ticket ERC-721 claim | Minted by `buyEntries` | Burned by winning redemption or refund | Current ticket owner; ticket ranges remain historical |

## Tracked totals and all writes

| Variable | Meaning | Increasing / setting writes | Decreasing / clearing writes |
| --- | --- | --- | --- |
| `totalEntries` | Lifetime sold entries and last assigned global entry | `buyEntries`: set to prior + `entryCount` | None; lifetime counter by design |
| `ticketCount` | Lifetime tickets minted / latest ID | `buyEntries`: `+1` | None; lifetime counter by design |
| `unsettledPot` | Collected USDC not yet allocated | `buyEntries`: `+ grossAmount` | `enableRefunds`: set 0 after copying; `_settleWinningTicket`: set 0 after allocating |
| `remainingRefundLiability` | USDC owed to all unrefunded tickets | `enableRefunds`: set to old `unsettledPot` | `refundTickets`: `- aggregateEntries * ENTRY_PRICE` |
| `winnerProceeds` | Current cash-winner USDC claim | `_settleWinningTicket`: set to 80% floor in `CashWon` | `redeemWinningTicket`: set 0 before transfer |
| `sponsorProceeds` | Current sponsor-recipient USDC claim | `_settleWinningTicket`: set to remainder | `releaseSponsorProceeds`: set 0 before transfer |
| `protocolFees` | Current treasury USDC claim | `_settleWinningTicket`: set to 5% floor | `releaseProtocolFees`: set 0 before transfer |
| `raffleCount` | Lifetime canonical clones | `RaffleFactory::createRaffle`: `+1` | None; lifetime counter |
| `raffleById`, `idByRaffle`, `isRaffle` | Bidirectional clone registry | `createRaffle`: one registration after initialization | None; immutable registry |
| `winningEntry` | Selected global entry | `fulfillRandomWords`: set once from authenticated word | None |
| `winningTicketId` | Proven range containing winning entry | `_settleWinningTicket`: set once | None |
| `settlementComplete` | Terminal liabilities allocated | `_settleWinningTicket`: false -> true | None |
| `winnerRedeemed` | Winning ticket burned and prize delivered | `redeemWinningTicket`: false -> true before atomic delivery | None |
| `prizeClaimed` | Escrowed prize released | `redeemWinningTicket` NFT branch or `releaseSponsorPrize`: false -> true | None |
| `status` | Lifecycle / economic result | constructor locks implementation; `initialize`, `onERC721Received`, `requestDraw`, `fulfillRandomWords`, `enableRefunds` transition it | Not numeric |

Derived totals:

- `accountedQuoteBalance = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees`.
- `grossSales = totalEntries * ENTRY_PRICE` is historical, not a current liability.
- A live ticket's refundable amount is `(lastEntry - firstEntry + 1) * ENTRY_PRICE` only in `Refunding`.

## Asymmetry table

| Movement / branch | Matching write | Assessment |
| --- | --- | --- |
| USDC enters in `buyEntries` | `unsettledPot += grossAmount` after transfer | Symmetric under trusted standard USDC; callback reverts roll back both |
| Pot becomes refundable | `unsettledPot = 0`; `remainingRefundLiability = old pot` | Exact liability migration |
| Refund USDC leaves | liability decremented before `_transferQuote` | Symmetric and atomic |
| Pot settles | pot clears; winner/sponsor/fee liabilities sum exactly to gross | Sponsor receives both percentage-rounding remainders |
| Cash winner / sponsor / treasury USDC leaves | respective claim clears before transfer | Symmetric and non-reentrant |
| Prize enters clone | receiver changes `AwaitingPrize -> Active`; factory checks `ownerOf` and status | Custody proof relies on behavior reported by the untrusted prize contract; attack this boundary |
| Prize leaves clone | `prizeClaimed = true`; caller checks reported `ownerOf` | State is atomic on revert, but verification again trusts the untrusted prize contract |
| Native ETH enters `requestDraw` | paid amount leaves to trusted wrapper and remainder is returned | No stored aggregate; intended same-transaction pass-through |
| Ticket burns on refund | represented entries debit aggregate refund liability | Symmetric |
| Ticket burns on winning redemption | `winnerProceeds` clears or `prizeClaimed` sets | Symmetric; losing tickets retain no terminal liability |
| Forced USDC or unrelated NFT arrives | no accounting write | Donation/untracked surplus; never used to increase claims. Unrelated NFTs are intentionally unrecoverable |

## Invariants

1. For every clone, `quoteToken.balanceOf(clone) >= accountedQuoteBalance()`; with canonical fee-free USDC and no donations, equality holds after each transaction.
2. Before terminal allocation, `unsettledPot == totalEntries * ENTRY_PRICE` and every other quote liability is zero.
3. In `Refunding`, `remainingRefundLiability` equals the sum of refund values of all unburned tickets, and no other quote claim is created.
4. After settlement, `winnerProceeds + sponsorProceeds + protocolFees == pre-settlement unsettledPot`; every raw unit is allocated exactly once.
5. Protocol fee is floor(`gross * 500 / 10_000`); cash winner is floor(`gross * 8_000 / 10_000`); sponsor receives the full remainder.
6. Ticket ranges are one-based, contiguous, non-overlapping, and cover exactly `[1,totalEntries]`.
7. `winningEntry` is always in `[1,totalEntries]`, and exactly one historical ticket range contains it.
8. Only the current winning-ticket owner can burn it and redeem; failed prize or quote delivery reverts the burn and all claim changes.
9. The configured prize is held by the clone from activation until exactly one successful winner delivery or sponsor return; it never moves between clones.
10. `initialize`, callback resolution, settlement, winning redemption, and prize release are each one-shot.
11. Draw requests occur only in `[endTime,endTime+2 days)`; accepted callbacks occur strictly before `drawRequestedAt+2 days`; refunds open at the applicable deadline.
12. Each factory registry entry binds one ID to one clone, and no clone is registered before atomic initialization and eventual prize escrow completes.

## Lifecycles and touched state

1. **Create / escrow:** `raffleCount` -> clone `initialized`, configuration, `AwaitingPrize` -> registries -> prize transfer -> `Active`, `prizeClaimed=false`.
2. **Buy / transfer:** USDC balance, `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`, ticket owner/balance/approval.
3. **Successful draw:** `Active` -> `Drawing`, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId` -> `winningEntry`, `resolvedAt`, `NftWon|CashWon`.
4. **Settle / redeem NFT:** `settlementComplete`, `winningTicketId`, `unsettledPot=0`, `sponsorProceeds`, `protocolFees` -> `winnerRecipient`, `winnerRedeemed`, ticket burn, `prizeClaimed`.
5. **Settle / redeem cash:** same plus `winnerProceeds` allocation -> ticket burn, `winnerProceeds=0`, USDC transfer; sponsor prize separately sets `prizeClaimed`.
6. **Timeout / refund:** `Active|Drawing` -> `unsettledPot=0`, `remainingRefundLiability`, `Refunding` -> ticket burns and liability decrements -> prize return sets `prizeClaimed`.
7. **Empty raffle:** sponsor may enable refunds before end, or anyone at/after end; no quote liability; prize returns once.
8. **Independent releases:** sponsor and treasury claims clear and transfer in either order after settlement.

## Cohorts and trust boundaries

- Sponsor: escrows prize; owed 95% if reserve met, 15% plus prize if missed, or prize on refund.
- Current ticket owners: bearer claim holders; all get full refunds on timeout, exactly one gets the terminal prize.
- Buyer vs recipient: buyer pays, but recipient owns the claim immediately.
- Winning-ticket owner at redemption: receives prize even if different from purchaser or owner at draw time.
- Sponsor recipient and protocol treasury: immutable independent beneficiaries.
- Permissionless requester / settler / releaser: pays VRF fee or advances state but receives no protocol value except fee excess.
- Factory and Chainlink wrapper: trusted immutable plumbing; the wrapper alone authenticates callbacks.
- Prize contracts and ticket-recipient contracts: expressly untrusted external-call boundaries.
- Late/last actors: there is no pro-rata yield cohort; the critical last-user test is the last refund ticket or last terminal liability claimant.

No share/exchange-rate, lending/liquidation, reward-index, oracle-price, or cross-chain aggregate exists. Those lens sections should attack the analogous ticket-range, asynchronous callback, escrow, and terminal-liability boundaries rather than invent absent accounting.
