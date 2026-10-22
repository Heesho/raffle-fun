# raffle.fun audit r001: supplementary whole-system security review

**Lane:** Anthropic provider, CLAUDE-SUP. Independent, source-only cold review, separate from the harness cells.
**Date:** 2026-10-21. **Reviewer:** Claude (Opus 5.5).
**Spec:** `DESIGN.md` (clean specification). Source decides actual behaviour.
**Scope (each file read in full):** `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`. I also read every reachable dependency present under `packages/contracts/node_modules`:
- OpenZeppelin 5.6.1: `ERC721`, `ERC721Utils`, `ReentrancyGuard`, `StorageSlot`, `SafeERC20`, `Clones`, `Math`.
- Chainlink 1.5.0: `VRFV2PlusWrapperConsumerBase`, `IVRFV2PlusWrapper`, `VRFV2PlusClient`.

Nothing outside the working directory was read. Nothing in `packages/` was changed. All scratch work is in `./sup-notes/`.

---

## 0. Executive summary

| Class | Count | IDs |
|---|---|---|
| Critical / High / Medium defects | **0** | none |
| Confirmed Low defects | 1 | SUP-01 |
| Confirmed Informational defects | 1 | SUP-02 |
| Configuration / integration risks | 5 | SUP-03 to SUP-07 |
| Unresolved leads | 3 | LEAD-1 to LEAD-3 |

- **Core invariants hold.** This covers custody and solvency, exact splits, no double claim, ticket-range coverage and uniform winner selection, one-shot guards, factory-clone binding, bounded exits, VRF filtering, reentrancy across ERC-721 hooks, and cross-clone isolation of liabilities. Each holds by reasoning, and each survived executable tests: **27 tests pass**, including a stateful multi-actor random walk run 512 + 3,000 times (two seeds) and a 150-seed coverage sweep (§10).
- **Every timing comparison matches DESIGN.md exactly.** That includes each `<`/`>=` at the request, callback and refund edges. There is no gap and no overlap between windows (§2.5).
- **SUP-01 (Low, confirmed by PoC).** Assume a sponsor sets `sponsorRecipient` to the address a future clone will occupy (clone addresses are predictable because clones use CREATE). Returning the prize then moves the NFT *into another raffle clone*, which breaks the DESIGN rule "Never move assets between raffle clones". The sponsor's USDC share is also stranded for good. Only the sponsor's own assets are affected.
- **SUP-02 (Informational, confirmed by PoC).** A deployer who sets the treasury to a future clone address bricks `createRaffle` permanently.
- **Main integration risk: SUP-03.** Prize escrow is verified only through `ownerOf`. A non-compliant or malicious prize can therefore leave escrow or become undeliverable, and NftWon deliberately has no fallback. A PoC shows the sponsor collecting 95% while the winner can never redeem. The USDC paths are never affected.

---

## 1. Inputs, integrity, environment

- **Scope file hashes:** recorded in `sup-notes/scope-sha256.txt`, e.g. Raffle.sol `6e4c9779…8617`, RaffleFactory.sol `d0e62b34…2ace`.
- **Dependency hashes:** all 31 entries in `dependency-hashes.json` match the files on disk (sha256 checked before and after the build).
- **Compiler:** solc 0.8.36, cancun, optimizer 200, `via_ir=false`, matching `packages/contracts/foundry.toml`. Builds clean.
- **Sizes:** Raffle runtime 15,947 B (EIP-170 limit 24,576). Factory initcode 21,870 B (EIP-3860 limit 49,152).
- **Harness:** a self-contained Foundry project under `sup-notes/poc/`. It has no forge-std; it declares its own cheatcode interface and remaps read-only into `packages/`. The mocks stand in for the trusted dependencies:
  - a 6-decimal USDC with a blacklist;
  - a behavioural VRF v2.5 wrapper: prices from `tx.gasprice`, checks the native-payment flag in extraArgs, deletes the callback before fulfilling, calls back with exact gas, swallows consumer failures, and has an optional synchronous-callback mode.

---

## 2. System map

### 2.1 Components and trust

