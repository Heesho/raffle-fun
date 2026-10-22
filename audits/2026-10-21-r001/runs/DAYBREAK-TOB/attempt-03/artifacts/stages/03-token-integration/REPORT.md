# Native S3 Token Integration Analyzer Report

## Audit identity

- **Stage:** S3 — Trail of Bits `token-integration-analyzer`
- **Target SHA:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Analysis date:** 2026-10-21
- **Platform:** Solidity/EVM, Solidity `0.8.36`
- **Requested and accepted local model:** `gpt-daybreak-blue-latest`
- **Cybersecurity access program:** `daybreak_blue`
- **Reasoning effort:** `ultra`
- **Fallback:** disabled
- **Provider-returned model identity:** `unknown`
- **Provider identity:** `unknown`
- **Identity limitation:** no JSON event-stream identity was supplied to this stage.

## Scope and exposure statement

The source-only scope was read in full:

- all five first-party production files;
- all 31 reachable dependency files listed in `target/dependency-hashes.json`;
- `target/DESIGN.md`;
- the complete inherited S1 dossier;
- the pinned `token-integration-analyzer` skill, assessment categories, and report templates.

All 31 dependency files matched their pinned SHA-256 values in `dependency-hashes.json`.

The target was not edited. No Slither command, test, compiler, scanner, RPC query, other audit, other cell, peer-stage report, or attempt-02 artifact was run or read. Slither ERC-conformance checks, generated properties, and dynamic conformance testing are deferred to the sealed S6 workflow. This report therefore completes the skill’s manual source-analysis path but does not claim tool-certified ERC conformance.

No deployed address or RPC endpoint was supplied. Scarcity, holder distribution, live balances, proxy/admin state, pause/blocklist state, deployed implementation identity, and exchange distribution were **not performed and are not guessed**.

---

## Executive summary

The system has four distinct token-facing surfaces:

| Surface | Source conclusion | Risk |
|---|---|---:|
| Raffle ticket ERC-721 implementation | Manual conformity pass through pinned OpenZeppelin inheritance. Safe minting, approval clearing, owner checks, safe transfers, and atomic claim burns are present. | Low |
| Configured ERC-20 quote token | SafeERC20 correctly handles missing/false return values, and every factory fixes one six-decimal address. Exact-balance accounting nevertheless depends entirely on the documented fee-free, non-rebasing canonical-token assumption. | Medium, conditional |
| Sponsor-selected ERC-721 prize | The factory accepts arbitrary self-reported ERC-721 behavior. ERC-165, callback fields, `ownerOf`, future custody, and delivery are all controlled by the selected token. This conflicts with `DESIGN.md` treating prize contracts as untrusted. | High |
| Chainlink wrapper | Caller authentication and timeout handling are locally sound, but request pricing, request-ID binding, randomness, retry behavior, and wrapper upgradeability are external trust properties. | Medium, trusted dependency |

### Risk conclusion

**Overall source-only risk: HIGH if arbitrary prize contracts are truly untrusted, as `DESIGN.md:L2` states.**

Under a narrower operational model in which:

1. deployment tooling pins the intended canonical quote token and Chainlink wrapper;
2. the quote token remains exact-transfer, fee-free, and non-rebasing; and
3. prize collections are independently vetted as honest ERC-721 implementations,

the residual integration risk is **MEDIUM**.

### Source-derived findings

| ID | Severity | Finding |
|---|---:|---|
| H-01 | High | Arbitrary prize self-attestation cannot guarantee custody or delivery, yet NFT-result quote proceeds can be released independently of successful prize redemption. |
| M-01 | Medium | Recorded quote liabilities use requested amounts rather than observed balance changes and are solvent only under the documented exact-transfer token assumption. |
| M-02 | Medium | Prize delivery uses unsafe `transferFrom`, bypassing contract-recipient acceptance while treating `ownerOf` as completed delivery. |
| L-01 | Low | The prize callback activates the raffle before the factory finishes creation, permitting paid clone mutations before `RaffleCreated`. |

No critical ticket-implementation conformity defect was found in the manual source pass.

---

# Findings

## H-01 — Arbitrary prize self-attestation cannot guarantee custody or delivery

### Code facts

- Any sponsor may choose the prize address: `src/RaffleFactory.sol:L97-L119`.
- Validation only requires deployed code and a successful, true self-report from `supportsInterface`: `src/RaffleFactory.sol:L154-L177`.
- The token controls its own `safeTransferFrom`, receiver invocation, callback arguments, and subsequent `ownerOf` response: `src/RaffleFactory.sol:L127-L134`.
- `Raffle.onERC721Received` validates an exact tuple, but `msg.sender` is the selected token and that token supplies `operator`, `from`, and `tokenId`: `src/Raffle.sol:L416-L430`.
- On `NftWon`, settlement immediately allocates 95% of the quote pot to the sponsor and 5% to the protocol: `src/Raffle.sol:L533-L557`.
- Those quote claims can be released without successful prize redemption: `src/Raffle.sol:L374-L391`.
- Prize redemption happens independently and relies on the token’s `transferFrom` and `ownerOf`: `src/Raffle.sol:L309-L345`.
- Once status is `NftWon`, there is no prize-failure transition to refunds: `src/Raffle.sol:L275-L300`.

### Trust-model conflict

- `DESIGN.md:L2` states that arbitrary prize contracts are untrusted.
- `src/interfaces/IRaffle.sol:L12-L15` instead assumes supported prizes are honest, standards-compliant ERC-721s.

The implementation enforces the latter assumption, not the former threat model.

### Impact

A malicious, upgradeable, paused, blacklist-capable, burnable, or otherwise nonstandard prize can:

1. self-report ERC-721 support;
2. fabricate initial custody through its callback and `ownerOf`;
3. later prevent delivery or report fictional delivery;
4. leave the winner without a usable prize or permanently unable to redeem; and
5. still allow sponsor and protocol quote proceeds to be paid after settlement.

