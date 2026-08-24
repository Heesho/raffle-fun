# Production Solidity source standardization — 2026-08-24

> **Superseded trust-model decision:** This record describes merge
> `90ecd7d74a6efcc0ce32aa0ac7a0478924be0d88`. On 2026-08-25, USDC was explicitly
> designated the trusted canonical token, superseding this record's decision to retain
> inbound and outbound balance-delta checks. Use the newer trusted-USDC follow-up record
> for the current candidate.

## Status and scope

This is the current, commit-bound review record for the production Solidity source at
`packages/contracts/src/**`. It is not an independent security audit or a deployment approval. Older records in this
directory are retained as historical evidence and are explicitly marked as superseded where their source references or
release conclusions no longer describe the current candidate.

The complete owned production set reviewed was:

- `Raffle.sol` — fixed raffle implementation used by ERC-1167 clones;
- `RaffleFactory.sol` — canonical clone factory and atomic prize escrow;
- `interfaces/IRaffle.sol`;
- `interfaces/IRaffleFactory.sol`;
- `libraries/RaffleConstants.sol`.

Tests, mocks, scripts, vendored dependencies, compiler output, caches, and generated consumer artifacts were excluded
from the production-source inventory. They were inspected or regenerated where needed to validate behavior.

The resulting production graph remains two deployed contracts: one `RaffleFactory` and its immutable `Raffle`
implementation, from which the factory creates fixed-target minimal proxies. The interfaces and constants library do
not add deployed protocol roles.

## Authoritative decisions applied

- The requested NatSpec author is exactly `heesho`, rendered as `/// @author heesho` immediately below every
  production `@title`.
- No trusted canonical token was named in the supplied decision template. The exact inbound and outbound balance-delta
  checks therefore remain part of the quote-token accounting boundary. Removing them without a concrete trusted-token
  decision would weaken existing security behavior.
- No liquidity architecture, token display-name change, or other protocol behavior change was supplied. No speculative
  liquidity, governance, compatibility, or rescue mechanism was added.

## Change classification

### Explicitly authorized protocol changes

None. The author correction changes documentation metadata only.

### Behavior-preserving cleanup

- Replaced the duplicate initialization/runtime protocol-destination predicates with one parameterized
  `_isProtocolDestination` helper. Initialization supplies the prospective prize-token address; runtime callers supply
  the stored prize-token address, preserving the former address set in both contexts.
- Cached the factory's `IERC721` prize reference across transfer and post-transfer ownership verification.
- Standardized source sections and moved existing functions into lifecycle-oriented source order.
- Retained explicit zero/false local initialization where Slither uses it to prove initialization.
- Removed the unused `OnlySponsor(address,address)` interface error. No production code referenced or emitted it.

### Documentation-only changes

- Completed NatSpec for every production contract, interface, library, public API, generated getter, type, event, error,
  constructor, parameter, return value, and non-trivial internal/private helper.
- Documented raw six-decimal quote-token units, native-token wei, timestamps, lifecycle scope, exact-transfer behavior,
  claim state, percentage rounding, and sponsor-remainder handling at the relevant declarations.
- Reconciled the current technical whitepaper and fact registry with the consolidated helper and the removed error.
- Replaced brittle production-source line suffixes in current facts with stable file-and-symbol references.
- Marked prior audit records as historical rather than rewriting their original evidence.
- Regenerated the three current public PDFs.

## ABI, storage, and executable-source review

- Function and event selectors are unchanged.
- The generated `Raffle` ABI removes only the unused `OnlySponsor(address,address)` error entry.
- `IRaffleFactory` now declares the already-existing `raffleCount()` public getter. This corrects interface completeness;
  it does not add a runtime selector to `RaffleFactory`.
- SDK and subgraph ABI copies were regenerated using the repository sync command. No SDK action or subgraph mapping
  required a semantic change.
- Canonicalized `forge inspect ... storageLayout` output is identical to baseline for both deployed contracts after
  removing compiler-local AST and numeric type IDs. Storage order, slots, offsets, and encodings did not change.
