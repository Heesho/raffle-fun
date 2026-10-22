# Native S6 Secure Workflow Report

## Audit identity and disposition

| Item | Value |
|---|---|
| Stage | S6 — Trail of Bits `secure-workflow-guide` |
| Date | 2026-10-21 |
| Frozen target SHA | `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` |
| Isolated runtime | `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/.audit-runtime/secure-workflow/target` |
| Evidence root | `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/` |
| Requested route | `model=gpt-daybreak-blue-latest; cyber_access_program=daybreak_blue; reasoning_effort=ultra; fallback=disabled; multi-agent=disabled` |
| Provider identity | **Unknown.** No provider event supplied an identity. The model string above is prompt-supplied route evidence, not a claimed provider-returned model identity. |
| Production remediation | Not performed; not authorized |
| Live transactions/publishing/purchases | None |

The native workflow is complete. Five independently derived issues were recorded:

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 1 |
| Medium | 1 |
| Low | 2 |
| Informational/conditional | 1 |

The highest-risk result is that an arbitrary sponsor-selected “ERC-721” contract can satisfy every local escrow check while never transferring a real asset. A deterministic test completed the entire NFT-winning flow: entrants paid quote tokens, the sponsor received 95%, the treasury received 5%, the buyer was reported as prize owner, yet the malicious token’s separate actual owner remained the sponsor.

All 43 original isolated-target files were rehashed against their pre-test values after testing: **43 checked, 0 mismatches**. Production source, dependencies, configurations, locks, and DESIGN.md remained unchanged.

## Scope and evidence integrity

The review covered all five first-party Solidity files and all 31 supplied Solidity dependencies—6,891 lines total:

- 1,514 first-party lines.
- 5,377 dependency lines.

The stage-created tests, mocks, configuration, build products, and analysis files remained inside the isolated runtime. Copies of every created test/property source were retained in the S6 evidence tree.

The final evidence inventory contains:

| Directory | Files | Bytes |
|---|---:|---:|
| `tool-output/` | 123 | 14,179,843 |
| `diagrams/` | 10 | 886,643 |
| `properties/` | 6 | 39,841 |
| `tests/` | 18 | 2,789,495 |
| `logs/` | 60 | 64,438 |

Key persistent records:

- [Machine-readable result summary](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/RESULTS.json)
- [Security property matrix](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SECURITY_PROPERTIES.md)
- [Slither triage](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/SLITHER_TRIAGE.md)
- [Detailed findings](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/FINDINGS.md)
- [Manual review](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/MANUAL_REVIEW.md)
- [Per-file coverage](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/properties/FILE_COVERAGE.md)
- [Exact command index](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tool-output/06-command-index.stdout)
- [Immutable-file verification](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tool-output/06-immutable-original-files-verification.stdout)
- [Final evidence hashes](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tool-output/06-evidence-manifest-final.stdout)

## Toolchain

