# Money Map — raffle.fun (`Raffle` ERC-1167 clone + `RaffleFactory`)

Scope: `Raffle.sol` (614 lines), `RaffleFactory.sol` (186), `IRaffle.sol` (521), `IRaffleFactory.sol` (150), `RaffleConstants.sol` (43). Spec: repo-root `DESIGN.md` (included at the top of `source.md`).

**Empty sections, stated up front:** there are NO shares or exchange rates, NO interest/index accrual, NO price oracles, NO liquidations, NO cross-chain messaging, NO owner/admin/pause/upgrade. The accounting is five USDC liability buckets plus one escrowed NFT per clone. Lenses whose home turf is absent (share-rate, liquidation, cross-chain) should map their lens onto the nearest analogue — the VRF request→callback is the only async two-step flow; the reserve threshold is the only outcome switch; the refund path is the only "withdraw" queue — and report nothing rather than force a finding.

## Plain-English model
- A sponsor (the `msg.sender` of `RaffleFactory::createRaffle`) escrows exactly one ERC-721 prize into a fresh clone. Buyers pay 1 USDC (1_000_000 raw units) per entry; each purchase mints ONE transferable ticket NFT covering a contiguous inclusive entry range `[firstEntry,lastEntry]`.
- After `endTime`, anyone may pay Chainlink VRF (in native ETH) to draw one entry. Reserve met (`totalEntries >= reserveEntries`) → `NftWon`: winner gets the NFT; 95% sponsorRecipient / 5% treasury. Reserve missed → `CashWon`: winner gets 80% of gross, sponsor 15% (remainder), treasury 5%, NFT goes back to sponsorRecipient.
- If nobody requests a draw within 2 days of `endTime`, or the callback misses its 2-day window, anyone flips the raffle to `Refunding`: each ticket burns for 100% of its entries and the NFT goes back to sponsorRecipient. An empty raffle can be closed by the sponsor any time, by anyone after `endTime`.
- Nobody earns yield. The only parties who can absorb a loss are: buyers (expected 20% haircut in `CashWon` vs. a refund), the draw requester (pays the VRF fee, never reimbursed), secondary-market counterparties of tickets, and whoever holds a claim that can never be collected (no sweep, no expiry, no admin).

