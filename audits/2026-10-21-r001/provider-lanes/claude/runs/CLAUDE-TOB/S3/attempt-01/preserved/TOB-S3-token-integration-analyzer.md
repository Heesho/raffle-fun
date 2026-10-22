# TOKEN INTEGRATION ANALYSIS REPORT — raffle.fun (S3)

| Field | Value |
|---|---|
| Project | raffle.fun NFT raffle — `Raffle` (ERC-1167 clone implementation) and `RaffleFactory` |
| Framework | Trail of Bits *Building Secure Contracts* — Token Integration Checklist + weird-ERC20 database (skill: `token-integration-analyzer`) |
| Token roles | **Quote token:** canonical six-decimal USDC (ERC-20, integrated, trusted per DESIGN.md) · **Prize:** arbitrary ERC-721 (integrated, untrusted per DESIGN.md) · **Ticket:** the protocol's own ERC-721, one collection per raffle clone (implemented) |
| Platform | Solidity 0.8.36, EVM `cancun`, optimizer 200 runs; Ethereum L1 targets (mainnet, Sepolia) per `hardhat.config.ts` |
| Dependencies (context only) | OpenZeppelin Contracts 5.6.1, Chainlink Contracts 1.5.0 — all 31 vendored files match `dependency-hashes.json` (0 mismatches) |
| Analysis date | 2026-10-21 |
| Run mode | Non-interactive delegated run. **No RPC or on-chain access was authorized, so every on-chain check is marked NOT PERFORMED.** No file under `packages/` was modified; all builds and tests ran in an isolated scratch copy outside the tree. |

**In-scope files (SHA-256, unchanged before and after the analysis)**

| File | Lines | SHA-256 |
|---|---:|---|
| `packages/contracts/src/Raffle.sol` | 614 | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| `packages/contracts/src/RaffleFactory.sol` | 186 | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| `packages/contracts/src/interfaces/IRaffle.sol` | 521 | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 150 | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 43 | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |

**Legend:** ✓ satisfied / safe · ⚠ concern or accepted risk · ✗ not satisfied · ◐ partial · ℹ informational. In checklists, `[x]` satisfied, `[ ]` not satisfied or not evidenced, `[~]` partial or risk accepted by design.

---

## EXECUTIVE SUMMARY

**Token type:** A protocol that integrates one trusted ERC-20 (USDC) and arbitrary, untrusted ERC-721 prize contracts, and implements its own ERC-721 ticket.

**Overall risk level: LOW–MEDIUM.** Critical: 0 · High: 0 · **Medium: 1** · **Low: 1** · Informational: 5

The **USDC integration is robust** under the documented trust model:
- Every USDC movement uses `SafeERC20`.
- The internal ledger never reads `balanceOf`.
- Every payout follows checks-effects-interactions behind `nonReentrant`.
- The protocol never issues zero-value transfers, transfers to the zero address, or approvals.
- Six-decimal arithmetic is exact: the 1,000,000-unit entry price makes every 5/15/80/95% split an integer, so no rounding dust exists.

Stateful fuzzing ran 131,072 handler calls per invariant across both outcome branches, with canary probes confirming every terminal state was reached. It found no violation of these invariants: balance equals ledger, value conservation, refund liability equals live tickets, and single prize location.

The **ticket ERC-721 is conformant**. `slither-check-erc` passes every check, and runtime tests confirm the clone-specific behaviour: metadata, approval clearing, burn semantics, safe-mint reentrancy, and the protocol-sink denylist.

**Top concerns**

- ⚠ **TIA-1 (Medium): in the NFT outcome, buyers bear all prize-contract risk.**
  - The factory accepts any contract that claims ERC-721 support.
  - Escrow is verified only once, at creation, using the prize contract's own answers.
  - Settlement releases 95% of gross to the sponsor whether or not the NFT can ever be delivered.
  - Demonstrated with a forged-escrow prize, a stale-approval prize the sponsor withdraws mid-sale, and an expiring-ownership (ENS-style) prize.
- ⚠ **TIA-2 (Low): immutable USDC recipients have no recovery path.** If the factory-wide treasury or a sponsor recipient is USDC-blocklisted, or otherwise becomes unusable, those claims are stranded permanently. Ticket-holder claims self-heal because tickets are transferable.
- ℹ **TIA-3: purchases are credited without a balance-delta check.** USDC is upgradeable. A future fee-on-transfer change would silently make every raffle insolvent: the last claimant cannot be paid.

**Recommendation:** Before mainnet, address TIA-1 with a spec-compatible on-chain escrow re-check plus frontend allowlisting, and correct the interface NatSpec. Decide explicitly on TIA-2 (beneficiary-controlled redirection) and TIA-3 (fail-closed delta check), and pin the canonical USDC address in deployment tooling (TIA-4).

### Findings summary

| ID | Title | Severity | Difficulty | Validation |
|---|---|---|---|---|
| TIA-1 | NFT-outcome winners bear all prize-contract risk: escrow is never re-verified after creation, while sponsor proceeds release unconditionally | **Medium** | Medium | 3 PoCs pass |
| TIA-2 | Immutable USDC recipients (treasury, sponsor recipient) cannot be redirected if blocklisted or unusable | **Low** | High | 5 PoCs pass |
| TIA-3 | Purchases are credited without balance verification; solvency depends on USDC staying fee-free | Informational | High | 1 PoC passes |
| TIA-4 | Quote-token identity is enforced only by deployment tooling (code presence + `decimals() == 6`) | Informational | High | Code review |
| TIA-5 | `releaseSponsorPrize` skips the runtime destination screen applied to USDC payouts (counterfactual clone recipients) | Informational | High | 1 PoC passes |
| TIA-6 | Ticket and spender authenticity rely on integrators: identical metadata across clones, empty `tokenURI`, losing tickets transferable, per-clone approvals | Informational | Medium | Code review + PoCs |
| TIA-7 | A sponsor can cheaply force the NFT branch by topping up the reserve (large-funds risk) | Informational | Low | 1 PoC passes |

---

## 1. GENERAL CONSIDERATIONS

| Check | Result | Evidence |
|---|---|---|
| Protocol security review history | ✗ Not evidenced | DESIGN.md states no tests, audit history, accepted-risk lists or scanner results are provided. |
| Team contactable | ⚠ Unknown | The only authorship signal is the `@author heesho` NatSpec tag; there is no `@custom:security-contact`. |
| Security mailing list | ⚠ Unknown | Nothing in scope. |
| Integrated token reviewed: USDC | ✓ Assumed | DESIGN.md designates USDC as a trusted canonical dependency. Circle's FiatToken is widely reviewed, but this was not verified in this run. |
| Integrated tokens reviewed: prize ERC-721s | ✗ No | Arbitrary and untrusted by design, so no review is possible per prize. See TIA-1. |

**Action:**
- Add `@custom:security-contact` to both contracts and publish a disclosure channel.
- Subscribe to Circle's USDC notices (upgrades, pauses, blocklist policy).

---

## 2. CONTRACT COMPOSITION

**Slither `human-summary`** (in-scope sources only, dependencies filtered):
- 5 source contracts, 710 SLOC; dependencies: 31 contracts, 2,220 SLOC.
- Issue counts: 0 high, 0 medium, 10 low, 2 informational, 0 optimization.
- ERCs detected: ERC721, ERC165 (plus ERC20 and ERC1363 interfaces from dependencies).

| Contract | # functions (incl. inherited) | ERCs | Complex code | Features |
|---|---:|---|---|---|
| `Raffle` | 144 | ERC165, ERC721 | Yes | Receive ETH, Send ETH, Tokens interaction, Assembly |
| `RaffleFactory` | 22 | — | Yes | Tokens interaction |
| `RaffleConstants` | 1 | — | No | — |

| Check | Result |
|---|---|
| Arithmetic safety | ✓ Solidity 0.8.36 checked arithmetic. The in-scope code has no `unchecked` blocks. Overflow bounds: `uint128` entries × `1e6` < 2¹⁴⁸, so no product can overflow. |
| Inline assembly | ✓ One `memory-safe` block, used for the native VRF-fee refund (`Raffle.sol:266-268`). It is outside the token paths. |
| Inheritance | `Raffle` inherits `IRaffle`, OZ `ERC721` (`Context`, `ERC165`, `IERC721`, `IERC721Metadata`, `IERC721Errors`), `ReentrancyGuard`, `IERC721Receiver` and `VRFV2PlusWrapperConsumerBase`. `RaffleFactory` inherits `IRaffleFactory` and `ReentrancyGuard`. Moderate depth. |
| Clone safety of inherited storage | ✓ Clones never run constructors. Two inherited pieces depend on constructor state, and both are handled. OZ 5.6.1 `ReentrancyGuard` tests `== ENTERED`, so a zeroed clone slot behaves as "not entered". `ERC721("", "")` storage is bypassed by `pure` `name()`/`symbol()` overrides (`Raffle.sol:479-487`). Both were verified at runtime (T4). |
| Few non-token functions | ✗ By design. The ticket ERC-721 is embedded in the escrow and lifecycle contract, so most functions are raffle logic. Accepted, because ticket semantics are inseparable from escrow state. |
| External calls in the token transfer path | ⚠ Ticket `_update` calls `_isProtocolDestination`. That function makes view (STATICCALL) calls to the trusted immutable factory: `raffleImplementation()` always for non-burns, and `isRaffle()` when the destination has code. These calls cannot mutate state. |
| Single address entry point | ⚠ Each raffle's ticket is one clone address, but a factory deployment yields many ticket collections with identical metadata, plus the locked implementation, which is itself an ERC-721. Integrators must authenticate with `factory.isRaffle(collection)` (TIA-6). |

**Status:** ACCEPTABLE. The complexity comes from lifecycle logic rather than token logic.

---

## 3. OWNER PRIVILEGES

**Slither `vars-and-auth` printer: every `msg.sender` condition in scope**

| Function | Authorization |
|---|---|
| `Raffle.initialize` | `msg.sender == factory`, once (`initialized` flag) |
| `Raffle.enableRefunds` | Anyone, gated by deadlines. The sponsor alone may close an **empty** raffle before `endTime`. |
| `Raffle.redeemWinningTicket` | Current owner of the winning ticket only |
| `Raffle.refundTickets` | Current owner of each ticket only (approved operators are not accepted) |
| `Raffle.onERC721Received` | Only the configured prize contract, with factory operator, sponsor `from`, exact token ID, while `AwaitingPrize` |
| `rawFulfillRandomWords` (inherited) | Chainlink wrapper only |
| `buyEntries`, `requestDraw`, `settleWinningTicket`, all `release*`, `RaffleFactory.createRaffle` | Permissionless |

**Protocol and ticket token**

| Privilege | Result |
|---|---|
| Upgradeability | ✓ None. ERC-1167 clones target a fixed implementation created in the factory constructor (`RaffleFactory.sol:89-91`). There is no proxy admin, beacon or UUPS hook. The implementation is locked (`initialized = true`, `status = Refunding`, `Raffle.sol:164-165`; runtime test `test_implementationLocked`). |
| Minting | ✓ Tickets are minted only by paid `buyEntries`, and each ticket is fully collateralized. There is no admin mint. |
| Pausability | ✓ None |
| Blacklisting | ✓ No administrable list. There is a fixed protocol-sink denylist: tickets cannot be minted or transferred to the raffle itself, the factory, USDC, the VRF wrapper, the prize contract, the implementation, or any registered raffle (`Raffle.sol:497-502`, `593-605`). |
| Rescue or sweep | ✓ None. Stray assets are deliberately unrecoverable (`Raffle.sol:410-411`). |
| Team | ⚠ Pseudonymous author tag only |

**Integrated quote token (USDC).** These are known FiatToken properties; on-chain configuration was NOT PERFORMED.

| Privilege | Impact on this protocol | Handling |
|---|---|---|
| Upgradeable proxy | Logic can change, for example fees or semantics | Trusted by design. No detection mechanism exists (TIA-3, TIA-4). |
| Pausable | All USDC paths halt | ✓ Delay only. No claim has a deadline (`test_pausedUSDC_delaysButNeverExpiresClaims`). Purchases during the sale window are blocked, which is inherent. |
| Blocklist | A blocklisted recipient or clone cannot receive or send | ✓ Ticket-holder claims self-heal through ticket transfer. ✗ Treasury and sponsor-recipient claims cannot be redirected (TIA-2). Clone blocklisting is isolated per clone. |
| Minting | No effect: entry pricing is fixed and there is no oracle | N/A |

