# Gebal assessment

Run: a9a573ab-b66c-4d87-8ca0-1e7a5d5bcf78

**Outcome: succeeded**

An empty findings list is not a security certificate\. Completed checks establish only their stated coverage\.

**Source-only run: no compiler, static analyzer or executable test coverage.**

Snapshot: 50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e

## Incomplete checks

All planned tasks completed. Coverage remains limited to the checks below.

## Scope and requirements

\# Clean design specification Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation\. One entry costs 1,000,000 units of canonical six-decimal USDC\. One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range\. Exactly one ERC721 prize is escrowed atomically at creation\. Reserve met awards NFT and 95% sponsor / 5% treasury\. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury\. Refund outcome pays 100% per entry and returns prize\. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss\. No administrator, mutable configuration or upgrade\. Request window \[sale end, end\+2days\); callback accepted strictly before request timestamp\+2days\. Refunds open at deadline\. Callback records result only\. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure\. Sponsor and treasury can claim independently after settlement\. Never move assets between raffle clones\. Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted\. Frontend discovery is advisory; transaction decisions must reread current chain state\.  This specification was composed before scanner results and historical findings\. Source, not design prose, determines actual behavior\. No tests, audit history, accepted-risk lists or scanner results are provided\. 

Authorized: packages/contracts/src/Raffle\.sol, packages/contracts/src/RaffleFactory\.sol, packages/contracts/src/interfaces/IRaffle\.sol, packages/contracts/src/interfaces/IRaffleFactory\.sol, packages/contracts/src/libraries/RaffleConstants\.sol, packages/contracts/foundry\.toml, packages/contracts/remappings\.txt, packages/contracts/package\.json, pnpm-lock\.yaml

Project path: packages/contracts

Explicit dependency paths: packages/contracts/node\_modules/@openzeppelin/contracts, packages/contracts/node\_modules/@chainlink/contracts

Execution policy: Exact file remappings were resolved from uniquely matching authorized library paths and are included in the approved plan\. Only profile\.default is selected; other profiles, RPC endpoints and formatting configuration are not loaded\. Controller overrides output/cache/script paths, denies FFI/filesystem/RPC and dependency downloads, and disables automatic remappings\. Configured fuzz/invariant campaigns are replaced by the disclosed fixed seed and bounded campaign\. Tests requiring denied capabilities cannot be validated\. Source-only intake does not establish compiler, test, property or security coverage\.

Excluded/absent: 

## Check evidence

- intake: succeeded. Recorded 40 authorized files\. Build configuration unsupported; see diagnosis\.
  Evidence: ede9798cdc052d851f01a19508756cd3273c36b969ead6eadc75ede94c3fc9c0

## Findings requiring human review

### An untrusted prize contract can fabricate both escrow and delivery

Severity: high; confidence: high; evidence: model; disposition: needs-review

The clean requirements treat arbitrary prize contracts as untrusted, but admission checks only that the contract reports ERC-721 interface support\. During createRaffle, the prize contract controls safeTransferFrom: it can invoke the clone receiver with the expected caller-supplied arguments without maintaining real ownership, and the factory then asks that same untrusted contract whether the clone owns the token\. This can activate a raffle with no genuine escrow\. On an NFT-winning redemption, the same contract can make transferFrom a no-op and report the winner from ownerOf; the raffle then retains winnerRedeemed/prizeClaimed and the ticket burn while no genuine NFT was delivered\. A sponsor controlling such a token can therefore sell entries and receive the NFT-outcome sponsor allocation without contributing an enforceable prize, contrary to the atomic-escrow and delivery requirements\. Assumptions: The clean-design statement that arbitrary prize contracts are untrusted includes contracts that falsely advertise ERC-721 behavior; the interface prose's honest-prize assumption is not treated as an overriding trust assumption\.; Entrants may buy from a raffle whose sponsor selected the adversarial prize contract\.; The adversarial prize contract can return the ERC-721 interface ID and self-consistent but false ownerOf results while accepting transferFrom/safeTransferFrom calls\.

Source: packages/contracts/src/RaffleFactory\.sol:127-134, packages/contracts/src/RaffleFactory\.sol:154-177, packages/contracts/src/Raffle\.sol:416-430, packages/contracts/src/Raffle\.sol:329-337

Artifacts: acb56b908f72af85a90165d3c15c87c9ea6960e10abf18af3a0ef6b66d597831

### Clone-isolation filtering recognizes only raffles from the current factory

Severity: low; confidence: medium; evidence: model; disposition: needs-review

Destination screening asks only this raffle's immutable factory whether an address is one of its registered clones\. A clone deployed by another RaffleFactory is therefore accepted as a sponsor recipient \(and can likewise be configured as a factory treasury\)\. In a cash/refund branch, releaseSponsorPrize uses unsafe transferFrom and moves the prize into that other clone, while quote-token releases also pass the factory-local screen and become unaccounted balances in the recipient clone\. The recipient clone has no rescue path\. This is a concrete cross-clone asset path contrary to the stated never-move-assets-between-clones requirement, although the party selecting the destination bears the direct loss\. Assumptions: More than one deployment of RaffleFactory can exist and the clone-isolation requirement applies across those deployments\.; A sponsor or factory deployer selects an existing clone from another factory as sponsorRecipient or protocolTreasury\.; The prize token otherwise follows ordinary ERC-721 transferFrom ownership semantics\.

Source: packages/contracts/src/RaffleFactory\.sol:154-169, packages/contracts/src/Raffle\.sol:395-406, packages/contracts/src/Raffle\.sol:560-566, packages/contracts/src/Raffle\.sol:587-604

Artifacts: acb56b908f72af85a90165d3c15c87c9ea6960e10abf18af3a0ef6b66d597831


## Coverage gaps

- No semantic, test, or property coverage established by intake\.
- External agent provenance, token usage and spend are unknown\.
- Imported observations do not complete blocked local checks or establish any property\.
- Source-only review: no compiler, test, fuzz, invariant, symbolic, gas, or runtime execution evidence was produced\.
- Gebal marked the Foundry configuration unsupported because gas\_reports is an unsupported key; source intake still succeeded but compilation coverage is absent\.
- Docker was unavailable and no pinned local tool image was configured, so no deterministic test-inclusive plan was created and host tools were not used as a fallback\.
- Canonical USDC's fee-free/non-rebasing transfer semantics and the canonical Chainlink wrapper's asynchronous/authenticated behavior are trusted assumptions, not locally executed facts\.
- The lockfile and dependency versions were checked for the selected OpenZeppelin 5\.6\.1 and Chainlink 1\.5\.0 closure, but non-reachable helpers in the captured dependency directories were not independently semantically audited\.
- No deployment addresses, chain state, frontend behavior, or post-snapshot source changes were examined\.
- The failed fresh Codex CLI specialist produced no review because the sandbox could not reach the model endpoint; provider-returned identity and usage remain unknown\.

## Provenance and cost

Method: native-review-v1; adapter: 0.2.0

Tool image: unavailable; compiler: 0\.8\.36; EVM: cancun

Planned direct provider/model: none

External reviewers: Codex / gpt-daybreak-blue-latest accepted-local; access daybreak\_blue; ultra; provider-returned-model unknown. External provenance, usage and spend are unverified.

Recorded direct API tokens: 0; reserved: 0. Monetary cost: unknown. Local compute cost is not measured.

The JSON report retains manifests, settings, decisions, invocations, source hashes, timelines and coverage records. Artifact IDs resolve through the local store or CLI evidence command.
