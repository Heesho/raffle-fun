# Money Map — raffle.fun (Raffle clone + RaffleFactory)

Built by the orchestrator from `DESIGN.md` (clean spec) plus source. Line numbers are `Raffle.sol` unless prefixed `F:` (`RaffleFactory.sol`) or `I:` (`IRaffle.sol`).
Empty / N/A surfaces: no shares, exchange rate, index, interest, yield, liquidation, oracle price, or cross-chain message. The only accrual is the fixed-price pot, split once by constant BPS. The async VRF request/callback pair is the only two-phase message. Lenses whose primary surface does not exist here should work the closest analogue named below rather than hunt totals that do not exist.

## 1. Assets

| Asset | Enters via | Leaves via |
| --- | --- | --- |
| USDC (`quoteToken`, trusted, 6 dp) | `buyEntries` `safeTransferFrom(msg.sender, this, entryCount*1e6)` :224 | `refundTickets` :369 (to ticket owner), `redeemWinningTicket` CashWon :342 (to winner), `releaseSponsorProceeds` :380 (to `sponsorRecipient`), `releaseProtocolFees` :390 (to `protocolTreasury`). All via `_transferQuote` :564, which screens `_isProtocolDestination` :593. |
| Prize ERC-721 (untrusted contract per DESIGN.md) | `F:createRaffle` `prize.safeTransferFrom(sponsor, raffle, id)` F:128 → `onERC721Received` :416 flips `AwaitingPrize→Active` :428; factory verifies `ownerOf` F:129 and `status()==Active` F:132 | `redeemWinningTicket` NftWon `transferFrom(this, winner, id)` :334 + `ownerOf` check :335; `releaseSponsorPrize` (CashWon or Refunding) :404 + check :405 |
| Native ETH | `requestDraw` `msg.value` :240 (`receive()` reverts :171) | wrapper fee `requestRandomWordsInNative{value: requestPrice}` (consumer base) via :257; excess `call` to `msg.sender` :267 |
| Ticket ERC-721 (this contract) | minted in `buyEntries` `_safeMint` :235 (one ticket per purchase, range `[first,last]`) | burned in `refundTickets` :364 or `redeemWinningTicket` :325; freely transferable in every state, screened by `_update` :497 |

Untracked: USDC sent directly to a clone, ETH forced via selfdestruct, NFTs sent with unsafe `transferFrom` (NatSpec :410). No sweep exists; surplus is stuck by design.

## 2. Tracked totals (every writer)

| Variable | Writes (+ / − / =) |
| --- | --- |
| `unsettledPot` | `+= grossAmount` buyEntries :233 · `= 0` enableRefunds :297 (moved to `remainingRefundLiability`) · `= 0` `_settleWinningTicket` :553 (split into the three claims) |
| `remainingRefundLiability` | `= unsettledPot` enableRefunds :298 · `-= amount` refundTickets :368 |
| `winnerProceeds` | `= cashAmount` `_settleWinningTicket` CashWon branch only :548 · `= 0` redeem CashWon branch :341 |
| `sponsorProceeds` | `= sponsorAmount` `_settleWinningTicket` :554 · `= 0` releaseSponsorProceeds :378 |
| `protocolFees` | `= protocolFee` `_settleWinningTicket` :555 · `= 0` releaseProtocolFees :388 |
| `accountedQuoteBalance()` :468 | view = sum of the five above |
| `totalEntries` (uint128) | `= lastEntry` buyEntries :230 only (lifetime; never decremented by refunds/burns) |
| `ticketCount` (uint128) | `++` buyEntries :231 only |
| `_ticketRanges[id]` | set buyEntries :232; never cleared (historical after burn, :138) |
| flags | `settlementComplete` :551 · `winningTicketId` :552 · `winnerRedeemed` :324 · `winnerRecipient` :323 · `prizeClaimed` :331 / :403 — all set-once, never reset |
| VRF state | `status=Drawing` :252 · `drawRequestedAt` :253 · `_requestInFlight` :254/:260 · `vrfRequestId` :259 · `winningEntry` :519 · `resolvedAt` :520 · `status=NftWon/CashWon` :521 |
| `status` | ctor `Refunding` :165 (implementation lock) · init `AwaitingPrize` :205 · `Active` :428 · `Drawing` :252 · `NftWon/CashWon` :521 · `Refunding` :299 |
| Factory | `raffleCount` F:105 · `raffleById` F:123 · `idByRaffle` F:124 · `isRaffle` F:125 (set BEFORE the prize transfer F:128) |

