# Gebal assessment

Run: ee890df3-084f-4d28-91d5-fa29d8fe5b7f

**Outcome: succeeded**

An empty findings list is not a security certificate\. Completed checks establish only their stated coverage\.

**Source-only run: no compiler, static analyzer or executable test coverage.**

Snapshot: d0b726edfae0c24ed708c5c0f1908c40f4ab85da8d1708de38fe437a384dcc0a

## Incomplete checks

All planned tasks completed. Coverage remains limited to the checks below.

## Scope and requirements

\# Clean design specification Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation\. One entry costs 1,000,000 units of canonical six-decimal USDC\. One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range\. Exactly one ERC721 prize is escrowed atomically at creation\. Reserve met awards NFT and 95% sponsor / 5% treasury\. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury\. Refund outcome pays 100% per entry and returns prize\. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss\. No administrator, mutable configuration or upgrade\. Request window \[sale end, end\+2days\); callback accepted strictly before request timestamp\+2days\. Refunds open at deadline\. Callback records result only\. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure\. Sponsor and treasury can claim independently after settlement\. Never move assets between raffle clones\. Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted\. Frontend discovery is advisory; transaction decisions must reread current chain state\.  This specification was composed before scanner results and historical findings\. Source, not design prose, determines actual behavior\. No tests, audit history, accepted-risk lists or scanner results are provided\. 

Authorized: packages/contracts/src/Raffle\.sol, packages/contracts/src/RaffleFactory\.sol, packages/contracts/src/libraries/RaffleConstants\.sol, packages/contracts/src/interfaces/IRaffle\.sol, packages/contracts/src/interfaces/IRaffleFactory\.sol, packages/contracts/foundry\.toml, packages/contracts/remappings\.txt, packages/contracts/package\.json, pnpm-lock\.yaml

Project path: packages/contracts

Explicit dependency paths: packages/contracts/node\_modules/@openzeppelin/contracts, packages/contracts/node\_modules/@chainlink/contracts

Execution policy: Exact file remappings were resolved from uniquely matching authorized library paths and are included in the approved plan\. Only profile\.default is selected; other profiles, RPC endpoints and formatting configuration are not loaded\. Controller overrides output/cache/script paths, denies FFI/filesystem/RPC and dependency downloads, and disables automatic remappings\. Configured fuzz/invariant campaigns are replaced by the disclosed fixed seed and bounded campaign\. Tests requiring denied capabilities cannot be validated\. Source-only intake does not establish compiler, test, property or security coverage\.

Excluded/absent: 

## Check evidence

- intake: succeeded. Recorded 40 authorized files\. Build configuration unsupported; see diagnosis\.
  Evidence: fdd67b60d0178fde433ec2c39230081c0bd18c4016c63c7af6f5f92082350fe0

## Findings requiring human review

### LEAD L-01: Untrusted-prize requirement exceeds the interface's honest-ERC721 assumption

Severity: informational; confidence: high; evidence: model; disposition: needs-review

The clean requirements call arbitrary prize contracts untrusted, while IRaffle states that supported prizes are honest standards-compliant ERC721s\. The factory checks self-reported ERC165 support, the receiver transition, and ownerOf after escrow; those checks cannot establish future transfer behavior\. In a reserve-met result, settlement can allocate the full pot to sponsor and treasury independently of NFT delivery\. If an admitted prize subsequently refuses transfer, redemption reverts atomically but NftWon has no refund transition\. This is a concrete conditional liveness/trust-boundary path, not a demonstrated exploit or a finding against an honest compliant prize: no particular hostile prize implementation is present in the pinned context\. Keep as a lead until the intended prize trust boundary and an applicable concrete prize behavior are established\. Defensive obligation: state the supported prize trust assumptions explicitly and assess whether the intended winner exit must survive permanent prize-delivery failure\. Assumptions: DESIGN\.md is authoritative for the requirement that arbitrary prize contracts are untrusted; interface comments are evidence of a narrower implementation assumption, not permission to narrow the audit\.; The conditional delivery failure requires prize behavior not instantiated by a prize implementation in this context\. No claim of an executed or confirmed loss path is made\.; Canonical USDC and the configured Chainlink wrapper behave according to the stated trusted dependency model\.

