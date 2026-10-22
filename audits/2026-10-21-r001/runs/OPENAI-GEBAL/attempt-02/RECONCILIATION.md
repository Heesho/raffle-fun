# Append-only reconciliation

Recorded: 2026-10-21T08:11:19.558Z. Original seal: 2026-10-21T08:05:46.738Z.

Target: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Snapshot: d0b726edfae0c24ed708c5c0f1908c40f4ab85da8d1708de38fe437a384dcc0a. Context: c5b7124850800b51b1a5b5346ac3abe133da1f07d34f2d0764eab305fbb6947d. Origin run: ee890df3-084f-4d28-91d5-fa29d8fe5b7f.

This addendum follows peer exposure. It does not overwrite or retrospectively alter FIRST-PASS.md, review.original.json, coverage.original.json, or SEAL.json. Both specialists reviewed the exact native context independently and sealed original responses. They used explicitly selected gpt-6-astra / ultra; returned provider identities remain unknown.

## Change to original L-02

The original broad destination-isolation lead is narrowed to C-01, a low-severity, high-confidence conditional source path within one factory. Both independent specialists identified the same missing runtime screening on sponsor-prize delivery.

Post-seal correction of the original broad L-02 lead. Raffle A can be initialized with a sponsorRecipient address that is not yet deployed or registered and differs from A and the fixed forbidden addresses. RaffleFactory subsequently creates and registers raffle B at that address using Clones.clone/CREATE. If A enters Refunding or CashWon, releaseSponsorPrize sends A's configured NFT to the stored recipient using transferFrom without re-evaluating _isProtocolDestination. An ordinary ERC721 transfer bypasses B's restrictive onERC721Received hook, and ownerOf correctly reports B, so A marks the prize claimed. Where B has a distinct configured prize, its release methods cannot return A's unrelated NFT and there is no generic rescue path. This is a source-supported same-factory no-assets-between-clones invariant violation, requiring deliberate or mistaken future-clone recipient configuration. Impact is the sponsor-directed prize becoming stranded; no ability to redirect a correctly configured unrelated user's claim, steal another raffle's USDC, or contaminate B's accounted pot was found. Confidence is in this conditional source path; no deployment, address calculation or executable reproduction was performed. Defensive property: NFT release should apply the intended current-destination policy consistently, while the design explicitly handles the liveness consequences of an immutable recipient that becomes ineligible.

A minimal source trace in prose is: A initializes while the selected future B address passes current checks; B is subsequently created and registered; A enters Refunding (an empty raffle permits sponsor cancellation, so a VRF outcome is not required); A's permissionless sponsor-prize release sends its ordinary NFT to B without invoking B's receiver; B now owns an unrelated NFT outside its configured release path. These are source statements and conditional state transitions, not an executed demonstration.

This is more specific than the original unconfirmed cross-factory/future-address discussion. Manual property P13 now has a source-supported counterexample to the broad isolation requirement; it must not be read as passing. Other properties remain source-reviewed and unproved.

## L-01 severity disagreement

| Reviewer | Original classification | Reconciliation |
|---|---|---|
| Root original | Informational / high confidence in mismatch and conditional path | Retained as a trust-assumption lead. |
| Accounting specialist | High / medium | Raw preserved; high severity is not adopted without establishing the claimed hostile-asset economic guarantee. |
| Lifecycle specialist | Medium / medium | Raw preserved; medium remains conditional on an intended usable terminal exit despite permanent hostile-prize behavior. |

The code does not make a hostile NFT permanently deliverable. It does correctly revert the ticket burn and all redemption effects when delivery fails. Independent release of sponsor/treasury proceeds is expressly required. Those facts support a trust-boundary clarification, rather than silently assuming either honest prizes or an unspecified recovery policy. Lack of an executable hostile artifact does not erase the conditional path; it limits claims of an established concrete deployment impact.

## Retained originals

- Root: review.original.json, FIRST-PASS.md, coverage.original.json, SEAL.json.
- Accounting: work/evidence/accounting_review/review.raw.json and SEAL.sha256.
- Lifecycle: work/evidence/lifecycle_review/review.raw.json and SHA256SUMS.
- Native schema and source-reference validation for both specialists: evidence/specialist-native-validation.json. Both preserve the original native hashes; neither was rewritten or transplanted into an execution context.
- Skeptical source adjudication: evidence/source_adjudication/ (final artifact manifest in stage-ledger.json).

Only the root original and this reconciled addendum are imported into the native origin run. The specialists' higher-severity originals remain separately available without presenting duplicate raw classifications as accepted native results. All native candidates remain needs-review.

## Coverage and limitations

All five production files including both interfaces were fully read by each source reviewer. Exact spans and resource hashes remain in their original coverage records. No compiler, test, analyzer, prover, chain query or live operation was executed. Docker probes and the native doctor confirm no usable default local daemon; no image was verified and the conditional test-inclusive plan was not created. The native source-only workflow can complete through valid review import and report export while deterministic/executable and formal stages remain BLOCKED/INCOMPLETE.