**Integrated prize tokens:** arbitrary. Owner, upgrade, pause, blocklist, burn, and transfer-policy powers of each prize collection are unknown and unverified on-chain. See TIA-1.

---

## 4. ERC-20 CONFORMITY (QUOTE TOKEN = USDC)

The protocol relies on only a narrow ERC-20 surface: `transferFrom` (purchase), `transfer` (payouts) and `decimals()` (factory constructor). Running `slither-check-erc` against deployed USDC was **NOT PERFORMED**, because there was no on-chain access and the deployed FiatToken source is not in the tree.

| Check | USDC (known behaviour, not verified on-chain) | Protocol handling (verified in code and tests) |
|---|---|---|
| `transfer` / `transferFrom` return `bool` | ✓ Returns `true`, reverts on failure | ✓ `SafeERC20.safeTransfer` / `safeTransferFrom` (`Raffle.sol:224`, `566`). It also tolerates empty return data (PoC `test_noReturnToken_supportedBySafeERC20`) and rejects `false` (PoC `test_falseReturnToken_failsClosed`). |
| `name` / `symbol` / `decimals` | ✓ Present | Only `decimals()` is read, as `uint8`, and it must equal 6 (`RaffleFactory.sol:70-78`). Malformed return data fails closed: decoding errors are not caught by `try`/`catch`, so the constructor reverts. |
| `decimals` is `uint8` < 255 | ✓ 6 | ✓ Enforced |
| Approve race mitigation | n/a | ✓ The protocol never calls `approve`. Buyers' approvals to a clone can be spent only for the buyer's own purchase, because `from` is always `msg.sender` (`Raffle.sol:224`). |
| `slither-check-erc` (USDC) | NOT PERFORMED | — |
| `slither-prop` | Not applicable. It generates ERC-20 properties only, and the protocol implements no ERC-20. | Replaced by Foundry stateful invariants over the USDC integration (Appendix C). |

---

## 5. ERC-20 EXTENSION RISKS

| Check | Result |
|---|---|
| External calls or hooks in transfers (ERC-777 style) | ✓ USDC has no hooks. Defence in depth: every USDC-moving function is `nonReentrant`. Payouts zero their state before transferring (`Raffle.sol:323-342`, `366-369`, `376-380`, `386-390`). The purchase pull precedes its effects but is guarded. |
| Transfer fees | ⚠ None today. USDC is upgradeable and the purchase path does not measure what it received (TIA-3). |
| Interest or rebasing | ✓ None. The ledger is internal (`accountedQuoteBalance()`, `Raffle.sol:468-470`), so unsolicited balance changes do not affect accounting. Donated USDC is stranded and unrecoverable (`test_donationsDoNotAffectLedger`). |

---

## 6. TOKEN SCARCITY ANALYSIS

On-chain holder, supply and exchange distribution queries were **NOT PERFORMED**, because no RPC was authorized.

| Check | Result |
|---|---|
| USDC supply distribution and exchange listings | NOT PERFORMED. The design has no price oracle, AMM or collateral valuation, so USDC concentration does not create a manipulation vector here. |
| Flash-loan risk | ✓ Understood. USDC flash loans are widely available but give no advantage: purchased funds are locked until the outcome, and there is no same-transaction exit. `refundTickets` requires `Refunding`, and refunds open only after the draw-request or callback deadline (`test_noSameTxExit_capitalLockedUntilOutcome`). |
| Flash minting | ✓ USDC has no flash mint. Tickets have no flash mint. |
| Large-fund risk | ⚠ A sponsor with capital can force the NFT branch at about a 5% cost by topping up the reserve (TIA-7). A whale buying most entries is part of the game design. |
| Ticket supply | Unbounded (`uint128` entries), one ticket per purchase, each fully collateralized at 1 USDC per entry |

---

## 7. WEIRD ERC-20 PATTERN ANALYSIS (QUOTE-TOKEN INTEGRATION, ALL 24 PATTERNS)

"Presence" refers to the integrated token (USDC). "Handling" is the protocol's verified behaviour.

| # | Pattern | Presence in USDC | Risk | Evidence and handling |
|---|---|---|---|---|
| 7.1 | Reentrant calls (ERC-777 hooks) | Not present | None | All USDC paths are `nonReentrant` and payouts follow CEI (see §5). |
| 7.2 | Missing return values | Not present | None | `SafeERC20` accepts empty return data from contracts (PoC: USDT-style token works end to end). |
| 7.3 | Fee on transfer | Not today; possible via upgrade | Low (accepted) | No balance-delta check in `buyEntries` (`Raffle.sol:223-233`) — **TIA-3**. PoC shows insolvency under a 1% fee. |
| 7.4 | Balance changes outside transfers | Not present (no rebasing) | None | Internal ledger; donations are ignored (PoC). |
| 7.5 | Upgradeable token | **Present** (FiatTokenProxy) | Low (accepted) | Immutable quote token, no upgrade detection — **TIA-3/TIA-4** (monitoring recommended). |
| 7.6 | Flash mintable | Not present | None | — |
| 7.7 | Blocklists | **Present** | Low | Ticket-holder claims self-heal through ticket transfer (PoC). Treasury and sponsor recipient are immutable — **TIA-2**. Clone blocklisting is isolated (PoC). |
| 7.8 | Pausable | **Present** | Low (accepted) | Claims have no deadlines, so a pause only delays them (PoC). Sales are blocked during a pause, which is inherent. |
| 7.9 | Approval race protection | Not relevant | None | The protocol never approves. |
| 7.10 | Revert on approval to zero address | — | None | No approvals |
| 7.11 | Revert on zero-value approval | — | None | No approvals |
| 7.12 | Revert on zero-value transfer | Not present | None | The protocol never transfers 0: purchase ≥ 1e6 (`entryCount > 0`, `Raffle.sol:218`); each refunded ticket ≥ 1e6; CashWon cash ≥ 800,000; `release*` revert on 0 (`Raffle.sol:377`, `387`); winner cash checks for 0 (`Raffle.sol:340`). |
| 7.13 | Multiple token addresses | Not present on L1 | None | Single immutable address. Bridged variants such as USDC.e on other chains are out of scope. |
| 7.14 | Low decimals (6) | **Present** | None | `ENTRY_PRICE = 1_000_000` raw units. All splits are exact multiples (fuzz PoC: fee × 20 == gross, allocations sum to gross, zero residual). The factory enforces 6 decimals. |
| 7.15 | High decimals | Not present | None | Enforced to 6 |
| 7.16 | `transferFrom` with `src == msg.sender` | — | None | The protocol never calls `transferFrom` with `from == address(this)`. |
| 7.17 | Non-string metadata | — | None | Only `decimals()` is read. |
| 7.18 | Revert on transfer to zero address | — | None | Recipients are always non-zero: ticket owner, or `sponsorRecipient`/`protocolTreasury`, both validated non-zero (`Raffle.sol:181-186`, `RaffleFactory.sol:68`). |
| 7.19 | No revert on failure (returns `false`) | Not present | None | `SafeERC20` reverts with `SafeERC20FailedOperation` (PoC). |
| 7.20 | Revert on large approvals | — | None | No approvals |
| 7.21 | Code injection via token name | — | Informational | No on-chain consumption. Prize-contract `name`/`symbol`/`tokenURI` are untrusted strings that frontends must sanitize (prizes are arbitrary). Ticket strings are constants. |
| 7.22 | Unusual `permit` | — | None | `permit` is not used. |
| 7.23 | Transfer less than amount | Not present | None | Exact amounts. `type(uint256).max` is never passed. |
| 7.24 | ERC-20 native-currency representation | Not applicable on Ethereum L1 | None | The native currency is used only for VRF fees, on a separate path (`requestDraw`). `receive()` rejects direct transfers (`Raffle.sol:171-173`). No `address(this).balance`-based accounting. |

---

## 8. TOKEN INTEGRATION SAFETY

### 8.1 Quote token (USDC): integration inventory

| Site | Direction | Amount source | Recipient | Guarding |
|---|---|---|---|---|
| `Raffle.sol:224` `buyEntries` | Pull | `entryCount × 1e6` | this clone | `nonReentrant`, `from = msg.sender` |
| `Raffle.sol:342` `redeemWinningTicket` (CashWon) | Push | `winnerProceeds` (zeroed first) | current owner of the winning ticket (`msg.sender`) | `nonReentrant`, CEI, ticket burned first |
| `Raffle.sol:369` `refundTickets` | Push | Σ entries × 1e6 (liability decremented first, checked) | ticket owner (`msg.sender`) | `nonReentrant`, CEI, tickets burned first |
| `Raffle.sol:380` `releaseSponsorProceeds` | Push | `sponsorProceeds` (zeroed first) | `sponsorRecipient` (fixed) | `nonReentrant`, CEI |
| `Raffle.sol:390` `releaseProtocolFees` | Push | `protocolFees` (zeroed first) | `protocolTreasury` (fixed) | `nonReentrant`, CEI |

All pushes go through `_transferQuote` (`Raffle.sol:564-567`), which re-screens the destination against protocol sinks at runtime before calling `safeTransfer`.

| Defensive pattern | Status |
|---|---|
| SafeERC20 everywhere | ✓ |
| Return-value verification | ✓ (via SafeERC20) |
| Balance verification on inflow | ✗ Not present (TIA-3) |
| Internal ledger independent of `balanceOf` | ✓ `accountedQuoteBalance()` exposes it for monitoring |
| Reentrancy protection | ✓ `nonReentrant` on every state-changing entry point, plus CEI |
| Zero-value / zero-address handling | ✓ Never issued |
| Allowlist | ✓ Single immutable quote token (identity enforced off-chain: TIA-4) |
| Blocklist-aware design | ◐ Self-healing for ticket holders; not for fixed recipients (TIA-2) |
| Claim independence | ✓ Each claim type (winner, refund, sponsor, treasury) moves independently; one blocked claimant never blocks another (PoCs) |
| Cross-clone isolation | ✓ Payouts to any registered raffle are rejected; tickets cannot be held by raffles (PoC). One edge case: TIA-5. |

**Stateful invariants** (Foundry, 512 runs × 256 depth = 131,072 calls each, two raffles, randomized lifecycle including ticket transfers, all branches reached per canary probes):
- `usdc.balanceOf(raffle) == accountedQuoteBalance()` ✓
- `totalIn == totalOut + balance` ✓
- `remainingRefundLiability == par value of unburned tickets` while refunding ✓
- the prize is in exactly one lifecycle-consistent location ✓
- fee divisibility ✓

### 8.2 Prize tokens (arbitrary ERC-721): integration inventory

| Site | Call | Verification |
|---|---|---|
| `RaffleFactory.sol:155` | `code.length > 0` | Must be a contract |
| `RaffleFactory.sol:157-162` | Address comparisons | Not the factory, USDC, VRF wrapper, implementation, or any registered raffle |
| `RaffleFactory.sol:171-177` | `supportsInterface(0x80ac58cd)` (STATICCALL, `try`/`catch`) | Must return `true`; otherwise fails closed |
| `RaffleFactory.sol:128` | `safeTransferFrom(msg.sender, raffle, id)` | `from` is always the caller (no arbitrary-from pulls) |
| `Raffle.sol:416-431` | `onERC721Received` | Caller must be the prize contract; operator, `from` and `tokenId` are checked, **but all are supplied by that same contract** |
| `RaffleFactory.sol:129-134` | `ownerOf(id) == raffle` and `status() == Active` | One-shot creation-time check, answered by the prize contract |
| `Raffle.sol:334-337` | `transferFrom(this, winner, id)` + `ownerOf == winner` | Post-delivery check catches silent no-ops (PoC). Reverts all effects on failure. |
| `Raffle.sol:404-405` | `transferFrom(this, sponsorRecipient, id)` + `ownerOf == recipient` | Same, but **no runtime sink re-screen** (TIA-5) |

**Weird and non-standard ERC-721 prize behaviours**

