# raffle.fun — documented security properties (skill Step 4)

Derived independently in this session from the five production files (`src/Raffle.sol`, `src/RaffleFactory.sol`,
`src/interfaces/IRaffle.sol`, `src/interfaces/IRaffleFactory.sol`, `src/libraries/RaffleConstants.sol`), their reachable
dependencies (OZ 5.6.1, Chainlink 1.5.0 VRF v2.5 wrapper consumer) and `DESIGN.md`. Each property lists where it is
exercised. Legend: **E** = Echidna property/assertion harness (`props/RaffleProperties.sol`), **M** = Medusa (same
harness), **F** = Foundry scenario/fuzz test (`props/foundry/*.t.sol`), **H** = Halmos symbolic check
(`props/halmos/RaffleSymbolic.t.sol`), **S** = custom Slither API check (`_generated/slither-custom/raffle_custom_checks.py`).
All test code is GENERATED SCRATCH CODE under `_generated/` and runs against byte-identical copies of the production
sources. Final outcomes (bounded): E/M/F/S all passing; H passing for every check except the two marked TIMEOUT
(solver unknown, no counterexample) — see TOB-S6-secure-workflow-guide.md §4.3.

## 1. State machine

`AwaitingPrize(0) → Active(1) → {Drawing(2) | Refunding(5)}`, `Drawing → {NftWon(3) | CashWon(4) | Refunding(5)}`;
`NftWon`, `CashWon`, `Refunding` are absorbing. The implementation is born `Refunding` + `initialized` (inert).

| ID | Property | Source anchor | Tested by |
|---|---|---|---|
| SM-1 | Only the transitions above occur; terminal states never change. | Raffle.sol:205,252,299,428,521 | E (`_afterAction` transition check), M, S (C4) |
| SM-2 | A clone is initialized exactly once, only by the factory; the implementation can never be initialized. | Raffle.sol:164-165,177-179 | E (`attackInitialize`), F (`test_implementation_is_locked_and_inert`), S (C3) |
| SM-3 | After `createRaffle` returns, the clone is registered, `Active`, and holds the prize (atomic escrow). | RaffleFactory.sol:105-134 | E (`createRaffle` postconditions), S (C10) |
| SM-4 | Entries can be bought only while `Active` and `block.timestamp < endTime`. | Raffle.sol:215-216 | E/M (`buy` expected-outcome) |
| SM-5 | `requestDraw` succeeds iff `Active ∧ totalEntries>0 ∧ endTime ≤ now < endTime+2d ∧ msg.value ≥ quote`; at most one request per raffle. | Raffle.sol:241-251 | E/M, F (`test_timingWindows…`), H (`check_requestDraw_iff_inside_window`) |
| SM-6 | A callback resolves iff `Drawing ∧ id==vrfRequestId ∧ len==1 ∧ now < drawRequestedAt+2d ∧ ¬inFlight`; otherwise it is a no-op that does not revert. | Raffle.sol:510-516 | E/M (`fulfill` modes), F (`test_vrf_unexpected_inputs…`, `test_syncCallback…`), H (`check_callback_window…`) |
| SM-7 | `enableRefunds` succeeds iff (Active ∧ empty ∧ (sender==sponsor ∨ now ≥ endTime)) ∨ (Active ∧ sold ∧ now ≥ endTime+2d) ∨ (Drawing ∧ now ≥ drawRequestedAt+2d). | Raffle.sol:279-294 | E/M, F, H (`check_enableRefunds_*`) |
| SM-8 | Windows are disjoint: no instant where both `requestDraw` and sold-raffle `enableRefunds` succeed, nor both callback resolution and Drawing-refunds. | Raffle.sol:245,287,291,512 | F (`test_timingWindows_disjoint_at_every_boundary`), H |
| SM-9 | Resolution: `winningEntry ∈ [1,totalEntries]`, `NftWon ⇔ totalEntries ≥ reserveEntries`, `resolvedAt < drawRequestedAt+2d`. | Raffle.sol:518-521 | E (`echidna_resolution_well_formed`), H (`check_winning_entry_in_range`) |
| SM-10 | Settlement happens at most once, only in NftWon/CashWon, only for the ticket whose range contains `winningEntry`. | Raffle.sol:533-538,579-585 | E/M (`settle`), S (C6) |
| SM-11 | Redemption at most once, only by the current owner of the winning ticket, burning it; failure reverts everything (incl. settle-on-redeem). | Raffle.sol:309-346 | E/M (`redeem`), F, H (`check_redeem_only_current_owner`) |
| SM-12 | The prize is released at most once: to the redeemer in NftWon; to `sponsorRecipient` in CashWon/Refunding; never in Active/Drawing. | Raffle.sol:329-337,395-407 | E (`echidna_prize_custody`), S (C7) |