Split math (`_settleWinningTicket` :539-555): `fee = mulDiv(pot,500,1e4)`; NftWon `sponsor = pot - fee`; CashWon `cash = mulDiv(pot,8000,1e4)`, `sponsor = pot - fee - cash`. Because `pot` is always a multiple of 1e6, all three are exact (no dust) — verify, do not assume.

## 3. Asymmetry table

| Total | Candidate asymmetry to attack | Orchestrator note |
| --- | --- | --- |
| `unsettledPot` | Inflow :224 vs `+=` :233 — same amount? Both exits zero it fully | No asymmetry seen; check every path that can reach a terminal state without passing either exit |
| `remainingRefundLiability` | `-=` :368 must equal Σ burned ranges × price; underflow would brick last refunder | Holds only if no ticket range is refunded twice / no ticket burned elsewhere first |
| `winnerProceeds` | written only in CashWon branch :548; zeroed only in CashWon redeem :341 | NftWon writes nothing (intended 0) |
| **Cross-asset coupling** | NftWon: `sponsorProceeds` (95%) becomes claimable at settlement :554 and is released :375 with NO dependency on the NFT leg :334 ever succeeding. CashWon/Refunding: prize leg :404 independent of USDC legs | No state converts an undeliverable NFT into cash/refund. DESIGN.md: "arbitrary prize contracts … are untrusted"; I:14-15 says "Supported prizes are honest, standards-compliant ERC-721s" — conflicting trust statements |
| Ticket screen vs payout screen | `_update` :498 screens recipients when a ticket moves; `_transferQuote` :565 re-screens at payout. `isRaffle` is only queried when `code.length != 0` :602 | Time-of-check vs time-of-use: a destination that is safe at transfer may be "unsafe" at payout (and vice-versa) |
| Native ETH | `msg.value` in, `requestPrice` + excess out; forced ETH unaccounted | `paidPrice` and `quotedFee` both computed from `tx.gasprice` in the same tx |

## 4. Invariants (D = from DESIGN.md, C = derived from code)

1. C: `USDC.balanceOf(raffle) >= accountedQuoteBalance()` at every step (solvency).
2. C: pre-terminal, `unsettledPot == totalEntries * 1e6 == Σ tickets (last-first+1) * 1e6`.
3. C: in Refunding, `remainingRefundLiability == Σ unburned tickets × 1e6`; the last refunder is paid in full.
4. D: NftWon → NFT to winner, 95% sponsor / 5% treasury. CashWon → 80% gross to winner, 15% sponsor, 5% treasury. Refunding → 100% per entry + prize returned.
5. D: fee floors on the aggregate; remainder allocated without loss (`cash + sponsor + fee == pot`).
6. C: ranges are contiguous, disjoint, cover `[1,totalEntries]`; exactly one ticket contains `winningEntry ∈ [1,totalEntries]`, and that ticket exists unburned at settlement.
7. D/C: the prize leaves exactly once — to the winner iff NftWon, to `sponsorRecipient` iff CashWon or Refunding.
8. C: each ticket is paid at most once (refund XOR winning redemption).
9. C: status is monotone `AwaitingPrize→Active→[Drawing→]{NftWon|CashWon|Refunding}`; terminal states never change; NftWon/CashWon can never reach Refunding.
10. D: request window `[endTime, endTime+2d)`; callback accepted strictly before `drawRequestedAt+2d`; refunds open at the deadline — callback and refund windows are disjoint.
11. D: callback records the result only; settlement is permissionless and storage-only.
12. D: redemption requires the CURRENT ticket owner, burns atomically, and reverts all effects on delivery failure.
13. D: sponsor and treasury claim independently after settlement.
14. D: never move assets between raffle clones; payouts never land on protocol plumbing.
15. C (liveness): every party with a claim (refunder, winner, sponsorRecipient, treasury) can always eventually collect it; no reachable state strands USDC or the NFT for its rightful owner.

## 5. Lifecycles (state touched per step)