| Behaviour | Outcome | Validation |
|---|---|---|
| `safeTransferFrom` without receiver callback (pre-standard style) | ✓ Creation reverts `PrizeEscrowVerificationFailed`; the NFT is not lost; nothing is registered | `test_noCallbackNFT_creationFailsClosed` |
| Non-`0x80ac58cd` ERC-165 or none (CryptoPunks, CryptoKitties-era contracts) | ✓ Rejected (fail closed); wrapped versions are required | Code review |
| Transfer that silently does nothing | ✓ `PrizeDeliveryVerificationFailed`; ticket and state preserved; retry succeeds | `test_silentNFT_deliveryCheckRevertsAndPreservesTicket` |
| Re-entrant prize during delivery | ✓ All re-entrant protocol calls revert (`nonReentrant`); state already final (CEI) | `test_reentrantPrize_cannotReenterDuringDelivery` |
| Pausing or blocklisting collection, in CashWon or Refunding | ✓ Only `releaseSponsorPrize` is blocked; winner cash, refunds, sponsor and treasury cash are unaffected; retry works later | `test_pausedPrize_inCashWon_blocksOnlySponsorPrize` |
| **Forged callback and `ownerOf` (malicious contract)** | ✗ Raffle becomes `Active` with no escrow; NftWon winner gets nothing; sponsor receives 95% | `test_lyingNFT_activeWithoutEscrow_nftWonPaysSponsorOnly` — **TIA-1** |
| **Approvals not cleared on transfer (EIP-721 non-conformance)** | ✗ Sponsor's pre-approved wallet withdraws the prize from escrow mid-sale; sponsor keeps the NFT and 95% | `test_staleApprovalNFT_sponsorPullsPrizeOutOfEscrow` — **TIA-1** |
| **Expiring ownership (e.g., ENS BaseRegistrar `ownerOf` reverts after expiry)** | ✗ Prize lapses in escrow; NftWon undeliverable; sponsor receives 95% | `test_expiringNFT_prizeLapsesInEscrow` — **TIA-1** |
| Upgradeable or admin-controlled collections (admin burn or clawback, ERC-721C-style transfer-validator policy changes after escrow, pausing in NftWon) | ✗ Same exposure for the NftWon winner. In NftWon, delivery may be retried indefinitely but may never succeed. | Code review — **TIA-1** |
| Delivery uses `transferFrom` (not `safeTransferFrom`) | ⚠ Intentional: it avoids receiver-hook griefing. A contract recipient that cannot handle ERC-721 locks the NFT. For the winner the recipient is `msg.sender`, so this is opt-in; for the sponsor recipient it is the sponsor's choice. | Code review |
| ENS names specifically | ⚠ While escrowed, the sponsor keeps the ENS registry controller (records) until a later owner calls `reclaim`. Also see expiry above. | Code review |
| Hybrid ERC-20/ERC-721 (ERC-404-style) | ⚠ Not tested. These contracts interpret `transferFrom`'s third argument as an ID or an amount; treat them as unverified. | — |

---

## 9. ERC-721 CONFORMITY (PROTOCOL TICKET)

`slither-check-erc . Raffle --erc erc721` **passed every check**:
- All required ERC-721 functions, plus `supportsInterface`, are present with correct return types and view modifiers, and emit the required events.
- `name`, `symbol` and `tokenURI` are present.
- `Transfer`, `Approval` and `ApprovalForAll` are present with correct indexing.

Clone-runtime confirmation:

| Check | Result | Evidence |
|---|---|---|
| Transfers to 0x0 revert | ✓ `ERC721InvalidReceiver(0)` | `test_transferToZeroReverts` |
| `safeTransferFrom` implemented | ✓ OZ 5.6.1; receiver check via `ERC721Utils` | slither-check-erc |
| `name` / `symbol` present | ✓ `"raffle.fun Ticket"` / `"RAFFLE"` on clones, despite `ERC721("", "")` in the implementation constructor | `test_cloneMetadataAndInterfaces` |
| `decimals` | ✓ Not present (correct) | — |
| `ownerOf` reverts for invalid or burned IDs | ✓ `ERC721NonexistentToken` | `test_refundBurnClearsApproval_ownerOfReverts` |
| Transfers clear approvals | ✓ | `test_transferClearsApproval` |
| Token IDs immutable and never reused | ✓ IDs are sequential from 1; ranges are immutable and retained after burn | `test_refundBurnClearsApproval_ownerOfReverts` |
| ERC-165 | ✓ `0x80ac58cd`, `0x5b5e139f`, `0x01ffc9a7` true; `0xffffffff` false | `test_cloneMetadataAndInterfaces` |
| `tokenURI` | ◐ Conformant but empty (`""`); reverts for unknown IDs | `test_tokenURIEmpty_andRevertsForUnknown` — TIA-6 |

---

## 10. ERC-721 COMMON RISKS (PROTOCOL TICKET)

| Check | Result | Evidence |
|---|---|---|
| `onERC721Received` reentrancy on mint | ✓ `_safeMint` is the last step of `buyEntries` (`Raffle.sol:235`), after all effects, under `nonReentrant`. A recipient that re-enters `buyEntries` is blocked. | `test_safeMintReceiverReentrancyBlocked` |
| Safe minting to contracts | ✓ `_safeMint`. A rejecting receiver reverts the purchase atomically, with no USDC taken. Note: EIP-7702-delegated EOAs report non-empty code, so the delegate must implement `onERC721Received` or the buyer must choose another recipient (fail closed). | `test_rejectingReceiverRevertsPurchaseAtomically` |
| Burning clears approvals | ✓ The OZ `_update` clears approvals on burn. `getApproved` reverts for burned IDs. | `test_refundBurnClearsApproval_ownerOfReverts` |
| Owner-only claims | ✓ Approved operators can transfer but **cannot** refund or redeem (`NotTicketOwner`). Contract holders (vaults, lending escrows) must withdraw the ticket or be able to call these functions directly. | `test_approvedOperatorCannotRefund` |
| Protocol-sink denylist | ✓ Mint and transfer to raffle, factory, USDC, wrapper, prize, implementation, or another raffle all revert. Burns skip the check (short-circuit `to != 0`, `Raffle.sol:498`). | `test_protocolDestinationsCannotHoldTickets` |
| Counterfactual sinks | ⚠ A destination screened while it has no code passes, even if it is a future clone address (TIA-5). | `test_counterfactualCloneAsSponsorRecipient` |

---

## DETAILED FINDINGS

### TIA-1 — NFT-outcome winners bear all prize-contract risk: escrow is never re-verified after creation, while sponsor proceeds release unconditionally

**Severity:** Medium · **Difficulty:** Medium · **Category:** Token integration (arbitrary ERC-721) / data validation

**Files:**
- `RaffleFactory.sol:128-134`, `154-177`
- `Raffle.sol:329-337`, `375-392`, `416-431`, `521`, `533-558`
- `IRaffle.sol:14-15`

**Description.** The factory admits any contract with code that answers `supportsInterface(type(IERC721).interfaceId) == true`:

```solidity
// RaffleFactory.sol:171-177
try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
    supports721 = supported;
} catch { revert UnsupportedPrizeToken(params.prizeToken); }
if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```

Escrow is verified exactly once, at creation, and every input to that verification comes from the prize contract itself:
- `ownerOf(prizeTokenId) == raffle` (`RaffleFactory.sol:129`).
- The clone's `status() == Active` (`RaffleFactory.sol:132`). `onERC721Received` sets `Active` after checking `operator`, `from` and `tokenId`, but those are arguments supplied by the calling prize contract (`Raffle.sol:421-426`).

After creation, no code path consults the prize contract before redemption:
- `buyEntries`, `requestDraw` and `fulfillRandomWords` never read `prizeToken.ownerOf`.
- `_settleWinningTicket` is storage-only.

In the `NftWon` branch (`totalEntries >= reserveEntries`, `Raffle.sol:521`), settlement allocates 95% of gross to `sponsorProceeds` and 5% to `protocolFees` (`Raffle.sol:540-544`). Both are immediately and independently releasable (`Raffle.sol:375-392`). The winner's entire claim is the NFT transfer, which reverts on any failure and has no fallback:

```solidity
// Raffle.sol:329-337
if (result == Status.NftWon) {
    ...
    prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
    if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner);
}
```

Consequently, any prize-contract behaviour after creation lands entirely on the NftWon winner, while the sponsor who chose the prize is paid in full. That behaviour can be:
- **Malicious:** forged callbacks and `ownerOf`, owner-controlled transfer logic, upgrades.
- **Non-conformant:** approvals not cleared on transfer.
- **Honest but unusual:** expiring ownership as in ENS's BaseRegistrar, admin pause or blocklist, transfer-validator policy changes after escrow, admin burn or clawback.

The interface NatSpec states *"Supported prizes are honest, standards-compliant ERC-721s"* (`IRaffle.sol:14-15`), but nothing enforces this. DESIGN.md explicitly classifies prize contracts as untrusted.

The protocol does isolate prize failures well elsewhere:
- Cash claims never call the prize contract.
- No-op transfers are caught by post-checks.
- Re-entry is blocked.

The gap is specific to the NftWon winner.

**Exploit scenario.** A malicious sponsor deploys a collection whose name and symbol imitate a blue-chip collection, and whose `approve` survives transfers. Before creating the raffle (reserve 1), the sponsor approves a second wallet for the prize token. Buyers spend 100,000 USDC. Before the draw, the second wallet pulls the NFT out of escrow. VRF resolves `NftWon`. Anyone settles; 95,000 USDC goes to the sponsor recipient and 5,000 USDC to the treasury. The winner's redemption reverts forever, and the sponsor keeps both the NFT and 95,000 USDC.

**Validation (all pass; Appendix C)**
- `test_lyingNFT_activeWithoutEscrow_nftWonPaysSponsorOnly`: the raffle is `Active` although no NFT moved. Redemption reverts `"rug"`. Sponsor recipient 95e6, treasury 5e6, winner 0.
- `test_staleApprovalNFT_sponsorPullsPrizeOutOfEscrow`: the creation-time check passes (`ownerOf == raffle`). The alternate wallet withdraws the NFT mid-sale. Redemption reverts `ERC721InsufficientApproval(raffle, 1)`. The sponsor ends with 95e6 **and** the NFT.
- `test_expiringNFT_prizeLapsesInEscrow`: ownership lapses one second before `endTime`. Redemption reverts `ERC721NonexistentToken(1)`. Sponsor 95e6.

**Recommendations**

*Short term*
- Re-verify escrow where buyers commit funds and where the outcome becomes irreversible. Require `prizeToken.ownerOf(prizeTokenId) == address(this)` in `buyEntries` and in `requestDraw`.
  - If the prize has left escrow, the draw can no longer be requested. `enableRefunds` then opens at `drawRequestDeadline()` and buyers recover 100%.
  - This is spec-compatible: the callback still records only, and settlement stays storage-only.
  - It defeats honest-but-unusual prizes whose failure occurs before the draw: stale approvals exercised mid-sale, expiry, admin clawback.
  - It cannot defeat a contract that lies about `ownerOf`.
  - The `ownerOf` call is a STATICCALL, so it cannot re-enter state changes. A griefing prize can only block its own raffle, which then refunds.
- Correct `IRaffle.sol:14-15` to state that prize contracts are untrusted and that NftWon winners rely entirely on the prize contract, and surface this in user-facing documentation.
- Frontends and indexers: treat every prize contract as unverified by default.
  - Maintain an advisory allowlist of verified collections: verified source, known proxy/admin configuration, standard approval clearing, no expiry semantics.
  - Re-read `ownerOf` immediately before each purchase.
  - Warn when ENS-style expiry precedes `endTime` + 4 days + a redemption margin.

*Long term*
- Consider a spec change so that in `NftWon` the sponsor's share is released only after successful delivery, or after a delivery timeout with a deterministic fallback (for example, the CashWon split). This would align the sponsor's incentives with delivery. It conflicts with the current "sponsor and treasury can claim independently" requirement, so it needs an explicit design decision.
- Add adversarial prize contracts to the project test suite: forged callbacks, stale approvals, expiry, pause, re-entrancy, silent no-op.

---

### TIA-2 — Immutable USDC recipients cannot be redirected if blocklisted or otherwise unusable

**Severity:** Low · **Difficulty:** High · **Category:** Token integration (blocklist)

**Files:** `RaffleFactory.sol:39`, `87`; `Raffle.sol:64`, `67`, `197-199`, `375-392`

