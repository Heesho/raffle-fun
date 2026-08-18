# Ethereum release-readiness review — 2026-08-17

> **Superseded candidate snapshot.** This report covers the earlier Ethereum migration
> candidate before the range-receipt, fixed-$1, 5/95/0 redesign. It is retained only as
> historical review evidence. Do not use its contracts, sizes, counts, or release
> decision for the current v1; see `CURRENT-SPECIFICATION.md`, `CURRENT-CAMPAIGN.md`,
> and `RELEASE-CHECKLIST.md`.

## Decision

**Audit-ready release candidate; no-go for mainnet today.** The Ethereum/Chainlink
VRF/clone worktree has strong fresh internal evidence and materially safer deployment
validation. It is not a final release because it is uncommitted, has not been rerun
from a clean final SHA, has no independent audit of this exact design, and has not
completed the monitored Sepolia soak or production operational/legal gates.

No deployment, broadcast, source verification, ownership transaction, package
publication, push, or pull request was performed during this review.

## Reviewed candidate

| Item                    | Value                                                                       |
| ----------------------- | --------------------------------------------------------------------------- |
| repository              | `/Users/hishamel-husseini/Documents/projects/raffle-fun`                    |
| baseline `HEAD`         | `090e29fc5bd481e2e244bbd52a716a7143248d82`                                  |
| candidate identity      | dirty worktree on `main`; final SHA does not yet exist                      |
| compiler                | Solidity 0.8.36, Cancun, optimizer 200, no via-IR for production            |
| toolchain               | Foundry 1.7.1, Hardhat 3.11.1, Node 22.23.2, pnpm 11.18.0                   |
| production dependencies | OpenZeppelin Contracts 5.6.1; first-party native-only Chainlink VRF adapter |
| forge-std               | `37a36ca389095b2f677abb07642634573ba7e265`                                  |

## Release changes reviewed

- Replaced unsupported Pyth Entropy/Ethereum assumptions with Chainlink VRF v2.5
  direct native funding on Ethereum mainnet and Sepolia.
- Replaced full raffle deployment per creation with factory-locked ERC-1167 clones.
  Initialization is factory-only, one-time, and atomic with registry and NFT escrow.
- Kept existing raffles non-upgradeable and removed any proxy-admin or mutable
  implementation path.
- Made callback gas and confirmations mandatory deployment parameters.
- Enforced the current Ethereum-supported callback-gas ceiling and 3–200 confirmation
  range in the factory constructor as well as deployment validation.
- Bound deployment records to an exact finalized block/hash, deployment transactions,
  five runtime-code hashes, verified live wrapper limits/state, official USDC state,
  implementation lock, owner acceptance, and Lens binding.
- Updated SDK, generated ABIs, subgraph, web configuration, documentation, tests, CI,
  and the deterministic gas baseline.
- Raised dependency CI to fail on moderate advisories and verify package signatures.
  Removed the broad Chainlink npm package and its 105 unrelated dependencies; a small
  first-party adapter retains only native wrapper selectors, official extra-args
  encoding, and wrapper-authenticated callback behavior.

## Fresh internal evidence

| Gate                           | Result                                                                                                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| canonical Foundry suite        | 96 pass, 0 fail, 1 intentional fork skip                                                                                                                            |
| Hardhat deployment/integration | 13 pass, 0 fail                                                                                                                                                     |
| strict campaign                | 10,000 fuzz cases/property; 1,000 x 256 invariants; 96 pass, 0 fail, zero handler reverts                                                                           |
| comparison compiler            | via-IR, optimizer 1,000; 96 pass, 0 fail                                                                                                                            |
| release stress predecessor     | four properties, 338,800,128 total handler calls, zero reverts during one-hour pre-adapter campaign; adapter delta then passed the full strict and fork suites      |
| production coverage            | 99.76% lines, 92.78% branches, 100% functions                                                                                                                       |
| static analysis                | Slither 0 findings across 49 contracts / 64 detectors                                                                                                               |
| dependencies                   | `pnpm audit --audit-level moderate` pass; all 1,176 registry packages have verified signatures; one accepted Low `elliptic@6.6.1` advisory remains in tooling paths |
| secrets                        | all Git history and every changed/untracked source file pass Gitleaks; allowlisted matches are public collection/USDC addresses                                     |
| sizes                          | Raffle 16,510-byte runtime; factory 4,769-byte runtime / 23,535-byte initcode; Lens 6,649-byte runtime                                                              |
| gas regression                 | deterministic non-fuzz snapshot baseline passes single-threaded; fuzz/invariants run as separate correctness gates                                                  |

