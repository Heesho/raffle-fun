# Gemini Simao attempt-04 append-only semantic adjudication

Recorded at `2026-10-21T23:36:05Z` for frozen target commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

## Decision

The native Simao judge remains an immutable transport and method-completion `SUCCESS`. Its sealed `FIRST-PASS.md` and `gate-ledger.md` are not accepted verbatim as semantically correct. This append-only adjudication corrects their status, source-anchor, severity, finding-disposition, and mitigation defects without changing any native or leaf artifact.

For matrix purposes, the Simao lane is **qualified only as the effective chain consisting of the sealed native `SUCCESS` plus this coordinator adjudication**. The native report by itself remains semantically unqualified. This package is not a global audit completion, release authorization, owner risk acceptance, proof that no other defect exists, or authorization to modify production code.

The corrected result adds no production root. Every native final item and retained lead maps to an existing reconciliation entry.

## Bound native result and route

- Cell: `SIMAO`.
- Recorded method: `exact-pinned-simao-post12leaf-native-adjudication-and-assembly`.
- Recorded route/model label: `gemini-4-argon-high`; recorded effort: `high`. This package repeats the receipt's label and does not infer an undisclosed model identity.
- Native conversation UUID: `e2b68668-c60b-4b9d-a773-27794ecc401f`.
- Terminal result: `SUCCESS`, transport status `native-stage-transport-completed`, process exit `0`, ended `2026-10-21T22:19:29.924244+00:00`.
- Strict transport receipt SHA-256: `e52fa41d3c31264fdf9ececfca90158803af9ee3a77e389c900e3d2c5eddfce8`.
- Sealed native report SHA-256: `0ef7933f0a78a897c2c0ddec092501f056668c461a5231ff5958e7f0f6aeb937`.
- Native completion receipt SHA-256: `43d3c2364efcc7cd73cc3e0c9884e3c03f4d87418678e55b0e5ae020f790b36f`.
- Native integrity seal SHA-256: `c95268ecd8269b24c1dba217fb31869a5c8144310a3b4ae1fc473924b786cc64`.

The frozen-input verifier completed with `ok: true`, `errors: []`, 435 files per working-tree/snapshot root, 31 reachable dependency files, and five production files. The native receipt's exact 43-file judge binding was independently rehashed. The integrity manifest accompanying this adjudication records every one of those 43 paths and hashes.

## Immutable historical leaf status correction

The native gate ledger line 5 is wrong. It names leaf 03 and leaf 06 as historical errors and uses fields that do not describe the effective binding. The exact effective statuses are:

| Leaf | Lens | Immutable native status | Report SHA-256 | Strict receipt SHA-256 |
|---|---|---|---|---|
| 03 | `temporal-cohort` | `ERROR` / `failed` | `52c062bfb6d23c6e6680712c45c7e1c6915b3fa893cf21f97142ac6c1ca860a3` | `95e4eadc75a789f24a25a7f1e3fa94b3587de3779767a19343783a734fa68b8b` |
| 04 | `liquidation-solvency` | `ERROR` / `failed` | `09c5299fea76260931864d4a3235d622960de66d328358641ef2a6a9af4a82b4` | `31bdeeb55d09699a5dbe2687a124abfecdeb439dac6a3f5320858a998809fe15` |
| 06 | `rounding-precision` | `SUCCESS` / `transport-completed` | `ee80f41b7985f6ec472d61e428ee4572093694804b67ec59bbe21250e4247a0e` | `92cba8cd473bbddd05652985feb3171b39914c1a1bc0872c84ab15afb86b6ccd` |

The leaf 03 and 04 reports remain usable as hash-bound specialist text because the coordinator had separately checked their closing output, but their transport statuses remain `ERROR`. Neither this adjudication nor any matrix may relabel them `SUCCESS`.

## Source and anchor corrections

The authoritative source for this adjudication is the 43-file clean-context binding, not generated concatenation offsets.