| Tool | Version |
|---|---|
| Slither / `slither-check-erc` | 0.11.6 |
| Forge | 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8` |
| Solidity | 0.8.36 for final Forge, Slither, and Echidna compilation |
| Echidna | 2.3.3 |
| Graphviz `dot` | 2.43.0 in disposable Debian container |
| Docker client/server | 29.8.2 / 29.8.2 |
| Echidna image | `ghcr.io/crytic/echidna/echidna:latest`, digest `sha256:80f90c3a727986fc31380a509a87fe0a14cdbda13f4ead102b2d7ffaff285261` |

For Foundry/Slither commands:

```text
PATH=/Users/hishamel-husseini/.foundry/bin:/opt/homebrew/bin:/usr/bin:/bin
```

For container commands:

```text
DOCKER_HOST=unix:///Users/hishamel-husseini/.lima/gebal/sock/docker.sock
```

Every invocation has a `.meta` record containing its exact shell-quoted command, working directory, UTC timestamps, exit code, and stdout/stderr paths.

# Findings

## S6-01 — High — An adversarial prize contract can fake escrow and delivery

### Evidence

The factory accepts sponsor-selected token code after checking only deployed code and that token’s self-reported ERC-165 response:

- `packages/contracts/src/RaffleFactory.sol:154-177`

It then relies on the same untrusted address to:

1. Execute `safeTransferFrom`.
2. Supply the activation callback.
3. Report custody through `ownerOf`.

Relevant lines:

- `RaffleFactory.sol:127-134`
- `Raffle.sol:416-430`

Redemption and sponsor return again rely on the same contract’s `transferFrom` and `ownerOf`:

- `Raffle.sol:329-337`
- `Raffle.sol:395-406`

Although `IRaffle.sol:12-15` describes supported prizes as honest and standards-compliant, DESIGN.md expressly states that arbitrary prize contracts are untrusted. ERC-165, callbacks, transfer behavior, and ownership reports are assertions from the same adversarial contract and cannot prove an independent custody fact.

### Reproduction

`test_Evidence_MaliciousPrizeCanFakeEscrowAndDelivery`:

- Creates a prize contract that reports ERC-721 support.
- Calls the correct receiver callback.
- Changes only a fake `reportedOwner`; its `actualOwner` remains the sponsor.
- Activates the raffle.
- Accepts one buyer payment.
- Resolves an NFT outcome.
- Releases 950,000 raw quote units to the sponsor recipient and 50,000 to the treasury.
- “Delivers” the prize by changing only the reported owner to the buyer.
- Confirms the actual owner is still the malicious sponsor.

The desired property `test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody` fails as expected.

### Impact

A malicious sponsor can publish a raffle for a nonexistent or non-custodied prize, collect real canonical quote tokens from entrants, and extract sponsor proceeds. Buyers can lose their payment while every local escrow and delivery check appears to succeed.

### Recommendation

Do not describe arbitrary prize contracts as trustlessly verified. Use one of:

- An allowlisted collection registry with audited code, explicit upgrade/governance policy, and deployment-specific attestations.
- A trusted custody adapter or vault whose ledger, rather than the arbitrary collection’s self-report, is authoritative.
- A narrower supported-prize policy enforced on-chain and in deployment configuration.

Delaying proceeds until delivery can reduce exposure but cannot establish truth against a prize contract that lies consistently at escrow and delivery.

## S6-02 — Medium — Prize delivery skips contract-recipient acceptance

### Evidence

Winner redemption and sponsor prize return both call unsafe ERC-721 `transferFrom`:

- Winner: `Raffle.sol:320-337`, specifically line 334.
- Sponsor recipient: `Raffle.sol:395-406`, specifically line 404.

The ticket is burned and delivery flags are set before the transfer:

- `Raffle.sol:323-325`
- `Raffle.sol:330-334`
- `Raffle.sol:400-404`

An `ownerOf` postcheck verifies only the resulting owner address. It does not verify that a contract recipient implements `IERC721Receiver` or can operate the prize.

### Reproduction

`test_Evidence_PrizeTransferSkipsIncompatibleContractReceiverCheck` uses a contract that accepts callbacks only from the raffle-ticket contract. It receives one callback for the safe-minted ticket, rejects the prize interface by design, but the prize is nevertheless transferred to it without any callback.

### Impact

A contract wallet or other contract ticket owner can successfully hold and redeem a raffle ticket but be incompatible with the prize NFT. The ticket is burned and the prize can become permanently inaccessible. A contract `sponsorRecipient` has the same exposure.

### Recommendation

Use:

```solidity
prizeToken.safeTransferFrom(address(this), recipient, prizeTokenId);
```

on both prize delivery paths. The existing checks-effects-interactions ordering and `nonReentrant` protection allow a rejected receiver callback to revert the entire transaction atomically.

## S6-03 — Low — Destination isolation is scoped to one factory

### Evidence

`_isProtocolDestination` compares fixed local addresses and queries only the clone’s own factory:

- `Raffle.sol:587-604`
- Ticket enforcement: `Raffle.sol:497-501`

Factory validation similarly checks only its local `isRaffle` mapping:

- `RaffleFactory.sol:154-168`
- Registry declarations: `RaffleFactory.sol:48-54`

A clone created by a second factory is not recognized.

### Reproduction

`test_Evidence_CrossFactoryRaffleDestinationIsAcceptedAndStrandsTicket` transfers a ticket from factory A’s raffle to factory B’s raffle. Factory A reports that the destination is not in its registry, and the transfer succeeds.

The desired property `test_Property_AllRaffleClonesAreRejectedDestinations` fails as expected.

### Impact

Tickets, configured payouts, or prize relationships can target another deployment’s raffle clone, violating the stated “Never move assets between raffle clones” invariant. A raffle clone has no generic execution or rescue facility, so assets sent to it can be stranded.

The action normally requires an owner, approved operator, or sponsor to choose the unsafe address, limiting severity.

### Recommendation

If multiple factories may exist, use a shared canonical registry or deployment registry consulted by every factory and clone. Otherwise scope the isolation claim explicitly to one factory and surface cross-deployment sinks to callers and frontends.

## S6-04 — Low — Prize callback can create pre-publication ticket state

### Evidence

The factory:

1. Registers the clone at `RaffleFactory.sol:123-125`.
2. Calls sponsor-selected prize code at `RaffleFactory.sol:127-128`.
3. Emits `RaffleCreated` only at `RaffleFactory.sol:136-147`.

During that external call, `onERC721Received` changes the clone to `Active`:

- `Raffle.sol:416-430`

The factory’s guard protects the factory, but the clone has a distinct reentrancy-guard slot. Prize code can therefore call `buyEntries` on the newly active clone before `createRaffle` returns.

### Reproduction

`test_Evidence_PrizeCanBuyEntriesBeforeCreateRaffleReturns` creates one paid entry and ticket from inside the prize transfer. `TicketPurchased` state exists before the canonical `RaffleCreated` publication point.

### Impact

Sponsor-controlled prize code can preallocate paid tickets and shape reserve progress or apparent demand before normal discovery. The purchase remains paid and visible once the transaction lands, so impact is limited, but creation-event consumers can observe unexpected event/state ordering.

### Recommendation

Keep the clone in `AwaitingPrize` through the receiver callback. After the transfer and custody checks, have only the factory execute a separate `activate` operation, then emit the creation event in a documented order.

## S6-05 — Informational/conditional — Quote accounting requires canonical fee-free token identity

### Evidence

The factory verifies only code and `decimals() == 6`:

- `RaffleFactory.sol:65-78`

Purchase accounting records the requested amount without measuring actual balance change:

- `Raffle.sol:223-233`

Payouts likewise assume exact standard transfer semantics:

- `Raffle.sol:560-566`

The intended assumption is documented at `IRaffle.sol:12-15`.

### Reproduction

`test_Evidence_FeeOnTransferQuoteCreatesCustodyDeficit` configures a 1% fee token. Buying ten entries records 10,000,000 units of liabilities while the raffle receives only 9,900,000.

### Disposition and recommendation

This is conditional because DESIGN.md explicitly trusts canonical fee-free USDC. Deployment automation must pin and independently verify the official per-chain token address and code. If arbitrary quote tokens are ever supported, account using balance deltas and separately handle rebasing and callback behavior.

# Step 1 — Known security issues

## Slither execution

From `packages/contracts`:

```text
slither . --exclude-dependencies
```

Result:

- Exit code: 255 because findings were emitted.
- Compilation succeeded using Foundry and Solidity 0.8.36.
- 36 contracts analyzed.
- 102 detectors executed.
- 14 results emitted.
- No High- or Medium-impact Slither detector result.

Structured rerun:

```text
slither . --exclude-dependencies --json <evidence>/tool-output/01-slither-results.json
```

Result: exit 255 with valid JSON.

Raw evidence:

- [Human-readable Slither output](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tool-output/01-slither-attempt-01.stderr)
- [Structured Slither JSON](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tool-output/01-slither-results.json)

No compiler, remapping, or source repair was necessary. An explicit PATH was supplied so Slither could find the known Forge binary. Slither detected both Foundry and Hardhat and selected Foundry.

## Complete detector triage

| # | Slither severity/confidence | Detector and source | Triage |
|---:|---|---|---|
| 1 | Low / Medium | `events-maths`: `initialize` writes `prizeTokenId` at `Raffle.sol:201`, `reserveEntries` at `:203`, and `endTime` at `:204` without a local event. | Informational/contextual false positive. Atomic factory creation later emits all values in `RaffleCreated` at `RaffleFactory.sol:136-147`; activation emits `PrizeDeposited` at `Raffle.sol:428-430`. |
| 2 | Low / Medium | `calls-loop`: `canonicalFactory.raffleImplementation()` at `Raffle.sol:599-601`, allegedly reachable from `refundTickets -> _burn -> _update`. | False positive. `_burn` supplies `to == address(0)`, so `to != address(0) && _isProtocolDestination(...)` short-circuits at `Raffle.sol:498`. The helper and factory getter do not execute in the loop. |
| 3 | Low / Medium | `calls-loop`: `canonicalFactory.isRaffle(destination)` at `Raffle.sol:603` on the same alleged stack. | False positive for the same short-circuit reason. The only external token call in `refundTickets` is the single aggregate payout after the loop at `Raffle.sol:367-369`. |
| 4 | Low / Medium | `reentrancy-benign`: wrapper call at `Raffle.sol:257`, followed by `vrfRequestId` and `_requestInFlight` writes at `:259-260`. | Conditional/mitigated. `requestDraw` is guarded; it sets `Drawing` and `_requestInFlight=true` before the call. An actual synchronous callback was tested and ignored. Wrapper correctness remains a trusted external assumption. |
| 5 | Low / Medium | `reentrancy-benign`: clone `initialize` at `RaffleFactory.sol:109-121`, followed by registry writes at `:123-124`. | False positive for the reported interaction. The target is a fresh fixed clone, initialization is one-shot/factory-only, and it does not call sponsor-selected code. The distinct later prize interaction was manually found as S6-04. |
| 6 | Low / Medium | `timestamp`: `enableRefunds`, `Raffle.sol:282,287,291`. | Informational, required lifecycle behavior. Exclusive deadline boundaries were tested. |
| 7 | Low / Medium | `timestamp`: `createRaffle`, `RaffleFactory.sol:100,102`. | Informational. Enforces a future end and maximum 30-day sale. |
| 8 | Low / Medium | `timestamp`: callback filter, `Raffle.sol:511-512`. | Informational. Exact callback/refund boundary passed testing. |
| 9 | Low / Medium | `timestamp`: purchase cutoff, `Raffle.sol:216`. | Informational. Required exclusive sale end; tested exactly at the boundary. |
| 10 | Low / Medium | `timestamp`: `callbackDeadline`, `Raffle.sol:464`. | False positive. `drawRequestedAt != 0` is a presence check, not timestamp ordering. |
| 11 | Low / Medium | `timestamp`: draw window, `Raffle.sol:242,245`. | Informational. The draw opens at sale end and closes exactly two days later; both edges were tested. |
| 12 | Informational / High | `assembly`: native refund at `Raffle.sol:266-268`. | Reviewed. It performs a memory-safe, zero-calldata value call to the original caller inside `nonReentrant`; failed refund reverts the transaction. No returndata or mutable memory is trusted. |
| 13 | Informational / High | `pragma`: nine compatible source constraints. | Informational. All five first-party files pin 0.8.36, and the complete graph compiled under 0.8.36 in Slither, Forge, and Echidna. |
| 14 | Informational / High | `naming-convention`: `IRaffle.ENTRY_PRICE()` at `IRaffle.sol:396`. | Intentional false positive. It is the ABI getter for an all-caps protocol constant and matches `Raffle.ENTRY_PRICE`. |

Generic static analysis did not identify S6-01 through S6-04; those came from manual trust-boundary analysis and adversarial executable tests.

# Step 2 — Special features

## Upgrade/proxy analysis

The explicit source/dependency search covered:

```text
proxy|upgrade|uups|transparent|beacon|diamond|erc1967|delegatecall|implementation|initializ|clone
```

It found:

- `Clones.clone(raffleImplementation)` at `RaffleFactory.sol:106`.
- Immutable `raffleImplementation` at `RaffleFactory.sol:42,89-91`.
- A locked implementation constructor at `Raffle.sol:151-166`.
- One-time clone initialization at `Raffle.sol:176-205`.
- Generic proxy/delegatecall utilities only in dependencies not selected by production.

No UUPS, transparent proxy, beacon, diamond, ERC-1967 slot, mutable implementation pointer, upgrader, proxy admin, owner, or upgrade entrypoint exists. ERC-1167 clones embed a fixed implementation target.

**Conclusion:** upgradeability checks are not applicable. A Slither upgradeability checker was not run because there is no upgradeable proxy pair or mutable upgrade mechanism to supply to it.

## ERC-721 conformance

Executed:

```text
slither-check-erc . Raffle --erc ERC721
```

Exit code: 0.

The tool marked all required functions present with correct return types/mutability where checked:

- `balanceOf`
- `ownerOf`
- Both `safeTransferFrom` overloads
- `transferFrom`
- `approve`
- `setApprovalForAll`
- `getApproved`
- `isApprovedForAll`
- `supportsInterface`
- `name`
- `symbol`
- `tokenURI`

It also confirmed:

- `Transfer`, `Approval`, and `ApprovalForAll`.
- Correct indexed fields.
- Expected event emission on transfer/approval paths.

The check analyzed the implementation contract. Because the deployed instances are ERC-1167 clones with constructor-set immutables, this was supplemented with `test_ERC721RuntimeConformanceOnClone`, which verified on an actual clone:

- ERC-165, ERC-721, and metadata interface IDs.
- Invalid interface rejection.
- Fixed name and symbol.
- Mint ownership and balances.
- Approval and operator transfer.
- Safe-transfer receiver rejection and atomic ownership rollback.

## Quote token, prize token, and wrapper integration

### Quote token

- Factory validates deployed code and six decimals at `RaffleFactory.sol:65-78`.
- Purchases use `SafeERC20.safeTransferFrom` at `Raffle.sol:223-224`.
- Claims use `SafeERC20.safeTransfer` at `Raffle.sol:560-566`.
- Standard, false-return, callback-capable, and fee-on-transfer mocks were executed.
- Exact accounting holds only under the documented canonical, fee-free, non-rebasing USDC assumption.

### Prize token

- Factory checks code and self-reported ERC-721 support at `RaffleFactory.sol:154-177`.
- Factory safe-transfers and checks self-reported ownership/status at `RaffleFactory.sol:127-134`.
- The clone validates callback tuple at `Raffle.sol:416-430`.
- Delivery uses `transferFrom` and self-reported ownership at `Raffle.sol:329-337,395-406`.
- Honest, missing-callback, lying, and reentrant prize implementations were executed.
- The arbitrary-prize trust boundary fails, as reported in S6-01.

### Chainlink wrapper

- Factory validates only code presence at `RaffleFactory.sol:65-67`.
- The inherited constructor calls the wrapper’s `link()` at `VRFV2PlusWrapperConsumerBase.sol:40-47`.
- Raffle price and estimate getters are at `Raffle.sol:435-448`.
- Draw request coordination is at `Raffle.sol:240-273`.
- Wrapper caller authentication is at `VRFV2PlusWrapperConsumerBase.sol:101-107`.
- Local callback acceptance is at `Raffle.sol:509-523`.

Synchronous, wrong-caller, wrong-ID, zero-word, late, duplicate, and valid callbacks were tested. The actual deployed wrapper implementation, identity, request-ID binding, retry policy, and randomness generation are absent from the target and remain external deployment assumptions.

## `slither-prop`

Applicability evidence established that:

- `Raffle` consumes an IERC20 quote token but does not implement ERC-20.
- The project is Foundry/Hardhat configured, not Truffle.
- No production ERC-20 inheritance exists.

The actual attempt was still executed:

```text
slither-prop . --contract Raffle
```

The process exited 0, but stderr reported:

```text
ERROR:root:Foundry not yet supported by slither-prop
```

No generated properties were silently assumed. `slither-prop` is inapplicable both because its controller does not support this Foundry project and because its generic properties target ERC-20 implementations. Project-specific Foundry and Echidna properties replaced it in Step 4.

# Step 3 — Visual security inspection

## Slither printers

All required printers executed successfully:

| Command | Exit | Preserved output |
|---|---:|---|
| `slither . --print inheritance-graph` | 0 | Raw Slither DOT and compiler/printer output |
| `slither . --print function-summary` | 0 | Complete raw table in `03-printer-function-summary.stderr` |
| `slither . --print vars-and-auth` | 0 | Complete raw table in `03-printer-vars-and-auth.stderr` |

The inheritance printer emitted DOT directly. The function-summary and vars-and-auth printers emit terminal tables, not DOT; their exact raw tables were retained and transcribed into supplemental DOT views for visualization. This is a disclosed controller adaptation.

## Graphviz rendering

Host `dot` was unavailable. Rendering used an authorized disposable Debian container.

Attempts were retained:

1. Direct bind-mount attempt: exit 126 because the Lima daemon could not create the host `/Users/.../Documents` mount path.
2. `docker cp` attempt: process exit 0, but incorrect outer-shell interpolation caused `dot: can't open .dot`; its artifacts were rejected.
3. Final `docker cp` attempt: exit 0, installed Graphviz, explicitly rendered all files, and copied results back.

