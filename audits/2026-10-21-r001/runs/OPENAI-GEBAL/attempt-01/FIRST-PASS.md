# OPENAI-GEBAL original first pass

Sealed original conclusions, written 2026-10-21T08:05:12.222071+00:00. Target SHA (operator supplied): `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

Native origin run: `25b0b84c-7eda-45e2-9d81-440aa16fcb7b`.
Snapshot: `50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e`.
Context: `2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142`.
Harness: `9ad24645f92a3821ae4539db5f1be52b48ed379e` (HEAD observed); replacement for historical supplied `5c68ec0284dc642823abe81cbc0e02fcb080a69f`, whose remote checkout failure was disclosed by the operator. This audit did not retry network checkout.

Accepted local model selection: **gpt-6-astra**, reasoning **ultra**, fallback **disabled**. Runner selection metadata was read separately. Provider-returned model, effort, access program, usage and spend: **unknown**. No identity claim rests on prompting or self-identification. This is provider-specific method execution, not provider-verified identity.

Original source reasoning used only the authoritative native `audit/context.json`. No historical report, test, scanner finding, peer source conclusion or external reconciliation was read. Before sealing, an environment-only specialist reported Docker unavailability; native intake diagnosis and launcher failures were also visible. This is therefore a cold pass with respect to source findings, not a claim that no tool metadata was seen. The two supplemental source specialists were instructed to withhold their conclusions until this seal. This document and review-original.json are not to be overwritten; later changes belong in an addendum.

## Requirements and assumptions

Original review assumptions, before final candidate disposition

The clean DESIGN.md embedded in audit/context.json is the requirement authority. Code comments are observed implementation claims, not amendments to those requirements. In particular, the design calls arbitrary prize contracts and ticket recipients untrusted, while IRaffle.sol:13-15 narrows supported prizes to honest standards-compliant ERC721s. This difference must remain explicit.

Canonical USDC and the VRF wrapper are trusted as specified. USDC transfers are assumed to move the requested six-decimal amount without fees or rebasing; address identity, blacklist/pause state, and deployed wrapper configuration are not established by this source snapshot. A prize contract's ownerOf answer is its own assertion and cannot independently establish economic authenticity or future transferability.

Required accounting properties are conservation of outstanding liabilities, one million quote units per entry, contiguous non-overlapping ranges, aggregate 5% protocol and 80% cash-winner allocations with sponsor remainder, and full refunds only in the refund branch. Required authorization is factory-only one-time initialization, current-owner claims, authenticated VRF resolution, and no mutable administrator.

Required lifecycle properties are exclusive sale end, request eligibility in [end,end+2days), callback acceptance strictly before requestedAt+2days, refund availability at each applicable deadline, one-way terminal outcomes, storage-only settlement, and atomic claim rollback on delivery failure. Exits should remain independent and bounded; assets should not move from one raffle clone into another.

Source reasoning is not an executed test or formal proof. Timing uses ordinary EVM transaction atomicity and monotonically progressing block time. CREATE addresses can become deployed/registered later; current registry membership need not be stable across transactions. No deployment identity or chain state is assumed to have been verified.

## Original conclusion

One low-severity source-supported candidate, C01, is retained for human review. No high- or medium-severity source-supported candidate was established by this original pass. This is neither a safety certificate nor an execution-backed finding.

**C01 — Sponsor prize return can send an NFT into a subsequently registered raffle clone.** Creation rejects currently known protocol destinations (RaffleFactory.sol:163-169; Raffle.sol:187-205,593-604). A different future clone address is not yet registered or deployed and can be supplied as sponsorRecipient. Factory deployment uses CREATE through Clones.sol:47-61 and records membership at RaffleFactory.sol:123-125. If the chosen recipient later becomes a clone before a CashWon/Refunding prize return, Raffle.sol:395-406 transfers to that stored address without a new destination check. Standard ERC721 transferFrom bypasses receiver acceptance (ERC721.sol:115-135); the ownership postcheck succeeds, and prizeClaimed becomes true. The receiving raffle only releases its own configured token/ID, so the unrelated prize can remain stranded. This breaches the clean no-inter-clone asset movement requirement. The sponsor must have selected the future address; no theft from ordinary recipients is established. Severity low, source-path confidence high, runtime reproduction absent. A defensive property should require sponsor prize delivery to reject then-current protocol destinations.

The original inert JSON with complete source spans and assumptions is `audit/review-original.json`. It retains exact exported snapshot/context hashes. No human acceptance is implied.

## Leads and limitations not promoted to additional findings

- Arbitrary hostile prize contracts can lie in supportsInterface/ownerOf, withhold transfers, or change behavior. The implementation's honest-ERC721 comment narrows the design trust boundary. Checks prove reported ownership, not external asset authenticity. This remains an explicit trust/design gap; no separate canonical-token drain is claimed.
- Counterfactual ticket recipients, foreign-factory plumbing and contracts unable to exercise their tickets need clearer destination scope. Choosing an uncontrolled recipient can strand one's own claims; no additional independently actionable path is promoted here.
- Canonical USDC pause/blacklist behavior, deployed Chainlink fee/configuration compatibility and wrapper callback gas consumption are unavailable integration obligations.
- Unsolicited NFTs/native/quote balances are not part of tracked liabilities and have no rescue path. No unauthorized withdrawal path was established.

## Per-file coverage

All five production files were explicitly included and all their source lines were read. Interfaces were not excluded. Hashes and native line counts below include the trailing newline convention.

| File | SHA256 | Coverage |
|---|---|---|
| packages/contracts/src/interfaces/IRaffle.sol | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` | Full original manual source read; 522 native lines |
| packages/contracts/src/interfaces/IRaffleFactory.sol | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` | Full original manual source read; 151 native lines |
| packages/contracts/src/libraries/RaffleConstants.sol | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` | Full original manual source read; 44 native lines |
| packages/contracts/src/Raffle.sol | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` | Full original manual source read; 615 native lines |
| packages/contracts/src/RaffleFactory.sol | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` | Full original manual source read; 187 native lines |

