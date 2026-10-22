# DAYBREAK-PASHOV — First-pass record

- Sealed at: `2026-10-21T08:02:26Z` (`2026-10-21T01:02:26-0700`, America/Los_Angeles)
- Supplied target SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- Workflow: Pashov `solidity-auditor`, supplied pin `8ce544c9c9affab448d3dc4c79191d052e3a57ec`, version file `4`
- Pass policy: one pass; prior-project memory off; repeated-run finding memory off
- Runtime policy: local selection `gpt-daybreak-blue-latest`; effort `ultra`; access program `daybreak_blue`; fallback disabled
- Provider-returned model/identity: `unknown` (the event streams contain no provider model or identity field)
- External reconciliation before this seal: none

## Original conclusions

The native Pashov report contains zero findings and zero leads because all 12 specialist threads failed before a response. Its exact coverage warning is: `No pass produced a run file. This scan reviewed nothing.` The zero count is not a clean-code conclusion.

The native dedup and four-gate judge stages are `INCOMPLETE/BLOCKED`. The native assembler stage completed and preserved its exact output at `native/full-report.md`.

The controller found one separate, source-supported lead before this seal. It is not inserted into or presented as a native Pashov finding:

- `CL-01 — untrusted-prize-self-report`: A sponsor-controlled prize contract can fabricate ERC-165 support, escrow, ownership, and delivery observations.
- Complete demonstrated path: a sponsor creates a reserve-one raffle with the fake prize; a buyer pays 1,000,000 units; the raffle resolves `NftWon`; the sponsor receives 950,000 units; the fake prize stays in the sponsor's internal ledger while `ownerOf` reports delivery to the winner.
- Source path: `RaffleFactory._validateCreateParams` lines 171-177 → `RaffleFactory.createRaffle` lines 127-133 → `Raffle.onERC721Received` lines 416-430 → `Raffle._settleWinningTicket` lines 533-557 → `Raffle.redeemWinningTicket` lines 329-336.
- Proof: `proofs/UntrustedPrize.t.sol`; final Forge result: two tests passed.
- Process classification: `LEAD`, unscored, because the required native specialist and judge stages did not complete.
- Minimal remediation direction: use a trusted immutable prize-token registry, or change the stated trust model because an arbitrary ERC-721 contract can fabricate every onchain ownership observation.

The isolated source copy compiled successfully: 36 files, Solidity 0.8.36. This compile result proves interface and compiler consistency only; it is not security coverage.

## Per-file coverage

| Production file | In all 12 bundles | Compiled | Specialist responses | Native dedup/judge | Controller coverage before seal |
|---|---:|---:|---:|---:|---|
| `Raffle.sol` | yes | yes | 0/12 | blocked | Partial targeted trace for prize activation, settlement, and redemption only |
| `RaffleFactory.sol` | yes | yes | 0/12 | blocked | Partial targeted trace and executable proof for untrusted prize admission only |
| `interfaces/IRaffle.sol` | yes, explicit | yes | 0/12 | blocked | Interface/compiler consistency only |
| `interfaces/IRaffleFactory.sol` | yes, explicit | yes | 0/12 | blocked | Interface/compiler consistency only |
| `libraries/RaffleConstants.sol` | yes | yes | 0/12 | blocked | Constants used by the targeted proof; no complete arithmetic review |

File hashes at seal time:

| File | SHA256 |
|---|---|
| `Raffle.sol` | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| `RaffleFactory.sol` | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| `IRaffle.sol` | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| `IRaffleFactory.sol` | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |
| `RaffleConstants.sol` | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |

## Per-property coverage

| Required native property/lens | Assigned context | Response returned | Status |
|---|---:|---:|---|
| Math and precision | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Access control | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Economic security | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Execution trace | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Invariants | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Periphery | 1 | 0 | `INCOMPLETE/BLOCKED` |
| First principles | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Asymmetry | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Boundaries | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Numerical gap hunter | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Trust gap hunter | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Flow gap hunter | 1 | 0 | `INCOMPLETE/BLOCKED` |
| Solidity compilation and interface consistency | local tool | complete | `COMPLETE`, non-security diagnostic |
| Untrusted prize admission-to-payout path | controller-only proof | complete | `PARTIAL`, not a native specialty or judge result |

No partial lens is represented as a full scan. Native analytical coverage is `0/12`, native run-file coverage is `0/1`, and full-scan completion is false.

## Native stage disposition

- Turn 1 discovery/scope: `COMPLETE`
- Turn 2 source and 12 bundles: `COMPLETE`
- Turn 3 specialists: `FAILED`, 0/12 returned
- Turn 4 dedup/canonicalization: `INCOMPLETE/BLOCKED`
- Turn 4 four-gate judging: `INCOMPLETE/BLOCKED`
- Turn 4 `run-1.md`: `INCOMPLETE/BLOCKED`, absent by native rule
- Turn 5 native assembly: `COMPLETE`, 0 run files and explicit coverage warning

`SEAL.json` stores the SHA256 of this exact file and the sealed artifact manifest. Corrections after sealing must be appended in a separate corrections file; this report must not be overwritten.