Actual artifacts:

| View | DOT | PNG | PDF |
|---|---|---|---|
| Inheritance | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.dot) | [2055×3099 PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/inheritance-graph.pdf) |
| Function summary | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.dot) | [1453×1161 PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/function-summary.pdf) |
| Variables/auth | [DOT](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.dot) | [1056×669 PNG](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.png) | [PDF](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/diagrams/vars-and-auth.pdf) |

## Diagram review

### Shadowing and linearization

`Raffle` inherits:

- `IRaffle`
- OpenZeppelin `ERC721`
- `ReentrancyGuard`
- `IERC721Receiver`
- `VRFV2PlusWrapperConsumerBase`

The security-sensitive override points are coherent:

- Fixed `name` and `symbol`.
- `_update` for destination screening.
- `onERC721Received` for prize activation.
- `fulfillRandomWords` behind the inherited wrapper-only gateway.

No state shadowing or ambiguous authorization override was found. ERC-721 ownership mutation remains routed through OpenZeppelin `_update`, and VRF caller authentication remains in the Chainlink base.

Clones do not run `ReentrancyGuard`’s constructor, so their namespaced guard slot initially contains zero. The supplied OpenZeppelin implementation treats only value 2 as entered; zero is accepted as not-entered and normalized after the first guarded call. No clone-specific guard bypass was found.