If prize transfer reverts, local state and the winning-ticket burn correctly roll back, but there is no recovery branch. If the token returns success and lies through `ownerOf`, redemption can finalize and burn the ticket without delivery of a genuine asset.

### Recommendation

Reconcile the threat model before deployment:

- If prize contracts are genuinely untrusted, do not rely on ERC-165 and `ownerOf` as authenticity proofs. Use a vetted collection allowlist, immutable adapters/wrappers, or an external curation policy anchored to the canonical factory.
- In `NftWon`, gate sponsor/protocol quote release on successful winner redemption. This does not defeat a fully malicious token, but it prevents proceeds from leaving while an honest-but-paused or receiver-incompatible prize remains undelivered.
- Define a timeout/fallback policy for an escrowed prize that becomes nontransferable.
- Make the user-facing trust boundary explicit: the protocol cannot prove the economic authenticity or future behavior of arbitrary NFT code.

---

## M-01 — Quote liabilities are based on requested amounts, not observed custody

### Code facts

- Construction verifies only code presence and `decimals() == 6`: `src/RaffleFactory.sol:L58-L78`.
- Canonical identity is expressly delegated to deployment tooling: `src/RaffleFactory.sol:L59-L63`.
- Purchases call `safeTransferFrom` and then credit the full requested `grossAmount` without measuring the raffle’s balance delta: `src/Raffle.sol:L223-L235`.
- All liabilities derive from that nominal amount: `src/Raffle.sol:L296-L299`, `L339-L342`, `L367-L390`, `L539-L555`.
- `accountedQuoteBalance()` returns the internal ledger only; it does not read `balanceOf`: `src/Raffle.sol:L467-L470`.
- SafeERC20 validates call/return behavior but not actual balance movement: `node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L47`, `L176-L244`.
- The exact-transfer requirement is only documented: `src/interfaces/IRaffle.sol:L12-L15` and `src/Raffle.sol:L560-L566`.

### Impact by token behavior

- **Fee-on-transfer or partial transfer:** `unsettledPot` exceeds actual custody immediately.
- **Negative rebase or administrator burn:** previously solvent liabilities become undercollateralized.
- **Positive rebase, interest, or airdrop:** surplus is not allocated and there is no rescue path.
- **No-op token returning no data:** SafeERC20 treats a non-reverting empty return as success, allowing tickets and liabilities without actual payment.
- **Outgoing transfer fee:** a claim can be cleared and its ticket burned while the recipient receives less than the recorded amount.
- **Pause or blocklist:** the transfer reverts and state rolls back, preserving the claim but potentially blocking it permanently.
- **Token upgrade:** any of these properties can appear after factory deployment.

### Qualification

This is conditional rather than an unconditional exploit because the design intentionally supports one deployment-selected canonical quote token and documents exact, fee-free, non-rebasing semantics. The supplied source and absent deployment evidence cannot establish that property.

### Recommendation

- Publish and enforce a chain-specific deployment manifest containing the canonical factory, quote token, wrapper, proxy implementation, and relevant admin/upgrade provenance.
- On purchase, compare the raffle’s quote balance before and after transfer and require an exact `grossAmount` increase.
- Consider exact sender/recipient balance checks for claim delivery where compatible with the selected token.
- Monitor `quoteToken.balanceOf(raffle)` against `accountedQuoteBalance()` for every live raffle.
- Treat any quote-token proxy upgrade or administrative semantic change as a protocol security event.

---

## M-02 — Prize delivery bypasses ERC-721 receiver acceptance

### Code facts

Both outbound prize paths use unsafe transfer:

- winner delivery: `src/Raffle.sol:L329-L337`;
- sponsor return: `src/Raffle.sol:L395-L406`.

They verify only that `ownerOf(tokenId)` reports the intended address afterward.

Ticket owners may be contracts because tickets can be safely minted or transferred to contracts through inherited ERC-721 behavior: `src/Raffle.sol:L235`; `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L136`, `L269-L290`.

### Impact

A contract can own and redeem a raffle ticket yet reject or be unable to manage the arbitrary prize. `transferFrom` skips `onERC721Received`; a standards-compliant prize can therefore become irrecoverably held by a contract that would have rejected a safe transfer. The raffle nevertheless burns the ticket, sets redemption complete, and treats `ownerOf` as successful delivery.

A ticket receiver may also accept only this raffle’s ticket contract and reject an unrelated prize contract, so prior ticket acceptance does not prove prize acceptance.

### Recommendation

Use `safeTransferFrom` for outbound prize delivery and retain the post-transfer ownership check. The redemption and release entry points already hold the raffle’s reentrancy guard, and any receiver rejection would revert the complete burn/state transition atomically.

If unsafe delivery is intentional, disclose that contract ticket owners must be capable of operating any selected prize even though no acceptance callback is performed.

---

## L-01 — Callback activation precedes factory finalization

### Code facts

- The clone becomes `Active` inside the prize receiver callback: `src/Raffle.sol:L416-L430`.
- Control then returns to sponsor-selected token code.
- The factory checks `ownerOf` and status and emits `RaffleCreated` only after `safeTransferFrom` completes: `src/RaffleFactory.sol:L127-L147`.
- The factory’s reentrancy guard protects the factory, not the newly created clone.

### Impact

After the receiver callback returns but before the malicious prize’s `safeTransferFrom` returns, the prize contract can call the now-active clone. In particular, it can make a fully funded `buyEntries` call, producing `TicketPurchased` and nonzero raffle state before `RaffleCreated`.

This does not create free entries because the quote transfer and normal checks still apply, but it complicates lifecycle assumptions, event ordering, indexers, and any consumer expecting creation publication to precede sales.

### Recommendation

Use two-phase activation:

