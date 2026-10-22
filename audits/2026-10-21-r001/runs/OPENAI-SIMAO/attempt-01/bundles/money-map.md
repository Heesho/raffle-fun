# Money map — raffle.fun

Target: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Named scope: Raffle.sol, RaffleFactory.sol, RaffleConstants.sol, IRaffle.sol, IRaffleFactory.sol, DESIGN.md.

## Vocabulary and trust
Buyers give 1,000,000 raw USDC per entry and receive one transferable ticket representing a contiguous inclusive entry range. No yield, lending, exchange rate, or cross-chain accounting exists. Exactly one selected entry determines the winning ticket. Current owner, not original buyer, holds refund/winner rights. Sponsor contributes one NFT. USDC and wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted under DESIGN.md. IRaffle NatSpec additionally describes honest standards-compliant supported prizes; examine this trust-boundary discrepancy explicitly rather than silently picking one interpretation.

## Assets and movements
| Asset | Inflow | Outflow |
|---|---|---|
| USDC | buyEntries pulls entryCount * ENTRY_PRICE from payer | redeemWinningTicket cash branch to current owner; refundTickets to current owners; releaseSponsorProceeds to fixed sponsorRecipient; releaseProtocolFees to fixed treasury |
| Prize ERC721 | factory createRaffle safe-transfers configured token/id from sponsor to clone; onERC721Received activates; factory verifies owner/status | redeemWinningTicket NFT branch to current owner; releaseSponsorPrize to fixed sponsorRecipient after CashWon/Refunding; ownership verified after transfer |
| Native currency | requestDraw msg.value | Chainlink request paidPrice; exact excess refunded to caller. Direct receive reverts; forced donations are not liabilities |
| Range ticket ERC721 | buyEntries mints sequential ticket after USDC pull | normal bearer transfers; redeemWinningTicket/refundTickets burn. Losing tickets remain historical collectibles with no claim |

## Tracked totals and all writers
| State | Writers / direction | Meaning |
|---|---|---|
| totalEntries | buyEntries +entryCount | lifetime entries; never decreases after burn |
| ticketCount | buyEntries +1 | lifetime ticket IDs, not live supply |
| unsettledPot | buyEntries +gross; enableRefunds =0 (-all); _settleWinningTicket =0 (-all) | unallocated paid entries |
| remainingRefundLiability | enableRefunds =old pot (+); refundTickets -burned entries*price | unredeemed full-refund claims |
| winnerProceeds | _settleWinningTicket CashWon =floor(gross*8000/10000) (+); redeemWinningTicket CashWon =0 (-all) | single winning ticket's cash claim |
| sponsorProceeds | _settleWinningTicket =gross-fee[-cash] (+); releaseSponsorProceeds =0 (-all) | fixed sponsor recipient's cash |
| protocolFees | _settleWinningTicket =floor(gross*500/10000) (+); releaseProtocolFees =0 (-all) | fixed treasury cash |
| raffleCount | factory createRaffle ++, reverted on creation failure | lifetime successful clones |
| _ticketRanges | buyEntries assigns first=old total+1,last=new total | immutable historical entry coverage |
| ERC721 balances/owners | inherited _update on mint/transfer/burn; balances +/-1, owners assigned/deleted | live ticket ownership, independent of historical counts |
| raffleById/idByRaffle/isRaffle | createRaffle assigns before NFT call; transaction rollback on failure | registry bijection and same-factory plumbing checks |

accountedQuoteBalance is the sum of all five current monetary liabilities; grossSales is totalEntries*price. Neither reads a live balance. NFT custody uses prizeClaimed, set before both NFT outflows and reverted if transfer/verification fails. Native funds have no persistent aggregate; request payment and refund are one transaction.

## Asymmetry table
| Tracked quantity | Value move / branch comparison | Assessment obligation |
|---|---|---|
| unsettledPot | cash/NFT settlement both zero pot; refund transition zeroes pot and credits refund liability | allocation sum must equal old pot |
| winnerProceeds | NFT branch never writes cash; cash branch credits then zeroes before payment | NFT outcome intentionally has no winner USDC claim |
| sponsorProceeds/protocolFees | both outcomes allocate; both independent releases zero before payment | every transfer failure must revert zeroing |
| refund liability | each ticket burn increases aggregate refund and reduces liability before transfer | duplicates/foreign/nonexistent IDs must revert entire batch |
| totalEntries/ticketCount/ranges | burns do not decrement lifetime aggregates or delete historical ranges | intentional history; terminal status and settlement flags must prevent stale ranges paying twice |
| actual USDC balance | direct donations are untracked and no sweep exists | cannot inflate claims; donate-only residual is not liability insolvency |
| native balance | forced native receipts untracked; request pays/refunds only own msg.value | no route to consume pre-existing native donation via inaccurate fee accounting |
| prizeClaimed | NFT win and sponsor return both set before transfer and verify reported owner | untrusted NFT truthfulness/liveness and reentrant calls require examination |
| registry | clone registered before untrusted prize transfer; callback sets Active before factory checks finish | all reentrant lifecycle effects must remain atomic and internally consistent |