**Description.** USDC (FiatToken) rejects transfers whose caller, sender or recipient is blocklisted (known behaviour; not verified on-chain). Two of the four quote-token claim types pay addresses fixed at creation, with no administrator, no beneficiary-controlled redirect, and no rescue path:
- **Treasury.** `protocolTreasury` is immutable in the factory and copied into every clone. It is the sole destination of `releaseProtocolFees`. If it is blocklisted (for example, at the operator's request after a key compromise), fees accrued in **every** raffle of the deployment become permanently unclaimable.
- **Sponsor recipient.** `sponsorRecipient` is fixed per raffle and is the sole destination of `releaseSponsorProceeds`. If it is blocklisted, that raffle's sponsor proceeds are stranded.

The same applies to any recipient that becomes unusable for other reasons, such as lost keys or an inoperable contract.

By contrast, winner cash and refunds are paid to the current ticket owner (`msg.sender`). A blocklisted holder simply transfers the ticket to another address and claims from there.

**Validation (all pass)**
- `test_blocklistedTreasury_freezesFeesInEveryRaffle`: fees stranded across two raffles; sponsor claims still work.
- `test_blocklistedSponsorRecipient_freezesOnlySponsorProceeds`: winner cash, treasury fees and NFT return are unaffected; 1.5 USDC sponsor proceeds stranded.
- `test_blocklistedWinner_recoversByTransferringTicket`: the claim is redirected through ticket transfer.
- `test_blocklistedClone_freezesThatCloneOnly` and `test_pausedUSDC_delaysButNeverExpiresClaims`: isolation and delay-only behaviour.

**Recommendations**

*Short term*
- Use a multisig treasury with documented key management.
- Document that sponsor recipients must be long-lived addresses able to hold both USDC and ERC-721.

*Long term*
- Add beneficiary-controlled redirection that preserves "no administrator". For example, `releaseProtocolFeesTo(address to)` callable only by `protocolTreasury`, and `releaseSponsorProceedsTo(address to)` callable only by `sponsorRecipient`, both routed through `_transferQuote` screening, while keeping the permissionless defaults.
- The motivation is key rotation and recovery. Because the same mechanism would let a blocklisted beneficiary direct funds elsewhere, confirm it with the operator's compliance obligations before adopting it.

---

### TIA-3 — Purchases are credited without balance verification; solvency depends on USDC staying fee-free

**Severity:** Informational (documented trust assumption) · **Difficulty:** High · **Category:** Token integration (upgradeable / fee-on-transfer)

**Files:** `Raffle.sol:223-233`, `560-561`; `IRaffle.sol:13-14`

**Description.** `buyEntries` pulls `grossAmount` and credits exactly `grossAmount` to `unsettledPot` without measuring what arrived. All later liabilities (refunds, winner, sponsor, treasury) derive from that credit.

This is correct for today's USDC, and the assumption is documented. However, USDC is an upgradeable proxy, and the token-integration checklist explicitly flags future-fee capability for USDC. If a fee were introduced on transfers into the raffle, every clone would over-credit purchases and become insolvent: earlier claims succeed and the last claimant's transfer reverts. Fees on outbound payouts alone would not break solvency, because the balance falls by the full amount, but they would underpay recipients.

**Validation:** `test_feeOnTransferUpgrade_overCreditsAndStrandsLastRefund`. With a 1% fee, the ledger is 100e6 against a balance of 99e6. Alice's 50e6 refund succeeds; Bob's 50e6 refund reverts with `"ERC20: transfer amount exceeds balance"`.

**Recommendations**

*Short term*
- Optional fail-closed guard in `buyEntries`: record `balanceOf(address(this))` before and after `safeTransferFrom`, and revert unless the delta equals `grossAmount`.
- This turns silent insolvency into a hard stop on new purchases, at the cost of about two extra STATICCALLs.

*Long term*
- Monitor the USDC proxy's `Upgraded` events.
- For every registered raffle, monitor the invariant `quoteToken.balanceOf(raffle) >= accountedQuoteBalance()` (the view already exists).
- Prepare a response plan.

---

### TIA-4 — Quote-token identity is enforced only by deployment tooling

**Severity:** Informational · **Difficulty:** High · **Category:** Configuration

**Files:** `RaffleFactory.sol:59-61`, `66-78`; `IRaffleFactory.sol:7-9`

**Description.** The constructor checks only that the quote token has code and reports `decimals() == 6`, and the NatSpec acknowledges that identity cannot be proven on-chain. Any six-decimal ERC-20 passes, including tokens with different semantics. Examples: a USDT-style token without return values (tolerated by SafeERC20), a token with a dormant fee switch, or an attacker-deployed token in a counterfeit factory deployment.

Every raffle inherits the factory's immutable quote token, so the deployment pin is the control. The deployment module referenced by `package.json` (`ignition/modules/RaffleFun.ts`) is not in the provided tree and was not reviewed.

**On-chain verification:** NOT PERFORMED.

**Recommendations**
- Pin per-chain canonical USDC addresses in deployment code and assert them. Confirm both values below against Circle's published list at deployment time; neither was verified on-chain here.
  - Ethereum mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
  - Sepolia: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- After deployment, verify `factory.quoteToken()`, `vrfWrapper()`, `protocolTreasury()` and `raffleImplementation()`, and the implementation's immutables.
- Frontends should hard-code the canonical factory address and check `RaffleCreated.quoteToken`.

---

### TIA-5 — `releaseSponsorPrize` skips the runtime destination screen applied to USDC payouts

**Severity:** Informational · **Difficulty:** High · **Category:** Data validation

**Files:** `Raffle.sol:193-195`, `395-407`, `564-567`, `598-604`; `RaffleFactory.sol:163-169`

**Description.** `_transferQuote` re-screens each USDC destination at runtime, but `releaseSponsorPrize` transfers the NFT to `sponsorRecipient` with no runtime screen. The creation-time screens cannot recognize an address that will become a clone later:
- Clone addresses are deterministic CREATE addresses of the factory.
- `_isProtocolDestination` consults the registry only for addresses that already have code (`destination.code.length != 0`, `Raffle.sol:602`).

A sponsor recipient set to a future clone's address therefore passes validation. Once that clone exists:
- The sponsor's USDC is permanently blocked by `InvalidQuoteDestination`.
- `releaseSponsorPrize` moves the prize NFT **into another raffle clone**, where it is unrecoverable. This contradicts DESIGN.md's "Never move assets between raffle clones".

The same code-gating lets a ticket be sent to a future clone address. Impact is limited to the sponsor's (or ticket holder's) own assets and requires choosing an exact future clone address.

**Validation:** `test_counterfactualCloneAsSponsorRecipient`. `releaseSponsorProceeds` reverts `InvalidQuoteDestination(futureClone)`, and the prize ends up owned by the second raffle clone.

**Recommendations**
- Apply `_isProtocolDestination(recipient, address(prizeToken))` in `releaseSponsorPrize`, reverting like `_transferQuote`, so the cross-clone invariant holds uniformly.
- Document that recipients must not be counterfactual contract addresses.

---

### TIA-6 — Ticket and spender authenticity rely on integrators

**Severity:** Informational · **Difficulty:** Medium · **Category:** Token implementation (ERC-721 integration surface)

**Files:** `Raffle.sol:224`, `477-487`, `491-502`

**Description**
- **Indistinguishable collections.** Every clone is a separate ERC-721 collection with the same constant name and symbol, and the locked implementation is another. `tokenURI` is empty. Wallets and marketplaces therefore cannot tell genuine tickets from look-alikes, which raffle a ticket belongs to, its entry range, or whether it already won or lost.
- **Tickets stay transferable in every state** (by design). Losing tickets remain tradeable after resolution, and listings created before resolution can be sniped once the result is known.
- **Per-clone USDC approvals.** Each clone is a fresh spender, so buyers approve a new address for every raffle. This is safe with genuine clones, because `buyEntries` only pulls from `msg.sender`, but it trains users to approve unfamiliar addresses, which counterfeit "raffles" can exploit.

**Recommendations**
- Expose ticket state on-chain: either `tokenURI` JSON with raffle id, range, status and whether the ticket contains `winningEntry`, or a dedicated view.
- Integrators must check `factory.isRaffle(collection)` before approvals, purchases or ticket trades, and read `status()`, `winningEntry()`, `ticketRange(id)` and `winnerRedeemed()` before pricing a ticket.
- Prefer exact-amount approvals.

---

### TIA-7 — A sponsor can cheaply force the NFT branch by topping up the reserve

**Severity:** Informational (economic; outside strict token-handling scope) · **Difficulty:** Low · **Category:** Large-funds risk

**Files:** `Raffle.sol:521`, `540-548`

**Description.** The outcome depends only on `totalEntries >= reserveEntries`. Anyone, including sponsor-controlled wallets, can buy until `endTime`. In `NftWon`, the sponsor recipient receives 95% of gross, including the sponsor's own purchases. Topping up the reserve therefore costs the sponsor only 5% of the top-up plus the chance of losing the NFT, while organic buyers' prize changes from 80% of the pot in cash to the NFT.

Flash loans cannot help, because capital is locked until the outcome.

**Validation:** `test_sponsorReserveTopUp_economics`. Reserve 1,000; organic entries 500; sponsor top-up 500. The sponsor recipient receives 950 USDC, a net +450 against +75 (plus the NFT back) without the top-up. The organic winner receives the NFT instead of 400 USDC.

**Recommendation:** Document that the reserve does not protect buyers against the sponsor. A structural fix is not possible on-chain (wallets are Sybil-able) without a design change.

---

## COMPLIANCE CHECKLIST

**General considerations**
- [ ] Security review completed (protocol) — not evidenced
- [ ] Team contactable — no security contact in source
- [ ] Security mailing list exists — unknown

**Contract composition**
- [x] Avoids unnecessary complexity (lifecycle-driven; acceptable)
- [x] Uses Solidity 0.8+ (0.8.36; no `unchecked`)
- [ ] Few non-token functions — by design, the ticket is embedded in the escrow
- [~] Single address entry point — one per raffle; many collections per deployment (TIA-6)

**Owner privileges (protocol / ticket)**
- [x] Not upgradeable (fixed-implementation clones)
- [x] Limited minting (paid purchases only)
- [x] Not pausable
- [x] No administrable blacklist (fixed sink denylist only)
- [ ] Known team — pseudonymous

**Owner privileges (USDC, integrated)**
- [~] Upgradeable / pausable / blocklist — present; risks understood and accepted by design (TIA-2, TIA-3)

**ERC-20 conformity (USDC; protocol-side verified, token-side NOT PERFORMED on-chain)**
- [x] Boolean return handling (SafeERC20; also tolerant of missing returns)
- [x] Metadata used safely (`decimals` only, enforced = 6)
- [x] Decimals `uint8`
- [x] Race condition N/A (no approvals)
- [ ] Passes `slither-check-erc` — NOT PERFORMED (no deployed source or on-chain access)
- [x] No external calls in transfers (no hooks; guarded anyway)
- [~] No transfer fees — true today; not defended (TIA-3)
- [x] Interest N/A; ledger internal

**Token scarcity**
- [ ] Distributed ownership — NOT PERFORMED
- [ ] Sufficient total supply — NOT PERFORMED
- [ ] Multiple exchange listings — NOT PERFORMED
- [x] Flash-loan risks understood (no same-transaction exit)
- [x] No flash minting

**ERC-721 conformity (ticket)**
- [x] Transfers to 0x0 revert
- [x] `safeTransferFrom` implemented
- [x] Metadata functions handled (constant overrides on clones)
- [x] `ownerOf` reverts properly
- [x] Transfers clear approvals
- [x] Token IDs immutable
- [x] `onERC721Received` protected (`nonReentrant`)
- [x] Safe minting implemented
- [x] Burning clears approvals

**ERC-721 prize integration**
- [~] Fails closed for missing callbacks, wrong ERC-165, silent no-ops and re-entrancy
- [ ] Conformance or continued escrow not verified after creation (TIA-1)

---

## ON-CHAIN ANALYSIS REPORT — NOT PERFORMED

No RPC or on-chain access was authorized for this run. None of the following were executed. They are listed for the deployment team.

| Target | Checks to perform |
|---|---|
| USDC (per chain) | Address matches Circle's published canonical address; EIP-1967 implementation and admin slots; `decimals() == 6`; `paused()`; `isBlacklisted(protocolTreasury)`; `isBlacklisted(raffle)` for registered raffles |
| Factory | Runtime bytecode matches compiled artifact (solc 0.8.36, optimizer 200, `cancun`); immutables `quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation`; implementation `initialized() == true` and `status() == Refunding` |
| VRF wrapper | Canonical Chainlink VRF v2.5 wrapper address for the chain |
| Every raffle | `factory.isRaffle(raffle)`; `prizeToken.ownerOf(prizeTokenId) == raffle`; prize contract source verified, proxy/admin/pause/expiry review; `usdc.balanceOf(raffle) >= accountedQuoteBalance()` |
| Token scarcity | Not material to this design (no oracle or AMM); optional USDC holder and exchange distribution |

---

## PRIORITIZED RECOMMENDATIONS

**CRITICAL:** none. **HIGH:** none.