1. receiver callback records receipt but leaves sales disabled;
2. after `safeTransferFrom` and custody verification return, the factory calls a factory-only activation function;
3. emit `RaffleCreated` only after activation.

---

# Native compliance checklist

Legend: **PASS** = established by supplied source; **CONDITIONAL** = depends on documented external assumptions; **UNKNOWN** = absent external/deployment evidence; **N/A** = not exercised; **DEFERRED** = controller-assigned S6 work.

| Category | Result | Native checklist conclusion |
|---|---|---|
| 1. General considerations | UNKNOWN | No supplied audit history, team contact channel, or security mailing list. |
| 2. Contract composition | PASS / CONDITIONAL | Solidity 0.8 checked arithmetic, fixed ERC-1167 implementation, immutable dependencies, and bounded batches. The raffle is necessarily more complex than a standalone token. |
| 3. Owner privileges | PASS internally; UNKNOWN externally | No protocol owner, admin mint, pause, blacklist, mutable configuration, or implementation upgrade. External token/wrapper administrators are unknown. |
| 4. ERC-20 conformity | CONDITIONAL | No ERC-20 implementation is supplied. SafeERC20 handles missing/false returns; actual token conformity is not visible. Slither checks are deferred. |
| 5. ERC-20 extension risks | CONDITIONAL | Hook reentrancy is guarded; transfer fees, rebases, blocklists, pauses, and upgrades are not accommodated by accounting. |
| 6. Token scarcity | NOT PERFORMED | No address or RPC was supplied. |
| 7. Weird ERC-20 patterns | COMPLETE SOURCE MATRIX | All 24 patterns are classified below. |
| 8. Integration safety | CONDITIONAL | Fixed token address, SafeERC20, checks-effects-interactions, and guards are present; exact balance verification and external implementation attestation are absent. |
| 9. ERC-721 conformity | PASS for ticket; UNKNOWN for prize | Ticket implementation manually conforms through pinned OpenZeppelin inheritance. Arbitrary prize conformity is not decidable from interfaces. |
| 10. ERC-721 common risks | PASS / GAP | Ticket safe mint, burn approval clearing, and guarded purchase callback are sound. Prize self-attestation and unsafe outbound delivery remain material gaps. |

---

# Assessment by category

## 1. General considerations

- **Security review history:** no evidence supplied. `DESIGN.md:L4` expressly says no audit history or scanner results were provided.
- **Team contactability:** no security contact information exists in the supplied scope. The NatSpec author field is not evidence of an incident-response channel.
- **Security mailing list:** no evidence in scope.
- **Dependency integrity:** all 31 manifest-listed dependency hashes matched.
- **Deployment provenance:** absent. No canonical factory, quote-token, wrapper, or prize address was supplied.

**Verdict:** incomplete operational evidence, without inferring that contacts or prior reviews do not exist elsewhere.

## 2. Contract composition

### First-party composition

The five production files contain 1,514 physical lines, including comments and blank lines:

- `Raffle.sol`: lifecycle, ERC-721 ticket implementation, custody, claims, and wrapper callback;
- `RaffleFactory.sol`: immutable configuration, clone registry, validation, and prize escrow;
- `IRaffle.sol` and `IRaffleFactory.sol`: ABI and documented assumptions;
- `RaffleConstants.sol`: fixed economics, timeouts, and limits.

`Raffle` combines ERC-721, receiver, reentrancy, quote custody, draw lifecycle, and Chainlink consumer behavior. This is substantial token composition, but the non-token functions are core raffle functionality rather than gratuitous extensions.

### Arithmetic

- Solidity `0.8.36` provides checked arithmetic.
- Entry overflow is explicitly bounded: `src/Raffle.sol:L218-L233`.
- Allocation uses full-precision `Math.mulDiv`: `src/Raffle.sol:L539-L547`.
- Sponsor proceeds receive the remainder, preserving the nominal pot despite floor rounding.
- No first-party `unchecked` block was found.
- Timestamp narrowing to `uint64` remains a formally unproven environmental assumption at `src/Raffle.sol:L253` and `L520`, though it is not a practical present-chain token risk.

### Proxy and entry-point model

- Each raffle is an ERC-1167 clone with a fixed implementation target: `src/RaffleFactory.sol:L89-L91`, `L105-L106`.
- There is no implementation mutation path.
- The implementation is locked by constructor state: `src/Raffle.sol:L151-L166`.
- A clone does not run the ERC-721 or ReentrancyGuard constructors. This is safe here because:
  - `name()` and `symbol()` are pure overrides: `src/Raffle.sol:L477-L487`;
  - a zero ReentrancyGuard slot is not equal to `ENTERED`, and the first protected call initializes it to the normal state through the modifier path: `ReentrancyGuard.sol:L88-L105`.
- One factory fixes one quote-token address and one wrapper address. Separate factory deployments can still select different dependencies, so users and frontends must anchor a canonical factory address.
- Each clone is intentionally a separate ERC-721 collection address, despite sharing `name` and `symbol`. Factory registry membership, not metadata, is the authoritative entry-point discriminator.

**Verdict:** sound fixed-clone composition, with expected protocol complexity and deployment-address trust.

## 3. Owner privileges

### Internal protocol

- No `owner`, role manager, pause, blacklist, rescue, arbitrary mint, mutable fee, dependency setter, or implementation upgrade exists.
- Ticket minting is public only through a positive quote-token purchase before `endTime`: `src/Raffle.sol:L209-L236`.
- Ticket supply is bounded by `uint128 totalEntries`; each mint requires at least one entry.
- Sponsor authority is limited to:
  - selecting prize/recipient/reserve/end time at creation;
  - enabling refunds early only for an empty active raffle: `src/Raffle.sol:L279-L288`.
- Draw, settlement, refund activation after deadlines, and claim releases are permissionless.
- Treasury and sponsor destinations are immutable per factory/raffle.