Configuration coverage: complete foundry.toml, remappings.txt and packages/contracts/package.json; full lockfile snapshot/hash with relevant importer and OpenZeppelin/Chainlink resolution entries inspected. Clean DESIGN.md is embedded verbatim as requirements. hardhat.config.ts and dependency-hashes.json were not selected into native context or used as review authority. The target byte manifest was computed without treating those extra files as source-review inputs.

Dependency coverage: all 31 closure files included and hash-verified by context handling. Detailed review covered Chainlink consumer base, wrapper and LINK interfaces, extra-argument encoding; ERC721 ownership/update/mint/burn/approvals/receiver checks; ReentrancyGuard and its uint256 StorageSlot access; Clones CREATE deployment; SafeERC20 transfer/transferFrom helpers; Math.mulDiv and its multiplication path; Context, IERC20, IERC721 and ERC165 contracts/interfaces. Other transitive library routines are included but not claimed fully audited. `audit/source-coverage.json` enumerates each source hash and coverage category.

## Per-property coverage

All statuses below describe manual source reasoning. None is measured execution coverage or formal proof.

| ID | Property | Status | Source references | Original reasoning |
|---|---|---|---|---|
| P01 | Immutable configuration / initialization | REVIEWED; no additional candidate | Raffle 155-205; Factory 65-92,97-125 | Implementation locked; factory immutable in implementation bytecode; only factory can initialize a clone once. Constructor guard zero state on clones remains safe because only ENTERED is prohibited. |
| P02 | Atomic prize intake | REVIEWED WITH ASSUMPTION | Factory 127-134; Raffle 416-430 | Receiver requires expected token, ID, sponsor and factory operator, then factory checks reported ownership and Active status. Semantic ownership depends on prize honesty. |
| P03 | Entry price, bounds and ticket ranges | REVIEWED; no candidate | Raffle 209-236; Constants 20-27 | Positive entries, checked uint128 aggregate, range [oldTotal+1,newTotal], one ticket per purchase. ticketCount <= totalEntries, so its increment cannot overflow earlier. USDC total <= (2^128-1)*10^6, within uint256. |
| P04 | Accounting and rounding conservation | REVIEWED; no candidate | Raffle 296-300,367-391,468-475,533-557 | Pot moves to refunds or split liabilities. Protocol=floor(gross*500/10000); cash=floor(gross*8000/10000); sponsor=remainder. Fixed one-million entry units make both shares exact for normal pots. Claims zero/decrement liabilities before transfers; reverts restore all effects. |
| P05 | Sale/request boundary and fee payer | REVIEWED; no candidate | Raffle 215-216,240-272,458-464; wrapper base 76-88 | Buy excludes end; request includes end, excludes end+2days, and requires sold entries. Caller covers actual native fee, excess refund failure reverts atomically. No USDC pot is spent for VRF. |
| P06 | VRF authentication and terminal outcome | REVIEWED; no candidate | wrapper base 101-106; Raffle 509-523 | Only immutable wrapper can call; in-flight, wrong state/id/word count and late callbacks ignored. One-based modulo selection stays within sold range; terminal status prevents repeats. Tiny modulo bias is not promoted to a material candidate. |
| P07 | Timeouts and bounded refund exit | REVIEWED; no candidate | Raffle 276-300,349-371; Constants 27,33-36 | Sold Active waits end+2days; Drawing waits request+2days; equal deadline enables refunds and excludes callback. Empty raffle sponsor may cancel early; others after sale end. Refund batch 1..100, owner-only, burn prevents duplicate claims. |
| P08 | Permissionless storage-only settlement | REVIEWED; no candidate | Raffle 304-305,533-557,579-585 | Range validation and liability allocation have no external call/ownership read. Unminted [0,0] range cannot contain positive winning entry. Historical burned ranges cannot produce terminal winner claims because refund and win states are exclusive. |
| P09 | Current owner and atomic redemption | REVIEWED WITH TOKEN ASSUMPTION | Raffle 309-345; ERC721 216-245,303-307 | OwnerOf is read at claim time; approved operator alone cannot redeem. Burn and winner/prize flags revert if delivery reverts or reported ownership fails. Arbitrary token lying about owner remains a trust limitation. |
| P10 | Independent sponsor and treasury claims | REVIEWED; no additional candidate | Raffle 375-406,564-566 | Permissionless fixed-recipient quote claims are independent after settlement. Winner-delivery failure does not block separately settled quote allocations. Blocking USDC state is an external liveness assumption. |
| P11 | Cross-clone isolation and dynamic destinations | CANDIDATE C01; low | Factory 163-169; Raffle 187-205,395-406,593-604 | Existing same-factory plumbing is excluded. NFT sponsor return omits runtime destination screening, so a recipient that later becomes a clone can receive another raffle prize. See C01. |
| P12 | Untrusted callback / reentrancy surfaces | REVIEWED; no additional candidate | Raffle state-changing entrypoints,416-430,497-523; Factory 97; ERC721 128-135,287-289 | Core economic functions use shared per-clone guard. Factory has separate guard. Mint recipient sees already-recorded range and pot. ERC721 transfers may reenter callbacks but do not themselves change raffle liabilities; only-owner burn paths and core guards constrain economic calls. |
| P13 | Dependency and compiler integration | PARTIAL / EXECUTION BLOCKED | Context dependency closure; foundry.toml; package.json; lockfile relevant entries | Pinned declarations: OpenZeppelin 5.6.1, Chainlink 1.5.0; 31 dependency source files snapshotted. Native diagnosis unsupported gas_reports; exact compiler 0.8.36 is not among documented tested images. No bytecode or gas evidence. |
| P14 | Interfaces and frontend advisory state | SOURCE INTERFACES REVIEWED; FRONTEND OUT OF SCOPE | IRaffle 1-521; IRaffleFactory 1-150 | Explicit ABI, event, error, enum, timing and ownership documentation checked against implementation. Honest-prize comment differs from clean untrusted-prize requirement. No frontend files supplied; current-chain reread behavior cannot be assessed. |