- Comment-and-whitespace stripping produced identical executable source for the documentation-only
  `RaffleConstants.sol` (`565` normalized characters; SHA-256 prefix `ac29e78c296f` before and after). The other four
  files intentionally have normalized differences corresponding to the helper consolidation, cached reference,
  removed unused error, and existing-getter interface declaration described above; those files are not misclassified
  as documentation-only.
- Runtime bytecode is not claimed to be identical: the implementation cleanup changes code generation. Behavior is
  supported by the tests and invariants below, while the storage-layout comparison establishes layout compatibility.
- Size reporting passes with `Raffle` at 16,974 runtime bytes (7,602-byte EIP-170 margin) and `RaffleFactory` at 3,949
  runtime bytes (20,627-byte margin).

## Verification record

All JavaScript commands used the repository-supported Node.js 22 runtime. The default shell's Node.js 20 fails before
project execution with `ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING`; that is an environment mismatch, not a source failure.

| Gate                                                | Result                                                                              |
| --------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Solidity formatting                                 | Passed                                                                              |
| Solidity lint                                       | Passed with warnings only; no errors                                                |
| Hardhat and Foundry compilation                     | Passed                                                                              |
| Standard Foundry tests                              | 80 passed, 0 failed, 1 RPC-gated fork test skipped                                  |
| Hardhat tests                                       | 21 passed                                                                           |
| Coverage                                            | 99.69% lines, 91.14% branches, 100% functions                                       |
| Gas snapshot                                        | Regenerated for the cleanup and passed freshness check; 62 passed, 1 RPC-gated skip |
| Slither                                             | 48 contracts, 64 detectors, 0 findings                                              |
| `FOUNDRY_PROFILE=audit`                             | 80 passed, 0 failed, 1 RPC-gated skip                                               |
| `FOUNDRY_PROFILE=audit_strict`                      | 80 passed, 0 failed, 1 RPC-gated skip                                               |
| `FOUNDRY_PROFILE=audit_release`                     | Stopped after more than one hour without a suite result; see below                  |
| Compiler size report                                | Passed; both production contracts remain below runtime and initcode limits          |
| Repository format, lint, typecheck, build, and test | Passed                                                                              |
| SDK ABI sync                                        | Passed                                                                              |
| Subgraph codegen and build                          | Passed                                                                              |
| Subgraph mappings                                   | 8 passed                                                                            |
| Current PDF builder                                 | 3 PDFs generated                                                                    |
| Current Markdown local links                        | Passed                                                                              |

The maximum `audit_release` profile uses 100,000 fuzz runs plus 5,000 invariant runs at depth 512 with a 3,600-second
invariant timeout. It remained CPU-active but produced no suite result after more than one hour and was terminated. This
is an incomplete optional maximum-depth campaign, not a failing assertion; the standard, `audit`, and `audit_strict`
profiles completed successfully. The retired `docs/whitepaper/**` builder is intentionally not run:
`docs/WHITEPAPER.md` states that it targets the superseded Base/Pyth design, depends on removed symbols, and must not be
used for current publication.

## Intentionally unchanged boundaries and remaining gates

- Exact-transfer token checks, non-reentrancy, accounting caps, fixed recipients, deadline boundaries, ticket ownership,
  post-transfer prize ownership checks, and pull-based claims remain unchanged because each protects an existing
  invariant.
- The factory, clone lifecycle, Chainlink request/callback flow, 80/5/15 outcome accounting, full-refund accounting,
  rounding direction, and empty-raffle behavior remain unchanged.
- No Ethereum RPC URL was configured, so the existing live Ethereum fork test remains skipped. Local mock, adversarial,
  invariant, Hardhat, SDK, web, and subgraph behavior passed; this does not establish live deployment readiness.
- The candidate is still not deployed and not independently audited. Deployment records, production environment
  configuration, live endpoints, external review, and a live smoke test remain separate release gates.
