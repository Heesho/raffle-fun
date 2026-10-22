# Gebal assessment

Run: 35ab82ba-9e64-4934-bd96-e3969b01a965

**Outcome: succeeded**

An empty findings list is not a security certificate\. Completed checks establish only their stated coverage\.

**Source-only run: no compiler, static analyzer or executable test coverage.**

Snapshot: d83129631037ed19fefb66eadb36bdf7c5da94d44b08cbccd50ef569628c3727

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
  Evidence: 5bd1d4153c342ad447c25b7b4560ff111b4349bfd8fce1e5b5cf04132c9724d6

## Findings requiring human review

### Self-reported ERC-721 state cannot enforce prize custody or delivery against an untrusted prize contract

Severity: high; confidence: high; evidence: model; disposition: needs-review

The factory accepts any contract that self-reports IERC721 support, activates the clone when that same configured contract calls onERC721Received with the expected arguments, and treats that contract's ownerOf response as escrow proof\. After an NFT result, settleWinningTicket allocates the pot without rechecking prize custody, and releaseSponsorProceeds can pay the sponsor before the winner attempts delivery\. A sponsor-controlled prize contract can therefore pass creation \(or genuinely transfer the token and later pause, seize, or block it\), allow sales, permit settlement and sponsor withdrawal, and then make transferFrom or ownerOf fail during redeemWinningTicket\. The failed redemption atomically rolls back its local burn and flags, but it cannot roll back sponsor proceeds released in an earlier transaction\. Under the stated untrusted-prize model, the winning bearer claim can be left without a bounded delivery path while 95% of gross sales has already left the raffle\. Assumptions: The clean requirement's untrusted-prize boundary includes sponsor-controlled transfer pausing or seizure, or false ERC-165 and ownerOf responses; if prizes are instead trusted to preserve standard ERC-721 ownership and transfer semantics, this path is excluded\.; At least one purchase occurs, reserveEntries is met, the correct winning ticket is settled, and sponsor proceeds are released before the winner's failed redemption\.; The canonical quote token and VRF wrapper behave according to the trusted-dependency assumptions\.

Source: packages/contracts/src/RaffleFactory\.sol:127-134, packages/contracts/src/RaffleFactory\.sol:154-178, packages/contracts/src/Raffle\.sol:304-345, packages/contracts/src/Raffle\.sol:375-381, packages/contracts/src/Raffle\.sol:416-430, packages/contracts/src/Raffle\.sol:533-557

Artifacts: 865a3c18dc2685f97f62c2cd9ee8fbc5ca588ec10720941ec5fba5e9b6d389a2

### Clone-isolation checks recognize only current clones of the same factory

Severity: low; confidence: high; evidence: model; disposition: needs-review

Both creation-time validation and runtime destination screening consult only the current factory's isRaffle registry\. A Raffle clone from another factory is absent from that registry while still reporting IERC721 support through inheritance\. Concretely, factory B can accept existing clone A as a prize-token contract; transfer of an A ticket to the new B clone passes A's local destination screen, and B's expected-prize callback activates, moving an asset directly between raffle clones\. A foreign clone can also be selected as sponsorRecipient or protocolTreasury, after which \_transferQuote sends USDC into that clone as an unaccounted balance\. The reviewed clone exposes no generic execute or rescue path for such USDC\. These paths violate the absolute cross-clone isolation requirement and can strand assets, although they require a sponsor, deployer, or ticket owner to select or approve the foreign clone\. Assumptions: Two independently deployed reviewed factories and their clones exist, and neither factory registers the other's clones\.; A sponsor, factory deployer, or ticket owner deliberately selects or approves a foreign clone address; no external global registry reconciliation is assumed\.; For the payout-lock consequence, the foreign clone receives standard USDC and exposes only the reviewed code, with no separate control or rescue path\.

Source: packages/contracts/src/RaffleFactory\.sol:154-178, packages/contracts/src/Raffle\.sol:28-28, packages/contracts/src/Raffle\.sol:416-430, packages/contracts/src/Raffle\.sol:497-502, packages/contracts/src/Raffle\.sol:564-567, packages/contracts/src/Raffle\.sol:593-604, packages/contracts/node\_modules/@openzeppelin/contracts/token/ERC721/ERC721\.sol:44-49

Artifacts: 865a3c18dc2685f97f62c2cd9ee8fbc5ca588ec10720941ec5fba5e9b6d389a2


## Coverage gaps

- No semantic, test, or property coverage established by intake\.
- External agent provenance, token usage and spend are unknown\.
- Imported observations do not complete blocked local checks or establish any property\.
- Source-only review: no assessed code was run; no compilation, tests, deployment, exploit, prover, scanner, or measured coverage evidence was produced or inspected\.
- The context contains no deployment address manifest or runtime bytecode\. Canonical-USDC, canonical-Chainlink-wrapper, treasury identity, and correct-chain binding therefore remain operator or deployment assumptions; the factory itself checks only code presence and six-decimal metadata for the quote token\.
- Embedded package metadata pins OpenZeppelin 5\.6\.1 and Chainlink 1\.5\.0, but no build artifact or deployed-bytecode correspondence is available; inherited behavior was assessed only from dependency source embedded in context\.json\.
- The 300,000-gas callback limit and live wrapper request and fulfillment behavior were not measured\. Source inspection shows a storage-only callback and timeout-to-refund path, but operational adequacy remains unverified\.
- No original target tree, git history, tests, reports, scanner output, memories, peers, internet material, or external reconciliation was inspected\.

## Provenance and cost

Method: native-review-v1; adapter: 0.2.0

Tool image: unavailable; compiler: 0\.8\.36; EVM: cancun

Planned direct provider/model: none

External reviewers: Codex / gpt-daybreak-blue-latest \(operator-selected alias; daybreak\_blue; ultra; provider-returned model unknown\). External provenance, usage and spend are unverified.

Recorded direct API tokens: 0; reserved: 0. Monetary cost: unknown. Local compute cost is not measured.

The JSON report retains manifests, settings, decisions, invocations, source hashes, timelines and coverage records. Artifact IDs resolve through the local store or CLI evidence command.