| Component | Trust (per DESIGN) | Notes |
|---|---|---|
| `RaffleFactory` | system | Ownerless; immutables: quote token, wrapper, treasury, implementation. Registry: `isRaffle`, `raffleById`, `idByRaffle`. |
| `Raffle` implementation | system | Deployed by the factory constructor. Locked: `initialized=true`, `status=Refunding` (Raffle.sol:164-165). |
| `Raffle` clones (ERC-1167, CREATE) | system | Per-raffle storage. Immutables (`factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `i_linkToken`) live in the implementation bytecode. The ReentrancyGuard slot starts at 0 in a clone, and OZ 5.x treats 0 as "not entered". |
| USDC | trusted canonical | Standard, non-rebasing, fee-free. Identity is not provable on-chain. |
| VRF v2.5 wrapper (native payment) | trusted canonical | Sole caller of `rawFulfillRandomWords`. |
| Prize ERC-721 | **untrusted** | Called at creation, redemption and return. |
| Ticket recipients / holders, ETH refund recipient | **untrusted** | Reached through `_safeMint`/`safeTransferFrom` hooks and the native refund call. |

### 2.2 Authority graph

| Entry point | Caller | Gate | Effect |
|---|---|---|---|
| `RaffleFactory.constructor` | deployer | quote has code and `decimals()==6`; wrapper has code; treasury ≠ 0, self, quote, wrapper, implementation | deploys the locked implementation |
| `createRaffle` | anyone (becomes `sponsor`) | prize has code and `supportsInterface(0x80ac58cd)`; recipient ≠ 0 and not plumbing; `reserve ≥ 1`; `now < end ≤ now+30d`; `nonReentrant` | clone → `initialize` → register → `prize.safeTransferFrom(sponsor→clone)` → require `ownerOf==clone` and `status()==Active` |
| `Raffle.initialize` | factory only, once | `!initialized`; `msg.sender==factory` | writes config; status AwaitingPrize |
| `onERC721Received` | prize contract only | AwaitingPrize, `tokenId==prizeTokenId`, `from==sponsor`, `operator==factory` | status Active |
| `buyEntries` | anyone (payer is `msg.sender`) | Active, `t<end`, `n>0`, no uint128 overflow, recipient ≠ 0 and not plumbing | pulls `n·1e6` USDC; mints ticket `[T+1, T+n]` |
| `requestDraw` | anyone; pays ETH | Active, `end ≤ t < end+2d`, entries > 0, `msg.value ≥ quote` | Drawing; one wrapper request; excess ETH returned |
| `rawFulfillRandomWords` | wrapper only | filters in `fulfillRandomWords` | NftWon or CashWon, or ignored |
| `enableRefunds` | sponsor (empty raffle, any time) or anyone (time-gated, §2.5) | Active or Drawing | Refunding; pot moves to refund liability |
| `settleWinningTicket` | anyone | NftWon/CashWon; `!settled`; range contains `winningEntry` | allocates liabilities (storage only) |
| `redeemWinningTicket` | current owner of the winning ticket | NftWon/CashWon; `!winnerRedeemed` | settles if needed, burns, delivers |
| `refundTickets` | current owner of every listed ticket | Refunding; 1 to 100 IDs | burns; pays `1e6·entries` |
| `releaseSponsorProceeds` / `releaseProtocolFees` | anyone | amount > 0 | pays the immutable recipient |
| `releaseSponsorPrize` | anyone | CashWon or Refunding; `!prizeClaimed` | NFT → `sponsorRecipient` |
| ERC-721 `approve` / `transferFrom` / `safeTransferFrom` | owner or approved | `_update` rejects plumbing destinations on non-burn updates | moves a ticket |

### 2.3 External-call inventory

| Site | Callee | Trust | Kind | State and guard at call time |
|---|---|---|---|---|
| Base ctor (Consumer L45) | `wrapper.link()` | trusted | staticcall | constructor |
| `initialize` → `_isProtocolDestination` (L598-603) | `factory.raffleImplementation()`, `factory.isRaffle()` | system | staticcall | before config writes |
| `buyEntries` L224 | `USDC.transferFrom(msg.sender, this, g)` | trusted | call | before writes; `nonReentrant` |
| `buyEntries` L235 → `_update` L498 | factory views | system | staticcall | — |
| `buyEntries` L235 → ERC721Utils | `recipient.onERC721Received` | **untrusted** | call | **after** all writes; guard held |
| `requestDraw` L249, Consumer L82 | `wrapper.calculateRequestPriceNative` | trusted | staticcall | — |
| Consumer L84 | `wrapper.requestRandomWordsInNative{value: price}` | trusted | call | Drawing, `drawRequestedAt` and `_requestInFlight` already set; guard held |
| `requestDraw` L267 | `msg.sender.call{value: excess}` (no returndata copy) | **untrusted** | call | after all writes; guard held |
| `redeemWinningTicket` L334-335 | `prize.transferFrom`, `prize.ownerOf` | **untrusted** | call / staticcall | after burn and flags; guard held |
| `redeem`/`refund`/`release*` → `_transferQuote` L565-566 | factory views; `USDC.transfer` | trusted | — | after writes; guard held |
| `releaseSponsorPrize` L404-405 | `prize.transferFrom`, `prize.ownerOf` | **untrusted** | call / staticcall | `prizeClaimed` set first; guard held |
| Inherited ticket `safeTransferFrom` | `to.onERC721Received` | **untrusted** | call | ownership already updated; unguarded, but touches no liability |
| Factory L71, L89 | `quote.decimals()`; `new Raffle` | trusted | — | constructor |
| Factory L172 | `prize.supportsInterface` | **untrusted** | staticcall | before clone |
| Factory L128 | `prize.safeTransferFrom` → `clone.onERC721Received` | **untrusted** | call | clone already registered; factory guard held; **clone guard not held** (see I-11) |
| Factory L129, L132 | `prize.ownerOf`, `clone.status()` | untrusted / system | staticcall | final verification |

### 2.4 Asset flows

- **USDC in:** `buyEntries`, from `msg.sender` to the clone, `n·1,000,000` raw units.
- **USDC out:**
  - CashWon redemption → current ticket owner (`msg.sender`)
  - refunds → `msg.sender`
  - sponsor proceeds → `sponsorRecipient` (immutable)
  - protocol fees → `protocolTreasury` (immutable)
- **Prize NFT in:** `createRaffle`, from the sponsor to the clone via `safeTransferFrom`, with the factory as operator.
- **Prize NFT out:** NftWon redemption → current ticket owner; CashWon or Refunding → `sponsorRecipient`. Both use `transferFrom` (no receiver hook) and then verify `ownerOf`.
- **ETH:** `requestDraw`. The wrapper takes exactly the price; the excess goes back to `msg.sender`. The clone keeps 0 (I-16).
- **Tickets:** minted in `buyEntries`; moved by ERC-721 transfers; burned in `redeemWinningTicket` and `refundTickets`. IDs are sequential and never reused. Ranges are kept after a burn.

### 2.5 State machine and window edges

```
[createRaffle tx] clone ──initialize(factory)──► AwaitingPrize ──onERC721Received(prize; from=sponsor; op=factory)──► Active
   (AwaitingPrize never outlives the tx: factory requires status()==Active, else the whole tx reverts)

Active ─buyEntries [t < end]──────────────────────────────────────────► Active (T += n)
Active ─enableRefunds [T==0 ∧ (sponsor ∨ t ≥ end)]────────────────────► Refunding
Active ─requestDraw  [T>0 ∧ end ≤ t < end+2d ∧ msg.value ≥ fee]──────► Drawing (drawRequestedAt = t)
Active ─enableRefunds [T>0 ∧ t ≥ end+2d]────────────────────────────► Refunding
Drawing ─callback [wrapper ∧ !inFlight ∧ id==vrfRequestId ∧ len==1 ∧ t < req+2d]──► NftWon (T ≥ reserve) | CashWon
Drawing ─enableRefunds [t ≥ req+2d]──────────────────────────────────► Refunding
NftWon / CashWon / Refunding: terminal (there are no transitions out)
```

| Edge | Code | Operator, in effect | DESIGN | Verdict |
|---|---|---|---|---|
| Sale | Raffle.sol:216 | revert if `t ≥ end`, so sales run in `[create, end)` | sale end exclusive | ✓ |
| Draw request | :242, :245 | revert if `t < end` or `t ≥ end+2d`, so `[end, end+2d)` | `[sale end, end+2days)` | ✓ |
| Active with entries → refunds | :286-287 | `t ≥ end+2d` | "refunds open at deadline" | ✓; meets the request window with no gap or overlap |
| Callback accepted | :512 | ignored if `t ≥ req+2d`, so `t < req+2d` | "strictly before request ts + 2days" | ✓ |
| Drawing → refunds | :290-291 | `t ≥ req+2d` | "refunds open at deadline" | ✓; meets the callback window with no gap or overlap |
| Empty raffle → refunds | :280-284 | sponsor any time; others `t ≥ end` | not stated; documented in IRaffle | intended |
| Sale duration | Factory :100-103 | `now < end ≤ now + 30d` | — | ✓ |

Executable evidence (in `Lifecycle.t.sol`): `test_edges_sale_request_activeRefund`, `test_edges_lastRequestSecond_and_callbackWindow` (request at `end+2d−1`, callback at `req+2d−1` accepted), `test_edges_callbackAtDeadlineIgnored_thenRefunds`, `test_edges_emptyRaffle`.

**Bounded lifetime.** `end ≤ create+30d`, the last request is at `end+2d−1s`, and the last callback deadline is `end+4d−1s`. One permissionless `enableRefunds` call therefore reaches a terminal state within about 34 days of creation in every branch.

### 2.6 Liability shape per state (g = gross = T·1e6; "−paid" = minus amounts already released)

| State | `unsettledPot` | `remainingRefundLiability` | `winnerProceeds` | `sponsorProceeds` | `protocolFees` |
|---|---|---|---|---|---|
| Active, Drawing, NftWon/CashWon before settlement | g | 0 | 0 | 0 | 0 |
| NftWon after settlement | 0 | 0 | 0 | 0.95g − paid | 0.05g − paid |
| CashWon after settlement | 0 | 0 | 0.80g − paid | 0.15g − paid | 0.05g − paid |
| Refunding | 0 | 1e6 · (entries in unburned tickets) | 0 | 0 | 0 |

---

## 3. Invariants

I derived these from DESIGN before judging the code. Each was then checked by reasoning and, where marked, executed.

| ID | Invariant | Status | Evidence |
|---|---|---|---|
| I-1 | **Solvency.** `USDC.balanceOf(clone) ≥` the sum of the 5 liability fields in every state; equality holds when there are no donations. | holds | Every mutation keeps the sum unchanged. A buy adds g to both sides. `enableRefunds` and settlement move value between fields; settlement keeps the sum because fee + (g − fee) = g and fee + cash + (g − fee − cash) = g. Payouts subtract the same amount from both sides. Random walk I1/I2 checked this after every step, with donations. |
| I-2 | **Exact splits, floor rounding, nothing lost.** fee = ⌊g·500/1e4⌋; cash = ⌊g·8000/1e4⌋; sponsor gets the remainder. | holds | Since g = T·1e6: fee = 50,000·T, cash = 800,000·T, sponsor = 950,000·T (NftWon) or 150,000·T (CashWon). The floors are exact, so the remainder is always 0. Fuzzed `testFuzz_splitExactness` up to 10⁷ entries. |
| I-3 | **Pot at settlement equals gross sales.** | holds | `unsettledPot` is written only by buy (+=), `enableRefunds` (=0) and settlement (=0). Settlement is reachable only from NftWon/CashWon, and neither is reachable from Refunding. |
| I-4 | **No double claim** on any leg. | holds | `settlementComplete`; `winnerRedeemed` plus the burn; `prizeClaimed` (the NftWon and CashWon/Refunding legs are mutually exclusive by status); burn per refunded ticket, so a duplicate ID makes `ownerOf` revert the batch; sponsor and fee fields zeroed before transfer. |
| I-5 | **Ticket ranges** are contiguous, disjoint and cover `[1, T]`; immutable; kept after burn; IDs never reused. | holds | Raffle.sol:226-232. Checked every walk step (I4). |
| I-6 | **Winner uniformity and uniqueness.** `winningEntry = (w mod T) + 1`; T is frozen before the request; exactly one ticket contains the winning entry. | holds | Sales end before the request window opens. Modulo bias ≤ T/2²⁵⁶ ≤ 2⁻¹²⁸. Settlement accepts only the containing range (:579-585); IDs 0 and > count read `(0,0)`. Walk I6 checked uniqueness. |
| I-7 | **Ownership after transfers.** The entitlement follows the ERC-721 owner at redeem/refund time; settlement ignores ownership. | holds | `test_redeem_deliveryFailureRevertsEverything`: after a transfer the new owner redeems and the old owner gets `NotTicketOwner`. |
| I-8 | **One-shot guards and initialization.** | holds | Implementation locked; clone `initialize` is factory-only and runs once; AwaitingPrize → Active only through the exact prize callback; status only moves forward. `test_binding_*`: a rogue clone of the implementation gets `OnlyFactory`, and the implementation's release path reverts. |
| I-9 | **Factory-clone binding.** Only clones the factory created are registered, and registration happens before any untrusted code runs. | holds | RaffleFactory.sol:106-125. |
| I-10 | **Prize custody.** Unclaimed means held by the clone; claimed means held by the winner (NftWon) or `sponsorRecipient`. | holds for honest prizes; unenforceable for untrusted ones | Walk I7. SUP-03. |
| I-11 | **Reentrancy across ERC-721 and ETH hooks.** | holds | Every liability-touching entry point is `nonReentrant`. Every untrusted call comes after all state writes (CEI). The unguarded functions (`initialize`, `onERC721Received`, `rawFulfillRandomWords`, ticket transfers) are gated by caller or status and touch no liability. `test_contractRecipient_callbackCannotReenter`. During the creation-time prize callback the clone guard is **not** held; a lying prize combined with a sponsor contract can push the clone to Refunding plus a prize "release", but the factory's final `status()==Active` check reverts the whole creation. `test_factoryStatusCheckCatchesForcedTransition` shows that check is load-bearing. |
| I-12 | **Bounded exits.** Every state has a time-bounded permissionless route to terminal, and every USDC liability has an exit that does not depend on the prize, the VRF or any other party. | holds (USDC); conditional (NFT) | NFT legs depend on the prize contract by design (revert on delivery failure). `test_redeem_deliveryFailureRevertsEverything`: a paused prize blocks only the NFT leg, while settlement and the sponsor and treasury exits proceed. `Independence.t.sol`: one blacklisted party blocks only its own claim. |
| I-13 | **VRF integrity.** Accepted only from the wrapper, only for the recorded ID, once, only while Drawing, only inside the window, only with one word, and never during the in-flight request. The callback never reverts on ABI-valid input. | holds | `test_vrf_syncCallbackIgnored_and_filters`. Cold callback costs ≈23.5k gas against the 300k limit (`test_callbackGasCold`). |
| I-14 | **No re-roll or cancel** after the request. | holds | Drawing has no route back to Active; one request per raffle. |
| I-15 | **Cross-clone isolation.** | holds for liabilities and third-party assets; **violated** on one self-inflicted path (SUP-01) | Tickets can't be sent to registered clones or the implementation (`test_isolation_crossClone`). USDC payouts are screened at payout time. Storage and guard slots are per clone. |
| I-16 | **No native ETH retained.** | holds | `paidPrice ≤ msg.value`; excess refunded; forced or pre-existing ETH can't subsidise a request (L250, L258). `test_vrf_feeExcessRefund_and_insufficient`. |
| I-17 | **Bounded execution** under the 2²⁴ per-transaction cap (EIP-7825). | holds | No loops over entries. The refund batch is capped at 100. Measured: factory deploy ≈4.15M gas, `createRaffle` ≈386k, 100-ticket refund ≈687k (warm). |

---

## 4. Confirmed findings

### SUP-01: the prize-return path has no payout-time destination screen, so a counterfactual-clone recipient moves the prize into another clone and strands the sponsor's USDC

- **Severity:** Low. **Confidence:** High (PoC executed). **Class:** CONFIRMED defect. It breaches a DESIGN invariant, but only the sponsor can cause it and only the sponsor loses.
- **Location:**
  - No screen on the prize leg: `Raffle.sol:395-407`, transfer at `:404`.
  - Screen present on the USDC leg: `Raffle.sol:564-567`.
  - Creation-time screens: `RaffleFactory.sol:163-169` and `Raffle.sol:193-195`. They call `_isProtocolDestination` (`Raffle.sol:593-605`), which looks up `isRaffle` only for addresses that already have code (`:602`).
- **Root cause:** Clone addresses come from CREATE (`RaffleFactory.sol:106`), so they are predictable and have no code until deployed. A creation-time check cannot recognise an address that only becomes a raffle clone later. The USDC leg re-screens at payout; the prize leg does not.
- **Preconditions:** the sponsor sets `sponsorRecipient = CREATE(factory, n)` for some future nonce n, and some later ordinary `createRaffle` reaches nonce n. No privileged party is involved.
- **Attack path** (numbers from `test_SUP01_counterfactualCloneRecipient`):
  1. Factory nonce is N. The sponsor creates raffle A at `CREATE(F,N)` with `sponsorRecipient = CREATE(F,N+1)`. Every screen passes because that address has no code.
  2. An unrelated user creates raffle B, which lands at `CREATE(F,N+1)`; now `isRaffle(B) == true`.
  3. Raffle A sells 10 entries against a reserve of 100 and resolves CashWon. Settlement allocates `sponsorProceeds = 1,500,000`.
  4. `releaseSponsorProceeds()` now always reverts with `InvalidQuoteDestination(B)`, because the recipient is immutable.
  5. `releaseSponsorPrize()` succeeds. Prize #11 is now owned by clone B, which can only ever move its own `prizeTokenId` (#12), so #11 can't be recovered.
  6. The winner's 8,000,000 and the treasury's 500,000 exit normally, and B's accounting is untouched.
- **Impact:**
  - Breaks the DESIGN rule "Never move assets between raffle clones".
  - The sponsor's own NFT and USDC share are stranded permanently.
  - Buyers, winner, treasury and the receiving clone lose nothing.
  - Same root cause, ticket variant (`test_SUP01b_ticketToFutureClone`): a ticket minted or transferred to a future clone address is owned by that clone for good. If it wins, the winner's leg is stranded; the sponsor and treasury are unaffected.
- **Minimal remedy:**
  - In `releaseSponsorPrize`, apply the same payout-time screen as `_transferQuote`, e.g. `if (_isProtocolDestination(recipient, address(prizeToken))) revert …`. At worst the prize then stays in its own clone, which restores the invariant.
  - Document that `sponsorRecipient` must be an EOA or an already-deployed contract, and have the UI warn when the recipient has no code.
  - Fully preventing the self-strand would need a fallback recipient that can change, which DESIGN forbids ("no mutable configuration").
- **Regression / property tests:**
  - `test_SUP01_counterfactualCloneRecipient`: after the fix, expect `releaseSponsorPrize` to revert.
  - Property: at the moment of every outbound USDC or NFT transfer, `to` is not a registered clone, the implementation, the factory, USDC, the wrapper or the prize.

### SUP-02: a treasury set to a future clone address permanently bricks `createRaffle`

- **Severity:** Informational. **Confidence:** High (PoC). **Class:** CONFIRMED, deployment configuration.
- **Location:** `RaffleFactory.sol:80-83`, `:90` screen the treasury only against self, quote, wrapper and implementation. `Raffle.sol:190-192` then rejects `treasury == address(this)` inside `initialize`.
- **Root cause:** the same CREATE predictability as SUP-01, applied to the immutable treasury.
- **Path:** the deployer passes `protocolTreasury_ = CREATE(factory, k+1)`. Raffles 1 to k−1 work. Creating raffle k reverts with `UnsafeProtocolDestination`, and the revert rolls back the CREATE nonce, so every retry targets the same address. In the PoC k = 1, so no raffle can ever be created.
- **Impact:** the deployment stops working. User funds are not at risk, existing raffles are unaffected, and the problem is visible on the first failure.
- **Remedy:** assert in the deployment script that the treasury is an existing Safe or EOA and is not `CREATE(factory, n)` for the expected range of n. Optionally, add a constructor check against the first few CREATE addresses.
- **Regression test:** `test_SUP02_treasuryEqualsFutureClone_bricksFactory`.

---

## 5. Configuration / integration risks

### SUP-03: untrusted-prize trust boundary (escrow verified only by `ownerOf`; no NftWon delivery fallback)

- **Class:** integration risk at the trust boundary. The behaviour matches DESIGN ("must revert all effects on delivery failure"). **Severity:** Low at protocol level; the loss falls on buyers in the affected raffle.
- **Location:** `RaffleFactory.sol:128-134`; `Raffle.sol:329-337`, `:395-407`.
- **What can go wrong:**
  - **(a) Non-compliant prize.** If per-token approval survives a transfer (`StickyApprovalNFT`), the sponsor's accomplice can pull the prize out of an Active raffle. Sales continue, the reserve is met, and the raffle resolves NftWon. The sponsor collects 9,500,000 of 10,000,000 and the winner's redemption reverts for good (`test_SUP03_nonCompliantPrize_escapesEscrow`).
  - **(b) Lying prize.** A prize contract can call `onERC721Received` itself and report `ownerOf == clone` without transferring anything; creation still succeeds. The factory's status check catches only forced *transitions* (I-11), not fake custody.
  - **(c) Honest collections whose transfer policy can change:** admin pause, ERC721-C validator level changes (owner-initiated transfers disabled, receiver constraints), blocklists, upgradeable proxies, or expiring registrations (ENS BaseRegistrar's `ownerOf` reverts after expiry). Any of these can make an escrowed prize undeliverable after creation.
  - In every case the USDC legs (settlement, sponsor/treasury claims, refunds) are unaffected (`test_redeem_deliveryFailureRevertsEverything`).
- **Why this is not a code defect:** no on-chain check can prove an arbitrary ERC-721 is honest. IRaffle scopes support to "honest, standards-compliant ERC-721s". DESIGN treats prizes as untrusted and mandates revert-on-failure, not a fallback.
- **Mitigations:**
  - A frontend/indexer allowlist, with warnings for upgradeable, pausable, ERC721-C and expiring collections.
  - Optional cheap hardening for the merely sloppy case: check `getApproved(prizeTokenId) == address(0)` after escrow. This does not stop a contract that lies.
  - A delivery-failure fallback (e.g. NftWon converting to cash after a timeout) would be a design change.

### SUP-04: the random word is public about one block early while tickets stay transferable

- **Class:** integration / market risk. **Severity:** Low/Informational.
- **Mechanism:** if the coordinator's fulfilment transaction goes through the public mempool, its proof calldata determines the random word. Anyone can therefore compute `winningEntry` and the winning ticket ID before the transaction is included.
- **Exposure:** tickets can be transferred in every state (`Raffle.sol:497-502`). In the same block, ahead of fulfilment, a searcher can buy the winning ticket from a standing listing, or dump losing tickets into standing collection bids.
- **What it is not:** the outcome itself (which entry wins) can't change, so this does not break Chainlink's "no inputs after request" guidance. It does move value away from listers and bidders.
- **Mitigation:** marketplaces and frontends should not keep listings or bids open while `status == Drawing`. Blocking non-burn transfers during Drawing would contradict the documented "transferable in every lifecycle state", so it's a design decision.

### SUP-05: draw liveness depends on someone paying the VRF fee; incentives are asymmetric

- **Class:** economic; intended. **Severity:** Informational.
- **Incentives:** anyone can draw, but it costs ETH. In a reserve-missed raffle, buyers as a group get 80% through a draw versus 100% through refunds, while the sponsor and treasury prefer the draw. Buyers cannot stop someone else from requesting. Small raffles may never be drawn and then refund at `end+2d`. All paths stay bounded.
- **Fee sizing:** the fixed 300k callback limit is about 12× the measured need (≈23.5k gas cold). The native fee scales with callback gas plus overhead, so a lower limit would cut the draw cost noticeably.
- **Quoting:** `getVrfRequestPrice()` (`Raffle.sol:436`) reads `tx.gasprice`, so an `eth_call` at a zero or default gas price under-quotes. UIs should call `estimateVrfRequestPrice` and overpay; the excess is refunded.

### SUP-06: failure modes of the trusted dependencies (assumptions to state explicitly)

- **USDC:**
  - Identity is not proven on-chain: the factory checks only code and `decimals()` (`RaffleFactory.sol:66-78`).
  - A blacklist or pause on a clone freezes all of that clone's liabilities.
  - A blacklist on one recipient blocks only that recipient's own claim, which resumes once it is lifted; ticket holders can move their tickets (`Independence.t.sol`).
- **VRF:**
  - If the wrapper is disabled, under-funded or withholds, the raffle never resolves and refunds open after the window.
  - An oracle that withholds selectively could turn unfavourable draws into refunds, which harms only the sponsor and treasury.
  - `requestConfirmations = 30` must sit within the target chain coordinator's `[minimum, 200]`. Otherwise every draw reverts and every raffle with entries ends in refunds.

### SUP-07: contract and EIP-7702-delegated recipients under `_safeMint`

- **Class:** integration. **Severity:** Informational.
- **Effect:** `_safeMint` (`Raffle.sol:235`) calls `onERC721Received` on any address with code. That includes EIP-7702-delegated EOAs whose delegate lacks the hook, so those purchases revert. Nothing is lost; the buyer can pick another recipient.
- **Outbound side:** prize deliveries deliberately use `transferFrom`, so a recipient cannot block them. The flip side is that a contract which cannot handle ERC-721s can strand what it receives.

---

## 6. Intended behaviour (verified; not defects)

- **Empty raffles:** the sponsor can close an empty raffle at any time, and anyone can after `endTime` (`Raffle.sol:280-284`). A buy racing the close simply reverts before USDC moves, so no buyer is harmed. DESIGN's "refunds open at deadline" is about raffles that have entries.
- **Bearer tickets:** whoever owns the ticket at redemption gets the prize. Settlement is storage-only and ignores ownership. Operators and approved addresses can't redeem or refund; they can only transfer.
- **Reserve crossing:** anyone, the sponsor included, can buy entries and push the total across the reserve, which flips the outcome type. That is how the reserve works, and buyers can see the rule.
- **Unclaimed prizes:** the winner's claim never expires. An unclaimed NftWon prize or CashWon cash stays in the clone indefinitely and never blocks the sponsor or treasury exits.
- **Unaccounted assets:** NFTs sent with plain `transferFrom`, USDC donations and forced ETH sit outside accounting and can't be rescued (documented at `Raffle.sol:410-411`). The random walk confirms donations don't disturb accounting.
- **Permissionless releases:** anyone can trigger them, but the recipients are fixed.
- **Ticket transfer restriction:** tickets can't be transferred to protocol plumbing. This narrows "transferable" in a documented way.

---

## 7. Informational notes (no security impact)

- **Checks that can never fire:**
  - `Raffle.sol:330`, `PrizeAlreadyClaimed` on the NftWon redemption path: in NftWon only redemption sets `prizeClaimed`, and `winnerRedeemed` already guards it.
  - `Raffle.sol:258`, `paidPrice > msg.value`: the price is computed in the same transaction as the L249 quote, so it can't exceed it.
  - `Raffle.sol:159`, `msg.sender == address(0)`.
- **Event ordering:** `TicketPurchased` (`:236`) is emitted after the recipient's hook runs, and `DrawRequested` (`:272`) after the native refund call. Logs from nested actions can come first, so indexers must not read current ownership from `TicketPurchased.recipient` (DESIGN: discovery is advisory).
- **Rounding path unused:** with the fixed constants the floor-and-remainder code never actually rounds, so no real input exercises that branch.

---

## 8. Leads (unresolved)

- **LEAD-1:** the real VRFV2PlusWrapper and Coordinator sources aren't in the working directory; only the interface is. I modelled their semantics: exact-gas callback, delete before call, no retry, price from `tx.gasprice`, native-mode check on extraArgs. The consumer's defensive filters make liveness independent of those details. The target chain's actual wrapper limits (maximum callback gas, minimum confirmations) should still be checked against deployment.
- **LEAD-2:** solc 0.8.36 is newer than the material I could consult. I did not check its known-bug list, because external reads are excluded.
- **LEAD-3:** the real USDC (FiatToken v2.x proxy) is not available. Standard semantics are assumed per the trust model.

## 9. Coverage gaps

- No mainnet fork; USDC and the VRF wrapper are mocks.
- No formal verification. Fuzzing is bounded: 60-step walks, at most 7 entries per buy, 6 actors.
- Behaviour near the uint128 limit was reasoned through (the overflow guard at `:219`) but executed only up to 10⁷ entries.
- ERC721-C, ENS and ERC-404/DN404 prize behaviour was reasoned from knowledge, not executed.
- Reorgs were not simulated.
- Gas was measured in forge's single-transaction environment; the callback was measured with `vm.cool`, and other cold costs are estimates.
- Deployment scripts, Ignition modules, frontend and indexer are absent or out of scope.

## 10. Reproduction

```
cd sup-notes/poc
forge test                                               # 27 tests, all pass (sup-notes/test-run.txt)
FOUNDRY_FUZZ_RUNS=3000 FOUNDRY_FUZZ_SEED=0x1f2e3d4c forge test --match-test testFuzz_
forge test --match-test test_walkCoverage -vvvv | grep Coverage
```

The coverage sweep over 150 seeds reached these states during the walk (before the forced drain): Drawing 50, NftWon 12, CashWon 23, Refunding 93. Terminal states: NftWon 17, CashWon 24, Refunding 109. Within the walks there were 10 redemptions, 15 settlements and 12 refunds.

| File | Purpose |
|---|---|
| `src/Mocks.sol` | USDC, VRF wrapper, pausable OZ prize, sticky-approval prize, receiver wallet |
| `test/Lifecycle.t.sol` | window edges, splits, atomicity, refund batches, VRF filters, isolation, binding, reentrancy, gas |
| `test/RandomWalk.t.sol` | stateful random walk with invariants I1–I8 after every step, then forced drain to terminal |
| `test/WalkCoverage.t.sol` | path-coverage sweep |
| `test/Findings.t.sol` | SUP-01, SUP-01b, SUP-02, SUP-03 |
| `test/Independence.t.sol` | per-recipient failure isolation |
| `test/CreationWindow.t.sol` | lying prize plus sponsor-contract creation window (I-11) |
| `test/ColdGas.t.sol` | cold callback gas |