## Invariants
1. Sum of five USDC liabilities <= actual clone USDC balance for trusted fee-free token; equality absent donations.
2. grossSales == totalEntries * 1,000,000; ticket ranges partition [1,totalEntries], no gaps/overlap.
3. totalEntries >= ticketCount, both lifetime monotone; no uint128 overflow succeeds.
4. Before terminal allocation/refunds, unsettledPot == grossSales; afterward it is zero exactly once.
5. NftWon allocation: sponsor+treasury == grossPot; CashWon: winner+sponsor+treasury == grossPot.
6. Refunding liability == sum(unburned refundable ticket entry counts)*ENTRY_PRICE; every credit debited once.
7. Only current ticket owner can redeem/refund; approved operators cannot claim unless current owner.
8. Failed payment or prize delivery rolls back burn, flags, and liability changes atomically.
9. Only wrapper-authenticated current request, one word, before callback deadline, outside request-in-flight resolves.
10. Draw window is [end,end+2days); callback window ends strictly at requestedAt+2days; at deadlines refund transition is possible.
11. Settlement is permissionless and storage-only, independent of winning owner's delivery behavior.
12. Prize disposition is exclusive: NFT winner OR sponsor in cash/refund result, never both.
13. Clone initialization is one-time factory-only; each clone's balances and claims are isolated.
14. Known protocol plumbing cannot own tickets/receive quote payouts; no cross-clone transfer by protocol paths.
15. Factory count/registry, exact prize escrow and Active status all succeed or all revert in one transaction.

## Lifecycles and touched state
- Create: validate params -> ++raffleCount -> clone -> initialize (initialized,sponsor,sponsorRecipient,treasury,prize,id,reserve,end,status AwaitingPrize) -> registry assigns -> NFT callback status Active -> final owner/status verification.
- Buy/transfer: quote pull -> totalEntries,ticketCount,ranges,unsettledPot increase -> inherited ticket owner/balance mint and receiver hook; ordinary transfer touches only ticket owners/balances/approval.
- Draw: after sale -> status Drawing,drawRequestedAt,_requestInFlight=true -> wrapper native payment -> vrfRequestId,_requestInFlight=false -> excess refund. Callback writes winningEntry,resolvedAt,status only.
- Settle NFT: validate winning range -> settlementComplete,winningTicketId,unsettledPot=0,sponsorProceeds,protocolFees. Redeem current owner -> winnerRecipient,winnerRedeemed,ticket burn,prizeClaimed -> NFT delivery+verification.
- Settle cash: same with winnerProceeds; redeem -> winnerRecipient,winnerRedeemed,ticket burn,winnerProceeds=0 -> USDC. Sponsor NFT return independent via prizeClaimed.
- Timeout/cancel: Active empty sponsor anytime/anyone after end; sold after request deadline; Drawing after callback deadline -> unsettledPot=0,remainingRefundLiability,status Refunding. Batches burn tickets and subtract liability. Prize return independent.
- Sponsor/treasury claims: corresponding liability=0 before fixed-recipient transfer; any caller triggers. No repeated settlement or refund outcome reversal.

## Cohorts and Last User Out baseline
Payer may differ from ticket recipient. Early/late ticket holders have equal per-entry odds and exact price refunds, no time accrual. Ticket transferees acquire all remaining bearer rights. NFT winner receives prize; cash winner 80% gross; sponsor 95% or 15% gross plus NFT returned for cash/refund; treasury 5% only successful results. Draw caller funds native oracle cost without compensation. No-entry sponsor gets NFT back; timed-out holders get 100% USDC. Under trusted transfer semantics, worst-order refund batches and independent cash claims should leave the last claimant fully backed and all liabilities zero. Malicious NFT/recipient effects, deadline boundaries, and permanent unreachable delivery remain specialist obligations.