- **L1 Create**: `F:createRaffle` → `F:_validateCreateParams` (prize code, ERC-165, recipient screen, `reserveEntries>0`) → `Clones.clone` → `initialize` (sponsor, recipient, treasury, prize, id, reserve, endTime; `AwaitingPrize`) → `raffleById/idByRaffle/isRaffle` → `prize.safeTransferFrom` (untrusted code runs) → `onERC721Received` (`Active`) → `ownerOf` + `status` checks.
- **L2 Sale** `[create, endTime)`: `buyEntries` → USDC in, `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`, `_safeMint` (recipient code runs, `nonReentrant`).
- **L3 Draw OK**: `requestDraw` (`Drawing`, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId`, ETH out + excess refund call) → wrapper `rawFulfillRandomWords` → `fulfillRandomWords` (`winningEntry`, `resolvedAt`, `NftWon|CashWon`) → `settleWinningTicket` (split, `unsettledPot=0`) → `redeemWinningTicket` (burn; NFT or cash) → `releaseSponsorProceeds` / `releaseProtocolFees` → CashWon: `releaseSponsorPrize`.
- **L4 Draw fails**: `requestDraw` → no / late / ignored callback → `enableRefunds` (Drawing branch, ≥ `callbackDeadline()`) → `refundTickets`×k → `releaseSponsorPrize`.
- **L5 No draw**: sold raffle, nobody calls `requestDraw` in 2 days → `enableRefunds` (Active branch, ≥ `drawRequestDeadline()`) → refunds → prize back.
- **L6 Empty**: `totalEntries==0` → sponsor `enableRefunds` any time, anyone after `endTime` → `releaseSponsorPrize`.
- **L7 Ticket market**: transfer in any state via `_update` screen; whoever owns at redeem/refund time is paid; approved operators cannot redeem/refund (owner-only :321, :360).
- **L8 Redeem-with-settle**: `redeemWinningTicket` on an unsettled raffle calls `_settleWinningTicket` itself :315.

## 6. Cohorts (who is owed what)

- **Sponsor** (`msg.sender` of `createRaffle`): escrows the NFT; may cancel an empty raffle early; may also buy entries (can move `totalEntries` across `reserveEntries`).
- **sponsorRecipient** (immutable): `sponsorProceeds` + returned NFT.
- **Protocol treasury** (factory immutable): 5% fee on any settled outcome; 0 on refunds.
- **Buyers / ticket holders**: pay `n × 1e6`; owed 100% back in Refunding; otherwise only the winner is owed.
- **Winner** = owner of the winning ticket at redemption: NFT (NftWon) or 80% of pot (CashWon). No redemption deadline.
- **Last buyer before `endTime`**: knows `totalEntries` and decides whether the reserve is met.
- **Draw requester** (anyone): pays the native VRF fee, never reimbursed. **Settler / releaser** (anyone): unpaid.
- **Trusted**: USDC, Chainlink VRF v2.5 native wrapper. **Untrusted** (DESIGN.md): prize contract (gets control at F:128, F:129, :334-335, :404-405), ticket recipients (`_safeMint` :235, ticket `safeTransferFrom`), excess-ETH refund recipient :267.
- **Not `nonReentrant`**: ERC-721 ticket `transferFrom/safeTransferFrom/approve/setApprovalForAll`, `onERC721Received`, `initialize`, `rawFulfillRandomWords`, views. Every other state-changing raffle function is `nonReentrant`; `F:createRaffle` is `nonReentrant` on the factory only.

## 7. Timing table (exclusive upper bounds)

| Action | Allowed when |
| --- | --- |
| `buyEntries` | `Active` and `now < endTime` :216 |
| `requestDraw` | `Active`, `now >= endTime`, `totalEntries>0`, `now < endTime+2d` :241-247 |
| callback resolves | `Drawing`, matching id, 1 word, not in-flight, `now < drawRequestedAt+2d` :510-513 |
| `enableRefunds` | Active+sold: `now >= endTime+2d`; Drawing: `now >= drawRequestedAt+2d`; Active+empty: sponsor any time, others `now >= endTime` :279-294 |
| settle / redeem | `NftWon` or `CashWon`, no deadline |
| `releaseSponsorPrize` | `CashWon` or `Refunding`, once |
