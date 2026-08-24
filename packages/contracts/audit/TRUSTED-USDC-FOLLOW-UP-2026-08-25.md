# Trusted canonical USDC follow-up — 2026-08-25

## Status and authoritative decision

This is the current review record for the trust-model clarification applied after merge
`90ecd7d74a6efcc0ce32aa0ac7a0478924be0d88`. USDC is the trusted canonical quote token.
Production deployment tooling must pin the target chain's official USDC address; the
factory constructor itself proves only code presence and six-decimal metadata.

Canonical USDC is assumed to be non-rebasing and to transfer the requested amount
without sender taxes, recipient fees, or bonus credits. Every transfer still uses
OpenZeppelin `SafeERC20`, but the raffle no longer repeats USDC's accounting with sender
or recipient balance snapshots.

This is an explicitly authorized behavior and trust-boundary change. It supersedes the
2026-08-24 standardization record's decision to retain exact-transfer delta checks.

## Source and ABI changes

- `buyEntries` now calls `safeTransferFrom` for `grossAmount` without pre/post
  `balanceOf` reads.
- `_transferQuoteExact` is renamed `_transferQuote` and now performs the existing
  protocol-destination rejection followed by `safeTransfer`.
- `IRaffle.UnsupportedQuoteToken(uint256,uint256)` and
  `IRaffle.UnsupportedQuoteTokenTransfer(uint256,uint256,uint256)` are removed because
  no execution path can raise them.
- The distinct `IRaffleFactory.UnsupportedQuoteToken(address)` remains: it reports a
  failed quote-token metadata read during factory construction.
- Function, event, and getter selectors are unchanged. Generated SDK and subgraph ABI
  copies remove only the two Raffle errors above.
- Canonicalized storage layouts for both deployed contracts are identical to baseline.
- `Raffle` runtime size is 15,947 bytes, 1,027 bytes below the preceding 16,974-byte
  candidate and 8,629 bytes below the EIP-170 limit. `RaffleFactory` runtime remains
  3,949 bytes; its initcode shrinks because it embeds the Raffle creation code.

## Preserved security boundaries

- `SafeERC20` rejects reverted and false-returning inbound or outbound calls.
- `nonReentrant`, checks-effects-interactions ordering, ticket burns, liability
  zeroing, overflow checks, accounting caps, fixed payout recipients, and protocol-sink
  rejection remain unchanged.
- New regression coverage proves a failed outbound SafeERC20 call restores both a
  fixed-recipient claim and a cash winner's ticket plus lazy settlement.
- Hardhat deployment validation now explicitly rejects a six-decimal quote-token
  address that is not the chain's configured official USDC.
- Circle pause, blocklist, proxy-upgrade, and transfer-liveness risks remain external.
  A wrong or later-nonstandard token can violate solvency and is outside the supported
  deployment model.

## Intentionally preserved historical evidence

`current-mutations.json`, its result JSON, and the superseded mutation-campaign narrative
remain unchanged and commit-bound to their recorded pre-follow-up source. They therefore
contain obsolete source snippets such as `_transferQuoteExact`. Updating one definition
without rerunning and re-fingerprinting the full campaign would falsify the retained 52/52
record. No mutation score is claimed for the trusted-USDC implementation; a clean campaign
remains a final-release gate.

## Verification

| Gate                                                | Result                                        |
| --------------------------------------------------- | --------------------------------------------- |
| Standard Foundry suite                              | 79 passed, 0 failed, 1 RPC-gated fork skip    |
| Hardhat suite                                       | 22 passed                                     |
| `FOUNDRY_PROFILE=audit`                             | 79 passed, 0 failed, 1 RPC-gated skip         |
| `FOUNDRY_PROFILE=audit_strict`                      | 79 passed, 0 failed, 1 RPC-gated skip         |
| Coverage                                            | 99.68% lines, 90.79% branches, 100% functions |
| Gas snapshot                                        | Regenerated and freshness check passed        |
| Slither                                             | 46 contracts, 64 detectors, 0 findings        |
| Compiler size report                                | Passed                                        |
| Canonical storage-layout comparison                 | Identical for Raffle and RaffleFactory        |
| ABI comparison                                      | Only the two authorized Raffle errors removed |
| SDK ABI sync                                        | Regenerated and freshness check passed        |
| Subgraph codegen, build, and mappings               | Passed; 8 mapping tests                       |
| Repository format, lint, typecheck, build, and test | Passed                                        |
| Current-source mutation campaign                    | Not rerun; historical evidence preserved      |

The Ethereum fork test remains unavailable without an RPC URL. Completed local tests
validate the clarified code and deployment mapping; they do not establish live
deployment readiness or replace an independent security review.