### Callable surfaces and access control

- `initialize`: immutable factory only, one-time.
- `buyEntries`: permissionless payer, caller-selected recipient, active/time/quantity/transfer/receiver gates.
- `requestDraw`: permissionless funded keeper during fixed window.
- `enableRefunds`: sponsor-only for early empty cancellation; otherwise permissionless at deadlines.
- Settlement/releases: permissionless triggers, fixed or current-owner destinations.
- Redemption/refunds: exact current ticket owner.
- ERC-721 approvals/transfers: inherited owner/operator authorization plus destination screening.
- VRF gateway: immutable wrapper only, followed by state/ID/shape/time checks.
- Prize callback: exact tuple validation, but activation during the callback creates S6-04.

Slither’s vars-and-auth printer is syntactic: it can show no direct `msg.sender` condition when authorization lives in a modifier, helper, inherited function, or subsequent ownership check. Manual control-flow review supplied that context.

### State writers and authorization

- Factory immutables: constructor only.
- Factory count/registry: guarded `createRaffle` only.
- Clone configuration: `initialize` only.
- `Active`: exact prize callback only.
- Entry ranges/count/pot: guarded purchases only.
- Draw fields: guarded request only.
- Resolution fields: wrapper-authenticated callback only.
- Refund liability: guarded timeout/cancellation transition and owner-authorized burns.
- Terminal liability buckets: one-time settlement and clear-before-transfer release paths.
- ERC-721 ownership/approval: inherited OpenZeppelin paths through overridden `_update`.

# Step 4 — Security properties and testing

## New stage-native sources

No existing project tests or historical test corpus was used. The stage created its harness from frozen source and DESIGN.md:

- `S6TestBase.sol`
- `S6Mocks.sol`
- `S6SecureWorkflow.t.sol`
- `S6Invariant.t.sol`
- `S6KnownViolation.t.sol`
- `S6Echidna.sol`
- `echidna.s6.yaml`