**MEDIUM (fix before deployment)**
1. **TIA-1:**
   - Add an escrow re-check (`ownerOf == address(this)`) in `buyEntries` and `requestDraw`.
   - Correct the `IRaffle` NatSpec on prize trust.
   - Ship frontend allowlisting and per-purchase `ownerOf` re-reads.
   - Make an explicit design decision on gating NftWon sponsor proceeds on delivery.

**LOW (fix soon)**

2. **TIA-2:** Add beneficiary-controlled redirection, subject to compliance review, or document the accepted risk; use a multisig treasury.

**INFORMATIONAL / best practices**

3. **TIA-3:** Fail-closed balance-delta check in `buyEntries`; monitor USDC upgrades and the balance ≥ ledger invariant.
4. **TIA-4:** Pin and assert canonical USDC and VRF wrapper addresses in deployment tooling; run the post-deployment immutables check.
5. **TIA-5:** Re-screen `sponsorRecipient` at runtime in `releaseSponsorPrize`.
6. **TIA-6:** Expose on-chain ticket state; publish integrator guidance (`isRaffle`, status reads, exact approvals).
7. **TIA-7:** Document the reserve semantics.
8. Add `@custom:security-contact`.
9. Add `slither-check-erc --erc erc721` and the adversarial-token and invariant suites from Appendix D to CI.

---

## APPENDIX A — METHODOLOGY AND TOOLING

1. **Context discovery.** Read all five in-scope files line by line, and the dependency code paths they rely on (context only): OZ `ERC721`, `ERC721Utils`, `SafeERC20`, `ReentrancyGuard`, `Clones`; Chainlink `VRFV2PlusWrapperConsumerBase`. Verified all 31 vendored dependency files against `dependency-hashes.json`: 31 checked, 0 mismatches.
2. **Isolated build.** Copied `src/` and `node_modules/` to a scratch directory outside the tree (`/tmp/tob-s3-scratch.GqRk6Z/proj`) with an equivalent `foundry.toml` and explicit `@chainlink/contracts/` remapping, then compiled with the cached solc 0.8.36 (`forge build --offline`). Raffle runtime is 15,947 B and RaffleFactory runtime is 3,949 B, both under EIP-170.
3. **Slither 0.11.6**
   - `slither-check-erc . Raffle --erc erc721`: all pass.
   - Printers: `human-summary`, `contract-summary`, `vars-and-auth`.
   - Full detectors, 102 total, `--filter-paths node_modules`: 12 results, all low or informational (Appendix B).
4. **`slither-prop`.** Not applicable: it generates ERC-20 properties only, and the protocol implements no ERC-20. Replaced by Foundry stateful invariants over the USDC integration and prize custody.
5. **Dynamic validation (Foundry 1.7.1)**
   - 33 unit and fuzz tests with standard and weird token mocks.
   - 6 invariants at 512 runs × 256 depth.
   - 5 reachability canaries, all of which broke as intended. This proves the fuzzer reaches NftWon redemption, CashWon redemption, refunds, prize return and fully-drained terminal states.
   - Echidna 2.3.3 was available but not used; Foundry invariants were used instead.
6. **On-chain analysis.** NOT PERFORMED (not authorized).
7. **Non-modification.** In-scope file hashes were recomputed after all work and are identical. No files were created under `packages/`.

## APPENDIX B — SLITHER DETECTOR TRIAGE

| Detector | Location | Triage |
|---|---|---|
| `events-maths` | `Raffle.initialize` (`prizeTokenId`, `reserveEntries`, `endTime`) | Informational. The values are emitted in `RaffleCreated` by the factory in the same transaction. |
| `calls-loop` (×2) | `refundTickets → _burn → _update → _isProtocolDestination` | **False positive.** `_update` short-circuits on `to != address(0)` (`Raffle.sol:498`), so burns make no external calls. |
| `reentrancy-benign` | `RaffleFactory.createRaffle` writes the registry after `initialize` | Benign. The call targets a fresh fixed-implementation clone, which makes only view calls back to the factory. The function is `nonReentrant` and annotated. |
| `timestamp` (×6) | Sale, request and callback windows | By design (day-scale windows; validator drift is immaterial). |
| `assembly` | `requestDraw` native refund | Benign (`memory-safe`; failure reverts). |
| `naming-convention` | `IRaffle.ENTRY_PRICE()` | Informational (constant getter). |

## APPENDIX C — VALIDATION RESULTS

Final run (`FOUNDRY_INVARIANT_RUNS=512 FOUNDRY_INVARIANT_DEPTH=256 FOUNDRY_FUZZ_RUNS=2000`): **39 passed, 0 failed.**

```text
T1_BaselineAccounting
[PASS] test_nftWon_allClaimsDrainExactly()
[PASS] test_cashWon_allClaimsDrainExactly()
[PASS] test_refundPath_fullPar_andPrizeReturn()
[PASS] testFuzz_allocationExactNoDust(uint64,uint64,uint256,bool) (runs: 2000)
[PASS] test_noSameTxExit_capitalLockedUntilOutcome()
[PASS] test_donationsDoNotAffectLedger()
T2_QuoteTokenBehaviour
[PASS] test_feeOnTransferUpgrade_overCreditsAndStrandsLastRefund()      -> TIA-3
[PASS] test_noReturnToken_supportedBySafeERC20()
[PASS] test_falseReturnToken_failsClosed()
[PASS] test_blocklistedSponsorRecipient_freezesOnlySponsorProceeds()   -> TIA-2
[PASS] test_blocklistedTreasury_freezesFeesInEveryRaffle()             -> TIA-2
[PASS] test_blocklistedWinner_recoversByTransferringTicket()
[PASS] test_blocklistedClone_freezesThatCloneOnly()
[PASS] test_pausedUSDC_delaysButNeverExpiresClaims()
T3_PrizeTokenBehaviour
[PASS] test_noCallbackNFT_creationFailsClosed()
[PASS] test_lyingNFT_activeWithoutEscrow_nftWonPaysSponsorOnly()       -> TIA-1
[PASS] test_staleApprovalNFT_sponsorPullsPrizeOutOfEscrow()            -> TIA-1
[PASS] test_expiringNFT_prizeLapsesInEscrow()                          -> TIA-1
[PASS] test_silentNFT_deliveryCheckRevertsAndPreservesTicket()
[PASS] test_pausedPrize_inCashWon_blocksOnlySponsorPrize()
[PASS] test_reentrantPrize_cannotReenterDuringDelivery()
T4_TicketERC721
[PASS] test_cloneMetadataAndInterfaces()
[PASS] test_tokenURIEmpty_andRevertsForUnknown()
[PASS] test_transferToZeroReverts()
[PASS] test_transferClearsApproval()
[PASS] test_refundBurnClearsApproval_ownerOfReverts()
[PASS] test_protocolDestinationsCannotHoldTickets()
[PASS] test_safeMintReceiverReentrancyBlocked()
[PASS] test_rejectingReceiverRevertsPurchaseAtomically()
[PASS] test_approvedOperatorCannotRefund()
T5_EdgeCases
[PASS] test_counterfactualCloneAsSponsorRecipient()                    -> TIA-5
[PASS] test_sponsorReserveTopUp_economics()                            -> TIA-7
[PASS] test_implementationLocked()
T6_Invariants (runs: 512, calls: 131072, reverts: 0 each)
[PASS] invariant_balanceEqualsLedger()
[PASS] invariant_conservation()
[PASS] invariant_refundLiabilityMatchesLiveTickets()
[PASS] invariant_prizeLocation()
[PASS] invariant_feeExact()
[PASS] invariant_callSummary()
T7_ReachabilityProbes (expected to FAIL; each failure proves the branch is reachable; excluded from the run above)
[FAIL: REACHED: NftWon redemption]
[FAIL: REACHED: CashWon redemption]
[FAIL: REACHED: refund paid]
[FAIL: REACHED: prize returned to sponsor recipient]
[FAIL: REACHED: settled raffle fully drained]
```

"PASS" on a finding-linked test means the test **confirmed the reported behaviour**. For example, TIA-1's tests pass because the winner receives nothing while the sponsor collects 95%.

## APPENDIX D — HARNESS SOURCE (FOR REPRODUCTION)

To reproduce:
1. Copy `packages/contracts/src` and `packages/contracts/node_modules` into an empty directory **outside** `packages/`.
2. Add the `foundry.toml` and `remappings.txt` below.
3. Place the three files below in `test/`.
4. Run `forge test --offline --no-match-contract T7_ReachabilityProbes`, and separately `--match-contract T7_ReachabilityProbes` for the canaries.

<details>
<summary><code>foundry.toml</code></summary>

```toml
[profile.default]
src = "src"
test = "test"
out = "out"
libs = ["node_modules"]
solc_version = "0.8.36"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = false
offline = true
```

</details>

<details>
<summary><code>remappings.txt</code></summary>

```text
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
@chainlink/contracts/=node_modules/@chainlink/contracts/
```

</details>

<details>
<summary><code>test/Mocks.sol</code></summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function getNonce(address) external view returns (uint64);
    function assume(bool) external pure;
    function toString(uint256) external pure returns (string memory);
}

// ---------------------------------------------------------------------------------------------------------------------
// Quote-token mocks (six decimals). MockUSDC models FiatToken semantics relevant to integration: bool returns,
// blocklist on caller/from/to, global pause, and a configurable fee that simulates a hypothetical proxy upgrade.
// ---------------------------------------------------------------------------------------------------------------------

contract MockUSDC {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isBlacklisted;
    bool public paused;
    uint256 public feeBps;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function blacklist(address a) external {
        isBlacklisted[a] = true;
    }

    function unBlacklist(address a) external {
        isBlacklisted[a] = false;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function setFeeBps(uint256 f) external {
        feeBps = f;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _check(msg.sender, msg.sender, to);
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _check(msg.sender, from, to);
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "ERC20: insufficient allowance");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        _move(from, to, amount);
        return true;
    }

    function _check(address caller, address from, address to) internal view {
        require(!paused, "Pausable: paused");
        require(
            !isBlacklisted[caller] && !isBlacklisted[from] && !isBlacklisted[to],
            "Blacklistable: account is blacklisted"
        );
    }

    function _move(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[from] -= amount;
        uint256 fee = amount * feeBps / 10_000;
        balanceOf[to] += amount - fee;
        balanceOf[address(0xFEE)] += fee;
    }
}

/// USDT/BNB/OMG-style token: transfer and transferFrom return no data.
contract NoReturnUSD {
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external {
        allowance[msg.sender][s] = a;
    }

    function transfer(address to, uint256 a) external {
        require(balanceOf[msg.sender] >= a);
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
    }

    function transferFrom(address f, address to, uint256 a) external {
        require(allowance[f][msg.sender] >= a);
        allowance[f][msg.sender] -= a;
        require(balanceOf[f] >= a);
        balanceOf[f] -= a;
        balanceOf[to] += a;
    }
}