### External privilege surfaces

Not decidable without deployed implementations:

- quote-token upgrade, mint, burn, freeze, blacklist, and pause administrators;
- prize-token upgrade, pause, transfer restriction, forced-transfer, or burn administrators;
- wrapper proxy and randomness authorities.

**Verdict:** internal centralization risk is low; external administrative risk is entirely deployment-dependent.

## 4. ERC-20 conformity

There is no ERC-20 implementation in the target. `IERC20` and `IERC20Metadata` are declarations only.

### Locally established

- `transfer` and `transferFrom` are invoked through SafeERC20.
- Missing return data is accepted only when the call succeeds and the target has code.
- a returned `false`, malformed nonempty return, or revert fails the operation: `SafeERC20.sol:L176-L244`.
- The factory reads `decimals()` as `uint8` and requires exactly six: `src/RaffleFactory.sol:L70-L78`.
- The protocol never invokes `approve`, increase/decrease allowance, or permit.
- Token `name` and `symbol` are never consumed.

### Not established

- actual transfer return behavior;
- actual balances moved;
- total supply or metadata;
- allowance semantics;
- upgradeability;
- Slither ERC-20 conformance;
- generated token properties.

**Verdict:** return-value integration is sound; underlying ERC-20 conformity is not decidable.

## 5. ERC-20 extension risks

### Hooks and reentrancy

All quote-token interactions occur from protected economic entry points:

- purchase: `src/Raffle.sol:L209-L235`;
- winner/refund/sponsor/protocol payouts: `src/Raffle.sol:L309-L390`;
- `_transferQuote`: `src/Raffle.sol:L560-L567`.

ERC-777-style or custom transfer callbacks cannot reenter another guarded raffle economic function. State is cleared or the claim ticket is burned before outbound transfer, and a reverting call rolls everything back.

Inherited ERC-721 approval and transfer functions are not guarded, but the quote token cannot be a ticket recipient because `_isProtocolDestination` rejects it: `src/Raffle.sol:L497-L501`, `L593-L604`.

### Fees, rebases, and interest

These are not handled:

- no incoming or outgoing balance-delta checks;
- no rebase synchronization;
- no yield/surplus allocation;
- no rescue for excess quote tokens;
- no compatibility response to token upgrades.

**Verdict:** callback reentrancy is mitigated; semantic token extensions are excluded only by trust and deployment policy.

## 6. Token scarcity analysis

**Not performed.**

The following native checks require a deployed address and RPC and were not available:

- `totalSupply`;
- number of holders;
- top-holder concentration;
- exchange/liquidity distribution;
- flash-loan availability;
- flash-mint modules;
- owner/admin configuration;
- proxy implementation and admin;
- live pause/blocklist status;
- current raffle custody and solvency.

No scarcity or distribution conclusion is inferred from “canonical USDC” documentation.

## 7. Complete weird ERC-20 pattern matrix

This matrix applies to the configured quote token. The inherited LINK interface is not an active payment surface because `Raffle` calls only `requestRandomnessPayInNative`; the base contract’s LINK-funded helper is not reached by first-party code.