Copies are under [tests/sources](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tests/sources).

Mocks covered:

- Standard, false-return, callback-capable, and fee-on-transfer quote tokens.
- Honest, missing-callback, lying, and creation-reentrant prize contracts.
- Synchronous and manual VRF callbacks.
- Accepting, rejecting, ticket-only, and reentrant recipients.

## Foundry results

### Final unit/fuzz campaign

```text
forge test \
  --match-contract S6SecureWorkflowTest \
  --fuzz-seed 0x53365f46494e414c5f46555a5a5f53454544 \
  --fuzz-runs 10000 \
  -vv
```

Exit 0:

- 21 tests passed.
- 0 failed.
- 0 skipped.
- Fee arithmetic property: 10,000 cases.
- Ticket partition/accounting property: 10,000 cases.

A valid machine-readable duplicate is preserved in `04-foundry-unit-fuzz-final-json.stdout`.

### Final invariant campaign

```text
FOUNDRY_INVARIANT_RUNS=256 \
FOUNDRY_INVARIANT_DEPTH=128 \
FOUNDRY_INVARIANT_FAIL_ON_REVERT=true \
forge test \
  --match-contract S6InvariantTest \
  --fuzz-seed 0x53365f46494e414c5f494e56415249414e54 \
  -vv
```

Exit 0:

- 3 invariants passed.
- 256 runs per invariant.
- Depth 128.
- 32,768 calls per invariant.
- 98,304 aggregate calls.
- 0 reverts and 0 discards.

Properties:

- Ranges remain a contiguous partition.
- Active-sale accounting matches custody and gross sales.
- No terminal liabilities exist during active sales.

A valid machine-readable duplicate is preserved in `04-foundry-invariant-final-json.stdout`.

### Known-violation campaign

```text
forge test \
  --match-contract S6KnownViolationTest \
  --fuzz-seed 0x53365f4b4e4f574e5f56494f4c4154494f4e \
  -vv
```

Exit 1, intentionally:

- `test_Property_AllRaffleClonesAreRejectedDestinations` failed because a cross-factory clone was accepted.
- `test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody` failed because the lying prize activated successfully.

These failures are evidence, not harness breakage. A valid JSON result is preserved in `04-foundry-known-violations-json.stdout`.

### Harness repair history

| Attempt | Exit | Result and repair |
|---|---:|---|
| Unit attempt 1 | 1 | 16 pass/5 fail. Four failures were exact-vs-partial custom-error expectation mismatches; one was a reentrant-prize fixture destination configuration. Test harness corrected only. |
| Unit attempt 2 | 1 | 20 pass/1 fail. A `wrapper.price()` getter consumed the “next call must revert” expectation; price was read before setting the expectation. |
| Boundary trace | 1 | `-vvvv` trace confirmed the harness-ordering issue. |
| Unit attempt 3 | 0 | 21/21 pass at 32 fuzz runs. |
| Final unit/fuzz v2 | 0 | 21/21 pass with 10,000 runs per fuzz property and strengthened full malicious-prize lifecycle reproduction. |
| Invariant attempt 1 | 1 | Minimal local `Vm` interface lacked the `targetContract` cheatcode selector. |
| Invariant attempt 2 | 0 | Exposed a Foundry-discoverable `targetContracts()` array; 3 properties passed at 32×32. |
| Final invariant | 0 | 3 properties passed at 256×128. |

No production source was edited to make a property pass.

## Echidna results

Because host `echidna-test` was absent, Echidna was run through the authorized Docker daemon.

The first version command used the image with `--version` as its direct command and exited 127 due image entrypoint semantics. The repaired invocation:

```text
docker run --rm ghcr.io/crytic/echidna/echidna:latest echidna-test --version
```

returned Echidna 2.3.3.

Final controller settings:

```yaml
testMode: property
testLimit: 20000
seqLen: 64
shrinkLimit: 5000
seed: 1396142931
workers: 1
coverage: true
corpusDir: echidna-corpus-s6
```

After installing/selecting Solidity 0.8.36 inside the container, the effective test command was:

```text
echidna-test test/foundry/s6/S6Echidna.sol \
  --contract S6Echidna \
  --config echidna.s6.yaml \
  --format text \
  --crytic-args "--compile-force-framework foundry"
```

Exit 0:

- 20,007 total calls.
- Sequence length 64.
- Seed 1396142931.
- 8,879 unique instructions.
- 8 unique code hashes.
- Corpus size 8.
- Four properties passed:

  - `echidna_no_terminal_liabilities_during_active_sales`
  - `echidna_active_sales_accounting_equals_custody`
  - `echidna_ranges_form_contiguous_partition`
  - `echidna_factory_registry_is_bidirectionally_consistent`

The image emitted an ARM64 warning that `solc-select` binaries are normally x86_64 and QEMU was absent. This was non-blocking: Solidity 0.8.36 installation, compilation, Slither preprocessing, and both Echidna campaigns completed successfully. The warning and successful output are both preserved.

The JSON result reports `success: true`, `error: null`, seed 1396142931, and four tests. The eight coverage sequences and HTML/LCOV/text reports are under [echidna-corpus-s6](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/06-secure-workflow/tests/echidna-corpus-s6).

## Foundry coverage

Final coverage command:

```text
FOUNDRY_FUZZ_RUNS=256 \
FOUNDRY_INVARIANT_RUNS=32 \
FOUNDRY_INVARIANT_DEPTH=32 \
forge coverage \
  --no-match-contract S6KnownViolationTest \
  --report summary
```

Exit 0.

| Production file | Lines | Statements | Branches | Functions |
|---|---:|---:|---:|---:|
| `src/Raffle.sol` | 87.04% (215/247) | 83.22% (243/292) | 34.48% (20/58) | 87.10% (27/31) |
| `src/RaffleFactory.sol` | 78.69% (48/61) | 81.48% (66/81) | 16.67% (3/18) | 100.00% (4/4) |

Coverage compilation disabled some optimizer/via-IR behavior and emitted source-map anchor warnings. It was used as a supplemental measurement, not as a substitute for adversarial properties or manual branch review.

## Per-property result matrix