/// ZRX/EURS-style token: returns false instead of reverting on failure.
contract FalseReturnUSD {
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        if (balanceOf[msg.sender] < a) return false;
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        if (allowance[f][msg.sender] < a || balanceOf[f] < a) return false;
        allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[to] += a;
        return true;
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// Chainlink VRF v2.5 wrapper mock (native payment, asynchronous fulfillment).
// ---------------------------------------------------------------------------------------------------------------------

interface IRawFulfill {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

contract MockVRFWrapper {
    uint256 public constant PRICE = 0.001 ether;
    uint256 public lastRequestId;
    mapping(uint256 => address) public consumerOf;

    function link() external pure returns (address) {
        return address(0x1111);
    }

    function linkNativeFeed() external pure returns (address) {
        return address(0);
    }

    function calculateRequestPrice(uint32, uint32) external pure returns (uint256) {
        return PRICE;
    }

    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return PRICE;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external pure returns (uint256) {
        return PRICE;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external pure returns (uint256) {
        return PRICE;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata)
        external
        payable
        returns (uint256 id)
    {
        require(msg.value == PRICE, "price");
        id = ++lastRequestId;
        consumerOf[id] = msg.sender;
    }

    function fulfill(uint256 id, uint256 word) external {
        uint256[] memory w = new uint256[](1);
        w[0] = word;
        IRawFulfill(consumerOf[id]).rawFulfillRandomWords(id, w);
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// Prize ERC-721 mocks: one standard collection plus weird / non-conformant / malicious variants.
// ---------------------------------------------------------------------------------------------------------------------

contract StdNFT is ERC721 {
    constructor() ERC721("Prize", "PRZ") { }

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}

/// Pre-standard style: safeTransferFrom never invokes onERC721Received.
contract NoCallbackNFT is StdNFT {
    function safeTransferFrom(address from, address to, uint256 id, bytes memory) public override {
        transferFrom(from, to, id);
    }
}

/// Non-conformant: transfers do not clear the single-token approval (violates EIP-721 Transfer semantics).
contract StaleApprovalNFT is StdNFT {
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal override {
        if (to == address(0) && auth == address(0) && !emitEvent) return; // skip the clear performed in _update
        super._approve(to, tokenId, auth, emitEvent);
    }
}

/// ENS-registrar style: ownership lapses at expiry; ownerOf and transfers revert afterwards.
contract ExpiringNFT is StdNFT {
    mapping(uint256 => uint256) public expiry;

    function setExpiry(uint256 id, uint256 exp) external {
        expiry[id] = exp;
    }

    function _ownerOf(uint256 id) internal view override returns (address) {
        if (expiry[id] != 0 && block.timestamp >= expiry[id]) return address(0);
        return super._ownerOf(id);
    }
}

/// Admin-pausable collection (OZ ERC721Pausable-like).
contract PausableNFT is StdNFT {
    bool public paused;

    function setPaused(bool p) external {
        paused = p;
    }

    function _update(address to, uint256 id, address auth) internal override returns (address) {
        require(!paused, "paused");
        return super._update(to, id, auth);
    }
}

/// No revert on failure: transferFrom silently does nothing while `silent` is set.
contract SilentNFT is StdNFT {
    bool public silent;

    function setSilent(bool s) external {
        silent = s;
    }

    function transferFrom(address from, address to, uint256 id) public override {
        if (silent) return;
        super.transferFrom(from, to, id);
    }
}

/// Re-enters the raffle from inside prize delivery.
contract ReentrantNFT is StdNFT {
    address public target;
    bool public attempted;
    bool public reentryBlocked;

    function arm(address t) external {
        target = t;
    }

    function transferFrom(address from, address to, uint256 id) public override {
        if (target != address(0) && from == target) {
            attempted = true;
            (bool ok1,) = target.call(abi.encodeCall(IRaffle.releaseSponsorProceeds, ()));
            (bool ok2,) = target.call(abi.encodeCall(IRaffle.releaseProtocolFees, ()));
            uint256[] memory ids = new uint256[](1);
            ids[0] = 2;
            (bool ok3,) = target.call(abi.encodeCall(IRaffle.refundTickets, (ids)));
            reentryBlocked = !ok1 && !ok2 && !ok3;
        }
        super.transferFrom(from, to, id);
    }
}

/// Malicious prize: claims ERC-721 support, never escrows anything, forges the receiver callback and ownerOf.
contract LyingNFT {
    address public pretendOwner;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        pretendOwner = to;
    }

    function ownerOf(uint256) external view returns (address) {
        return pretendOwner;
    }

    function transferFrom(address, address, uint256) external pure {
        revert("rug");
    }

    function setApprovalForAll(address, bool) external { }
}

// ---------------------------------------------------------------------------------------------------------------------
// Ticket-recipient helpers.
// ---------------------------------------------------------------------------------------------------------------------

contract ReentrantTicketReceiver is IERC721Receiver {
    IRaffle public raffle;
    bool public armed;
    bool public reentryBlocked;

    function arm(IRaffle r) external {
        raffle = r;
        armed = true;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (armed) {
            armed = false;
            try raffle.buyEntries(address(this), 1) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RejectingReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert("no tickets");
    }
}
```

</details>

<details>
<summary><code>test/TokenIntegration.t.sol</code></summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "../src/RaffleFactory.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./Mocks.sol";

abstract contract Base {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal constant TREASURY = address(0x7EA5);
    address internal constant SPONSOR = address(0x5905);
    address internal constant SPONSOR_RECIPIENT = address(0x5EC1);
    address internal constant SPONSOR_ALT = address(0x5A17);
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA201);
    address internal constant KEEPER = address(0x4EE9);

    MockVRFWrapper internal vrf;
    MockUSDC internal usdc;
    RaffleFactory internal factory;

    function setUp() public virtual {
        vrf = new MockVRFWrapper();
        usdc = new MockUSDC();
        factory = new RaffleFactory(address(usdc), address(vrf), TREASURY);
    }

    function _eq(uint256 a, uint256 b, string memory m) internal pure {
        if (a != b) revert(string.concat(m, ": ", vm.toString(a), " != ", vm.toString(b)));
    }

    function _create(RaffleFactory f, address prize, uint256 id, uint128 reserve) internal returns (IRaffle r) {
        vm.startPrank(SPONSOR);
        IERC721(prize).setApprovalForAll(address(f), true);
        r = IRaffle(
            f.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: SPONSOR_RECIPIENT,
                    prizeToken: prize,
                    prizeTokenId: id,
                    reserveEntries: reserve,
                    endTime: uint64(block.timestamp + 1 days)
                })
            )
        );
        vm.stopPrank();
    }

    function _buy(IRaffle r, MockUSDC q, address who, uint128 n) internal returns (uint256 t) {
        q.mint(who, uint256(n) * 1e6);
        vm.startPrank(who);
        q.approve(address(r), type(uint256).max);
        t = r.buyEntries(who, n);
        vm.stopPrank();
    }

    function _draw(IRaffle r, uint256 word) internal {
        vm.warp(r.endTime());
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        uint256 id = r.requestDraw{ value: 0.01 ether }();
        vrf.fulfill(id, word);
    }

    function _one(uint256 id) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = id;
    }

    /// CREATE address for `f` at its current nonce plus `offset` (single-byte RLP nonce range only).
    function _nextClone(address f, uint256 offset) internal view returns (address) {
        uint256 n = uint256(vm.getNonce(f)) + offset;
        require(n > 0 && n < 0x80, "nonce range");
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), f, uint8(n))))));
    }
}

// =====================================================================================================================
// T1: quote-token accounting with standard USDC semantics
// =====================================================================================================================
contract T1_BaselineAccounting is Base {
    function test_nftWon_allClaimsDrainExactly() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 10);
        uint256 t1 = _buy(r, usdc, ALICE, 7);
        _buy(r, usdc, BOB, 5);
        _eq(usdc.balanceOf(address(r)), r.accountedQuoteBalance(), "acct after buys");
        _draw(r, 3); // entry 4, inside alice's [1,7]
        require(r.status() == IRaffle.Status.NftWon, "status");
        vm.prank(ALICE);
        r.redeemWinningTicket(t1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        require(nft.ownerOf(1) == ALICE, "nft delivered");
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 11_400_000, "sponsor 95%");
        _eq(usdc.balanceOf(TREASURY), 600_000, "treasury 5%");
        _eq(usdc.balanceOf(address(r)), 0, "residual balance");
        _eq(r.accountedQuoteBalance(), 0, "residual ledger");
    }

    function test_cashWon_allClaimsDrainExactly() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 100);
        _buy(r, usdc, ALICE, 7);
        uint256 t2 = _buy(r, usdc, BOB, 5);
        _draw(r, 8); // entry 9, inside bob's [8,12]
        require(r.status() == IRaffle.Status.CashWon, "status");
        vm.prank(BOB);
        r.redeemWinningTicket(t2);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        r.releaseSponsorPrize();
        _eq(usdc.balanceOf(BOB), 9_600_000, "winner 80%");
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 1_800_000, "sponsor 15%");
        _eq(usdc.balanceOf(TREASURY), 600_000, "treasury 5%");
        _eq(usdc.balanceOf(address(r)), 0, "residual");
        require(nft.ownerOf(1) == SPONSOR_RECIPIENT, "prize returned");
    }

    function test_refundPath_fullPar_andPrizeReturn() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 10);
        uint256 t1 = _buy(r, usdc, ALICE, 3);
        uint256 t2 = _buy(r, usdc, BOB, 4);
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(ALICE);
        r.refundTickets(_one(t1));
        vm.prank(BOB);
        r.refundTickets(_one(t2));
        r.releaseSponsorPrize();
        _eq(usdc.balanceOf(ALICE), 3e6, "alice par");
        _eq(usdc.balanceOf(BOB), 4e6, "bob par");
        _eq(usdc.balanceOf(address(r)), 0, "residual");
        require(nft.ownerOf(1) == SPONSOR_RECIPIENT, "prize back");
    }

    function testFuzz_allocationExactNoDust(uint64 a, uint64 b, uint256 word, bool meet) public {
        uint128 na = uint128(a % 1_000_000) + 1;
        uint128 nb = uint128(b % 1_000_000) + 1;
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, meet ? 1 : type(uint128).max);
        uint256 t1 = _buy(r, usdc, ALICE, na);
        uint256 t2 = _buy(r, usdc, BOB, nb);
        _draw(r, word);
        uint256 gross = (uint256(na) + nb) * 1e6;
        bool aliceWins = r.winningEntry() <= na;
        uint256 t = aliceWins ? t1 : t2;
        r.settleWinningTicket(t);
        _eq(r.winnerProceeds() + r.sponsorProceeds() + r.protocolFees(), gross, "allocation sum");
        _eq(r.protocolFees() * 20, gross, "fee exactly 5%, no flooring loss");
        vm.prank(aliceWins ? ALICE : BOB);
        r.redeemWinningTicket(t);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(address(r)), 0, "residual");
    }

    function test_noSameTxExit_capitalLockedUntilOutcome() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 10);
        uint256 t1 = _buy(r, usdc, ALICE, 5);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Active));
        r.refundTickets(_one(t1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, uint256(r.endTime()) + 2 days, block.timestamp
            )
        );
        r.enableRefunds();
    }

    function test_donationsDoNotAffectLedger() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 10);
        uint256 t = _buy(r, usdc, ALICE, 2);
        usdc.mint(address(r), 123); // unsolicited balance change outside protocol transfers
        _eq(r.accountedQuoteBalance(), 2e6, "ledger ignores donation");
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(ALICE);
        r.refundTickets(_one(t));
        _eq(usdc.balanceOf(address(r)), 123, "donation stranded (no rescue path)");
    }
}

// =====================================================================================================================
// T2: quote-token weird behaviours (USDC upgrade/blocklist/pause; USDT- and ZRX-style returns)
// =====================================================================================================================
contract T2_QuoteTokenBehaviour is Base {
    function test_feeOnTransferUpgrade_overCreditsAndStrandsLastRefund() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 10);
        usdc.setFeeBps(100); // hypothetical proxy upgrade that introduces a 1% transfer fee
        uint256 t1 = _buy(r, usdc, ALICE, 50);
        uint256 t2 = _buy(r, usdc, BOB, 50);
        _eq(r.accountedQuoteBalance(), 100e6, "credited");
        _eq(usdc.balanceOf(address(r)), 99e6, "received");
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(ALICE);
        r.refundTickets(_one(t1));
        vm.prank(BOB);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        r.refundTickets(_one(t2));
    }

    function test_noReturnToken_supportedBySafeERC20() public {
        NoReturnUSD q = new NoReturnUSD();
        RaffleFactory f = new RaffleFactory(address(q), address(vrf), TREASURY);
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(f, address(nft), 1, 10);
        q.mint(ALICE, 5e6);
        vm.startPrank(ALICE);
        q.approve(address(r), 5e6);
        uint256 t = r.buyEntries(ALICE, 5);
        vm.stopPrank();
        _eq(q.balanceOf(address(r)), 5e6, "pulled");
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(ALICE);
        r.refundTickets(_one(t));
        _eq(q.balanceOf(ALICE), 5e6, "refunded");
    }

    function test_falseReturnToken_failsClosed() public {
        FalseReturnUSD q = new FalseReturnUSD();
        RaffleFactory f = new RaffleFactory(address(q), address(vrf), TREASURY);
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(f, address(nft), 1, 10);
        vm.prank(ALICE); // no balance, no allowance: token returns false instead of reverting
        vm.expectRevert(abi.encodeWithSignature("SafeERC20FailedOperation(address)", address(q)));
        r.buyEntries(ALICE, 1);
        _eq(r.ticketCount(), 0, "no ticket");
    }

    function test_blocklistedSponsorRecipient_freezesOnlySponsorProceeds() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 100);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _draw(r, 0); // CashWon, entry 1
        usdc.blacklist(SPONSOR_RECIPIENT);
        vm.prank(ALICE);
        r.redeemWinningTicket(t1); // winner unaffected
        r.releaseProtocolFees(); // treasury unaffected
        r.releaseSponsorPrize(); // NFT path unaffected
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        r.releaseSponsorProceeds(); // no alternate destination exists
        _eq(r.sponsorProceeds(), 1_500_000, "sponsor proceeds stranded");
    }

    function test_blocklistedTreasury_freezesFeesInEveryRaffle() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        nft.mint(SPONSOR, 2);
        IRaffle r1 = _create(factory, address(nft), 1, 1);
        IRaffle r2 = _create(factory, address(nft), 2, 1);
        _buy(r1, usdc, ALICE, 10);
        _buy(r2, usdc, BOB, 10);
        _draw(r1, 0);
        _draw(r2, 0);
        r1.settleWinningTicket(1);
        r2.settleWinningTicket(1);
        usdc.blacklist(TREASURY);
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        r1.releaseProtocolFees();
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        r2.releaseProtocolFees();
        r1.releaseSponsorProceeds(); // independent claims still work
        r2.releaseSponsorProceeds();
        _eq(r1.protocolFees() + r2.protocolFees(), 1e6, "fees stranded across raffles");
    }

    function test_blocklistedWinner_recoversByTransferringTicket() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 100);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _draw(r, 0); // CashWon
        usdc.blacklist(ALICE);
        vm.prank(ALICE);
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        r.redeemWinningTicket(t1);
        vm.prank(ALICE);
        IERC721(address(r)).transferFrom(ALICE, CAROL, t1);
        vm.prank(CAROL);
        r.redeemWinningTicket(t1);
        _eq(usdc.balanceOf(CAROL), 8e6, "claim redirected via bearer ticket");
    }

    function test_blocklistedClone_freezesThatCloneOnly() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        nft.mint(SPONSOR, 2);
        IRaffle r1 = _create(factory, address(nft), 1, 10);
        IRaffle r2 = _create(factory, address(nft), 2, 10);
        uint256 a = _buy(r1, usdc, ALICE, 2);
        uint256 b = _buy(r2, usdc, BOB, 2);
        usdc.blacklist(address(r1));
        vm.warp(uint256(r1.endTime()) + 2 days);
        r1.enableRefunds();
        r2.enableRefunds();
        vm.prank(ALICE);
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        r1.refundTickets(_one(a));
        vm.prank(BOB);
        r2.refundTickets(_one(b));
        _eq(usdc.balanceOf(BOB), 2e6, "other clone unaffected");
    }

    function test_pausedUSDC_delaysButNeverExpiresClaims() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 100);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _draw(r, 0); // CashWon
        usdc.setPaused(true);
        vm.warp(block.timestamp + 365 days);
        vm.prank(ALICE);
        vm.expectRevert(bytes("Pausable: paused"));
        r.redeemWinningTicket(t1);
        usdc.setPaused(false);
        vm.prank(ALICE);
        r.redeemWinningTicket(t1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(address(r)), 0, "all claims paid after unpause");
    }
}

// =====================================================================================================================
// T3: arbitrary / weird / malicious ERC-721 prize contracts
// =====================================================================================================================
contract T3_PrizeTokenBehaviour is Base {
    function test_noCallbackNFT_creationFailsClosed() public {
        NoCallbackNFT nft = new NoCallbackNFT();
        nft.mint(SPONSOR, 1);
        address predicted = _nextClone(address(factory), 0);
        vm.startPrank(SPONSOR);
        nft.setApprovalForAll(address(factory), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffleFactory.PrizeEscrowVerificationFailed.selector, predicted, address(nft), uint256(1)
            )
        );
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(nft),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        require(nft.ownerOf(1) == SPONSOR, "nft not lost");
        _eq(factory.raffleCount(), 0, "nothing registered");
    }

    function test_lyingNFT_activeWithoutEscrow_nftWonPaysSponsorOnly() public {
        LyingNFT nft = new LyingNFT();
        IRaffle r = _create(factory, address(nft), 1, 1);
        require(r.status() == IRaffle.Status.Active, "active with no real escrow");
        uint256 t1 = _buy(r, usdc, ALICE, 100);
        _draw(r, 0);
        require(r.status() == IRaffle.Status.NftWon, "nftwon");
        vm.prank(ALICE);
        vm.expectRevert(bytes("rug"));
        r.redeemWinningTicket(t1);
        r.settleWinningTicket(t1); // permissionless, storage-only
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 95e6, "sponsor collected 95%");
        _eq(usdc.balanceOf(TREASURY), 5e6, "treasury collected 5%");
        _eq(usdc.balanceOf(ALICE), 0, "winner received nothing");
    }

    function test_staleApprovalNFT_sponsorPullsPrizeOutOfEscrow() public {
        StaleApprovalNFT nft = new StaleApprovalNFT();
        nft.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        nft.approve(SPONSOR_ALT, 1); // survives the escrow transfer on this non-conformant collection
        IRaffle r = _create(factory, address(nft), 1, 1);
        require(nft.ownerOf(1) == address(r), "escrow verified at creation");
        uint256 t1 = _buy(r, usdc, ALICE, 100);
        vm.prank(SPONSOR_ALT);
        nft.transferFrom(address(r), SPONSOR_ALT, 1); // prize silently leaves escrow
        _draw(r, 0);
        require(r.status() == IRaffle.Status.NftWon, "nftwon");
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("ERC721InsufficientApproval(address,uint256)", address(r), 1));
        r.redeemWinningTicket(t1);
        r.settleWinningTicket(t1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 95e6, "sponsor 95%");
        require(nft.ownerOf(1) == SPONSOR_ALT, "sponsor also kept the NFT");
    }

    function test_expiringNFT_prizeLapsesInEscrow() public {
        ExpiringNFT nft = new ExpiringNFT();
        nft.mint(SPONSOR, 1);
        nft.setExpiry(1, block.timestamp + 1 days - 1); // lapses just before the sale ends
        IRaffle r = _create(factory, address(nft), 1, 1);
        uint256 t1 = _buy(r, usdc, ALICE, 100);
        _draw(r, 0); // warps to endTime: the prize has already lapsed
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", uint256(1)));
        r.redeemWinningTicket(t1);
        r.settleWinningTicket(t1);
        r.releaseSponsorProceeds();
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 95e6, "sponsor 95% despite undeliverable prize");
    }

    function test_silentNFT_deliveryCheckRevertsAndPreservesTicket() public {
        SilentNFT nft = new SilentNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 1);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _draw(r, 0);
        nft.setSilent(true);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.PrizeDeliveryVerificationFailed.selector, ALICE));
        r.redeemWinningTicket(t1);
        require(IERC721(address(r)).ownerOf(t1) == ALICE, "ticket preserved");
        require(!r.winnerRedeemed() && !r.prizeClaimed(), "no state change");
        nft.setSilent(false);
        vm.prank(ALICE);
        r.redeemWinningTicket(t1);
        require(nft.ownerOf(1) == ALICE, "delivered on retry");
    }

    function test_pausedPrize_inCashWon_blocksOnlySponsorPrize() public {
        PausableNFT nft = new PausableNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 100);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _draw(r, 0); // CashWon
        nft.setPaused(true);
        vm.prank(ALICE);
        r.redeemWinningTicket(t1); // cash path does not touch the prize contract
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        vm.expectRevert(bytes("paused"));
        r.releaseSponsorPrize();
        nft.setPaused(false);
        r.releaseSponsorPrize();
        require(nft.ownerOf(1) == SPONSOR_RECIPIENT, "returned once unpaused");
    }

    function test_reentrantPrize_cannotReenterDuringDelivery() public {
        ReentrantNFT nft = new ReentrantNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 1);
        uint256 t1 = _buy(r, usdc, ALICE, 10);
        _buy(r, usdc, BOB, 10);
        _draw(r, 0); // NftWon, alice
        nft.arm(address(r));
        vm.prank(ALICE);
        r.redeemWinningTicket(t1);
        require(nft.attempted() && nft.reentryBlocked(), "reentry blocked by nonReentrant");
        require(nft.ownerOf(1) == ALICE, "delivered");
    }
}

// =====================================================================================================================
// T4: raffle ticket ERC-721 conformity and common risks
// =====================================================================================================================
contract T4_TicketERC721 is Base {
    IRaffle internal r;
    StdNFT internal nft;

    function setUp() public override {
        super.setUp();
        nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        r = _create(factory, address(nft), 1, 10);
    }

    function test_cloneMetadataAndInterfaces() public view {
        require(keccak256(bytes(IERC721Metadata(address(r)).name())) == keccak256("raffle.fun Ticket"), "name");
        require(keccak256(bytes(IERC721Metadata(address(r)).symbol())) == keccak256("RAFFLE"), "symbol");
        require(IERC165(address(r)).supportsInterface(0x80ac58cd), "erc721");
        require(IERC165(address(r)).supportsInterface(0x5b5e139f), "metadata");
        require(IERC165(address(r)).supportsInterface(0x01ffc9a7), "erc165");
        require(!IERC165(address(r)).supportsInterface(0xffffffff), "0xffffffff");
    }

    function test_tokenURIEmpty_andRevertsForUnknown() public {
        uint256 t = _buy(r, usdc, ALICE, 1);
        require(bytes(IERC721Metadata(address(r)).tokenURI(t)).length == 0, "empty uri");
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", uint256(99)));
        IERC721Metadata(address(r)).tokenURI(99);
    }

    function test_transferToZeroReverts() public {
        uint256 t = _buy(r, usdc, ALICE, 1);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("ERC721InvalidReceiver(address)", address(0)));
        IERC721(address(r)).transferFrom(ALICE, address(0), t);
    }

    function test_transferClearsApproval() public {
        uint256 t = _buy(r, usdc, ALICE, 1);
        vm.prank(ALICE);
        IERC721(address(r)).approve(CAROL, t);
        vm.prank(ALICE);
        IERC721(address(r)).transferFrom(ALICE, BOB, t);
        require(IERC721(address(r)).getApproved(t) == address(0), "cleared");
    }

    function test_refundBurnClearsApproval_ownerOfReverts() public {
        uint256 t = _buy(r, usdc, ALICE, 2);
        vm.prank(ALICE);
        IERC721(address(r)).approve(CAROL, t);
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(ALICE);
        r.refundTickets(_one(t));
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", t));
        IERC721(address(r)).ownerOf(t);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", t));
        IERC721(address(r)).getApproved(t);
        (uint128 a, uint128 b) = r.ticketRange(t);
        require(a == 1 && b == 2, "historical range retained, id never reused");
    }

    function test_protocolDestinationsCannotHoldTickets() public {
        StdNFT nft2 = new StdNFT();
        nft2.mint(SPONSOR, 7);
        IRaffle other = _create(factory, address(nft2), 7, 10);
        uint256 t = _buy(r, usdc, ALICE, 1);
        address[7] memory sinks = [
            address(r),
            address(factory),
            address(usdc),
            address(vrf),
            address(nft),
            factory.raffleImplementation(),
            address(other)
        ];
        for (uint256 i; i < sinks.length; ++i) {
            vm.prank(ALICE);
            vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, sinks[i]));
            IERC721(address(r)).transferFrom(ALICE, sinks[i], t);
        }
        usdc.mint(ALICE, 1e6);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(other)));
        r.buyEntries(address(other), 1);
    }

    function test_safeMintReceiverReentrancyBlocked() public {
        ReentrantTicketReceiver rec = new ReentrantTicketReceiver();
        rec.arm(r);
        usdc.mint(ALICE, 1e6);
        vm.startPrank(ALICE);
        usdc.approve(address(r), 1e6);
        r.buyEntries(address(rec), 1);
        vm.stopPrank();
        require(rec.reentryBlocked(), "reentry blocked");
        _eq(r.ticketCount(), 1, "one ticket");
    }

    function test_rejectingReceiverRevertsPurchaseAtomically() public {
        RejectingReceiver rec = new RejectingReceiver();
        usdc.mint(ALICE, 1e6);
        vm.startPrank(ALICE);
        usdc.approve(address(r), 1e6);
        vm.expectRevert(bytes("no tickets"));
        r.buyEntries(address(rec), 1);
        vm.stopPrank();
        _eq(usdc.balanceOf(ALICE), 1e6, "no funds taken");
    }

    function test_approvedOperatorCannotRefund() public {
        uint256 t = _buy(r, usdc, ALICE, 1);
        vm.prank(ALICE);
        IERC721(address(r)).setApprovalForAll(CAROL, true);
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        vm.prank(CAROL);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, t, CAROL, ALICE));
        r.refundTickets(_one(t));
    }
}

// =====================================================================================================================
// T5: edge cases
// =====================================================================================================================
contract T5_EdgeCases is Base {
    function test_counterfactualCloneAsSponsorRecipient() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        address futureClone = _nextClone(address(factory), 1); // address the *next-but-one* clone will occupy
        vm.startPrank(SPONSOR);
        nft.setApprovalForAll(address(factory), true);
        IRaffle r1 = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: futureClone,
                    prizeToken: address(nft),
                    prizeTokenId: 1,
                    reserveEntries: 100,
                    endTime: uint64(block.timestamp + 1 days)
                })
            )
        );
        vm.stopPrank();
        StdNFT nft2 = new StdNFT();
        nft2.mint(SPONSOR, 2);
        IRaffle r2 = _create(factory, address(nft2), 2, 100);
        require(address(r2) == futureClone, "prediction");
        uint256 t = _buy(r1, usdc, ALICE, 10);
        _draw(r1, 0); // CashWon
        vm.prank(ALICE);
        r1.redeemWinningTicket(t);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, futureClone));
        r1.releaseSponsorProceeds(); // USDC path re-screens the destination at runtime
        r1.releaseSponsorPrize(); // NFT path does not
        require(nft.ownerOf(1) == address(r2), "prize moved into a different raffle clone");
    }

    function test_sponsorReserveTopUp_economics() public {
        StdNFT nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        IRaffle r = _create(factory, address(nft), 1, 1000);
        uint256 tA = _buy(r, usdc, ALICE, 500); // organic demand: 500 of a 1,000-entry reserve
        _buy(r, usdc, SPONSOR_ALT, 500); // sponsor-controlled wallet tops up the reserve
        _draw(r, 0); // entry 1: alice wins the NFT instead of 400 USDC cash
        require(r.status() == IRaffle.Status.NftWon, "forced NftWon");
        vm.prank(ALICE);
        r.redeemWinningTicket(tA);
        r.releaseSponsorProceeds();
        // Sponsor side paid 500 and received 950 (+450). Without the top-up: CashWon, sponsor +75 and NFT back,
        // alice +400 cash.
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 950e6, "sponsor proceeds");
    }

    function test_implementationLocked() public {
        IRaffle impl = IRaffle(factory.raffleImplementation());
        require(impl.initialized() && impl.status() == IRaffle.Status.Refunding, "locked");
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        impl.initialize(
            IRaffle.RaffleInitParams({
                sponsor: SPONSOR,
                sponsorRecipient: SPONSOR_RECIPIENT,
                protocolTreasury: TREASURY,
                prizeToken: address(1),
                prizeTokenId: 1,
                raffleId: 1,
                reserveEntries: 1,
                endTime: 2
            })
        );
        vm.expectRevert();
        impl.releaseSponsorPrize(); // prizeToken is address(0): high-level call to a code-less target reverts
    }
}
```

</details>

<details>
<summary><code>test/Invariants.t.sol</code></summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "../src/RaffleFactory.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./Mocks.sol";

/// Randomised lifecycle driver over two raffles (one NFT-biased reserve, one cash-biased reserve).
contract Handler {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant KEEPER = address(0x4EE9);

    MockUSDC public immutable usdc;
    MockVRFWrapper public immutable vrf;
    IRaffle[2] public raffles;
    address[4] public actors = [address(0xA1), address(0xA2), address(0xA3), address(0xA4)];
    uint256[2] public totalIn;
    uint256[2] public totalOut;
    uint256[2] public pendingRequest;
    uint256 public calls;
    uint256 public refundsOk;
    uint256[2] public redeemsOk;
    uint256 public prizeReturns;

    constructor(MockUSDC u, MockVRFWrapper v, IRaffle r0, IRaffle r1) {
        usdc = u;
        vrf = v;
        raffles[0] = r0;
        raffles[1] = r1;
    }

    function _bound(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        return lo + (x % (hi - lo + 1));
    }

    function _liveTicket(IRaffle r, uint256 seed) internal view returns (uint256 id, address owner) {
        uint256 count = r.ticketCount();
        if (count == 0) return (0, address(0));
        id = seed % count + 1;
        try IERC721(address(r)).ownerOf(id) returns (address o) {
            owner = o;
        } catch {
            id = 0;
        }
    }

    function buy(uint256 rs, uint256 actorSeed, uint256 n) external {
        ++calls;
        uint256 i = rs % 2;
        IRaffle r = raffles[i];
        if (r.status() != IRaffle.Status.Active || block.timestamp >= r.endTime()) return;
        uint128 entries = uint128(_bound(n, 1, 1000));
        address a = actors[actorSeed % 4];
        uint256 amt = uint256(entries) * 1e6;
        usdc.mint(a, amt);
        vm.startPrank(a);
        usdc.approve(address(r), amt);
        r.buyEntries(a, entries);
        vm.stopPrank();
        totalIn[i] += amt;
    }

    function transferTicket(uint256 rs, uint256 ticketSeed, uint256 toSeed) external {
        ++calls;
        IRaffle r = raffles[rs % 2];
        (uint256 id, address owner) = _liveTicket(r, ticketSeed);
        if (id == 0) return;
        vm.prank(owner);
        IERC721(address(r)).transferFrom(owner, actors[toSeed % 4], id);
    }

    function warp(uint256 dt) external {
        ++calls;
        vm.warp(block.timestamp + _bound(dt, 0, 3 days));
    }

    function requestDraw(uint256 rs) external {
        ++calls;
        uint256 i = rs % 2;
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        try raffles[i].requestDraw{ value: 0.002 ether }() returns (uint256 id) {
            pendingRequest[i] = id;
        } catch { }
    }

    function fulfill(uint256 rs, uint256 word) external {
        ++calls;
        uint256 i = rs % 2;
        if (pendingRequest[i] == 0) return;
        vrf.fulfill(pendingRequest[i], word);
        pendingRequest[i] = 0;
    }

    function enableRefunds(uint256 rs, bool asSponsor) external {
        ++calls;
        if (asSponsor) vm.prank(address(0x5905));
        try raffles[rs % 2].enableRefunds() { } catch { }
    }

    function refund(uint256 rs, uint256 ticketSeed) external {
        ++calls;
        uint256 i = rs % 2;
        IRaffle r = raffles[i];
        (uint256 id, address owner) = _liveTicket(r, ticketSeed);
        if (id == 0) return;
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        vm.prank(owner);
        try r.refundTickets(ids) returns (uint256 amt) {
            totalOut[i] += amt;
            ++refundsOk;
        } catch { }
    }

    function redeem(uint256 rs, bool settleFirst) external {
        ++calls;
        uint256 i = rs % 2;
        IRaffle r = raffles[i];
        IRaffle.Status s = r.status();
        if ((s != IRaffle.Status.NftWon && s != IRaffle.Status.CashWon) || r.winnerRedeemed()) return;
        uint128 w = r.winningEntry();
        uint256 count = r.ticketCount();
        for (uint256 id = 1; id <= count; ++id) {
            (uint128 a, uint128 b) = r.ticketRange(id);
            if (w >= a && w <= b) {
                if (settleFirst && !r.settlementComplete()) r.settleWinningTicket(id);
                address owner = IERC721(address(r)).ownerOf(id);
                vm.prank(owner);
                totalOut[i] += r.redeemWinningTicket(id);
                ++redeemsOk[i];
                return;
            }
        }
        revert("winning ticket not found");
    }

    function releaseSponsorProceeds(uint256 rs) external {
        ++calls;
        uint256 i = rs % 2;
        try raffles[i].releaseSponsorProceeds() returns (uint256 a) {
            totalOut[i] += a;
        } catch { }
    }

    function releaseProtocolFees(uint256 rs) external {
        ++calls;
        uint256 i = rs % 2;
        try raffles[i].releaseProtocolFees() returns (uint256 a) {
            totalOut[i] += a;
        } catch { }
    }

    function releaseSponsorPrize(uint256 rs) external {
        ++calls;
        try raffles[rs % 2].releaseSponsorPrize() {
            ++prizeReturns;
        } catch { }
    }
}

abstract contract InvBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant TREASURY = address(0x7EA5);
    address internal constant SPONSOR = address(0x5905);
    address internal constant SPONSOR_RECIPIENT = address(0x5EC1);

    MockUSDC internal usdc;
    MockVRFWrapper internal vrf;
    RaffleFactory internal factory;
    StdNFT internal nft;
    IRaffle[2] internal raffles;
    Handler internal h;

    function setUp() public {
        usdc = new MockUSDC();
        vrf = new MockVRFWrapper();
        factory = new RaffleFactory(address(usdc), address(vrf), TREASURY);
        nft = new StdNFT();
        nft.mint(SPONSOR, 1);
        nft.mint(SPONSOR, 2);
        vm.startPrank(SPONSOR);
        nft.setApprovalForAll(address(factory), true);
        for (uint256 i; i < 2; ++i) {
            raffles[i] = IRaffle(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: SPONSOR_RECIPIENT,
                        prizeToken: address(nft),
                        prizeTokenId: i + 1,
                        reserveEntries: i == 0 ? 1 : 5000,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                )
            );
        }
        vm.stopPrank();
        h = new Handler(usdc, vrf, raffles[0], raffles[1]);
    }

    function targetContracts() public view returns (address[] memory a) {
        a = new address[](1);
        a[0] = address(h);
    }
}

contract T6_Invariants is InvBase {
    /// Quote-token balance always equals the internal ledger (standard, fee-free USDC; no donations in the driver).
    function invariant_balanceEqualsLedger() public view {
        for (uint256 i; i < 2; ++i) {
            require(usdc.balanceOf(address(raffles[i])) == raffles[i].accountedQuoteBalance(), "balance != ledger");
        }
    }

    /// Value conservation: everything paid in is either still held or was paid out by a protocol claim.
    function invariant_conservation() public view {
        for (uint256 i; i < 2; ++i) {
            require(h.totalIn(i) == h.totalOut(i) + usdc.balanceOf(address(raffles[i])), "conservation");
        }
    }

    /// While refunding, the remaining liability equals the par value of exactly the unburned tickets.
    function invariant_refundLiabilityMatchesLiveTickets() public view {
        for (uint256 i; i < 2; ++i) {
            IRaffle r = raffles[i];
            if (r.status() != IRaffle.Status.Refunding) continue;
            uint256 live;
            uint256 count = r.ticketCount();
            for (uint256 id = 1; id <= count; ++id) {
                try IERC721(address(r)).ownerOf(id) returns (address) {
                    (uint128 a, uint128 b) = r.ticketRange(id);
                    live += (uint256(b) - a + 1) * 1e6;
                } catch { }
            }
            require(r.remainingRefundLiability() == live, "refund liability mismatch");
        }
    }

    /// The prize is in exactly one place consistent with the lifecycle.
    function invariant_prizeLocation() public view {
        for (uint256 i; i < 2; ++i) {
            IRaffle r = raffles[i];
            address o = nft.ownerOf(i + 1);
            if (!r.prizeClaimed()) {
                require(o == address(r), "prize left escrow without a claim");
            } else if (r.status() == IRaffle.Status.NftWon) {
                require(o == r.winnerRecipient(), "nft not with winner");
            } else {
                require(o == SPONSOR_RECIPIENT, "nft not with sponsor recipient");
            }
        }
    }

    /// Settlement never leaves dust: allocations are exact multiples of the 5% fee unit.
    function invariant_feeExact() public view {
        for (uint256 i; i < 2; ++i) {
            IRaffle r = raffles[i];
            if (!r.settlementComplete()) continue;
            require(r.grossSales() % 20 == 0, "gross not fee-divisible");
        }
    }

    function invariant_callSummary() public view {
        h.calls();
    }
}

/// Canary properties that SHOULD break: each failure proves the fuzzer reaches that lifecycle branch.
contract T7_ReachabilityProbes is InvBase {
    function invariant_probe_nftWonRedeemed() public view {
        require(h.redeemsOk(0) == 0 || raffles[0].status() != IRaffle.Status.NftWon, "REACHED: NftWon redemption");
    }

    function invariant_probe_cashWonRedeemed() public view {
        require(h.redeemsOk(1) == 0 || raffles[1].status() != IRaffle.Status.CashWon, "REACHED: CashWon redemption");
    }

    function invariant_probe_refundPaid() public view {
        require(h.refundsOk() == 0, "REACHED: refund paid");
    }

    function invariant_probe_prizeReturned() public view {
        require(h.prizeReturns() == 0, "REACHED: prize returned to sponsor recipient");
    }

    function invariant_probe_fullyDrainedAfterWin() public view {
        for (uint256 i; i < 2; ++i) {
            IRaffle r = raffles[i];
            require(
                !(r.winnerRedeemed() && r.sponsorProceeds() == 0 && r.protocolFees() == 0
                        && usdc.balanceOf(address(r)) == 0),
                "REACHED: settled raffle fully drained"
            );
        }
    }
}
```

</details>

---

*End of report.*