| # | Pattern | Classification | Evidence / visibility limitation | Protocol impact |
|---:|---|---|---|---|
| 1 | Reentrant calls / transfer hooks | **Not decidable for external token** | Quote implementation absent. Transfers occur at `Raffle.sol:L224`, `L342`, `L369`, `L380`, `L390`; all callers are guarded. | Hook-based reentry into economic entry points is blocked. A malicious token can still misreport transfer success or call unrelated external systems. |
| 2 | Missing return values | **Not decidable for external token** | Only `IERC20` is supplied. SafeERC20 explicitly supports empty return data at `SafeERC20.sol:L176-L199`, `L212-L244`. | Standard missing-return tokens are handled. A no-op token returning no data cannot be distinguished from success without balance checks. |
| 3 | Fee on transfer | **Not decidable for external token** | No token implementation or balance-delta check; nominal accounting at `Raffle.sol:L223-L235`. | Incoming fees undercollateralize all claims; outgoing fees short-pay recipients. |
| 4 | Balance modification outside transfers | **Not decidable for external token** | No implementation, runtime balance, or rebase logic supplied. Ledger-only getter at `Raffle.sol:L467-L470`. | Negative changes cause insolvency; positive rebases/airdrops create trapped surplus. |
| 5 | Upgradeable token | **Not decidable for external token** | Factory stores one immutable address but no proxy/implementation data is supplied: `RaffleFactory.sol:L32-L42`, `L65-L91`. | An external upgrade can introduce fees, hooks, pauses, blocklists, or false accounting after deployment. |
| 6 | Flash mintable | **Not decidable for external token** | No implementation, module list, or live deployment supplied. | Ordinary flash liquidity does not create free entries because quote units remain escrowed, but monetary integrity and token-specific flash-mint behavior remain external. |
| 7 | Blocklists | **Not decidable for external token** | No external administration or live state supplied. | Blocking a raffle or recipient can permanently prevent purchases or claims. Reverting payouts roll back local state but do not restore liveness. |
| 8 | Pausable token | **Not decidable for external token** | No implementation/admin state supplied. | A pause can freeze every raffle sharing the quote address. |
| 9 | Approval race protections | **Not applicable** | First-party code never calls `approve`; source search found only transfer operations. | Buyers manage allowance externally. Reset-to-zero UX belongs to clients/deployment compatibility, not protocol calls. |
| 10 | Revert on approval to zero address | **Not applicable** | No first-party approval calls. | No reachable protocol effect. |
| 11 | Revert on zero-value approvals | **Not applicable** | No first-party approval calls. | No reachable protocol effect. |
| 12 | Revert on zero-value transfers | **Not applicable** | Entry count must be positive; every claim derives from at least one `1_000_000`-unit entry, and empty claim buckets revert: `Raffle.sol:L217-L224`, `L339-L342`, `L367-L390`. | Exercised quote transfers are nonzero. |
| 13 | Multiple token addresses | **Not found in supplied source** | Each factory and implementation use one immutable quote address: `RaffleFactory.sol:L33`, `L85`; `Raffle.sol:L58`, `L162`. No migration or alias path exists. External address aliases cannot be checked without deployment data. | Address-based accounting is internally consistent within one factory. Canonical factory selection remains off-chain configuration. |
| 14 | Low decimals | **Found** | Factory requires exactly six decimals: `RaffleFactory.sol:L70-L78`; one entry is `1_000_000` raw units: `RaffleConstants.sol:L20-L24`. | Intentional and correctly expressed in raw units. Percentage floors use `mulDiv`; sponsor receives the remainder. |
| 15 | High decimals | **Not applicable** | Construction rejects every reported precision other than six: `RaffleFactory.sol:L76-L78`. | High-decimal overflow/precision paths are unreachable for a truthfully reporting token. |
| 16 | `transferFrom` with `src == msg.sender` | **Not applicable** | In `safeTransferFrom(msg.sender, address(this), grossAmount)`, the ERC-20 caller is the raffle while the source is the external buyer: `Raffle.sol:L223-L224`. | The DSToken/OpenZeppelin allowance-decrement difference is not exercised. |
| 17 | Non-string metadata | **Not applicable** | Quote-token `name` and `symbol` are never called; only typed `uint8 decimals()` is used: `RaffleFactory.sol:L70-L78`. | No metadata decoding risk in protocol source. |
| 18 | Revert on transfer to zero address | **Not applicable** | Inbound destination is the raffle. Sponsor recipient and treasury are nonzero; winners come from `ownerOf`; refund recipient is `msg.sender`: `Raffle.sol:L181-L186`, `L320-L342`, `L349-L390`. | No quote-token transfer targets zero. |
| 19 | No revert on failure / returns false | **Not decidable for external token** | External behavior absent. SafeERC20 converts a returned false or malformed nonempty result into a revert: `SafeERC20.sol:L176-L244`. | False-return behavior is handled. False success or empty-return no-op behavior requires balance verification. |
| 20 | Revert on large approvals | **Not applicable** | The protocol never approves a spender. | Buyer/client max-approval behavior is outside supplied contracts; exact approvals remain possible. |
| 21 | Code injection through token name | **Not applicable** | Quote-token name/symbol are not read or emitted by the source. No frontend code is in scope. | No on-chain injection sink. Frontend display behavior remains outside visibility. |
| 22 | Unusual or no-op permit | **Not applicable** | No permit function or signature path exists. | No phantom-permit risk in protocol contracts. |
| 23 | Transfer less than requested amount | **Not decidable for external token** | SafeERC20 checks call status, not amount received; no pre/post balances at `Raffle.sol:L223-L235`. | Partial transfer creates the same insolvency as a transfer fee. The protocol does not use `type(uint256).max`, but other partial semantics remain possible. |
| 24 | ERC-20 representation of native currency | **Not decidable for external token** | No deployed identity was supplied. Source treats quote ERC-20 and native VRF payment separately and contains no wrap/unwrap path: `Raffle.sol:L240-L272`. | No source-visible double-booking path, but chain-specific token identity cannot be established. |

## 8. Token integration safety assessment

### ERC-20 quote flow

| Control | Result |
|---|---|
| Safe transfer wrapper | PASS — all quote movements use SafeERC20. |
| Missing/false return handling | PASS for standard variants. |
| Reentrancy guard | PASS for all quote-touching raffle entry points. |
| Checks-effects-interactions | PASS for outgoing claims; reverted transfers restore burns and liability state. |
| Incoming balance verification | GAP — no balance delta is measured. |
| Outgoing recipient balance verification | GAP. |
| Fee-on-transfer support | FAIL by design; exact token semantics are assumed. |
| Rebase/yield support | FAIL by design. |
| Blocklist/pause recovery | No recovery beyond retaining a reverting claim. |
| Token allowlist | One immutable address per factory, but constructor validation proves only code and six decimals. |
| Upgrade detection | None. |
| Zero-value handling | PASS; exercised transfers are positive. |
| Solvency reporting | Partial — internal liabilities are exposed, but actual balance comparison is external. |

### ERC-721 prize flow

| Phase | Local controls | Residual external risk |
|---|---|---|
| Selection | Code presence and ERC-165 self-report | A malicious token can lie; proxy/admin state is unknown. |
| Escrow | `safeTransferFrom`, exact callback tuple, post-call `ownerOf`, `Active` status | All observations are controlled by the selected token. Callback activates before factory finalization. |
| Holding period | Prize address/ID immutable | Token can upgrade, pause, burn, reassign, blacklist, or change ownership semantics. |
| Winner delivery | State/burn before interaction, nonReentrant, post-`ownerOf` check | Unsafe `transferFrom` bypasses receiver consent; token can revert, short-circuit, or lie. |
| Sponsor return | One-time flag, nonReentrant, post-`ownerOf` check | Same unsafe transfer and external-behavior limitations. |
| Failure recovery | Revert restores local state | No terminal fallback/refund path after `NftWon`. |

### Chainlink wrapper integration

- Factory validates code presence only: `src/RaffleFactory.sol:L65-L67`.
- Wrapper address is immutable and callback caller authentication is enforced by `VRFV2PlusWrapperConsumerBase.sol:L101-L107`.
- Raffle also checks in-flight state, lifecycle, request ID, word count, and strict callback deadline: `src/Raffle.sol:L509-L523`.
- A synchronous callback is deliberately ignored while the request call is in flight. If a wrapper treated that synchronous attempt as final, the raffle would wait until timeout and refund.
- Request price is observed once by `getVrfRequestPrice` and again inside `requestRandomnessPayInNative`; the second price is treated as actual payment: `src/Raffle.sol:L249-L260`, `VRFV2PlusWrapperConsumerBase.sol:L76-L89`.
- Request-ID uniqueness/binding, unpredictability, retry behavior, fulfillment gas, wrapper upgrades, and canonical identity are not present in supplied source.