| ID | Property | Result/evidence |
|---|---|---|
| LIF-01 | Clone initialization is factory-only and one-time. | Pass; initialization unit test and `Raffle.sol:176-205`. |
| LIF-02 | Implementation is locked/inert; initialized clone begins awaiting prize. | Pass; implementation/clone assertions. |
| LIF-03 | Only the exact configured prize callback tuple activates the raffle. | Pass for tuple enforcement and no-callback rollback. |
| LIF-04 | Activation proves genuine persistent prize custody. | **Fail; S6-01.** |
| LIF-05 | Sales require `Active` and `timestamp < endTime`. | Pass at exact boundary. |
| LIF-06 | Draw requests require sold entries and `[endTime,endTime+2d)`. | Pass at opening/closing boundaries. |
| LIF-07 | Callback requires wrapper caller, current ID, one word, Drawing state, no in-flight request, and pre-deadline time. | Pass locally; wrapper implementation remains external. |
| LIF-08 | Refunds open exactly at applicable deadlines; late callback cannot resolve. | Pass. |
| LIF-09 | Duplicate/wrong callbacks cannot rewrite a terminal result. | Pass. |
| AUTH-01 | Only current winning-ticket owner redeems. | Pass. |
| AUTH-02 | Ticket transfer/approval follows ERC-721 owner/operator authorization. | Pass, static and runtime. |
| AUTH-03 | Keepers cannot redirect fixed sponsor/protocol claims. | Pass, subject to destination findings. |
| AUTH-04 | Only the immutable wrapper reaches internal fulfillment. | Pass for caller authentication. |
| AUTH-05 | Only sponsor can cancel an empty raffle early; deadline paths are permissionless. | Pass by manual control-flow and boundary review. |
| ACC-01 | Ticket ranges form a positive, sequential partition of `1..totalEntries`. | Pass: 10,000-case fuzz, 98,304 invariant calls, and Echidna. |
| ACC-02 | During active sales, pot, gross sales, total-derived gross, and accounted balance agree. | Pass. |
| ACC-03 | Actual custody equals liabilities for canonical fee-free quote behavior. | Conditional pass using standard token model. |
| ACC-04 | Refund transition and per-ticket refund conserve 100% of the pot. | Pass. |
| ACC-05 | Terminal allocation buckets sum to gross. | Pass for NFT and cash outcomes. |
| ACC-06 | Reachable fee arithmetic has no dust. | Pass: 10,000 cases; each entry contributes exact 50,000 protocol and 800,000 cash-winner units. |
| ACC-07 | Claims clear state before transfer and failed transfers roll back. | Pass for standard tokens; malicious prize truthfulness fails separately. |
| ACC-08 | Six-decimal successful transfer implies exact balance delta. | **Conditional fail; S6-05.** |
| ACC-09 | Active sales have no terminal/refund liabilities or completion flags. | Pass in Foundry and Echidna. |
| TKT-01 | Incompatible ticket receiver rolls back payment, accounting, and mint. | Pass. |
| TKT-02 | Refund/redemption burns the ticket with its claim. | Pass. |
| TKT-03 | Historical ranges cannot independently authorize a second claim. | Pass by state/ownership/one-time-flag review. |
| ERC-01 | Required ERC-721 ABI/events/indexing conform. | Pass via actual `slither-check-erc`. |
| ERC-02 | Clone interface support, balances, approvals, transfers, and safe-receiver rollback conform at runtime. | Pass. |
| RE-01 | Quote and ticket callbacks cannot reenter protected purchase. | Pass. |
| RE-02 | Synchronous wrapper callback cannot resolve before request ID persistence. | Pass; ignored while in-flight. |
| RE-03 | Prize callback cannot mutate active sale state before factory publication. | **Fail; S6-04.** |
| RE-04 | Refund loop contains no external calls before aggregate payout. | Pass; Slither loop reports are infeasible due burn short-circuit. |
| PRIZE-01 | Prize omitting receiver callback cannot create a raffle. | Pass with full atomic rollback. |
| PRIZE-02 | Arbitrary prize cannot fake escrow/delivery. | **Fail; S6-01.** |
| PRIZE-03 | Prize delivery to contracts checks receiver acceptance. | **Fail; S6-02.** |
| DST-01 | Same-factory/local protocol sinks are rejected. | Pass. |
| DST-02 | All raffle clones, including other factories, are rejected. | **Fail; S6-03.** |
| DST-03 | Permissionless callers cannot redirect fixed proceeds. | Pass. |
| VRF-01 | Local callback binding/state validation is complete. | Pass. |
| VRF-02 | Deployed wrapper guarantees request binding and unpredictable unbiased words. | Unresolved external assumption; implementation/identity absent. |
| VRF-03 | `% totalEntries + 1` always selects a valid entry. | Pass. Theoretical modulo bias is below roughly `2^-128` at the maximum entry domain and informational. |

# Step 5 — Manual review

## Privacy

The explicit search covered secrets, private state, commit/reveal, salts, passwords, encryption, confidentiality, and hidden state.

No on-chain secret or privacy mechanism exists. Solidity `private` is used only for implementation encapsulation and is not confidential. Sponsor identity, purchases, entry ranges, ticket ownership, request IDs, liabilities, lifecycle, and the winning entry are public or reconstructible.

No privacy-specific vulnerability was found. Users must assume purchase activity and holdings are public.

## Front-running, ordering, and MEV

- Entry price is fixed; there is no AMM price or slippage parameter.
- Buyers can observe participation/reserve progress and choose whether to buy near the sale end. This is intrinsic to the public raffle.
- Entry ordering is deterministic, but the future VRF word is requested after sales freeze.
- Permissionless request, settlement, refund activation, and releases cannot select a recipient or alter allocated amounts.
- Normal block-timestamp discretion can move an exact boundary by roughly a block, but the sale and two-day windows are coherent.
- Ticket transfers after resolution intentionally transfer a bearer claim.
- S6-04 is the material ordering result: sponsor-selected prize code can create tickets before `RaffleCreated`.

No profitable sandwich, oracle-price, or keeper-redirection path was found.

## Cryptography, randomness, signatures, and hashes

The search covered `keccak256`, SHA functions, `ecrecover`, signatures, permits, nonces, blockhash, `prevrandao`, randomness, entropy, packed encoding, and timestamps.

