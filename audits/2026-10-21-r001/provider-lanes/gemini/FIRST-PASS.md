# First-Pass Cold Source-Only Security Audit Report (`FIRST-PASS.md`)

- **Run ID**: `2026-10-21-r001`
- **Provider Lane**: Google Gemini (`gemini-4-argon`, Gemini 4 Argon (High))
- **Runner**: `/Applications/Antigravity.app/Contents/Resources/bin/language_server` (`hub-2.25.0`)
- **Frozen Target Commit**: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Cold-Pass Isolation Declaration**: This report was produced and sealed strictly from the 5 in-scope production Solidity files (`Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, `RaffleConstants.sol`), architecture docs (`README.md`, `DESIGN.md`, `ARCHITECTURE.md`, `docs/SECURITY.md`), and imported library dependencies (`@openzeppelin/contracts`, `@chainlink/contracts`). Zero test files (`packages/contracts/test/**`), zero historical audits (`packages/contracts/audit/**`, `packages/contracts/audit-corpus/**`), and zero peer provider lanes (`audits/2026-10-21-r001/provider-lanes/{codex,claude}`) were read prior to sealing `FIRST-PASS.md.sha256`.

---

## 1. Cold-Pass Cell Execution Summary

| Cell ID | Harness & Pinned Commit | Cold Execution Status | Output Artifact |
|---|---|---|---|
| `GEMINI-SIMAO` | `0xSimao/solidity-auditor` @ `29fd7da75a13d34fc500912334603ff62dc15897` | **COMPLETED** (Money Map + 12 parallel specialist lens subagents + Turn 6 4-gate adjudication) | `runs/GEMINI-SIMAO/attempt-01/REPORT.md` |
| `GEMINI-PASHOV` | `pashov/skills` (`solidity-auditor`) @ `b3fd9ebbbd3fc4f0bd6dc6dad9ceb2dc9dffd6fa` | **COMPLETED** (12 parallel specialist & gap-hunter subagents + Turn 4 judging + Turn 5 `assemble.sh`) | `runs/GEMINI-PASHOV/attempt-01/REPORT.md` |
| `GEMINI-TOB` | `trailofbits/skills` @ `82fe8226252622fa807643bdca1710901198553a` | **COMPLETED** (All 6 declared stages: `audit-context-building`, `entry-point-analyzer`, `token-integration-analyzer`, `guidelines-advisor`, `spec-to-code-compliance`, `secure-workflow-guide` + `code-maturity-assessor`) | `runs/GEMINI-TOB/attempt-01/REPORT.md` |
| `GEMINI-GEBAL` | `gebal` @ `fd0fa51efebec1fc9ca4eb2ad26dddc71ecaa6aa` | **COMPLETED** (`gebal review` -> `approve` -> `run` -> `context` -> `import-review` -> `decide` -> `report` in `md`, `json`, `html`, `sarif`) | `runs/GEMINI-GEBAL/attempt-01/REPORT.md` |
| `GEMINI-OPENKRITT` | `openkritt` @ `725ea5f2bd51ff8ed29ca4f38482ca7fc0d55c05` | **BLOCKED (Pre-flight)** (Hardcoded `claude` CLI / Anthropic runtime dependency; documented in `BLOCKER.md`) | `runs/GEMINI-OPENKRITT/attempt-01/BLOCKER.md` |
| `GEMINI-SUPPLEMENTARY` | Native `gemini-4-argon` Cold Adversarial Review | **COMPLETED** (Independent manual line-by-line review) | `runs/GEMINI-SUPPLEMENTARY/attempt-01/REPORT.md` |

---

## 2. Consolidated First-Pass Findings Matrix

| Finding ID | Severity | Title | Affected Locations | Discovering Cells |
|---|---|---|---|---|
| **FP-M-01** | **Medium** | Predictable `CREATE` clone addresses bypass `_isProtocolDestination` before deployment, permanently locking quote payouts/tickets and allowing cross-clone ERC-721 prize transfers in `releaseSponsorPrize` and `redeemWinningTicket` | `RaffleFactory.sol:L125, L165-L167`, `Raffle.sol:L334, L404, L497-L502, L565, L593-L605` | `GEMINI-SIMAO` (`M-1`), `GEMINI-PASHOV` (`#1 [95]`, `#2 [92]`, `#8 [75]`), `GEMINI-TOB` (`TOB-GEMINI-01`), `GEMINI-GEBAL` (`#1`), `GEMINI-SUPPLEMENTARY` (`GEMINI-01`) |
| **FP-M-02** | **Medium** | Decoupled `releaseSponsorProceeds` in `Status.NftWon` allows sponsor to extract 95% of buyer USDC when untrusted/pausable/restricted `prizeToken` reverts in `redeemWinningTicket` | `Raffle.sol:L329-L339, L375-L382, L533-L558`, `RaffleFactory.sol:L171-L177` | `GEMINI-SIMAO` (`M-2`), `GEMINI-PASHOV` (`#3 [85]`), `GEMINI-TOB` (`TOB-GEMINI-02`), `GEMINI-GEBAL` (`#2`), `GEMINI-SUPPLEMENTARY` (`GEMINI-02`) |
| **FP-L-01** | **Low** | Discontinuous payout cliff at `totalEntries == reserveEntries` and unrestricted single-buyer under-target `requestDraw` enable sponsor self-purchase arbitrage (95% rebate) and 20% fee extraction | `Raffle.sol:L209-L236, L243-L248, L521, L539-L550` | `GEMINI-SIMAO` (`L-1`), `GEMINI-PASHOV` (`#4 [82]`, `#6 [78]`), `GEMINI-TOB` (`TOB-GEMINI-03`), `GEMINI-GEBAL` (`#3`), `GEMINI-SUPPLEMENTARY` (`GEMINI-03`) |
| **FP-L-02** | **Low** | Sponsor pre-`endTime` empty-raffle cancellation (`enableRefunds`) can be front-run by a 1-USDC `buyEntries` call, locking the prize NFT for up to 32 days (or winning it for 1 USDC if `reserveEntries == 1`) | `Raffle.sol:L209, L280-L285` | `GEMINI-SIMAO` (`L-2`), `GEMINI-PASHOV` (`#5 [80]`), `GEMINI-TOB` (`TOB-GEMINI-04`), `GEMINI-GEBAL` (`#4`), `GEMINI-SUPPLEMENTARY` (`GEMINI-04`) |
| **FP-L-03** | **Low** | `Raffle.onERC721Received` sets `Status.Active` inside `prize.safeTransferFrom` before `RaffleCreated` is emitted, allowing an untrusted `prizeToken` to call `buyEntries` mid-creation | `RaffleFactory.sol:L139-L147`, `Raffle.sol:L416-L431` | `GEMINI-SIMAO` (`L-3`), `GEMINI-PASHOV` (`#7 [76]`), `GEMINI-TOB` (`TOB-GEMINI-05`), `GEMINI-GEBAL` (`#5`), `GEMINI-SUPPLEMENTARY` (`GEMINI-05`) |
| **FP-I-01** | **Informational** | Missing upper bound on `reserveEntries`, unrestricted secondary ticket transfers during `Status.Drawing`, and ERC-1167 `ReentrancyGuard` cold-slot / `VRF_CALLBACK_GAS_LIMIT = 300_000` gas overhead | `RaffleFactory.sol:L178`, `Raffle.sol:L497-L502`, `RaffleConstants.sol:L39` | `GEMINI-SIMAO` (`I-1`, `I-2`, `I-3`), `GEMINI-TOB` (`TOB-GEMINI-06`), `GEMINI-GEBAL` (`#6`), `GEMINI-SUPPLEMENTARY` (`GEMINI-06`) |

---

## 3. Detailed Technical Specifications of First-Pass Findings

### FP-M-01: Predictable `CREATE` Clone Addresses Bypass `_isProtocolDestination` Before Deployment, Permanently Locking Quote Payouts/Tickets and Allowing Cross-Clone ERC-721 Prize Transfers

- **Severity**: Medium
- **Confidence**: High (95/100)
- **Root Cause**:
  In `RaffleFactory.createRaffle` (`RaffleFactory.sol:L125`), each `Raffle` clone is deployed via `Clones.clone(raffleImplementation)`, which uses the EVM `CREATE` opcode. Because `CREATE` derives the child address solely from `(address(factory), factoryNonce)`, the address of every future clone $R_k$ ($k \ge 1$, `factoryNonce = k + 1`) is deterministic and publicly computable before $R_k$ is deployed.
  Before $R_k$ is deployed:
  - `R_k.code.length == 0`
  - `factory.isRaffle(R_k) == false`
  Consequently:
  1. `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L166`) and `Raffle._isProtocolDestination` (`Raffle.sol:L601`: `if (!unsafeDestination && destination.code.length != 0)`) evaluate `isRaffle(R_k)` as `false`, allowing $R_k$ as `sponsorRecipient` in `initialize` and as `to` in `buyEntries` / `ERC721.transferFrom`.
  2. `ERC721Utils.checkOnERC721Received` in `_safeMint` checks `if (to.code.length > 0)` and therefore does not invoke `R_k.onERC721Received`.
  Once any user calls `createRaffle` to deploy $R_k$, `R_k.code.length == 45` and `factory.isRaffle(R_k) == true`:
  - **Locked `sponsorProceeds`**: In `Raffle.releaseSponsorProceeds()` (`Raffle.sol:L380`), `_transferQuote(R_k, amount)` (`Raffle.sol:L565`) re-checks `_isProtocolDestination(R_k, address(prizeToken))` and permanently reverts with `InvalidQuoteDestination(R_k)`.
  - **Cross-clone NFT transfer into $R_k$**: In `Raffle.releaseSponsorPrize()` (`Raffle.sol:L404`) and `Raffle.redeemWinningTicket()` (`Raffle.sol:L334`), `_isProtocolDestination` is omitted and `prizeToken.transferFrom(address(this), R_k, prizeTokenId)` transfers the prize NFT directly into clone $R_k$, violating the explicit `DESIGN.md` rule *"Never move assets between raffle clones"* and permanently stranding the NFT inside $R_k$.
  - **Permanently unclaimable tickets/refunds/prizes**: Any ticket owned by $R_k$ in an earlier raffle can never be redeemed (`redeemWinningTicket`) or refunded (`refundTickets`) because `Raffle` has no outbound call capability, and `_transferQuote(R_k, ...)` reverts.
  - **Delayed factory DoS via `protocolTreasury`**: If `protocolTreasury` is set to $R_k$ in the `RaffleFactory` constructor, `createRaffle` works for clones $1 \dots k-1$ and permanently reverts with `UnsafeProtocolDestination(R_k)` at clone $k$.
- **Recommended Mitigation**:
  1. Deploy clones in `RaffleFactory.createRaffle` using `Clones.cloneDeterministic(raffleImplementation, salt)` where `salt = keccak256(abi.encode(msg.sender, raffleId, block.prevrandao))`, or precompute deterministic clone addresses so `_isProtocolDestination` can reject them without relying on `destination.code.length != 0`.
  2. Enforce `if (_isProtocolDestination(recipient, address(prizeToken))) revert UnsafeProtocolDestination(recipient);` in `Raffle.releaseSponsorPrize()` and in the `Status.NftWon` branch of `Raffle.redeemWinningTicket()`.

---

### FP-M-02: Decoupled `releaseSponsorProceeds` in `Status.NftWon` Allows Sponsor to Extract 95% of Buyer USDC When Untrusted/Restricted `prizeToken` Fails Delivery in `redeemWinningTicket`

- **Severity**: Medium
- **Confidence**: High (85/100)
- **Root Cause**:
  `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L171-L177`) accepts any contract address that returns `true` from `IERC165.supportsInterface(0x80ac58cd)` as `prizeToken`, and `DESIGN.md` explicitly classifies arbitrary prize contracts as untrusted. However, when a raffle resolves to `Status.NftWon`, `_settleWinningTicket` (`Raffle.sol:L533-L558`) immediately allocates `95%` of `unsettledPot` to `sponsorProceeds` in storage, and `releaseSponsorProceeds()` (`Raffle.sol:L375-L382`) transfers `sponsorProceeds` to `sponsorRecipient` without requiring `prizeClaimed == true`. If `prizeToken` is pausable, blacklist-enabled, expiring, or controlled by a malicious sponsor and reverts (or fails `ownerOf == winner`) in `redeemWinningTicket` (`Raffle.sol:L334-L337`), the sponsor extracts 95% of buyer USDC while the winner cannot receive the NFT and `Status.NftWon` can never transition to `Status.Refunding`.
- **Recommended Mitigation**:
  Require `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotClaimed();` in `Raffle.releaseSponsorProceeds()` (and optionally in `releaseProtocolFees()`), or provide a recovery path to `Status.Refunding` if `prizeToken` delivery fails before sponsor proceeds are released.

---

### FP-L-01: Discontinuous Payout Cliff at `totalEntries == reserveEntries` and Unrestricted Single-Buyer Under-Target `requestDraw` Enable Sponsor Self-Purchase Arbitrage and 20% Fee Extraction

- **Severity**: Low
- **Confidence**: High (82/100)
- **Root Cause**:
  1. At `totalEntries == reserveEntries`, the sponsor's share of `unsettledPot` jumps discontinuously from `15%` (`Status.CashWon`) to `95%` (`Status.NftWon`). Because neither `sponsor` nor `sponsorRecipient` is blocked from calling `buyEntries`, a sponsor pays a net cost of `$0.05` (`5%` protocol fee) per `$1.00` entry once `totalEntries >= reserveEntries` and can buy the shortfall right before `endTime` to capture an extra `80%` of honest buyers' pot plus proportional probability of winning back their own NFT.
  2. When `totalEntries < reserveEntries` and only one buyer participated (`ticketCount == 1`), `requestDraw()` (`Raffle.sol:L243-L246`) still allows the sponsor to trigger a VRF draw at `endTime`, forcing `Status.CashWon` and extracting `20%` (`15%` `sponsorProceeds` + `5%` `protocolFees`) from the sole buyer while returning the NFT to the sponsor.
- **Recommended Mitigation**:
  Block `sponsor` and `sponsorRecipient` in `_isProtocolDestination`, and require `ticketCount >= 2` when `totalEntries < reserveEntries` in `requestDraw()`.

---

### FP-L-02: Sponsor Pre-`endTime` Empty-Raffle Cancellation (`enableRefunds`) Can Be Front-Run by a 1-USDC `buyEntries` Call

- **Severity**: Low
- **Confidence**: High (80/100)
- **Root Cause**:
  `Raffle.enableRefunds()` (`Raffle.sol:L280-L285`) allows `sponsor` to cancel a raffle before `endTime` only when `totalEntries == 0`. A mempool observer can front-run the sponsor's `enableRefunds()` transaction with `buyEntries(attacker, 1)` (`1 USDC`), setting `totalEntries = 1` and causing `enableRefunds()` to revert with `RefundsNotAvailable(endTime + 2 days, block.timestamp)`.
- **Recommended Mitigation**:
  Allow `sponsor` to invoke `enableRefunds()` before `endTime` even when `totalEntries > 0` (so buyers can claim 100% refunds in `Status.Refunding`), or introduce a `startTime` window before sales open.

---

### FP-L-03: `Raffle.onERC721Received` Sets `Status.Active` Inside `prize.safeTransferFrom` Before `RaffleCreated` Is Emitted

- **Severity**: Low
- **Confidence**: High (76/100)
- **Root Cause**:
  In `RaffleFactory.createRaffle` (`RaffleFactory.sol:L139-L147`), `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` invokes `Raffle.onERC721Received` (`Raffle.sol:L416-L431`), which sets `status = Status.Active` while the clone's `ReentrancyGuard` is unentered and before `createRaffle` checks `prize.ownerOf(params.prizeTokenId) == raffle` or emits `RaffleCreated`. An untrusted `prizeToken` can therefore call `raffle.buyEntries` inside `safeTransferFrom` before `RaffleCreated` is emitted.
- **Recommended Mitigation**:
  Emit `RaffleCreated` before `prize.safeTransferFrom`, or activate the clone via a dedicated factory call after verifying `prize.ownerOf(params.prizeTokenId) == raffle`.

---

### FP-I-01: Unbounded `reserveEntries` Upper Limit, Unrestricted Secondary Ticket Transfers During `Status.Drawing`, and ERC-1167 `ReentrancyGuard` / `VRF_CALLBACK_GAS_LIMIT` Gas Overhead

- **Severity**: Informational
- **Confidence**: High
- **Details**:
  1. `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L178`) checks `params.reserveEntries != 0` but enforces no upper bound on `uint128 reserveEntries`, allowing values exceeding total USDC supply where `Status.NftWon` is unreachable.
  2. `Raffle._update` (`Raffle.sol:L497-L502`) permits ERC-721 ticket transfers during `Status.Drawing` and after draw resolution, exposing open secondary-market orders to VRF fulfillment mempool front-running.
  3. `Raffle` uses storage-backed `ReentrancyGuard` on ERC-1167 clones (where slot `_status` starts at `0`, penalizing the first `buyEntries` caller with a 20,000-gas `0 -> 1` SSTORE) instead of `ReentrancyGuardTransient` (`cancun`), and sets `VRF_CALLBACK_GAS_LIMIT = 300_000` (`RaffleConstants.sol:L39`) when `fulfillRandomWords` uses ~50,000 gas.