### Address-entry-point assessment

- Every clone has a distinct ticket-token address; identical names/symbols are not sufficient identity.
- Factory registry getters provide the intended canonical clone membership.
- The shared implementation is locked and cannot serve as an active raffle.
- Counterfeit factories with different immutable dependencies can be deployed from the same source. Canonical factory and dependency addresses therefore require an authenticated deployment manifest.
- `_isProtocolDestination` blocks the current clone, canonical factory, quote token, wrapper, prize, implementation, and registered same-factory clones: `src/Raffle.sol:L593-L604`.
- Unsafe ERC-721 `transferFrom` can still send tickets or unrelated NFTs to arbitrary contracts, including contracts that cannot recover them. This is standard unsafe-transfer behavior and is not fully preventable by a finite destination denylist.

## 9. ERC-721 conformity

### Ticket implementation

| Requirement | Result and evidence |
|---|---|
| ERC-165/ERC-721/metadata interface support | PASS — inherited `ERC721.supportsInterface`: `ERC721.sol:L44-L50`. |
| Transfer to zero reverts | PASS — `ERC721.sol:L114-L125`. Internal zero-address updates are reserved for burns. |
| `safeTransferFrom` implemented | PASS — both overloads and receiver check at `ERC721.sol:L127-L136`; selector enforcement at `ERC721Utils.sol:L25-L48`. |
| `name` and `symbol` | PASS — fixed pure values at `Raffle.sol:L477-L487`. |
| `tokenURI` | Conforming but empty — inherited function validates existence and returns an empty URI because `_baseURI()` is empty: `ERC721.sol:L75-L90`. |
| ERC-721 `decimals` | N/A — ERC-721 does not require it and none is defined. |
| `ownerOf` invalid/burned behavior | PASS — `_requireOwned` reverts for zero owner: `ERC721.sol:L60-L63`, `L420-L432`. |
| Transfer authorization | PASS — owner, per-token approval, and operator paths at `ERC721.sol:L157-L187`. |
| Approval clearing | PASS — `_update` clears approval before transfer or burn: `ERC721.sol:L216-L245`. |
| Token-ID immutability | PASS — sequential IDs are assigned once; `_mint` rejects an existing ID, and `ticketCount` never decreases. |
| Safe minting | PASS — `buyEntries` uses `_safeMint`: `Raffle.sol:L228-L236`; inherited receiver check at `ERC721.sol:L269-L290`. |
| Burn clears approvals | PASS — `_burn` uses `_update(address(0), ...)`: `ERC721.sol:L292-L308`. |
| Burn/claim atomicity | PASS for reverting dependencies — burn and claim state revert if quote/prize calls revert. |
| Transfer restrictions | `_update` rejects known protocol sinks before inherited mutation: `Raffle.sol:L491-L502`. This is a deliberate restriction, not a detected ERC-721 ledger inconsistency. |

### Ticket callback behavior

- During purchase, accounting and ownership are written before the receiver callback, while `buyEntries` holds `nonReentrant`.
- A receiver can call inherited ERC-721 approval or transfer methods during its callback and move the newly minted ticket before `buyEntries` returns. The purchase event still records the initial recipient. No later purchase logic assumes that recipient remains owner.
- During an ordinary inherited safe transfer, a receiver may redeem/refund the newly received ticket in its callback if lifecycle conditions permit. The outer safe transfer has no post-callback mutation, and the economic entry points are independently guarded, so no double claim was found.
- Unsafe inherited `transferFrom` can strand a ticket in an incapable contract; this is the standard ERC-721 unsafe-transfer risk.

### Arbitrary prize conformity

Not decidable. The supplied `IERC721` and `IERC165` declarations establish expected signatures only. They do not establish:

- truthful ERC-165 support;
- authorization enforcement;
- transfer-before-callback ordering;
- callback selector enforcement;
- truthful or persistent `ownerOf`;
- approval clearing;
- nonzero transfer checks;
- token-ID persistence;
- absence of pause, blacklist, upgrade, burn, or forced transfer.

## 10. ERC-721 common risks

### `onERC721Received`

- Ticket safe mint and safe transfer use OpenZeppelin’s state-update-then-callback pattern.
- Purchase callbacks are protected by the raffle guard.
- Prize escrow callback accepts only `AwaitingPrize`, the configured token/ID, configured sponsor, and factory operator: `src/Raffle.sol:L421-L430`.
- Those fields are insufficient against a malicious prize because the prize invokes the callback and controls its own ledger.
- Prize callback activation can expose the clone before factory finalization, as described in L-01.

### Safe minting

PASS for raffle tickets. Contract recipients must return the selector, and rejection reverts payment, ticket state, and accounting atomically.

### Burning and approvals

PASS. Winning redemption and refunds burn only after checking current ownership. OpenZeppelin clears approval during `_update`, and later transfer failures revert the entire burn.

### Prize transfer and callback risk

- Outbound prize delivery is not safe and invokes no required receiver callback.
- A malicious prize may nevertheless make arbitrary callbacks from its own `transferFrom`; the surrounding raffle function remains guarded.
- Local checks-effects-interactions and atomic rollback protect raffle state from a reverting delivery, but cannot prove genuine external asset semantics.

---

# Facts, assumptions, and unverifiable properties