Source: packages/contracts/src/interfaces/IRaffle\.sol:12-15, packages/contracts/src/RaffleFactory\.sol:127-134, packages/contracts/src/RaffleFactory\.sol:171-177, packages/contracts/src/Raffle\.sol:279-294, packages/contracts/src/Raffle\.sol:329-342, packages/contracts/src/Raffle\.sol:375-391, packages/contracts/src/Raffle\.sol:533-555

Artifacts: e46bc45e17fbcb98b883bfa713ed6b9792a9298ca20118a68d8cc1fc35fc3155


## Coverage gaps

- No semantic, test, or property coverage established by intake\.
- External agent provenance, token usage and spend are unknown\.
- Imported observations do not complete blocked local checks or establish any property\.
- Source-only review: no compilation, tests, fuzzing, invariant execution, gas measurements, static analyzer execution, symbolic execution or formal proof was performed\. Manual property coverage is not measured executable coverage\.
- Native diagnosis is unsupported because foundry\.toml profile\.default contains gas\_reports\. Compiler metadata is 0\.8\.36 / Cancun; runtime compatibility and deployed bytecode remain unverified\.
- Existing tests are excluded by explicit sourceOnly=true, existingTests=false scope\. Docker daemon is unavailable and no pinned local tool image was verified, so the separately conditional test-inclusive plan is blocked and no host-tool fallback is authorized\.
- All five production files including IRaffle\.sol and IRaffleFactory\.sol were reviewed in full from this exact context\. Dependencies were snapshotted in full; manual semantic review focused on reachable ERC721 ownership/mint/burn, SafeERC20 transfer, clone creation, reentrancy storage, Math\.mulDiv and VRF base/authentication\. Remaining library utility text was not exhaustively audited\.
- Root pnpm-lock\.yaml is fully pinned; only the relevant contracts importer and Chainlink/OpenZeppelin resolution entries were semantically inspected\. Package declarations identify @chainlink/contracts 1\.5\.0 and @openzeppelin/contracts 5\.6\.1\. No registry provenance or deployed canonical address was verified\.
- L-02 \(unconfirmed integration lead\): destination checks recognize the current factory and its already registered clones, not every other-factory or not-yet-created clone\. Raffle\.sol 593-604 and RaffleFactory\.sol 154-168 need a precise interpretation of never move assets between raffle clones\. No unauthorized victim-loss path is established; deliberate selection or transfer to an unreachable address is not promoted to a vulnerability\.
- USDC administrative freeze/blacklisting and a permanently non-cooperating prize can obstruct their respective transfers; transaction atomicity preserves recorded claims on revert but cannot guarantee delivery by a third-party asset contract\.
- NFT payout uses transferFrom plus ownerOf verification, not a receiver hook\. This avoids a receiver veto but relies on the owner-selected or immutable recipient being capable of managing the received NFT; no unsupported claim that every contract recipient can recover it is made\.
- No frontend, deployed contract state, production credentials, historical report, scanner result, prior test source, memory or peer conclusion was used for this original pass\. Target SHA is operator-supplied and exact selected bytes are bound by the native snapshot; source git history was not inspected\.
- Local model selection is gpt-6-astra with ultra effort as provided by the active runner instruction; provider-returned model and effort fields are unknown\. No provider adapter or fallback was used\. External usage, cost and provider identity are not independently verified by Gebal\.

## Provenance and cost

Method: native-review-v1; adapter: 0.2.0

Tool image: unavailable; compiler: 0\.8\.36; EVM: cancun

Planned direct provider/model: none

External reviewers: assistant:Codex / operator-selected gpt-6-astra ultra; provider-returned model unknown. External provenance, usage and spend are unverified.

Recorded direct API tokens: 0; reserved: 0. Monetary cost: unknown. Local compute cost is not measured.

The JSON report retains manifests, settings, decisions, invocations, source hashes, timelines and coverage records. Artifact IDs resolve through the local store or CLI evidence command.