Coverage excludes scripts, mocks, and tests from the first-party denominator. Coverage
emitted known source-anchor warnings for clone-delegated code and mocks; the
production-only LCOV threshold script still passed. Internal testing and static tools
have false negatives and are not substitutes for an external audit.

## Ethereum fork evidence

Read-only fork tests exercised official USDC and wrapper code, factory/implementation
deployment, canonical clones, NFT escrow/ticket lifecycle, live-USDC purchases, native
request pricing, and unauthorized callback rejection.

| Network          | Pinned block | Block hash                                                           | Wrapper runtime hash                                                 | USDC runtime hash                                                    | Result |
| ---------------- | -----------: | -------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------- | ------ |
| Ethereum mainnet |   25,774,963 | `0xefc7388924303e18501bb3dd86443b6cb22339c02e21892a000b34c9b51c7107` | `0x79dd04a1a325740433d8ffbbc0a9217c5d88992d6f58c58daad0982d41f639bc` | `0xd80d4b7c890cb9d6a4893e6b52bc34b56b25335cb13716e0d1d31383e6b41505` | pass   |
| Ethereum Sepolia |   11,508,270 | `0x4e1bdccfe83df56f2d45dbb8b8cd671183c9e69068ffc8d1b5acbb7c8cf42acd` | `0x079cd722dd7b8789bdb5f313d032e4f8fe66bb75e93f07acd6ec33b50d1dc42b` | `0xcd3f29e2ea9c61dadd48bfeaf8b2884b6de9dfee7bf45329452c4c33d0868ceb` | pass   |

Latest-head runs also passed. These observations are block-specific and must be
repeated against the clean final SHA and on release day.

## Remaining no-go conditions

1. Create one final source commit and rerun every aggregate, fork, ABI/codegen, and
   deployment-validation gate from a clean checkout; record all hashes.
2. Obtain an independent audit of the exact commit, lockfile, clone initialization and
   storage model, VRF direct-funding/authentication/gas/confirmation/timeouts, asset
   accounting, and deployment configuration. Resolve every Critical/High and supported
   Medium.
3. Select and independently review the owner and treasury Safes, signer thresholds,
   modules/guards/recovery, callback gas, confirmations, and maximum supported value.
4. Deploy only the candidate to Sepolia, verify every contract, accept Safe ownership,
   install the monitors, and complete `docs/SEPOLIA-SOAK.md` plus incident drills.
5. Complete jurisdiction-specific gaming/promotion, consumer, sanctions, tax, privacy,
   and terms review. Decide whether mainnet requires an onchain gross-value cap: the
   current permissionless contracts have none, and a frontend cap is not enforceable.
   Any contract change must precede the final audit and repeat affected campaigns.
6. Perform a written go/no-go review. Only then may a guarded mainnet operator
   procedure be authorized and the exact finalized deployment record signed.

## Current primary references

- Chainlink VRF v2.5 supported networks and Ethereum wrapper limits:
  <https://docs.chain.link/vrf/v2-5/supported-networks>
- Chainlink direct-funding integration and security notes:
  <https://docs.chain.link/vrf/v2-5/direct-funding/get-a-random-number>
- Circle official USDC contract addresses:
  <https://developers.circle.com/stablecoins/usdc-contract-addresses>
- OpenZeppelin fixed minimal clones:
  <https://docs.openzeppelin.com/contracts/5.x/api/proxy>
- ERC-1167 minimal-proxy standard: <https://eips.ethereum.org/EIPS/eip-1167>
- Solidity known bugs: <https://docs.soliditylang.org/en/latest/bugs.html>