| Classification | Items |
|---|---|
| **Code facts** | Fixed quote/wrapper addresses per factory; fixed implementation; no internal admin; SafeERC20 on every quote movement; nominal rather than observed balance accounting; OpenZeppelin ERC-721 ticket ledger; safe ticket mint; unsafe prize outbound transfer; prize ERC-165/callback/`ownerOf` checks; wrapper-address callback authentication. |
| **Documented trust assumptions** | Quote token is canonical six-decimal, fee-free, exact-transfer, and non-rebasing USDC; prize is honest and standards-compliant in `IRaffle.sol`; wrapper is the intended canonical Chainlink deployment. |
| **Design tension** | `DESIGN.md` calls arbitrary prize contracts untrusted, while the implementation requires honest prize semantics. |
| **Unverifiable deployed properties** | Actual addresses, runtime bytecode, proxy implementations/admins, token fees/rebases/hooks, pause/blocklist state, mint/burn authority, wrapper randomness/request binding, live balances, holder distribution, and prize collection behavior. |

---

# Prioritized recommendations

## Priority 0 — Resolve the prize trust model

**Code fact:** arbitrary sponsor-selected code supplies every custody and delivery observation.

**Documented assumption:** `IRaffle.sol` assumes an honest ERC-721.

**Unverifiable property:** actual prize implementation and upgrade controls.

Choose one enforceable policy:

- restrict prizes to vetted immutable collections/adapters;
- require an authenticated external allowlist tied to factory identity;
- or explicitly classify prize authenticity and deliverability as a user-borne risk.

For `NftWon`, prevent sponsor/protocol proceeds from being released before successful winner redemption and define a failure fallback.

## Priority 1 — Attest canonical deployment identities

Publish a signed chain-specific manifest for:

- canonical factory;
- raffle implementation;
- quote-token proxy and implementation;
- quote-token admin/upgrade authority;
- wrapper proxy and implementation;
- treasury.

Construction’s code-and-decimals checks must not be treated as identity verification.

## Priority 1 — Enforce or continuously verify exact quote accounting

Add incoming balance-delta validation and reject a purchase unless the exact nominal amount arrives. Where practical, validate outgoing deltas as well.

At minimum, continuously monitor:

`quoteToken.balanceOf(raffle) >= accountedQuoteBalance()`

Any discrepancy should halt frontend purchases and trigger incident response.

## Priority 1 — Use safe outbound prize delivery

Replace both outbound `transferFrom` calls with `safeTransferFrom` and preserve the post-transfer `ownerOf` check. Receiver rejection should revert the burn/release state.

## Priority 2 — Finalize activation after escrow returns

Separate prize receipt from sale activation so sponsor-selected token code cannot interact with an active clone before factory verification and `RaffleCreated`.

## Priority 2 — Specify external upgrade and emergency policy

Document the operational response to:

- quote-token or wrapper upgrades;
- pause/blocklist activation;
- prize collection upgrades;
- detected balance/accounting mismatch;
- wrapper request/callback anomalies.

The contracts are immutable, so response options are deployment/frontend coordination rather than on-chain administration.

## Priority 3 — Complete sealed S6 conformance work

In S6, run the approved tooling and properties for:

- `slither-check-erc` on the ticket implementation;
- contract/human summaries;
- generated ERC-721 properties;
- safe-mint callback reentrancy;
- burn/claim rollback;
- fee-on-transfer, no-return, false-return, no-op, rebase, blocklist, and pause mocks;
- malicious ERC-721 callback/`ownerOf` mocks;
- wrapper synchronous callback, duplicate ID, wrong length, late callback, and retry behavior.

---

# Unresolved leads

1. **Quote-token identity:** exact deployed address, proxy implementation, admin, upgrade delay, and chain provenance.
2. **Quote-token semantics:** actual received/sent balance deltas, missing-return behavior, fees, rebases, admin burns, hooks, blocklists, pauses, and upgrade history.
3. **Prize behavior:** each selected token’s implementation, proxy controls, ERC-165 truthfulness, transfer ordering, callback behavior, custody persistence, burn/pause/blacklist capabilities, and delivery semantics.
4. **Wrapper identity:** canonical deployment, proxy/admin structure, price behavior, request-ID uniqueness and binding, callback retry policy, randomness provenance, and fulfillment gas behavior.
5. **Creation-time semantics:** whether consumers require `RaffleCreated` to precede every ticket event and whether zero entries at publication is intended.
6. **Contract recipients:** whether ticket-owning contracts are expected to accept arbitrary prizes, and whether unsafe prize delivery is intentional.
7. **Canonical-address discovery:** how users distinguish the intended factory from byte-identical deployments with malicious dependencies.
8. **Live solvency:** actual quote balance versus each raffle’s internal liabilities.
9. **Operational security:** prior audits, team security contact, disclosure process, and security mailing list.
10. **On-chain scarcity/distribution:** not performed without addresses and RPC.

# Per-property depth gaps

| Property | Source depth achieved | Remaining gap |
|---|---|---|
| Ticket ERC-721 ledger | Complete manual path through mint, transfer, approval, burn, ownership, and callback dependencies | Tool-based conformance and dynamic properties deferred to S6 |
| Quote return semantics | SafeERC20 internals fully inspected | Concrete token runtime absent |
| Quote amount semantics | Every source accounting and transfer site inspected | No runtime balance deltas or deployed token code |
| Reentrancy | Guards, external-call ordering, and ERC-721 callback paths manually traced | No adversarial dynamic execution |
| Prize custody | Factory transfer, callback tuple, post-owner check, and release paths fully traced | Token-controlled truth and future behavior unverifiable |
| Prize receiver compatibility | Unsafe outbound calls identified | No actual winner/sponsor recipient implementations |
| Wrapper authentication | Base caller gate and Raffle callback filter inspected | Wrapper implementation, request binding, and retry behavior absent |
| Upgradeability | No protocol upgrade path found | External token/wrapper/prize proxy controls unknown |
| Scarcity/distribution | None | Requires deployed addresses, indexer/RPC data |
| Team/security process | No evidence in supplied scope | Requires project documentation or contact information |

---

# Per-file coverage