## 2. Accounting (quote token, six-decimal USDC)

| ID | Property | Source anchor | Tested by |
|---|---|---|---|
| A-1 | Solvency, exact: `USDC.balanceOf(raffle) == accountedQuoteBalance() + unsolicited donations` (accounting never reads balances). | Raffle.sol:468-470 | E (`echidna_solvency_and_conservation`, with a `donate` action) |
| A-2 | Conservation: `paidOut(raffle) + accountedQuoteBalance() == grossSales() == totalEntries × 1e6`. | Raffle.sol:223-233,473-475 | E, M |
| A-3 | Active/Drawing: `unsettledPot == grossSales`, all other buckets 0. | Raffle.sol:233 | E (`echidna_status_bucket_shape`) |
| A-4 | Refunding: `unsettledPot == 0` and `remainingRefundLiability == 1e6 × Σ entries of live tickets`. | Raffle.sol:296-299,368 | E (`echidna_refund_liability_matches_live_tickets`), F, H (`check_refund_conservation` — **TIMEOUT, undecided**) |
| A-5 | Split exactness: fee = ⌊5%⌋, NftWon sponsor = gross−fee, CashWon cash = ⌊80%⌋ and sponsor = remainder; fee+cash+sponsor == gross. With 1e6-unit entries all splits are exact (no rounding residue). | Raffle.sol:539-555, RaffleConstants.sol:15-21 | E/M (`_checkSplit`), F (`testFuzz_settlementSplitExact_fullDomain`, 2000 runs over uint128), H (`check_split_exact_symbolic_entries` — **TIMEOUT, undecided**; z3 re-solve also timed out) |
| A-6 | NftWon/CashWon: before settlement `unsettledPot == grossSales`; after settlement `unsettledPot == 0`; refund liability always 0. | Raffle.sol:551-555 | E |
| A-7 | Refund amount == 1e6 × Σ(last−first+1) of the batch; never underflows the liability; duplicates/foreign/nonexistent IDs revert the batch. | Raffle.sol:349-372 | E/M (`refund` with corruption modes), F, H |
| A-8 | USDC leaves a raffle only to: `sponsorRecipient`, `protocolTreasury`, the authenticated winning-ticket owner, or authenticated refunding owners. | Raffle.sol:342,369,380,390 | S (C2, C12), E |
| A-9 | No USDC transfer to protocol plumbing (self, factory, implementation, quote token, wrapper, prize token, registered raffles with code). | Raffle.sol:564-567,593-605 | S (C2), F (`test_F4b…` shows the runtime screen) |

## 3. Ticket ledger (ERC-721 + ranges)

| ID | Property | Source anchor | Tested by |
|---|---|---|---|
| T-1 | Ticket IDs are 1..ticketCount; ranges are contiguous, ordered, non-overlapping and cover exactly `[1,totalEntries]`. | Raffle.sol:226-232 | E (`echidna_ticket_ranges_partition`) |
| T-2 | Ranges are immutable history (unchanged after burn); unminted IDs read `(0,0)`. | Raffle.sol:138-139,451-455 | E |
| T-3 | Live tickets are never owned by protocol plumbing. | Raffle.sol:497-502 | E (`transferTicket` destModes, `echidna_no_ticket_owned_by_protocol`), H (`check_ticket_transfer_destination_screen`), S (C8) |
| T-4 | Burned tickets cannot be refunded or redeemed again. | Raffle.sol:325,364 | E/M, H |
| T-5 | `entryCount > 0`; `totalEntries ≤ 2^128−1` (overflow reverts). | Raffle.sol:218-221 | E (`buyHuge`), F |