- No custom first-party signature or permit scheme exists.
- No first-party blockhash or `prevrandao` randomness exists.
- Chainlink’s client uses typed extra-argument encoding.
- Wrapper caller authentication is an address equality check.
- Application callback binding uses caller, request ID, state, word count, in-flight state, and deadline.
- The `% totalEntries + 1` result is always one-based and in range.
- Theoretical modulo bias is negligible for `totalEntries <= 2^128-1`.
- `uint64(block.timestamp)` narrowing lacks an explicit range check but is safe for realistic deployment horizons.

Actual deployed VRF identity, implementation, request binding, retry behavior, and word quality could not be established from the supplied source.

## DeFi, oracle, flash-loan, and protocol assumptions

The explicit search found no:

- DEX/AMM integration.
- Lending/borrowing.
- Liquidation.
- Vault/pool accounting.
- Market oracle or price feed.
- Flash-loan callback.
- Swap/router interaction.

A flash loan provides no local price-manipulation surface: entries require a fixed quote-token transfer, and there is no same-transaction withdrawal path before the asynchronous lifecycle completes.

The external pricing surface is the trusted wrapper’s native request fee. The helper recalculates the actual price. If it exceeds `msg.value`, the post-call check reverts the entire transaction, including the wrapper interaction.

Protocol correctness still depends on:

- Correct official-USDC deployment selection.
- Correct official Chainlink wrapper selection.
- Wrapper request/fulfillment semantics.
- Prize collection trust policy.

## Dangerous primitive review

The search covered `tx.origin`, delegatecall, selfdestruct, assembly, CREATE2, low-level calls, signatures, unchecked blocks, and raw callbacks.

First-party production contains:

- No `tx.origin`.
- No selfdestruct.
- No upgrade delegatecall.
- One memory-safe assembly native refund at `Raffle.sol:266-268`.
- Fixed ERC-1167 clone creation.
- No custom cryptographic primitive.

Generic low-level and CREATE2 utilities exist in dependencies but are not selected by the first-party runtime paths under review.

# Per-file coverage

## Five production files

| File | Coverage |
|---|---|
| `src/Raffle.sol` | Full 614-line manual review; Slither detectors and printers; ERC-721 static check; direct Foundry fuzz/invariant and Echidna execution. 87.04% line coverage. All five findings intersect its lifecycle/external-call logic. |
| `src/RaffleFactory.sol` | Full 186-line review; Slither/printers; direct creation, clone registry, timing, malicious-prize, callback, and cross-factory tests. 78.69% line coverage and 100% function coverage. |
| `src/interfaces/IRaffle.sol` | Full 521-line ABI, event, error, lifecycle, and trust-assumption review; compiled and exercised by both controllers; included in ERC-721 conformance. |
| `src/interfaces/IRaffleFactory.sol` | Full 150-line creation/registry ABI, events, errors, and deployment-responsibility review; used by all factory harnesses. |
| `src/libraries/RaffleConstants.sol` | Full 43-line review; economics, timeouts, batch bounds, price, and VRF settings exercised or manually checked. |

## Thirty-one dependencies

| # | Dependency | Coverage |
|---:|---|---|
| 1 | `@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` | Full interface read; inherited LINK field/getter mapped. LINK payment path is unused. |
| 2 | `VRFV2PlusWrapperConsumerBase.sol` | Full review; constructor binding, native request helper, raw caller gate, getters, and dispatch executed. |
| 3 | `IVRFV2PlusWrapper.sol` | Full interface review; price, estimate, request, ID, and `link()` calls mapped. Implementation absent. |
| 4 | `VRFV2PlusClient.sol` | Full read; native-payment extra-args encoding directly exercised. |
| 5 | `interfaces/IERC1363.sol` | Full read; compiled through SafeERC20, but ERC-1363 helpers are not called. |
| 6 | `interfaces/IERC165.sol` | Full alias read; transitive interface dependency. |
| 7 | `interfaces/IERC20.sol` | Full alias read; transitive interface dependency. |
| 8 | `interfaces/draft-IERC6093.sol` | Full error-interface read; ERC-721 receiver/authorization errors exercised. Other error families are unreachable. |
| 9 | `proxy/Clones.sol` | Full clone-mechanism review; production `clone` executed. Deterministic/CREATE2 variants are not selected. |
| 10 | `token/ERC20/IERC20.sol` | Full interface review; transfers, approvals, balances modeled across four adversarial token behaviors. |
| 11 | `token/ERC20/extensions/IERC20Metadata.sol` | Full read; factory decimals validation executed. |
| 12 | `token/ERC20/utils/SafeERC20.sol` | Full review; selected safe transfer functions executed, including false-return rollback. Other helpers are unused. |
| 13 | `token/ERC721/ERC721.sol` | Full inheritance/authorization/update review; mint, burn, balance, owner, approvals, transfer, safe transfer, metadata, and interface paths executed. |
| 14 | `token/ERC721/IERC721.sol` | Full ABI/event review; static and runtime conformance. |
| 15 | `token/ERC721/IERC721Receiver.sol` | Full review; prize and ticket callbacks executed with accepting, rejecting, reentrant, and incompatible recipients. |
| 16 | `token/ERC721/extensions/IERC721Metadata.sol` | Full interface review; interface ID, name, symbol, and inherited token URI behavior mapped. |
| 17 | `token/ERC721/utils/ERC721Utils.sol` | Full receiver-check review; accept/reject/revert paths executed. |
| 18 | `utils/Bytes.sol` | Full source captured/read; transitive utility, no direct first-party call. |
| 19 | `utils/Context.sol` | Full read; `_msgSender` reached through ERC-721 authorization. |
| 20 | `utils/Create2.sol` | Full read; compiled via deterministic clone helpers but not selected by production. |
| 21 | `utils/Errors.sol` | Full read; supporting clone/low-level errors compiled; selected clone path reviewed. |
| 22 | `utils/LowLevelCall.sol` | Full read; generic low-level functions searched and determined unreachable from first-party paths. |
| 23 | `utils/Panic.sol` | Full read; transitive arithmetic/bytes utility, no direct call. |
| 24 | `utils/ReentrancyGuard.sol` | Full namespaced-slot and clone behavior review; callbacks and guarded entrypoints exercised. |
| 25 | `utils/StorageSlot.sol` | Full read; transitive utility. No first-party mutable implementation/admin slot exists. |
| 26 | `utils/Strings.sol` | Full source captured/read; transitive ERC-721 URI/math support. |
| 27 | `utils/introspection/ERC165.sol` | Full read; ERC-165/ERC-721/metadata/invalid-ID checks executed. |
| 28 | `utils/introspection/IERC165.sol` | Full interface review; factory prize queries tested against honest, missing-callback, and lying implementations. |
| 29 | `utils/math/Math.sol` | Full source captured/read; selected `mulDiv` reviewed and fee properties fuzzed 10,000 times. |
| 30 | `utils/math/SafeCast.sol` | Full source captured/read; compiled but not directly called. First-party timestamp casts reviewed separately. |
| 31 | `utils/math/SignedMath.sol` | Full read; transitive Strings helper, no signed first-party arithmetic. |