All paths below are relative to `target/packages/contracts/`. No production files are grouped. The two grouped OpenZeppelin interface files are grouped only because both are import-only re-export shims with no declarations or executable logic.

## First-party production files — 5/5

| File | Lines read | Coverage |
|---|---:|---|
| `src/Raffle.sol` | 1–614 | Complete lifecycle, quote custody, ERC-721 ticket behavior, prize handling, wrapper interaction, destination checks, accounting, burns, callbacks, and releases. |
| `src/RaffleFactory.sol` | 1–186 | Complete constructor validation, immutable configuration, clone creation/registry, prize checks, escrow, and publication ordering. |
| `src/interfaces/IRaffle.sol` | 1–521 | Complete ABI, events, errors, lifecycle documentation, and explicit quote/prize trust assumptions. |
| `src/interfaces/IRaffleFactory.sol` | 1–150 | Complete factory ABI, registry model, deployment responsibility, and canonical-address assumption. |
| `src/libraries/RaffleConstants.sol` | 1–43 | Complete fees, entry price, required decimals, timeout, batch, and VRF constants. |

## Reachable dependencies — 31/31

| Dependency | Lines read | Reachability / token relevance |
|---|---:|---|
| `node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` | 1–31 | LINK interface used by wrapper base construction; LINK-funded request helper is not called by Raffle. |
| `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` | 1–118 | Native request helper, wrapper immutable, raw callback authentication, and inherited views. |
| `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` | 1–83 | Interface-only pricing, request, LINK, and feed boundary. |
| `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` | 1–27 | Native-payment extra-argument encoding used by `requestDraw`. |
| `node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol` | 1–86 | Transitive SafeERC20 extension interface; relaxed ERC-1363 functions are not called. |
| `node_modules/@openzeppelin/contracts/interfaces/IERC165.sol`; `interfaces/IERC20.sol` | 1–6 each | Import-only re-export shims; no runtime logic. |
| `node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol` | 1–162 | Standard ERC-721 error types reached by inherited implementation. ERC-20/1155 error declarations have zero first-party relevance. |
| `node_modules/@openzeppelin/contracts/proxy/Clones.sol` | 1–294 | `clone(address)` deployment path is used. Deterministic/immutable-argument variants are not reached. |
| `node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol` | 1–79 | Quote-token ABI; declarations are not implementation evidence. |
| `node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` | 1–26 | Factory’s six-decimal validation boundary. |
| `node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | 1–280 | All quote transfer return/revert behavior; approval and ERC-1363 helpers are unused. |
| `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` | 1–433 | Full ticket ledger, interface support, transfer, safe transfer, approval, mint, burn, metadata, and ownership logic. |
| `node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol` | 1–135 | Ticket/prize interface requirements and unsafe-transfer warning. |
| `node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` | 1–28 | Ticket and prize receiver selector contract. |
| `node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` | 1–27 | Inherited ticket metadata interface. |
| `node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` | 1–50 | Receiver callback detection, selector validation, and revert bubbling. |
| `node_modules/@openzeppelin/contracts/utils/Bytes.sol` | 1–332 | Transitive Strings utility; no direct first-party integration logic. |
| `node_modules/@openzeppelin/contracts/utils/Context.sol` | 1–28 | Supplies inherited `_msgSender`; no meta-transaction override exists. |
| `node_modules/@openzeppelin/contracts/utils/Create2.sol` | 1–91 | Reachable only through unused deterministic Clones variants. |
| `node_modules/@openzeppelin/contracts/utils/Errors.sol` | 1–34 | Clone deployment failure errors; other declarations have zero token relevance. |
| `node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol` | 1–127 | Transitive through unused Create2 deployment failure path; no first-party calls. |
| `node_modules/@openzeppelin/contracts/utils/Panic.sol` | 1–57 | Transitive arithmetic panic helper used by Math. |
| `node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` | 1–119 | Factory and clone shared guard semantics, including clone zero-slot behavior. |
| `node_modules/@openzeppelin/contracts/utils/StorageSlot.sol` | 1–143 | ReentrancyGuard storage backing; other slot types have zero first-party relevance. |
| `node_modules/@openzeppelin/contracts/utils/Strings.sol` | 1–532 | Inherited ERC-721 `tokenURI` formatting support; the ticket’s empty base URI yields an empty URI. |
| `node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol` | 1–25 | Base ERC-165 ticket support. |
| `node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol` | 1–25 | Interface declaration used by ticket inheritance and prize self-report validation. |
| `node_modules/@openzeppelin/contracts/utils/math/Math.sol` | 1–763 | `mulDiv` allocation path plus transitive ERC-721 metadata helpers. |
| `node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol` | 1–1162 | Transitive Math/Strings casting helpers; first-party timestamp casts do not use it. |
| `node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol` | 1–68 | Transitive Strings helper; no direct first-party path. |

---

# Method and controller adaptation

The native skill phases were applied as follows:

1. **Context discovery:** identified a combined ERC-721 implementation and ERC-20/ERC-721/wrapper integration on EVM.
2. **Slither phase:** not executed under the cold-stage rule. ERC criteria were checked manually, and all tool-backed conformance work is deferred to S6.
3. **Code analysis:** completed through full-file reading, manual control/data-flow tracing, targeted source searches, dependency reachability, callback ordering, privilege analysis, and hash reconciliation.
4. **On-chain analysis:** not performed because no deployed address or RPC was supplied.
5. **Risk assessment:** completed across all ten native categories, all 24 weird ERC-20 patterns, ticket/prize ERC-721 behavior, SafeERC20 semantics, accounting assumptions, privilege boundaries, clone entry points, and Chainlink wrapper trust.

This is a source-only S3 assessment. It establishes what the frozen source does and which properties it assumes; it does not attest any deployed token, prize, wrapper, factory, holder distribution, or live configuration.