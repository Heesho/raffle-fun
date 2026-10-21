# `GEMINI-OPENKRITT` — OpenKritt Security Review (`attempt-02`)

- **Run ID**: `GEMINI-OPENKRITT` (`attempt-02`)
- **Provider / Model**: Google Gemini (`gemini-4-argon`, `Gemini 4 Argon (High)`)
- **Upstream Harness**: `open-kritt/open-kritt` (`https://github.com/open-kritt/open-kritt.git`, commit `43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`)
- **Engine & Workflow**: `open_kritt_engine` (`prompting.py`, `schema.py`, `queue.py`, `models.py`, `post_processing.py`) executing the canonical 3-depth **`external-flow-analysis`** workflow (`defaultWorkflowSeeds.json`) followed by semantic deduplication (`build_dedupe_prompt` / `validate_dedupe_payload`) and **`Blockchain security triage`** severity ranking (`defaultSeverityRankers.js` / `build_ranker_prompt` / `validate_ranker_payload`)
- **Context Mode**: Cold source-only clean context (`packages/contracts/src/**`, `DESIGN.md`, and OpenZeppelin / Chainlink / Solady dependencies in `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini/runs/GEMINI-OPENKRITT/attempt-02/clean-context/`; zero tests or prior audits mounted)
- **Target Frozen Commit**: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`
- **Status**: `COMPLETED`

---

## 1. Execution Provenance & Relationship to `attempt-01`

- In `attempt-01` (`runs/GEMINI-OPENKRITT/attempt-01/BLOCKER.md`), we documented that the upstream OpenKritt worker CLI adapter (`engine/open_kritt_engine/harnesses.py`) only defines subprocess CLI wrappers for `codex`, `claude-code`, and `grok-build` (`Unsupported harness: gemini`), and its full stack assumes Docker + PostgreSQL (`open-kritt-postgres:5432`).
- In `attempt-02`, we staged the pinned upstream OpenKritt repository (`43e1d19a00ce50bd93253d1c6c3a48cfffbcc4c3`) into `/Users/hishamel-husseini/.gemini/antigravity/brain/2e9c188b-5d8e-48b7-bce3-b1f2ebc4987c/scratch/raffle-audit-r001-gemini/harnesses/openkritt` and ran the upstream Python engine (`open_kritt_engine`) directly against our isolated cold source-only `clean-context` snapshot while routing each generated prompt and JSON schema to native `gemini-4-argon` (`Gemini 4 Argon (High)`) read-only subagents:
  - **Depth 0 (`Map external entrypoints`)**: Subagent `17db93cf-f53a-4730-80f4-ab4974ab959f` (`subagents/depth0-step1-response.json`) — validated via `open_kritt_engine.schema.validate_payload` (`19` external entrypoints).
  - **Depth 1 (`Trace reachable flows`)**: Subagents `5477e0ff-5f7b-4b59-b7fe-5ed8d2dbdcb7` (`subagents/depth1-1to10-response.json`) and `fd1db832-908b-4b1d-a2e6-a49642561b0c` (`subagents/depth1-11to19-response.json`) — all `19` responses validated via `open_kritt_engine.schema.validate_payload` and queued via `open_kritt_engine.queue.build_pending_jobs` (`40` traced production flows).
  - **Depth 2 (`Investigate flow vulnerabilities`)**: Subagents `160b17c3-cb0f-45da-93d2-e5c0473d592a` (`subagents/depth2-20to39-response.json`) and `bbf6968f-9674-4d18-9a98-71ebb337e1bb` (`subagents/depth2-40to59-response.json`) — all `40` flow investigations validated via `open_kritt_engine.schema.validate_payload` (`7` raw findings across flows `20, 23, 25, 46, 53, 55, 57`; `33` verified-safe stubs; `0` remaining pending jobs).
  - **Post-Processing Deduplication (`dedupe`)**: Subagent `0450d45f-5882-4a99-bc48-7bdaebb19a2c` (`subagents/post-dedupe-response.json`) — validated via `open_kritt_engine.post_processing.validate_dedupe_payload` and mapped via `dedupe_mapping_from_clusters` (`2` canonical vulnerability clusters: `1:1` and `1:3`).
  - **Post-Processing Severity Ranker (`Blockchain security triage`)**: Subagent `f9d020c1-7a18-4a4f-9a26-04304ff3a031` (`subagents/post-ranker-response.json`) — validated via `open_kritt_engine.post_processing.validate_ranker_payload` and `rank_updates_from_payload`.

All machine-readable OpenKritt engine tables and post-processing outputs are preserved alongside this report:
- `step-results.json` (`59` rows in `workflows.step_results`: `19` Depth 0 entrypoints + `40` Depth 1 flows)
- `vulnerabilities.json` (`7` rows in `workflows.vulnerabilities` with deduplication and `Blockchain security triage` rank metadata)
- `post-processing.json` (complete deduplication clusters and ranker output)

---

## 2. Executive Summary of Findings

| Rank | Canonical ID | Cluster ID (Member IDs) | Impact Level (`Blockchain security triage`) | Bounty Estimate (USD) | Summary | Location |
| ---: | :---: | :---: | :---: | :---: | --- | --- |
| **1** | `1` | `1:1` (`[1, 2, 4]`) | **Low** | `$250 – $1,000` | Precomputed future `Raffle` clone `CREATE` address bypasses `sponsorRecipient` protocol-destination screening in `createRaffle` / `initialize`, later locking `sponsorProceeds` in `releaseSponsorProceeds` and stranding the returned prize NFT inside the sibling `Raffle` clone via `releaseSponsorPrize` | `RaffleFactory.sol:166`, `Raffle.sol:193`, `Raffle.sol:404` |
| **2** | `3` | `1:3` (`[3, 5, 6, 7]`) | **Low** | `$0 – $250` | Minting or transferring a ticket (`buyEntries`, `transferFrom`, `safeTransferFrom`) to a precomputed future `Raffle` clone `CREATE` address bypasses `_isProtocolDestination` and `checkOnERC721Received` while `to.code.length == 0`, permanently stranding the ticket and its prize or refund claim once the sibling `Raffle` clone is deployed | `Raffle.sol:498`, `Raffle.sol:602` |

- **Critical**: `0`
- **High**: `0`
- **Medium**: `0`
- **Low**: `2` canonical (`7` raw flow findings across `7` flows; `33` flows verified free of vulnerabilities)

---

## 3. Canonical Findings (Ranked by `Blockchain security triage`)

### [OK-L-01] Precomputed Future `Raffle` Clone `CREATE` Address Bypasses `sponsorRecipient` Protocol-Destination Screening and Later Locks `sponsorProceeds` / Strands Returned `prizeToken` NFT

| Field | Value |
| --- | --- |
| **Canonical Finding ID** | `1` (Cluster `1:1`, merging raw findings `1`, `2`, `4` from Flows `20`, `23`, `46`) |
| **Rank** | `1` of `2` |
| **Impact Level** | `low` (`$250 – $1,000`) |
| **Vulnerability Type** | `Destination Hygiene / Settlement Liveness Bypass` & `Missing Destination Validation / Locked Asset` |
| **Primary Locations** | `packages/contracts/src/RaffleFactory.sol:166`, `packages/contracts/src/Raffle.sol:193`, `packages/contracts/src/Raffle.sol:404`, `packages/contracts/src/Raffle.sol:565` |
| **Malicious Actor** | Any external EOA or contract acting as raffle sponsor |
| **Exploitable** | `true` |
| **Root Bug** | Precomputed future `Raffle` clone `CREATE` addresses bypass time-of-creation `isRaffle` and code-length destination screening in `_validateCreateParams` and `_isProtocolDestination` before the sibling clone is deployed |

#### Explanation
`RaffleFactory.createRaffle` deploys `Raffle` clones using OpenZeppelin `Clones.clone(raffleImplementation)` (`CREATE`), making every future clone address deterministically predictable from `address(factory)` and the factory's account nonce (`keccak256(rlp(address(factory), nonce))`). Both `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:166`) and `Raffle._isProtocolDestination` (`Raffle.sol:602-604`) only reject a `Raffle` clone address if it is *already* deployed and registered in `isRaffle[destination]` (`destination.code.length != 0 && canonicalFactory.isRaffle(destination)`).

When a sponsor configures `params.sponsorRecipient` to the deterministic `CREATE` address of a future `Raffle` clone (e.g., `nonce + 1`), `sponsorRecipient.code.length == 0` and `isRaffle[sponsorRecipient] == false` at creation time, so `createRaffle` and `Raffle.initialize` succeed. Once a subsequent `createRaffle` call deploys the sibling `Raffle` clone at `sponsorRecipient`, `isRaffle[sponsorRecipient]` becomes `true` and `sponsorRecipient.code.length != 0`:
1. **`sponsorProceeds` permanently locked (`Raffle.sol:380` -> `Raffle.sol:565`)**: Calling `releaseSponsorProceeds()` invokes `_transferQuote(sponsorRecipient, amount)`, which re-evaluates `_isProtocolDestination(sponsorRecipient, address(prizeToken))` at claim time and permanently reverts with `InvalidQuoteDestination(sponsorRecipient)`.
2. **`prizeToken` NFT transferred into sibling `Raffle` clone and stranded (`Raffle.sol:404`)**: Unlike `_transferQuote`, `releaseSponsorPrize()` (`Raffle.sol:395-409`) does not re-check `_isProtocolDestination(sponsorRecipient, address(prizeToken))` and uses `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` rather than `safeTransferFrom`. If Raffle #1 resolves to `CashWon` or `Refunding`, calling `releaseSponsorPrize()` transfers the NFT directly into the sibling `Raffle` clone at `sponsorRecipient` (bypassing `onERC721Received`), violating the `DESIGN.md` core rule *"Never move assets between raffle clones"* and permanently stranding the NFT unless the sibling raffle happens to configure the exact same `(prizeToken, prizeTokenId)` pair.

#### Trigger Flow
1. `packages/contracts/src/RaffleFactory.sol:97 RaffleFactory.createRaffle` — Sponsor calls `createRaffle` with `params.sponsorRecipient` set to the deterministic `CREATE` address of a future `Raffle` clone (`computeCreateAddress(address(factory), factoryNonce + 1)`).
2. `packages/contracts/src/RaffleFactory.sol:166 RaffleFactory._validateCreateParams` — Checks `isRaffle[params.sponsorRecipient]`, which is `false` because the future clone has not been deployed yet.
3. `packages/contracts/src/Raffle.sol:193 Raffle.initialize` — Calls `_isProtocolDestination(params.sponsorRecipient, params.prizeToken)`, which skips `canonicalFactory.isRaffle(destination)` because `destination.code.length == 0`.
4. `packages/contracts/src/RaffleFactory.sol:106 RaffleFactory.createRaffle` — A subsequent `createRaffle` call deploys a new ERC-1167 clone via `Clones.clone(raffleImplementation)` at that exact `CREATE` address and sets `isRaffle[sponsorRecipient] = true`.
5. `packages/contracts/src/Raffle.sol:380 Raffle.releaseSponsorProceeds` / `packages/contracts/src/Raffle.sol:404 Raffle.releaseSponsorPrize` — `_transferQuote` reverts permanently with `InvalidQuoteDestination(sponsorRecipient)` because `isRaffle[sponsorRecipient]` is now `true`, while `releaseSponsorPrize` transfers the NFT into the sibling `Raffle` clone where it is permanently stranded.

#### Ranker Reasoning (`Blockchain security triage`)
Concrete and reproducible bypass of protocol-destination screening in `RaffleFactory._validateCreateParams` and `Raffle.initialize` using a deterministic future `Clones.clone` `CREATE` address as `sponsorRecipient`. Once the sibling `Raffle` clone is deployed and registered in `isRaffle`, `_transferQuote` in `releaseSponsorProceeds` permanently reverts with `InvalidQuoteDestination` (locking `sponsorProceeds` in the contract), while `releaseSponsorPrize` uses unscreened `transferFrom` and moves the prize NFT directly into the sibling `Raffle` clone, violating the design invariant against moving assets between raffle clones. Ranked **Low** rather than Medium because `sponsorRecipient` is sponsor-chosen at creation and does not affect winner payouts, buyer refunds, or protocol treasury fees.

#### Minimal Remediation
In `Raffle.releaseSponsorPrize()` (`Raffle.sol:402`), enforce `_isProtocolDestination` before transferring the prize NFT:
```solidity
if (_isProtocolDestination(recipient, address(prizeToken))) {
    revert UnsafeProtocolDestination(recipient);
}
```
Additionally, to make future clone addresses unpredictable or screenable at creation time, either deploy clones via `Clones.cloneDeterministic` with a salt incorporating `msg.sender` and `block.prevrandao`, or maintain a precomputed / salt-bound registry so future clone addresses cannot be targeted prior to deployment.

---

### [OK-L-02] Minting or Transferring Tickets (`buyEntries`, `transferFrom`, `safeTransferFrom`) to a Precomputed Future `Raffle` Clone `CREATE` Address Bypasses `_isProtocolDestination` and Strands the Ticket Claim

| Field | Value |
| --- | --- |
| **Canonical Finding ID** | `3` (Cluster `1:3`, merging raw findings `3`, `5`, `6`, `7` from Flows `25`, `53`, `55`, `57`) |
| **Rank** | `2` of `2` |
| **Impact Level** | `low` (`$0 – $250`) |
| **Vulnerability Type** | `Protocol Destination Check Bypass / Permanent Fund & Prize Locking` |
| **Primary Locations** | `packages/contracts/src/Raffle.sol:498`, `packages/contracts/src/Raffle.sol:602` |
| **Malicious Actor** | Any external EOA or contract purchasing or transferring raffle tickets |
| **Exploitable** | `true` |
| **Root Bug** | Precomputed future `Raffle` clone `CREATE` addresses bypass time-of-creation `isRaffle` and code-length destination screening in `_validateCreateParams` and `_isProtocolDestination` before the sibling clone is deployed |

#### Explanation
`Raffle._update` (`Raffle.sol:497-502`) screens every ticket mint (`buyEntries`) and transfer (`transferFrom`, `safeTransferFrom`) via `_isProtocolDestination(to, address(prizeToken))` to enforce the design invariant that protocol contracts cannot own tickets and strand claims. However, `_isProtocolDestination` (`Raffle.sol:602-604`) only queries `canonicalFactory.isRaffle(to)` when `to.code.length != 0`, and OpenZeppelin `ERC721Utils.checkOnERC721Received` skips the `onERC721Received` callback when `to.code.length == 0`.

Because `RaffleFactory` deploys clones at deterministic `CREATE` addresses (`Clones.clone`), a buyer or ticket holder can mint or transfer a ticket to a not-yet-deployed `Raffle` clone address while `to.code.length == 0` and `isRaffle[to] == false`. Once a subsequent `RaffleFactory.createRaffle` call deploys the sibling `Raffle` clone at `to`, the ticket is owned by a registered `Raffle` contract (`isRaffle[to] == true`) that has no function to transfer, redeem (`redeemWinningTicket`), or refund (`refundTickets`) tickets (and is also rejected by `_isProtocolDestination` in `_transferQuote`), permanently locking the ticket's winning prize (`NftWon` / `CashWon`) or refund (`remainingRefundLiability`) inside the `Raffle` contract.

#### Trigger Flow
1. `packages/contracts/src/Raffle.sol:209 Raffle.buyEntries` (or `ERC721.transferFrom` / `safeTransferFrom`) — Caller supplies `recipient` / `to` set to the deterministic `CREATE` address of a future `RaffleFactory` clone (`computeCreateAddress(address(factory), factoryNonce)`).
2. `packages/contracts/src/Raffle.sol:498 Raffle._update` — Calls `_isProtocolDestination(to, address(prizeToken))`, which returns `false` because `to.code.length == 0` and `isRaffle[to] == false`.
3. `packages/contracts/src/Raffle.sol:501 Raffle._update` — Mints or transfers `ticketId` to `to`; `ERC721Utils.checkOnERC721Received` skips `onERC721Received` because `to.code.length == 0`.
4. `packages/contracts/src/RaffleFactory.sol:106 RaffleFactory.createRaffle` — Next raffle creation deploys a `Raffle` clone at `to` and sets `isRaffle[to] = true`, stranding the ticket inside a `Raffle` contract that cannot transfer, redeem, or refund it.

#### Ranker Reasoning (`Blockchain security triage`)
Reproducible bypass of `Raffle._update` ticket destination hygiene using the same precomputed future `Raffle` clone `CREATE` address mechanism during `buyEntries` (or pre-deployment ticket transfers), since `_isProtocolDestination` skips `canonicalFactory.isRaffle` when `to.code.length == 0` and `ERC721._safeMint` skips `onERC721Received` for codeless recipients. Ranked below Finding 1 with reduced reward because it shares the same underlying root cause and a buyer can already strand their own ticket and claim by minting or transferring to any unowned address without impacting other participants' refunds, sponsor payouts, or treasury fees.

---

## 4. Depth 0 — External Entrypoints Inventory (`19` Entrypoints)

| `step_result_id` | Entrypoint Label | Handler | Location | External Actor |
| ---: | --- | --- | --- | --- |
| `1` | `RaffleFactory.createRaffle(CreateRaffleParams)` | `RaffleFactory.createRaffle` | `RaffleFactory.sol:97` | Any external EOA or contract acting as raffle sponsor |
| `2` | `Raffle.receive()` | `Raffle.receive` | `Raffle.sol:171` | Any external EOA or contract transferring native currency with empty calldata |
| `3` | `Raffle.initialize(RaffleInitParams)` | `Raffle.initialize` | `Raffle.sol:176` | Canonical `RaffleFactory` during clone deployment, or any external caller attempting direct initialization |
| `4` | `Raffle.buyEntries(address,uint128)` | `Raffle.buyEntries` | `Raffle.sol:209` | Any external EOA or contract purchasing raffle entries |
| `5` | `Raffle.requestDraw()` | `Raffle.requestDraw` | `Raffle.sol:240` | Any external EOA or contract after `endTime` and before `drawRequestDeadline()` |
| `6` | `Raffle.enableRefunds()` | `Raffle.enableRefunds` | `Raffle.sol:276` | Sponsor before `endTime` when `totalEntries == 0`, or any external caller after liveness deadlines |
| `7` | `Raffle.settleWinningTicket(uint256)` | `Raffle.settleWinningTicket` | `Raffle.sol:304` | Any external EOA or contract after VRF draw resolution (`NftWon` or `CashWon`) |
| `8` | `Raffle.redeemWinningTicket(uint256)` | `Raffle.redeemWinningTicket` | `Raffle.sol:309` | Current owner of the winning ERC-721 ticket |
| `9` | `Raffle.refundTickets(uint256[])` | `Raffle.refundTickets` | `Raffle.sol:349` | Current owner of one or more ERC-721 raffle tickets when `status == Status.Refunding` |
| `10` | `Raffle.releaseSponsorProceeds()` | `Raffle.releaseSponsorProceeds` | `Raffle.sol:375` | Any external EOA or contract after winning ticket settlement |
| `11` | `Raffle.releaseProtocolFees()` | `Raffle.releaseProtocolFees` | `Raffle.sol:385` | Any external EOA or contract after winning ticket settlement |
| `12` | `Raffle.releaseSponsorPrize()` | `Raffle.releaseSponsorPrize` | `Raffle.sol:395` | Any external EOA or contract when `status == Status.CashWon` or `Status.Refunding` |
| `13` | `Raffle.onERC721Received(address,address,uint256,bytes)` | `Raffle.onERC721Received` | `Raffle.sol:416` | Configured `prizeToken` contract during `safeTransferFrom` (or any external caller invoking callback directly) |
| `14` | `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords(uint256,uint256[])` | `Raffle.fulfillRandomWords` | `Raffle.sol:504` | Configured Chainlink VRF v2.5 Wrapper (`i_vrfV2PlusWrapper`) |
| `15` | `ERC721.transferFrom(address,address,uint256)` | `Raffle._update` | `Raffle.sol:497` | Ticket owner or approved ERC-721 operator |
| `16` | `ERC721.safeTransferFrom(address,address,uint256)` | `Raffle._update` | `Raffle.sol:497` | Ticket owner or approved ERC-721 operator |
| `17` | `ERC721.safeTransferFrom(address,address,uint256,bytes)` | `Raffle._update` | `Raffle.sol:497` | Ticket owner or approved ERC-721 operator |
| `18` | `ERC721.approve(address,uint256)` | `ERC721.approve` | `Raffle.sol:28` | Ticket owner or operator approved for all |
| `19` | `ERC721.setApprovalForAll(address,bool)` | `ERC721.setApprovalForAll` | `Raffle.sol:28` | Any external EOA or contract setting operator approvals for its own tickets |

---

## 5. Depth 1 & Depth 2 — Flow Trace & Vulnerability Investigation Matrix (`40` Flows)

| Flow `step_result_id` | Parent Entrypoint (`prev_id`) | Focal Location | Flow Summary | Depth 2 Verdict |
| ---: | :---: | --- | --- | --- |
| `20` | `1` (`createRaffle`) | `RaffleFactory.sol:128` | Validates parameters, clones & initializes `Raffle`, registers in factory mappings, escrows prize via `safeTransferFrom`, verifies `ownerOf` and `Status.Active` | **Finding `#1`** (`Cluster 1:1`, Low) |
| `21` | `1` (`createRaffle`) | `RaffleFactory.sol:154` | Reverts creation on invalid parameters, timing bounds, protocol destination, or failed post-transfer escrow check | Verified Safe (`stub: true`) |
| `22` | `2` (`receive`) | `Raffle.sol:172` | Unconditionally reverts direct native-currency transfers with `DirectNativeTransfer()` | Verified Safe (`stub: true`) |
| `23` | `3` (`initialize`) | `Raffle.sol:197` | Initializes newly cloned `Raffle` once when called by `factory`, screens destinations via `_isProtocolDestination`, sets `Status.AwaitingPrize` | **Finding `#2`** (`Cluster 1:1`, Low) |
| `24` | `3` (`initialize`) | `Raffle.sol:177` | Reverts initialization on implementation, already-initialized clones, non-factory callers, or restricted destinations | Verified Safe (`stub: true`) |
| `25` | `4` (`buyEntries`) | `Raffle.sol:235` | Pulls `ENTRY_PRICE * entryCount` in `quoteToken`, assigns sequential `[firstEntry, lastEntry]` range, increments `unsettledPot`, `_safeMint`s ticket | **Finding `#3`** (`Cluster 1:3`, Low) |
| `26` | `4` (`buyEntries`) | `Raffle.sol:215` | Reverts entry purchase when not `Active`, at/after `endTime`, invalid `recipient`, `entryCount == 0`, or `uint128` overflow | Verified Safe (`stub: true`) |
| `27` | `5` (`requestDraw`) | `Raffle.sol:257` | Transitions `Active -> Drawing`, pays VRF wrapper in native currency, records `vrfRequestId`, refunds excess native value | Verified Safe (`stub: true`) |
| `28` | `5` (`requestDraw`) | `Raffle.sol:241` | Reverts draw request outside `[endTime, drawRequestDeadline())`, when `totalEntries == 0`, underfunded VRF fee, or failed native refund | Verified Safe (`stub: true`) |
| `29` | `6` (`enableRefunds`) | `Raffle.sol:280` | Enables refunds on empty `Active` raffle (`totalEntries == 0`) by sponsor before `endTime` or anyone at/after `endTime` | Verified Safe (`stub: true`) |
| `30` | `6` (`enableRefunds`) | `Raffle.sol:286` | Enables full refunds on `Active` raffle with sold entries at/after `drawRequestDeadline()`, moving `unsettledPot` to `remainingRefundLiability` | Verified Safe (`stub: true`) |
| `31` | `6` (`enableRefunds`) | `Raffle.sol:289` | Enables full refunds on `Drawing` raffle at/after `callbackDeadline()`, moving `unsettledPot` to `remainingRefundLiability` | Verified Safe (`stub: true`) |
| `32` | `6` (`enableRefunds`) | `Raffle.sol:282` | Reverts `enableRefunds` before applicable liveness deadline or in non-refundable status | Verified Safe (`stub: true`) |
| `33` | `7` (`settleWinningTicket`) | `Raffle.sol:533` | Settles winning ticket in `NftWon`, splitting `unsettledPot` into `protocolFees` (5%) and `sponsorProceeds` (95% remainder) | Verified Safe (`stub: true`) |
| `34` | `7` (`settleWinningTicket`) | `Raffle.sol:546` | Settles winning ticket in `CashWon`, splitting `unsettledPot` into `protocolFees` (5%), `winnerProceeds` (80%), and `sponsorProceeds` (remainder) | Verified Safe (`stub: true`) |
| `35` | `7` (`settleWinningTicket`) | `Raffle.sol:579` | Reverts settlement when already settled, wrong status, or `ticketId` range does not contain `winningEntry` | Verified Safe (`stub: true`) |
| `36` | `8` (`redeemWinningTicket`) | `Raffle.sol:334` | Settles if needed, verifies `msg.sender == ownerOf(ticketId)`, burns ticket, transfers prize NFT to winner in `NftWon` and verifies `ownerOf` | Verified Safe (`stub: true`) |
| `37` | `8` (`redeemWinningTicket`) | `Raffle.sol:342` | Settles if needed, verifies `msg.sender == ownerOf(ticketId)`, burns ticket, transfers `winnerProceeds` USDC to winner in `CashWon` | Verified Safe (`stub: true`) |
| `38` | `8` (`redeemWinningTicket`) | `Raffle.sol:320` | Reverts redemption on already-redeemed, wrong status, ticket mismatch, non-owner caller, or failed delivery | Verified Safe (`stub: true`) |
| `39` | `9` (`refundTickets`) | `Raffle.sol:368` | Verifies ownership and burns 1..100 tickets in-loop in `Refunding`, decrements `remainingRefundLiability`, transfers USDC refund | Verified Safe (`stub: true`) |
| `40` | `9` (`refundTickets`) | `Raffle.sol:359` | Reverts batch refund on wrong status, batch size `0` or `> 100`, non-owner/burned/duplicate ticket ID, or restricted caller destination | Verified Safe (`stub: true`) |
| `41` | `10` (`releaseSponsorProceeds`) | `Raffle.sol:380` | Zeroes `sponsorProceeds` and transfers USDC to `sponsorRecipient` via `_transferQuote` | Verified Safe (`stub: true`) |
| `42` | `10` (`releaseSponsorProceeds`) | `Raffle.sol:377` | Reverts when `sponsorProceeds == 0` or `_isProtocolDestination(sponsorRecipient)` is true at claim time | Verified Safe (`stub: true`) |
| `43` | `11` (`releaseProtocolFees`) | `Raffle.sol:387` | Reverts when `protocolFees == 0` or `_isProtocolDestination(protocolTreasury)` is true | Verified Safe (`stub: true`) |
| `44` | `11` (`releaseProtocolFees`) | `Raffle.sol:390` | Zeroes `protocolFees` and transfers USDC to `protocolTreasury` via `_transferQuote` | Verified Safe (`stub: true`) |
| `45` | `12` (`releaseSponsorPrize`) | `Raffle.sol:397` | Reverts when status is neither `CashWon` nor `Refunding` or `prizeClaimed` is already true | Verified Safe (`stub: true`) |
| `46` | `12` (`releaseSponsorPrize`) | `Raffle.sol:404` | Sets `prizeClaimed = true`, transfers prize NFT to `sponsorRecipient` via `transferFrom`, and verifies `ownerOf` | **Finding `#4`** (`Cluster 1:1`, Low) |
| `47` | `13` (`onERC721Received`) | `Raffle.sol:422` | Reverts with `UnexpectedPrize` unless `AwaitingPrize`, `msg.sender == prizeToken`, `tokenId == prizeTokenId`, `from == sponsor`, `operator == factory` | Verified Safe (`stub: true`) |
| `48` | `13` (`onERC721Received`) | `Raffle.sol:425` | Transitions `status` from `AwaitingPrize` to `Active` and returns `IERC721Receiver.onERC721Received.selector` | Verified Safe (`stub: true`) |
| `49` | `14` (`rawFulfillRandomWords`) | `VRFV2PlusWrapperConsumerBase.sol:74` | Reverts with `OnlyVRFWrapperCanFulfill` when `msg.sender != address(i_vrfV2PlusWrapper)` | Verified Safe (`stub: true`) |
| `50` | `14` (`rawFulfillRandomWords`) | `Raffle.sol:512` | Emits `VrfCallbackIgnored` and returns early without state mutation on in-flight, wrong-status, wrong-requestId, wrong-length, or expired callbacks | Verified Safe (`stub: true`) |
| `51` | `14` (`rawFulfillRandomWords`) | `Raffle.sol:516` | Computes `winningEntry = (randomWords[0] % totalEntries) + 1` and transitions to `NftWon` (`>= reserveEntries`) or `CashWon` (`< reserveEntries`) | Verified Safe (`stub: true`) |
| `52` | `15` (`transferFrom`) | `Raffle.sol:498` | Reverts ticket transfer on restricted protocol destination or failed ERC-721 owner/approval check | Verified Safe (`stub: true`) |
| `53` | `15` (`transferFrom`) | `Raffle.sol:501` | Screens `to` via `_isProtocolDestination` and updates ticket owner via `super._update` | **Finding `#5`** (`Cluster 1:3`, Low) |
| `54` | `16` (`safeTransferFrom(3)`) | `Raffle.sol:498` | Reverts 3-arg `safeTransferFrom` on restricted protocol destination, unauthorized caller, or non-receiver contract | Verified Safe (`stub: true`) |
| `55` | `16` (`safeTransferFrom(3)`) | `Raffle.sol:501` | Screens `to` via `_isProtocolDestination`, updates owner, and runs `checkOnERC721Received` | **Finding `#6`** (`Cluster 1:3`, Low) |
| `56` | `17` (`safeTransferFrom(4)`) | `Raffle.sol:498` | Reverts 4-arg `safeTransferFrom` on restricted protocol destination, unauthorized caller, or non-receiver contract | Verified Safe (`stub: true`) |
| `57` | `17` (`safeTransferFrom(4)`) | `Raffle.sol:501` | Screens `to` via `_isProtocolDestination`, updates owner, and runs `checkOnERC721Received` with `data` | **Finding `#7`** (`Cluster 1:3`, Low) |
| `58` | `18` (`approve`) | `Raffle.sol:28` | Approves `to` for `ticketId` when called by owner or operator | Verified Safe (`stub: true`) |
| `59` | `19` (`setApprovalForAll`) | `Raffle.sol:28` | Sets or revokes operator approval for `msg.sender` | Verified Safe (`stub: true`) |