# Controller adaptations and unexecuted items

| Item | Disposition |
|---|---|
| Foundry instead of a generic property generator | Authorized native adaptation because the repository is Foundry-configured. Actual Echidna was also installed and run. |
| Echidna not on host PATH | Resolved through Docker using the supplied daemon. |
| Graphviz not on host PATH | Resolved by installing Graphviz in a disposable Debian container and using `docker cp`. |
| Function-summary/vars-and-auth visualization | Slither printers output tables rather than DOT; raw tables were preserved and supplemental DOT/PNG/PDF views were generated. |
| Slither compiler discovery | Explicit PATH supplied; no source, lock, config, or remapping modification needed. |
| `slither-prop` | Attempted; tool reported Foundry unsupported and target is not an ERC-20 implementation. Replaced with project-specific Foundry/Echidna properties. |
| Upgradeability checker | Not run because exhaustive search established a fixed-target ERC-1167 system with no upgrade mechanism or proxy-admin pair. |
| Manticore | Not run because the workflow’s executable-property requirement was fulfilled with project-native Foundry plus actual Echidna; adding a third controller would duplicate rather than unlock an otherwise unexecuted property class. |
| Live wrapper/USDC/deployment verification | Not executed because deployed addresses/implementations were absent and live transactions were not authorized. |
| Production fixes | Not applied because remediation was not authorized. |

# Limitations and unresolved leads

1. The actual deployed Chainlink wrapper implementation and address were not supplied. Request pricing, ID binding, word provenance, callback retries, upgrade authority, and liveness cannot be established from an interface alone.
2. The actual per-chain quote-token deployment was not supplied. Source checks cannot establish official-USDC identity from code presence and decimals.
3. Arbitrary future prize contracts are dynamic external code. S6-01 shows that interface checks cannot make them trustless.
4. Contract-recipient capabilities outside `IERC721Receiver` are unknowable; S6-02 demonstrates the concrete unsafe-delivery consequence.
5. Foundry branch percentages are lower than line coverage because the stage prioritized lifecycle properties, adversarial integrations, and exact boundaries over exhaustive error-branch enumeration.
6. Property campaigns demonstrate counterexamples and substantial generated coverage, not formal proof over all EVM states.
7. No chain-specific timestamp/sequencer behavior or deployed wrapper transaction was exercised.
8. Provider identity remains unknown because no provider event supplied one.

# Prioritized action plan

1. **Before launch: resolve S6-01.** Define and enforce a trusted-prize policy or custody adapter. Do not market arbitrary prize escrow as verified by ERC-165/callback/`ownerOf`.
2. **Replace prize `transferFrom` with `safeTransferFrom`.** Cover both winner redemption and sponsor return with incompatible and reentrant receiver tests.
3. **Move activation after factory custody checks.** Make the callback record receipt only; let the factory perform the final `Active` transition and publication.
4. **Define the multi-factory trust boundary.** Use a shared registry if “never between clones” is intended globally, or explicitly scope the guarantee.
5. **Pin external dependencies in deployment automation.** Verify official USDC and Chainlink wrapper addresses, code, chain ID, and expected configuration before and after deployment.
6. **Retain the S6 tests in CI.** Run deterministic unit/fuzz, invariants, known-violation regression tests, ERC conformance, and Echidna after remediation.
7. **Add deployed-integration tests.** On a non-production fork, verify wrapper request pricing/ID/callback behavior and the concrete quote-token implementation without broadcasting production transactions.
8. **Document event ordering and current-state reads.** Frontends should not assume `RaffleCreated` necessarily describes the first event/state unless S6-04 is fixed.

# Workflow checklist

- [x] Read the pinned skill, workflow steps, example report, permitted dossier, DESIGN.md, all five production files, and all 31 dependencies.
- [x] Run actual `slither . --exclude-dependencies`.
- [x] Preserve human-readable and JSON Slither results.
- [x] Triage all 14 detector results with severity and exact source lines.
- [x] Search explicitly for proxy and upgrade patterns.
- [x] Run actual ERC-721 `slither-check-erc`.
- [x] Review quote, prize, and wrapper interactions independently.
- [x] Attempt and disposition `slither-prop`.
- [x] Run all three required Slither printers.
- [x] Produce and inspect DOT, PNG, and PDF artifacts.
- [x] Review inheritance/linearization, callable surfaces/access controls, and state-writer authority.
- [x] Write a project-specific property document.
- [x] Create new stage-native Foundry fuzz/unit/invariant tests.
- [x] Create adversarial quote, prize, wrapper, and recipient mocks.
- [x] Run deterministic 10,000-case fuzz campaigns.
- [x] Run deterministic 256×128 invariant campaigns.
- [x] Install/containerize and run Echidna.
- [x] Preserve structured machine-readable results and corpus.
- [x] Preserve intentional property failures without modifying production.
- [x] Complete privacy, MEV/ordering, cryptography/randomness, and DeFi/oracle/flash-loan reviews.
- [x] Provide per-property and per-file coverage.
- [x] Copy all created test/property sources into S6 evidence.
- [x] Verify all 43 original target files remained byte-identical.
- [ ] Production remediation — not authorized.
- [ ] Live deployment/dependency validation — deployment data absent and live transactions not authorized.