## 4. Access control

| ID | Property | Source anchor | Tested by |
|---|---|---|---|
| AC-1 | `initialize`: factory only, once. | Raffle.sol:176-179 | E, F, S |
| AC-2 | `rawFulfillRandomWords`: VRF wrapper only. | VRFV2PlusWrapperConsumerBase.sol:101-107 | E (`attackDirectFulfill`), F |
| AC-3 | `onERC721Received`: only the exact configured prize, from the sponsor, operated by the factory, in AwaitingPrize. | Raffle.sol:416-431 | E (`attackSpoofPrizeHook`), F (`test_F3…` shows the trust boundary) |
| AC-4 | Redemption/refund only by current ticket owners. | Raffle.sol:320-321,359-360 | E/M, H |
| AC-5 | The sponsor's only privilege is closing an empty Active raffle early. | Raffle.sol:280-284 | F (`test_emptyRaffle…`), H (`check_enableRefunds_empty`) |
| AC-6 | Factory: no owner/admin; `createRaffle` permissionless; the prize is always pulled from `msg.sender`. | RaffleFactory.sol:97-148 | F (`test_factory_rejects…`) |
| AC-7 | No function changes price, fee rates, timing constants, treasury, implementation, quote token or wrapper. | RaffleConstants.sol; immutables | S (vars-and-auth, C3) |

## 5. Arithmetic

| ID | Property | Tested by |
|---|---|---|
| AR-1 | No overflow anywhere in the uint128 entry domain (gross ≤ (2^128−1)×1e6 < 2^256; mulDiv takes the high==0 path). | F (full-domain fuzz), H (symbolic entries), E (`buyHuge`) |
| AR-2 | Deadlines computed in uint256 (no uint64 wraparound). | Source review (Raffle.sol:459,464) |
| AR-3 | `uint128((word % total) + 1)` is lossless and in range. | E, H |
| AR-4 | `uint64(block.timestamp)` casts are lossless for realistic timestamps. | Source review |

## 6. External interactions

| ID | Property | Tested by |
|---|---|---|
| EI-1 | Every value-moving entry point is `nonReentrant`; callbacks to untrusted code happen after state updates. | S (C1, C10), Slither reentrancy detectors (triaged) |
| EI-2 | Prize delivery is verified via `ownerOf` after `transferFrom`; any delivery failure reverts all effects. | E/M, F (`test_F2…` shows the revert-all behavior) |
| EI-3 | Authenticated, ABI-decodable callbacks never revert and use ≪ 300k gas. | E/M (`fulfill`, gas < 120k), F, H, S (C5) |
| EI-4 | Only `requestDraw` accepts ETH; excess is refunded atomically; raffles retain no ETH. | E (`echidna_no_eth_and_inert_implementation`, `attackDirectEth`), F |
| EI-5 | USDC handled through SafeERC20; the canonical-USDC trust assumption (non-fee-on-transfer, non-rebasing) is explicit. | Source/DESIGN review |

## 7. Standards conformance

| ID | Property | Tested by |
|---|---|---|
| ST-1 | ERC-721 (+Metadata) and ERC-165 conformance of the ticket. | `slither-check-erc` (ERC721, ERC165): all checks pass |
| ST-2 | `onERC721Received` returns the selector only for the expected deposit; all else reverts. | E, F |
| ST-3 | `name()`/`symbol()` are constant across clones; `tokenURI` is empty (no metadata). | Source review (Raffle.sol:479-487) |