| File | Physical lines | SHA-256 |
|---|---:|---|
| `DESIGN.md` | 4 | `25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1` |
| `packages/contracts/src/Raffle.sol` | 614 | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` |
| `packages/contracts/src/RaffleFactory.sol` | 186 | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 43 | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` |
| `packages/contracts/src/interfaces/IRaffle.sol` | 521 | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 150 | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` |

The gate ledger's claimed physical counts of 22, 212, and 65 for `RaffleConstants.sol`, `IRaffle.sol`, and `IRaffleFactory.sol` are generated-bundle range lengths, not the bound physical files. They are rejected as physical-source metadata.

The honest-prize interface statement is at `IRaffle.sol:12-15`, specifically lines 14-15, not line 202. Line 202 declares `UnexpectedPrize`. More importantly, `DESIGN.md:2` and `SCOPE.md` explicitly place arbitrary prize contracts inside the untrusted boundary, while `RaffleFactory.sol:171-178` enforces only an ERC-165 response and `RaffleFactory.sol:128-134` checks only the initial escrow state. The non-enforced interface prose cannot exclude an attacker-created ERC-721 from the audited reachable state space.

For M-1, the correct physical anchors are `Raffle.sol:329-337`, `375-392`, and `533-558`; the creation path is `RaffleFactory.sol:97-134` and `171-178`. Native Option B's `Raffle.sol:388/398` function anchors are rejected: the entry lines are 375 and 385.

## Final finding adjudication

| Native ID | Existing entry IDs | Corrected disposition | Corrected severity |
|---|---|---|---|
| `M-1` | `RF-001`; blacklist aside `OBS-002` | Confirm the untrusted-prize payout/delivery separation under the declared scope. Reject the unverified ENS/ERC721C deployed-token examples as proof and keep the isolated USDC-recipient observation separate. | **High under the explicit untrusted-prize scope**; a narrower honest-prize-only product would instead have a documented trust limitation. |
| `M-2` | `CLOSED-002`; duplicated delivery component `RF-001` | Reject the standalone Medium. Sponsor top-up and the reserve cliff are disclosed open-sale/outcome economics. M-2 can be a reachability step for RF-001 but is not another root. | No standalone security severity. |
| `M-3` | `CLOSED-002` | Reject. Sales remain open to all participants through `endTime`; no fixed-odds or sponsor-exclusion promise exists. A transaction slippage field cannot prevent later purchases. | No security severity. |
| `L-1` | `CLOSED-004` | Reject. A paid entry validly makes the raffle nonempty, ending the sponsor's exceptional pre-end empty-raffle cancellation path. | Not a security finding. |
| `L-2` | `OBS-008`, `EVIDENCE-001`, `CLOSED-002` | Split the bundled claim. Caller-funded single-request VRF is a bounded operating risk; genuine live fulfillment remains an assurance gap; the single-owner cash split is specified economics. | Informational / unscored assurance, not Low. |
| `I-1` | `RF-002`, `OBS-004` | Confirm the sponsor-selected future-clone sink sequence and recipient-capability limitation; it is self-selected and not a general theft path. | Low for RF-002; informational for OBS-004. |
| `I-2` | `RF-002` | Treat as the prize-return leg of RF-002, not a new root. The sponsor chooses the immutable recipient. | No additional severity beyond RF-002 Low. |
| `I-3` | `RF-001`, `OBS-004` | Split: malicious prize refusal is RF-001; absence of a receiver callback for a contract ticket owner is a recipient-capability limitation. | RF-001 High under untrusted-prize scope; otherwise informational. |
| `I-4` | `CLOSED-002` | Reject as a separate defect; this is the documented reserve boundary already considered with M-2. | No security severity. |
| `I-5` | `OBS-006` | Confirm event/callback ordering only. Factory post-transfer checks and transaction atomicity prevent the claimed corruption path; no asset loss was shown. | Informational. |
| `I-6` | `OBS-006`, `CONFIG-002` | Split event ordering from the public extreme-reserve configuration. Neither establishes an undisclosed loss path. | Informational / intended configuration. |
| `I-7` | `CONFIG-002`, `ADVISORY-001` | Extreme reserve is public intended configuration. `prizeToken == protocolTreasury` already reverts atomically in `Raffle.initialize`; the difference is validation location/error reporting only. | No security severity. |

The native report's corrected effective counts are therefore not its printed `0 High / 3 Medium / 2 Low / 7 Info`. This adjudication contributes no new root: it maps the source-supported malicious-prize mechanism to existing `RF-001`, the future-clone sink to existing `RF-002`, and all other material to existing observation, assurance, configuration, advisory, or closed entries. Matrix counts must come from the controlling reconciled register rather than recounting these native IDs.

## Retained unverified-lead mapping

The native report's 12 unnumbered lead summaries remain unpromoted and map as follows: `_isProtocolDestination` to `RF-002`/`OBS-004`; `releaseSponsorPrize` to `RF-002`; recipient blacklist to `OBS-002`; payout-before-delivery and settlement-before-delivery to `RF-001`; `redeemWinningTicket` to `RF-001`/`OBS-004`; `requestDraw` to `OBS-008`/`EVIDENCE-001`/`CLOSED-002`; `buyEntries` and `fulfillRandomWords` to `CLOSED-002`; `enableRefunds` to `CLOSED-004`; `onERC721Received` to `OBS-006`; `createRaffle` to `OBS-006`/`CONFIG-002`; and `_validateCreateParams` to `CONFIG-002`/`ADVISORY-001`.

## Mitigation and diff corrections

No native diff is approved as ready to apply.

1. M-1's sample has the wrong `releaseSponsorProceeds` signature: the function returns only `uint256 amount` at `Raffle.sol:375`. `PrizeDeliveryVerificationFailed` requires an address and describes a post-transfer ownership check; `NothingToClaim` does not exist, while `NoSponsorProceeds` is used at line 377. More importantly, gating only sponsor proceeds leaves protocol fees independently releasable and does not create liability-safe refund accounting.
2. M-3's sample names nonexistent `InvalidEntryCount`; the current overflow guard uses `TotalEntriesOverflow(totalEntries, entryCount)`. Subtracting `reserveEntries - totalEntries` also underflows after reserve is exceeded and silently changes the documented open-sale design.
3. L-2's sample bypasses the actual `_requireStatus(Status.Active)` call and names nonexistent `NoEntries`; the current error is `NoEntriesSold`. `ticketCount > 1` does not prove distinct participants because one address can own or buy multiple tickets. A gas-price floor or re-request policy requires separate wrapper, fairness, and timeout design.
4. I-2's sample does not match the actual `releaseSponsorPrize` locals and uses the quote-specific `InvalidQuoteDestination` for a prize path. Any recipient policy must cover future addresses and an alternate claimant path; merely adding a current-code registry check does not solve future-code capability changes.
5. Adding `nonReentrant` only to `onERC721Received` does not stop the untrusted prize contract from calling `buyEntries` after the receiver hook returns but before its outer `safeTransferFrom` returns. Delayed activation is an architecture change, not a one-line fix.
6. I-7 names nonexistent `InvalidReserveEntries` and `InvalidPrizeToken`. The actual zero-reserve error is `ZeroReserveEntries`; unsafe prize destinations use `UnsafeProtocolDestination(address)`. The treasury equality case already reverts atomically from `Raffle.initialize`.

For RF-001, remediation must first resolve the product trust model. If arbitrary prizes remain supported, no NftWon sponsor or protocol quote claim may become externally payable before verifiable delivery, and any timeout/refund design must account for unsettled funds, allocated claims, already paid claims, successful delivery, and winner inaction. A malicious token's own `ownerOf` response is not independent proof. If only vetted honest prizes are intended, enforcement must be onchain rather than prose. These are design requirements, not an approved patch.

## Gate result and matrix recommendation

- Native transport and method completion: `PASS`, preserving the original `SUCCESS`.
- Protected-input, 43-file target binding, 12-leaf binding, and artifact integrity: `PASS`.
- Independent semantic review performed: `PASS` for this append-only effective chain.
- Verbatim native report truth/severity/anchor acceptance: `REJECTED`.
- Corrected effective semantic acceptance: `PASS_WITH_APPEND_ONLY_ADJUDICATION`.
- New production root introduced: `NO`.
- Provider continuation or retry required: `NO`; continuing a terminally successful judge is not eligible repair work.
- Global matrix/final delivery completion: not asserted here.

The matrix should retain the historical native `SUCCESS`, reference this package as the semantic correction layer, and qualify Simao only under the corrected effective-chain interpretation.