## 1. Assets
| Asset | In | Out |
| --- | --- | --- |
| USDC `quoteToken` (trusted canonical; blacklistable/pausable) | `buyEntries` L224 `safeTransferFrom(msg.sender)`, gross = `entryCount * 1e6` | `redeemWinningTicket` L342 (CashWon → ticket owner), `refundTickets` L369 (→ caller = owner), `releaseSponsorProceeds` L380 (→ `sponsorRecipient`), `releaseProtocolFees` L390 (→ `protocolTreasury`). All via `_transferQuote` (destination-screened) |
| Prize ERC-721 (untrusted contract) | `RaffleFactory::createRaffle` L128 `prize.safeTransferFrom(sponsor, clone)` → `Raffle::onERC721Received` (status → Active) | `redeemWinningTicket` L334 (NftWon → ticket owner; `transferFrom` + `ownerOf` check), `releaseSponsorPrize` L404 (CashWon/Refunding → `sponsorRecipient`; `transferFrom` + `ownerOf` check). NOT destination-screened at release time |
| Native ETH | `requestDraw` `msg.value` | `paidPrice` → VRF wrapper (inside `requestRandomnessPayInNative`); `excess` → `msg.sender` via raw `call(gas())` L267. `receive()` reverts; force-sent ETH has no exit |
| Ticket ERC-721 (this clone's own collection) | minted in `buyEntries` (`_safeMint` → recipient callback) | burned in `refundTickets`, `redeemWinningTicket`. Transferable in EVERY status (DESIGN). `_update` screens `to` via `_isProtocolDestination` |
| Unsolicited USDC / NFTs / ETH | donations | none ("cannot be rescued"); never read by accounting — there is no `balanceOf(this)` anywhere |

## 2. Tracked totals (every writer)
| Variable | + / set | − / clear |
| --- | --- | --- |
| `unsettledPot` | `buyEntries` L233 `+= grossAmount` | `enableRefunds` L297 `= 0` (moved to refund bucket); `_settleWinningTicket` L553 `= 0` (split three ways) |
| `remainingRefundLiability` | `enableRefunds` L298 `= unsettledPot` | `refundTickets` L368 `-= entries * ENTRY_PRICE` |
| `winnerProceeds` | `_settleWinningTicket` L548 `= cashAmount` (CashWon only) | `redeemWinningTicket` L341 `= 0` (CashWon) |
| `sponsorProceeds` | `_settleWinningTicket` L554 `= grossPot - fee [- cash]` | `releaseSponsorProceeds` L378 `= 0` |
| `protocolFees` | `_settleWinningTicket` L555 `= floor(gross * 500 / 10000)` | `releaseProtocolFees` L388 `= 0` |
| `totalEntries` (lifetime; never decremented, not even on refund) | `buyEntries` L230 | — |
| `ticketCount` | `buyEntries` L231 | — |
| `_ticketRanges[id]` (historical, survives burn) | `buyEntries` L232 | — |
| `prizeClaimed` | `redeemWinningTicket` L331 (NftWon); `releaseSponsorPrize` L403 | — |
| `winnerRedeemed`, `winnerRecipient` | `redeemWinningTicket` L323-324 | — |
| `settlementComplete`, `winningTicketId` | `_settleWinningTicket` L551-552 | — |
| `status` | impl ctor → Refunding; `initialize` → AwaitingPrize; `onERC721Received` → Active; `requestDraw` → Drawing; `fulfillRandomWords` → NftWon/CashWon; `enableRefunds` → Refunding | — |
| `drawRequestedAt`, `vrfRequestId`, `_requestInFlight` | `requestDraw` L253-260 | — |
| `winningEntry`, `resolvedAt` | `fulfillRandomWords` L519-520 | — |
| Factory `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle` | `createRaffle` L105, L123-125 | — |

`accountedQuoteBalance()` = `unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees` (view only; never used to size a payout).

## 3. Asymmetry table
Orchestrator pass found NO USDC moved-without-tracking and NO one-branch-only write: every USDC outflow zeroes or decrements exactly its own bucket, and settlement splits `grossPot` exactly (`ENTRY_PRICE = 1e6`, so 5% = 50_000/entry and 80% = 800_000/entry — no rounding remainder exists for any entry count). Lenses: VERIFY this, do not assume it. The seams below are where drift-like shapes remain:

| Seam | Where | Shape |
| --- | --- | --- |
| Destination screening applied on some exits, not others | `_transferQuote` L565 and `_update` L498 call `_isProtocolDestination`; `releaseSponsorPrize` L404 and `redeemWinningTicket` L334 (NFT) do not; ETH excess L267 does not | screened in one branch only (DESIGN: "Never move assets between raffle clones") |
| Screening is a point-in-time check against a growing registry | `_isProtocolDestination` L602 skips `isRaffle` for code-less addresses; clones come from `Clones.clone` (CREATE → address predictable from factory nonce); `sponsorRecipient` validated only at `initialize`/factory | check-at-init vs. state-at-payout |
| Prize custody is "verified" only by the prize contract's own answers | factory L128-134 (`ownerOf`, clone `status`); raffle L335 / L405 (`ownerOf`); `onERC721Received` L421-424 trusts caller-supplied `operator`/`from` arguments | untrusted input faithfully propagated |
| Ticket transferability across `Drawing` → resolution | `fulfillRandomWords` result is computable from the pending fulfillment tx; tickets transferable in every status | mistimed snapshot / ordering |
| Draw initiation cost borne by one volunteer | `requestDraw` caller pays VRF in ETH, unreimbursed; draw vs. refund preference differs by cohort (holders prefer refund when reserve missed; sponsor/treasury prefer draw) | cohort incentive asymmetry |
| Refund/redeem require `msg.sender == ownerOf` (approved operators excluded) | L321, L360 | integration assumption |

## 4. Invariants
- I1 `quoteToken.balanceOf(clone) >= accountedQuoteBalance()` at all times (solvency; DESIGN "remainder must be allocated without loss").
- I2 Pre-terminal (Active / Drawing / NftWon / CashWon before settlement): `unsettledPot == totalEntries * ENTRY_PRICE`.
- I3 Refunding: `remainingRefundLiability == Σ_{unburned tickets} (lastEntry - firstEntry + 1) * ENTRY_PRICE`; the last refunder is paid in full and the bucket reaches exactly 0.
- I4 Settlement: `cash + sponsor + fee == grossPot`; fee = floor(5%); cash = floor(80%) in CashWon, 0 in NftWon; sponsor = remainder.
- I5 The prize NFT leaves exactly once, to exactly one party: NftWon → winning-ticket owner; CashWon/Refunding → `sponsorRecipient`.
- I6 Refund branch and win branch are mutually exclusive per clone.
- I7 Ticket ranges partition `[1, totalEntries]`; exactly one ticket contains `winningEntry ∈ [1, totalEntries]`.
- I8 Status is monotone: AwaitingPrize → Active → (Drawing → (NftWon | CashWon | Refunding)) | Refunding. No back-edges, no second request, no re-roll.
- I9 Time windows (DESIGN): buy `< endTime`; request `[endTime, endTime + 2d)`; callback `< drawRequestedAt + 2d`; refunds open exactly at the applicable deadline; empty raffle: sponsor any time, anyone `>= endTime`.
- I10 Only VRF determines the winner: no actor can choose, preview-and-react, censor-and-retry, or bias the drawn entry.
- I11 Claims are independent: sponsor, treasury, winner, and each refunder can each collect regardless of the others (blacklist, malicious receiver, malicious prize).
- I12 Assets never move between raffle clones; the factory never holds assets.
- I13 Redemption: only the current ticket owner; burn is atomic with delivery; any delivery failure reverts everything.
- I14 Each clone is initialized once, only by the factory, and becomes Active only by receiving its exact configured prize from the sponsor via the factory.

## 5. Lifecycles (state touched per step)
- L1 Create: factory `_validateCreateParams` → `++raffleCount` → `Clones.clone` → `initialize` (sponsor, sponsorRecipient, treasury, prizeToken/Id, raffleId, reserveEntries, endTime; status = AwaitingPrize) → register `raffleById` / `idByRaffle` / `isRaffle` → `prize.safeTransferFrom(sponsor, clone)` → `onERC721Received` (status = Active) → factory checks `ownerOf` and clone `status`.
- L2 Buy: `buyEntries` (USDC in; `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`; `_safeMint` → recipient callback).
- L3 Draw: `requestDraw` (status = Drawing, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId`; ETH to wrapper, excess to caller) → wrapper `rawFulfillRandomWords` → `fulfillRandomWords` (`winningEntry`, `resolvedAt`, status = NftWon | CashWon) or ignored (emit only; the wrapper has already consumed the request — no retry).
- L4 NftWon: `settleWinningTicket` (anyone; `unsettledPot` → `sponsorProceeds`, `protocolFees`; `settlementComplete`, `winningTicketId`) → `redeemWinningTicket` (owner; `winnerRecipient`, `winnerRedeemed`, burn, `prizeClaimed`, NFT out); `releaseSponsorProceeds`, `releaseProtocolFees` (anyone, independent).
- L5 CashWon: settle (also `winnerProceeds`) → redeem (USDC out); `releaseSponsorPrize` (NFT → sponsorRecipient); releases.
- L6 Refund: `enableRefunds` (`unsettledPot` → `remainingRefundLiability`, status = Refunding) → `refundTickets` batches of ≤100 (burn, USDC out); `releaseSponsorPrize`.
- L7 Empty raffle: sponsor `enableRefunds` any time (anyone at `>= endTime`) → `releaseSponsorPrize`.
- L8 Secondary market: ticket `transferFrom` / `safeTransferFrom` in any status (no status guard; only `_update` screening).

## 6. Cohorts and what each is owed
| Actor | Gives | Owed / powers |
| --- | --- | --- |
| Sponsor (creator) | prize NFT, gas | via `sponsorRecipient`: 95% gross (NftWon) / 15% + NFT (CashWon) / NFT (Refunding, empty). Power: close an empty raffle early |
| `sponsorRecipient` (fixed per clone) | — | sponsor's USDC and the returned NFT |
| `protocolTreasury` (immutable in factory, shared by every clone) | — | 5% gross in NftWon/CashWon; 0 on refund |
| Buyer / ticket holder (bearer) | 1 USDC per entry | 100% back on refund; otherwise a chance at the NFT or 80% of the pot |
| Winner (owner of the winning ticket at redemption) | burns the ticket | NFT (NftWon) or 80% gross (CashWon) |
| Draw requester (anyone) | VRF fee in ETH | excess ETH back; nothing else |
| Settler / releaser / refund-enabler (anyone) | gas | nothing |
| Secondary-market counterparties | price paid for a ticket | the claim the ticket represented when they traded |
| Untrusted: prize contract, ticket-recipient contracts, ETH-refund recipient | — | — |
| Trusted: USDC, Chainlink VRF v2.5 wrapper/coordinator | — | — |

## 7. External calls and reentrancy surface
- `nonReentrant`: `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`; factory `createRaffle`. (OZ 5.6.1 guard uses an ERC-7201 slot; clone starts at 0 ≠ ENTERED, so it works without a constructor.)
- Unguarded: ticket `transferFrom` / `safeTransferFrom` / `approve` / `setApprovalForAll`, `onERC721Received`, `rawFulfillRandomWords` (wrapper-only), inherited `getBalance` / `getLinkToken`, views.
- Untrusted callouts: prize `transferFrom` / `ownerOf` / `safeTransferFrom` / `supportsInterface`; recipient `onERC721Received` (`_safeMint`, ticket `safeTransferFrom`); requester ETH `call(gas())` (after `vrfRequestId` is set, before the event). Factory views `raffleImplementation()` / `isRaffle()` are called from every `_update` and `_transferQuote`.
- Constants: ENTRY_PRICE 1e6; fee 500 bps; cash 8000 bps; refund batch ≤ 100 tickets; sale ≤ 30 d; request window 2 d; callback window 2 d; callback gas 300k; 30 confirmations.
- Dependency sources present under `packages/contracts/node_modules/` (OZ 5.6.1, Chainlink 1.5.0 `VRFV2PlusWrapperConsumerBase`, `IVRFV2PlusWrapper`). The wrapper implementation itself is not vendored — reason from the trusted canonical VRF v2.5 wrapper.
