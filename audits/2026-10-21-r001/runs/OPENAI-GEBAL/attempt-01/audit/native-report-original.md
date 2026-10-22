# Gebal assessment

Run: 25b0b84c-7eda-45e2-9d81-440aa16fcb7b

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
  Evidence: 24ad8f48cb9d257179a75b6844f905b698fe4c671864e6c82b6d8e705bd0ee8c

## Findings requiring human review

### Sponsor prize release can transfer into a subsequently registered raffle clone

Severity: low; confidence: high; evidence: model; disposition: needs-review

Source-supported candidate, low severity and needs human review\. Sponsor-recipient screening is performed at creation/initialization against the current same-factory registry\. A sponsorRecipient equal to a future clone address is then code-less and unregistered, so it can pass\. If that address subsequently becomes another raffle clone before the first raffle returns its NFT, releaseSponsorPrize uses transferFrom to the stored recipient without repeating \_isProtocolDestination\. A standard ERC721 transfer bypasses the receiving clone receiver hook and ownerOf then confirms the new clone, so the first raffle marks the prize claimed even though the second clone only has release paths for its own configured prize\. This violates the stated no movement between raffle clones property and can strand the returned NFT\. The quote-token release path does repeat the destination check, making this omission specific to the sponsor NFT return\. Impact requires the sponsor-selected future-address recipient; no arbitrary theft from normally configured raffles is established\. Defensive property: prize return must reject a recipient that is registered protocol plumbing at delivery time\. An execution check remains outstanding\. Assumptions: The sponsor selects an as-yet undeployed future same-factory clone address as sponsorRecipient, distinct from the clone being initialized\.; That address is deployed and registered before a CashWon or Refunding sponsor-prize return\.; The prize is an ordinary standards-compliant ERC721 and differs from the receiving clone's configured prize\.; This is a recipient-selection edge case, not demonstrated theft from an honest sponsor who selected an address they control\.

Source: packages/contracts/src/RaffleFactory\.sol:163-169, packages/contracts/src/RaffleFactory\.sol:105-125, packages/contracts/src/Raffle\.sol:187-205, packages/contracts/src/Raffle\.sol:395-406, packages/contracts/src/Raffle\.sol:593-604, packages/contracts/node\_modules/@openzeppelin/contracts/proxy/Clones\.sol:47-61, packages/contracts/node\_modules/@openzeppelin/contracts/token/ERC721/ERC721\.sol:115-135

Artifacts: 0500524c7fc7ed20bbbf89713e5a82f1e6cbb68c7001ac582a21f8417acc5be0


## Coverage gaps

- No semantic, test, or property coverage established by intake\.
- External agent provenance, token usage and spend are unknown\.
- Imported observations do not complete blocked local checks or establish any property\.
- Source-only review: no Solidity compilation, static analyzer, existing tests, generated tests, gas measurement, fuzzing, invariant campaign, solver or formal proof was executed\.
- Native diagnosis marks configuration unsupported due to gas\_reports\. Compiler 0\.8\.36 is outside the documented tested sandbox compiler set \(0\.8\.26/0\.8\.28/0\.8\.30\)\.
- Docker daemon access was unavailable in the supplementary environment check; no locally usable pinned tool image was established\. No test-inclusive plan is permitted without that prerequisite\. No tests were supplied in the authorized target\.
- Clean DESIGN calls arbitrary prize contracts untrusted; IRaffle\.sol:13-15 assumes honest standards-compliant prizes\. Interface support, callback parameters and ownerOf assertions cannot establish honest escrow/delivery or future transferability of an arbitrary hostile prize\. This is a trust-boundary/design limitation, not a separately demonstrated canonical-token exploit\.
- Canonical USDC and Chainlink wrapper implementations/deployment parameters are not supplied\. The consumer base and interfaces are reviewed; canonical identity, deployed max gas/confirmations, billing and callback delivery are unverified\.
- All 31 selected dependency source files are included and hash-verified\. Primary dependency call paths were inspected; unused/transitive library routines were not comprehensively audited\. Lockfile relevant package entries were inspected, not all monorepo packages\.
- Counterfactual and foreign-factory recipients, arbitrary contract recipients unable to operate a ticket or NFT, token pause/blacklist restrictions and unsolicited assets can limit exits\. Beyond the documented future-clone prize-return candidate, no additional actionable source-supported fault is claimed\.
- The supplied target SHA is recorded as operator provenance\. No target git history or external repository was consulted to independently authenticate that SHA\.
- Provider-returned model identity, external usage and spend are unknown\. Accepted local selection is gpt-6-astra with ultra effort, fallback disabled; Gebal does not verify that identity\.

## Provenance and cost

Method: native-review-v1; adapter: 0.2.0

Tool image: unavailable; compiler: 0\.8\.36; EVM: cancun

Planned direct provider/model: none

External reviewers: assistant:Codex / accepted-local gpt-6-astra; effort ultra; provider-returned model unknown; fallback disabled. External provenance, usage and spend are unverified.

Recorded direct API tokens: 0; reserved: 0. Monetary cost: unknown. Local compute cost is not measured.

The JSON report retains manifests, settings, decisions, invocations, source hashes, timelines and coverage records. Artifact IDs resolve through the local store or CLI evidence command.