## Native execution status at seal

Completed: required protocol/schema reading; literal scope with sourceOnly=true/existingTests=false, both interfaces and exact dependency closure; native review/plan creation; assistant inspection and delegated approval; intake run; authoritative context export; original own-model source review and response creation. Import and native report export are pending after this seal and must be evidenced separately before claiming native own-model workflow completion.

The exact requested pnpm gebal launcher was attempted and preserved. First it failed offline package metadata lookup; the exact already-installed Node 22.23.3/pnpm 10.34.6 runtime was copied into this cell. The wrapper then failed on a sandbox-denied tsx IPC socket. An explicitly recorded launcher adjustment uses the same npx-pinned packages and unchanged Gebal entrypoint via `pnpm --dir HARNESS exec node --import tsx packages/cli/src/main.ts`. No harness or target files were changed. No different model or assessed toolchain was substituted.

Blocked/incomplete: compiler, existing tests, static analysis, runtime proof of candidates, fuzz/invariant/gas checks. Docker default socket absent and an existing local endpoint inaccessible; a usable pinned local image could not be established, so the conditional test-inclusive plan is not created. The authorized target contains no tests. Native diagnosis reports unsupported gas_reports; compiler 0.8.36 is outside the documented tested image list. No host Forge/Slither or assessed scripts were used as fallback. Gebal has no implemented native formal-proof, automatic specialist/judge or generated-artifact execution stages; supplemental reviewers do not change that fact.

Raw native logs, exact context and original response are retained under audit/, and persistent native state under gebal-state/. Later status, reconciliation and reports must retain this seal and append corrections.
