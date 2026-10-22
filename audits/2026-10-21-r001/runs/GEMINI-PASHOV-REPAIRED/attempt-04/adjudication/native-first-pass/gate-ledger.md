# Native Post-Leaf Adjudication & Gate Ledger (`raffle-fun`)

- **Scan Stamp (`{stamp}`)**: `2026-10-21-explicit-high-a04`
- **Project (`{project-name}`)**: `raffle-fun`
- **Passes (`{passes}`)**: `1` (`K = 1`)
- **Memory**: `off` (Turn 4 steps 4 and 6 and Turn 5 step 1 skipped per `SKILL.md` and `references/dedup-and-assembly.md`)
- **Bundle Directory (`{bundle_dir}`)**: `.audit-judge-inputs`
- **References Path (`{resolved_path}`)**: `.agents/skills/solidity-auditor/references`
- **Accepted Specialist Leaves**: `12/12` (`.native-leaf-results/leaf-01.md` .. `.native-leaf-results/leaf-12.md`, bound in `.native-leaf-results/binding.json`)

---

## 1. Raw Leaf Input Binding & Physical Source Line Mapping

### 1.1 Concatenated Bundle (`source.md`) to Physical Source File Offset Map

| In-Scope / Context File | Physical Lines | Bundle (`source.md`) Lines | Offset Conversion |
| --- | --- | --- | --- |
| `packages/contracts/src/Raffle.sol` | `1–614` | `4–617` | `physical = bundle - 3` |
| `packages/contracts/src/RaffleFactory.sol` | `1–186` | `624–809` | `physical = bundle - 623` |
| `packages/contracts/src/interfaces/IRaffle.sol` | `1–520` | `816–1335` | `physical = bundle - 815` |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | `1–149` | `1343–1491` | `physical = bundle - 1342` |
| `packages/contracts/src/libraries/RaffleConstants.sol` | `1–43` | `1499–1541` | `physical = bundle - 1498` |

### 1.2 Accepted Specialist Leaf Receipts (`.native-leaf-results/binding.json`)

| Leaf | Specialist Perspective | File | SHA-256 | Native Terminal Status | Raw Items |
| --- | --- | --- | --- | --- | --- |
| 1 | `math-precision-agent` | `.native-leaf-results/leaf-01.md` | `d61d5f4098fe8b6744b3973ace71f09818e71cbf89a10dd5e5aa19669650c004` | `SUCCESS` | 0 FINDINGs, 2 LEADs (`L1-1`, `L1-2`) |
| 2 | `access-control-agent` | `.native-leaf-results/leaf-02.md` | `19cee03a9a26832b39bff01ab55534db199f7ce2e9640c78c1cb18829499cb00` | `SUCCESS` | 0 FINDINGs, 0 LEADs |
| 3 | `economic-security-agent` | `.native-leaf-results/leaf-03.md` | `96ab5dcb7c97640ab03f2b525f8c4c413a5613e223144cbe4d42ddaef98b3f05` | `ERROR` (historical preserved) | 4 FINDINGs (`L3-1`..`L3-4`), 3 LEADs (`L3-5`..`L3-7`) |
| 4 | `execution-trace-agent` | `.native-leaf-results/leaf-04.md` | `9da3b98924022886dbd1d55c4ab504d2e2139205c3f303e67650de0c4d0e7d51` | `ERROR` (historical preserved) | 0 FINDINGs, 2 LEADs (`L4-1`, `L4-2`) |
| 5 | `invariant-agent` | `.native-leaf-results/leaf-05.md` | `49eafb24f30f2b8ab661deeb40ed896685a6f142f0b0d3bed66d1ef241c77b17` | `SUCCESS` | 1 FINDING (`L5-1`), 1 LEAD (`L5-2`) |
| 6 | `periphery-agent` | `.native-leaf-results/leaf-06.md` | `dcfeeb382943487e7de9d5024d3cb1694da476de071dfecd6a8299ae81fd05ec` | `SUCCESS` | 0 FINDINGs, 0 LEADs |
| 7 | `first-principles-agent` | `.native-leaf-results/leaf-07.md` | `dcfeeb382943487e7de9d5024d3cb1694da476de071dfecd6a8299ae81fd05ec` | `SUCCESS` | 0 FINDINGs, 0 LEADs |
| 8 | `asymmetry-agent` | `.native-leaf-results/leaf-08.md` | `cee3069a384b7ca5c88064710261da43af5e828c991887eda86f45a81084e44c` | `SUCCESS` | 0 FINDINGs, 2 LEADs (`L8-1`, `L8-2`) |
| 9 | `boundary-agent` | `.native-leaf-results/leaf-09.md` | `1e0e5c1bdeb3fe3eec2c3d803af541645830832ee7dc097196529fd5ca30f076` | `SUCCESS` | 0 FINDINGs, 4 LEADs (`L9-1`..`L9-4`) |
| 10 | `numerical-gap-agent` | `.native-leaf-results/leaf-10.md` | `b5edff24b9359fa2a4db6dfd02cff80549ac236db8fdad3c6e864af4b6a8e650` | `SUCCESS` | 0 FINDINGs, 2 LEADs (`L10-1`, `L10-2`) |
| 11 | `trust-gap-agent` | `.native-leaf-results/leaf-11.md` | `0cc69c4d8227ea647efe40918a0411004c48bfb55955935a8a4230bb62c108d4` | `SUCCESS` | 5 FINDINGs (`L11-1`..`L11-5`), 1 LEAD (`L11-6`) |
| 12 | `flow-gap-agent` | `.native-leaf-results/leaf-12.md` | `19eae531d74be63d0f7acb1e4eda0bd3845226b0d0724ca8e7804f46cbc8e228` | `SUCCESS` | 5 FINDINGs (`L12-1`..`L12-5`), 1 LEAD (`L12-6`) |

### 1.3 Complete Raw Specialist Observations (33 Raw Items: 15 FINDINGs, 18 LEADs)

| Raw ID | Leaf | Kind | Contract | Function | Raw `bug_class` | Raw Bundle Anchors → Resolved Physical Source Anchors |Canonical Group ID |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `L1-1` | 1 | `LEAD` | `RaffleFactory` | `_validateCreateParams` | `unbounded-reserve-entries` | `RaffleFactory.sol:178` (`bundle:801`), `Raffle.sol:223,521` | `G06` |
| `L1-2` | 1 | `LEAD` | `Raffle` | `_isProtocolDestination` | `unregistered-future-clone-destination` | `Raffle.sol:593–605` (`bundle:596–608`), `Raffle.sol:564–567` | `G10` |
| `L3-1` | 3 | `FINDING` | `Raffle` | `releaseSponsorProceeds` | `premature-sponsor-payout` | `bundle:536–561` → `Raffle.sol:533–558`; `bundle:378–385` → `Raffle.sol:375–382`; `bundle:777–802` → `RaffleFactory.sol:154–179`; `bundle:337` → `Raffle.sol:334`; `bundle:296` → `Raffle.sol:293` | `G01` |
| `L3-2` | 3 | `FINDING` | `Raffle` | `buyEntries` | `sponsor-rebate-ticket-dilution` | `bundle:212–240` → `Raffle.sol:209–237`; `bundle:543–547` → `Raffle.sol:540–544` | `G03` |
| `L3-3` | 3 | `FINDING` | `RaffleFactory` | `createRaffle` | `unbounded-reserve-entries` | `bundle:801` → `RaffleFactory.sol:178`; `bundle:243–250` → `Raffle.sol:240–247`; `bundle:524` → `Raffle.sol:521`; `bundle:548–551` → `Raffle.sol:545–548`; `bundle:398–410` → `Raffle.sol:395–407` | `G05` |
| `L3-4` | 3 | `FINDING` | `Raffle` | `enableRefunds` | `cancellation-frontrun-lock` | `bundle:282–291` → `Raffle.sol:279–288` | `G07` |
| `L3-5` | 3 | `LEAD` | `Raffle` | `_isProtocolDestination` | `future-clone-address-bypass` | `Raffle.sol:593–605` (`bundle:596–608`), `Raffle.sol:564–567` | `G10` |
| `L3-6` | 3 | `LEAD` | `Raffle` | `releaseSponsorProceeds` | `immutable-recipient-usdc-blacklist` | `Raffle.sol:198–199,375–382,385–392` (`bundle:201–202,378–395`) | `G13` |
| `L3-7` | 3 | `LEAD` | `Raffle` | `requestDraw` | `single-shot-vrf-request` | `Raffle.sol:240–273,289–291` (`bundle:243–276,292–294`) | `G12` |
| `L4-1` | 4 | `LEAD` | `Raffle` | `_isProtocolDestination` | `across-tx-clone-destination-bypass` | `Raffle.sol:593–605,375–382,395–407`, `RaffleFactory.sol:106` | `G10` |
| `L4-2` | 4 | `LEAD` | `Raffle` | `enableRefunds` | `operation-interleaving-cancellation-block` | `Raffle.sol:276–301,209–237,349–372` | `G07` |
| `L5-1` | 5 | `FINDING` | `Raffle` | `_isProtocolDestination` | `time-of-check-destination-bypass` | `Raffle.sol:176–206,209–237,308–346,349–372,375–382,395–407,497–502,564–567,593–605`; `RaffleFactory.sol:89,106,125,154–179` | `G10` |
| `L5-2` | 5 | `LEAD` | `Raffle` | `requestDraw` | `premature-in-flight-flag-reset` | `Raffle.sol:254–271,509–524` (`bundle:257–274,512–527`) | `G11` |
| `L8-1` | 8 | `LEAD` | `Raffle` | `_isProtocolDestination` | `asymmetric-destination-check` | `Raffle.sol:593–605,564–567,395–407,308–346` | `G10` |
| `L8-2` | 8 | `LEAD` | `Raffle` | `initialize` | `asymmetric-input-validation` | `Raffle.sol:187–189` (`bundle:190–192`), `RaffleFactory.sol:154–179` | `G16` |
| `L9-1` | 9 | `LEAD` | `Raffle` | `_isProtocolDestination` | `future-clone-sink-bypass` | `Raffle.sol:593–605,375–382`, `RaffleFactory.sol:106` | `G10` |
| `L9-2` | 9 | `LEAD` | `RaffleFactory` | `constructor` | `future-clone-treasury-collision` | `RaffleFactory.sol:65–92` (`bundle:688–715`), `Raffle.sol:190–192` | `G17` |
| `L9-3` | 9 | `LEAD` | `Raffle` | `releaseSponsorPrize` | `unsafe-erc721-prize-return` | `Raffle.sol:395–407,176–206` (`bundle:398–410,179–209`) | `G08` |
| `L9-4` | 9 | `LEAD` | `Raffle` | `fulfillRandomWords` | `synchronous-vrf-callback-ignored` | `Raffle.sol:254,509–516` (`bundle:257,512–519`) | `G14` |
| `L10-1` | 10 | `LEAD` | `Raffle` | `_isProtocolDestination` | `precomputed-clone-destination-bypass` | `Raffle.sol:593–605,395–407,564–567,304–306,349–372`, `RaffleFactory.sol:106` | `G10` |
| `L10-2` | 10 | `LEAD` | `Raffle` | `getVrfRequestPrice` | `zero-gasprice-quote-mismatch` | `Raffle.sol:436–438,249–250,441–443` (`bundle:439–446,252–253`) | `G15` |
| `L11-1` | 11 | `FINDING` | `Raffle` | `_settleWinningTicket` | `sponsor-rebate-entry-dilution` | `bundle:212–240` → `Raffle.sol:209–237`; `bundle:543–548` → `Raffle.sol:540–545` | `G04` |
| `L11-2` | 11 | `FINDING` | `Raffle` | `buyEntries` | `reserve-cliff-pot-capture` | `bundle:212–240` → `Raffle.sol:209–237`; `bundle:524` → `Raffle.sol:521`; `bundle:546–552` → `Raffle.sol:543–549` | `G03` |
| `L11-3` | 11 | `FINDING` | `RaffleFactory` | `createRaffle` | `unbounded-reserve-cash-rake` | `bundle:801` → `RaffleFactory.sol:178`; `bundle:524` → `Raffle.sol:521`; `bundle:549–551` → `Raffle.sol:546–548`; `bundle:398–410` → `Raffle.sol:395–407`; `bundle:222` → `Raffle.sol:219` | `G05` |
| `L11-4` | 11 | `FINDING` | `Raffle` | `enableRefunds` | `empty-raffle-cancel-block` | `bundle:282–291` → `Raffle.sol:279–288`; `bundle:212–240` → `Raffle.sol:209–237` | `G07` |
| `L11-5` | 11 | `FINDING` | `Raffle` | `requestDraw` | `uncompensated-vrf-fee-asymmetry` | `bundle:243–276` → `Raffle.sol:240–273`; `bundle:288–294` → `Raffle.sol:285–291` | `G09` |
| `L11-6` | 11 | `LEAD` | `Raffle` | `releaseSponsorProceeds` | `premature-sponsor-payout-before-prize-delivery` | `Raffle.sol:533–558,375–382,308–346` (`bundle:536–561,378–385,311–349`) | `G01` |
| `L12-1` | 12 | `FINDING` | `Raffle` | `_isProtocolDestination` | `unregistered-future-clone-sink` | `bundle:729,748,789` → `RaffleFactory.sol:106,125,166`; `bundle:196,324,363,383,398–410,501,568,596–608` → `Raffle.sol:193,321,360,380,395–407,498,565,593–605` | `G10` |
| `L12-2` | 12 | `FINDING` | `Raffle` | `enableRefunds` | `sponsor-cancel-frontrun-lock` | `bundle:282–291,398–410,212–240,549` → `Raffle.sol:279–288,395–407,209–237,546` | `G07` |
| `L12-3` | 12 | `FINDING` | `Raffle` | `_settleWinningTicket` | `premature-sponsor-proceeds-release` | `bundle:751` → `RaffleFactory.sol:128`; `bundle:524,307,536–561,378–385,311–349,337` → `Raffle.sol:521,304,533–558,375–382,308–346,334` | `G02` |
| `L12-4` | 12 | `FINDING` | `RaffleFactory` | `_validateCreateParams` | `unbounded-reserve-entries` | `bundle:801` → `RaffleFactory.sol:178`; `bundle:226,524,549–550,398` → `Raffle.sol:223,521,546–547,395` | `G06` |
| `L12-5` | 12 | `FINDING` | `Raffle` | `releaseSponsorPrize` | `unsafe-prize-nft-transfer` | `bundle:1362–1368` → `IRaffleFactory.sol:20–26`; `bundle:777–802` → `RaffleFactory.sol:154–179`; `bundle:179–209,383,398–410,337` → `Raffle.sol:176–206,380,395–407,334` | `G08` |
| `L12-6` | 12 | `LEAD` | `Raffle` | `requestDraw` | `premature-in-flight-flag-reset` | `bundle:263,270` → `Raffle.sol:260,267` | `G11` |

---

## 2. Turn 4 Step 1 — Deduplication, Canonicalisation, Function Isolation, Mechanism & Fix Preservation, and Completeness

### 2.1 Bug-Class Label Canonicalisation (HARD GATE) & Function Isolation (HARD GATE)

All deduplication stays strictly within `(Contract, function)`. No item is merged across different `function:` fields.

| Tuple # | `(Contract, function)` | Raw Items & Raw `bug_class` Labels | Same or Distinct Bug Class? | Canonical Label Choice & Rule Applied | Canonical `group_key` (`key`) | `[agents: N]` |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `(Raffle, _isProtocolDestination)` | `L1-2` (`unregistered-future-clone-destination`), `L3-5` (`future-clone-address-bypass`), `L4-1` (`across-tx-clone-destination-bypass`), `L5-1` (`time-of-check-destination-bypass`), `L8-1` (`asymmetric-destination-check`), `L9-1` (`future-clone-sink-bypass`), `L10-1` (`precomputed-clone-destination-bypass`), `L12-1` (`unregistered-future-clone-sink`) | Same bug class (all 8 describe precomputed `CREATE` clone address passing `_isProtocolDestination` when `code.length == 0` before deployment) | Rule 3 (all 8 labels have count 1; `future-clone-sink-bypass` is shortest at 24 chars and names the defect) | `Raffle \| _isProtocolDestination \| future-clone-sink-bypass` (`raffle\|-isprotocoldestination\|future-clone-sink-bypass`) | `[agents: 8]` (1, 3, 4, 5, 8, 9, 10, 12) |
| 2 | `(Raffle, buyEntries)` | `L3-2` (`sponsor-rebate-ticket-dilution`), `L11-2` (`reserve-cliff-pot-capture`) | Same bug class (both stem from `buyEntries` permitting uncapped sponsor entry purchases that receive a 95% rebate in `NftWon`; `L3-2` proof explicitly includes both post-reserve dilution and reserve-crossing pot capture) | Rule 3 (`sponsor-rebate-ticket-dilution` names the defect, whereas `pot-capture` names the consequence; both mechanisms and both fixes preserved under Wide-Description and Fix Preservation) | `Raffle \| buyEntries \| sponsor-rebate-ticket-dilution` (`raffle\|buyentries\|sponsor-rebate-ticket-dilution`) | `[agents: 2]` (3, 11) |
| 3 | `(Raffle, enableRefunds)` | `L3-4` (`cancellation-frontrun-lock`), `L4-2` (`operation-interleaving-cancellation-block`), `L11-4` (`empty-raffle-cancel-block`), `L12-2` (`sponsor-cancel-frontrun-lock`) | Same bug class (all 4 describe `buyEntries(attacker, 1)` setting `totalEntries = 1` before `enableRefunds`, blocking pre-`endTime` sponsor cancellation) | Rule 3 (all 4 labels have count 1; `empty-raffle-cancel-block` is shortest at 25 chars and names the defect) | `Raffle \| enableRefunds \| empty-raffle-cancel-block` (`raffle\|enablerefunds\|empty-raffle-cancel-block`) | `[agents: 4]` (3, 4, 11, 12) |
| 4 | `(Raffle, fulfillRandomWords)` | `L9-4` (`synchronous-vrf-callback-ignored`) | Single item | Unchanged (`synchronous-vrf-callback-ignored`) | `Raffle \| fulfillRandomWords \| synchronous-vrf-callback-ignored` (`raffle\|fulfillrandomwords\|synchronous-vrf-callback-ignored`) | `[agents: 1]` (9) |
| 5 | `(Raffle, getVrfRequestPrice)` | `L10-2` (`zero-gasprice-quote-mismatch`) | Single item | Unchanged (`zero-gasprice-quote-mismatch`) | `Raffle \| getVrfRequestPrice \| zero-gasprice-quote-mismatch` (`raffle\|getvrfrequestprice\|zero-gasprice-quote-mismatch`) | `[agents: 1]` (10) |
| 6 | `(Raffle, initialize)` | `L8-2` (`asymmetric-input-validation`) | Single item | Unchanged (`asymmetric-input-validation`) | `Raffle \| initialize \| asymmetric-input-validation` (`raffle\|initialize\|asymmetric-input-validation`) | `[agents: 1]` (8) |
| 7 | `(Raffle, releaseSponsorPrize)` | `L9-3` (`unsafe-erc721-prize-return`), `L12-5` (`unsafe-prize-nft-transfer`) | Same bug class (both describe `releaseSponsorPrize` calling `prizeToken.transferFrom` instead of `safeTransferFrom` to a contract `sponsorRecipient`) | Rule 3 (each count 1; `unsafe-prize-nft-transfer` is shortest at 25 chars vs 26 chars and names the defect) | `Raffle \| releaseSponsorPrize \| unsafe-prize-nft-transfer` (`raffle\|releasesponsorprize\|unsafe-prize-nft-transfer`) | `[agents: 2]` (9, 12) |
| 8 | `(Raffle, releaseSponsorProceeds)` | Group A: `L3-1` (`premature-sponsor-payout`), `L11-6` (`premature-sponsor-payout-before-prize-delivery`)<br>Group B: `L3-6` (`immutable-recipient-usdc-blacklist`) | Group A items are the same bug class (`releaseSponsorProceeds` paying out before `prizeToken` delivery in `NftWon`).<br>Group B is a genuinely distinct bug class (`quoteToken` blacklisting immutable `sponsorRecipient`/`protocolTreasury`). | Group A: Rule 3 (`premature-sponsor-payout` is shortest at 24 chars vs 46 chars).<br>Group B: Unchanged (`immutable-recipient-usdc-blacklist`). | `G01`: `Raffle \| releaseSponsorProceeds \| premature-sponsor-payout` (`raffle\|releasesponsorproceeds\|premature-sponsor-payout`)<br>`G13`: `Raffle \| releaseSponsorProceeds \| immutable-recipient-usdc-blacklist` (`raffle\|releasesponsorproceeds\|immutable-recipient-usdc-blacklist`) | `G01`: `[agents: 2]` (3, 11)<br>`G13`: `[agents: 1]` (3) |
| 9 | `(Raffle, requestDraw)` | Group A: `L11-5` (`uncompensated-vrf-fee-asymmetry`)<br>Group B: `L5-2`, `L12-6` (`premature-in-flight-flag-reset`)<br>Group C: `L3-7` (`single-shot-vrf-request`) | Three distinct bug classes in `requestDraw`:<br>- `G09` (`L11-5`): uncompensated VRF fee and `totalEntries < reserveEntries` `CashWon` draw initiation.<br>- `G11` (`L5-2`, `L12-6`): `_requestInFlight = false` set before native refund call.<br>- `G12` (`L3-7`): single-shot `Status.Drawing` transition with no VRF retry path on wrapper timeout. | `G11`: Exact match (`premature-in-flight-flag-reset`, 2 agents).<br>`G09` & `G12`: Unchanged distinct classes. | `G09`: `Raffle \| requestDraw \| uncompensated-vrf-fee-asymmetry` (`raffle\|requestdraw\|uncompensated-vrf-fee-asymmetry`)<br>`G11`: `Raffle \| requestDraw \| premature-in-flight-flag-reset` (`raffle\|requestdraw\|premature-in-flight-flag-reset`)<br>`G12`: `Raffle \| requestDraw \| single-shot-vrf-request` (`raffle\|requestdraw\|single-shot-vrf-request`) | `G09`: `[agents: 1]` (11)<br>`G11`: `[agents: 2]` (5, 12)<br>`G12`: `[agents: 1]` (3) |
| 10 | `(Raffle, _settleWinningTicket)` | Group A: `L12-3` (`premature-sponsor-proceeds-release`)<br>Group B: `L11-1` (`sponsor-rebate-entry-dilution`) | Two genuinely distinct bug classes in `_settleWinningTicket`:<br>- `G02` (`L12-3`): allocating `sponsorProceeds` before `prizeToken` delivery (`prizeClaimed`).<br>- `G04` (`L11-1`): allocating 95% of uncapped `grossPot` (above `reserveEntries`) to `sponsorProceeds`. | Kept as two separate records per `dedup-and-assembly.md` ("Two genuinely different bugs in one function keep two labels and stay two records"). | `G02`: `Raffle \| _settleWinningTicket \| premature-sponsor-proceeds-release` (`raffle\|-settlewinningticket\|premature-sponsor-proceeds-release`)<br>`G04`: `Raffle \| _settleWinningTicket \| sponsor-rebate-entry-dilution` (`raffle\|-settlewinningticket\|sponsor-rebate-entry-dilution`) | `G02`: `[agents: 1]` (12)<br>`G04`: `[agents: 1]` (11) |
| 11 | `(RaffleFactory, constructor)` | `L9-2` (`future-clone-treasury-collision`) | Single item | Unchanged (`future-clone-treasury-collision`) | `RaffleFactory \| constructor \| future-clone-treasury-collision` (`rafflefactory\|constructor\|future-clone-treasury-collision`) | `[agents: 1]` (9) |
| 12 | `(RaffleFactory, createRaffle)` | `L3-3` (`unbounded-reserve-entries`), `L11-3` (`unbounded-reserve-cash-rake`) | Same bug class (both describe setting unreachable `reserveEntries` in `createRaffle` to force `Status.CashWon` and take 15% + keep NFT) | Rule 3 (`unbounded-reserve-entries` is shorter at 25 chars vs 27 chars and names the defect rather than the `cash-rake` consequence) | `RaffleFactory \| createRaffle \| unbounded-reserve-entries` (`rafflefactory\|createraffle\|unbounded-reserve-entries`) | `[agents: 2]` (3, 11) |
| 13 | `(RaffleFactory, _validateCreateParams)` | `L1-1` (`unbounded-reserve-entries`), `L12-4` (`unbounded-reserve-entries`) | Same bug class (exact match) | Rule 2 (both agents used `unbounded-reserve-entries`) | `RaffleFactory \| _validateCreateParams \| unbounded-reserve-entries` (`rafflefactory\|-validatecreateparams\|unbounded-reserve-entries`) | `[agents: 2]` (1, 12) |

### 2.2 Function-Level Second Pass & Wide-Description Verification

- **`(Raffle, buyEntries)` (`G03`)**: Constituent `L3-2` includes both post-reserve 95% rebate dilution (`totalEntries >= reserveEntries`) and reserve-crossing pot capture (`totalEntries < reserveEntries` → `reserveEntries`), and constituent `L11-2` focuses on reserve-crossing pot capture. Both mechanisms are preserved in `G03`'s description and Option A / Option B fixes.
- **`(Raffle, enableRefunds)` (`G07`)**: Constituents `L3-4`, `L4-2`, `L11-4`, `L12-2` all describe an attacker purchasing 1 entry (`1 USDC`) to make `totalEntries == 1` before `sponsor` calls `enableRefunds()`, locking the prize until `endTime` / `drawRequestDeadline()`. Both distinct fixes (`allow-and-handle` below `reserveEntries` vs `restrict` via `startTime` delay) are preserved as Option A and Option B.
- **`(Raffle, releaseSponsorProceeds)` (`G01`, `G13`)**: `G01` covers premature `sponsorProceeds` withdrawal in `Status.NftWon` when `prizeToken.transferFrom` reverts in `redeemWinningTicket`; `G13` covers USDC blacklisting of the immutable `sponsorRecipient` / `protocolTreasury`. Every constituent mechanism appears in `G01` or `G13`.
- **`(Raffle, requestDraw)` (`G09`, `G11`, `G12`)**: `G09` covers uncompensated native VRF fee and `totalEntries < reserveEntries` `Status.CashWon` forcing; `G11` covers clearing `_requestInFlight` before the low-level native refund call; `G12` covers the single-shot `Status.Drawing` request with no retry path on wrapper timeout. Every constituent mechanism appears in `G09`, `G11`, or `G12`.
- **`(Raffle, _settleWinningTicket)` (`G02`, `G04`)**: `G02` covers allocating `sponsorProceeds` before `prizeClaimed` in `Status.NftWon`; `G04` covers allocating 95% of uncapped `grossPot` (above `reserveEntries`) to `sponsorProceeds`. Both constituent mechanisms appear as distinct findings.
- **`(RaffleFactory, createRaffle)` (`G05`)**: Constituents `L3-3` and `L11-3` both describe unreachable `reserveEntries` forcing `Status.CashWon`; both distinct fixes (capping `reserveEntries` in `_validateCreateParams` vs zeroing `sponsorProceeds` in `Status.CashWon`) are preserved as Option A and Option B.

### 2.3 Fix Preservation Check (HARD GATE)

| Canonical Group | Raw Fixes Collected Verbatim | Distinct ADD-Lines / Fix Directions | Output Representation |
| --- | --- | --- | --- |
| `G01` (`Raffle.releaseSponsorProceeds`) | `L3-1`: `Transfer prizeToken to the owner of the ticket inside _settleWinningTicket, or require prizeClaimed to be true when status is Status.NftWon in releaseSponsorProceeds.` (`L11-6` is a LEAD with no `fix:`) | 1 raw finding fix (`require prizeClaimed` in `releaseSponsorProceeds` when `status == Status.NftWon`) | Single `**Fix**` diff block |
| `G02` (`Raffle._settleWinningTicket`) | `L12-3`: `Require prizeClaimed to be true before releaseSponsorProceeds and releaseProtocolFees can pay out when status is Status.NftWon.` | 1 raw finding fix | Single `**Fix**` diff block |
| `G03` (`Raffle.buyEntries`) | `L3-2`: `Cap totalEntries at reserveEntries or a fixed maximum entry count in buyEntries, and reject purchases from sponsor and sponsorRecipient.`<br>`L11-2`: `Block the sponsor and sponsorRecipient from buyEntries, or refund all buyers when totalEntries is below reserveEntries at endTime.` | 2 distinct fixes:<br>- Option A (`restrict`): cap `totalEntries` at `reserveEntries` and reject `sponsor` / `sponsorRecipient` in `buyEntries`.<br>- Option B (`ban-path`): block `sponsor` / `sponsorRecipient` in `buyEntries`. | `**Fix (Option A — restrict)**:` + `**Fix (Option B — ban-path)**:` |
| `G04` (`Raffle._settleWinningTicket`) | `L11-1`: `Cap totalEntries at reserveEntries in buyEntries, or cap sponsorProceeds at the reserve amount in _settleWinningTicket.` | 1 raw finding fix | Single `**Fix**` diff block |
| `G05` (`RaffleFactory.createRaffle`) | `L3-3`: `Enforce a reasonable upper bound on reserveEntries in _validateCreateParams, or route raffles that miss reserveEntries to Status.Refunding instead of Status.CashWon.`<br>`L11-3`: `Enforce a reasonable maximum on reserveEntries in _validateCreateParams, and set sponsorProceeds to zero when status is CashWon.` | 2 distinct fixes:<br>- Option A (`validate`): enforce upper bound on `reserveEntries` in `_validateCreateParams`.<br>- Option B (`restrict`): zero `sponsorProceeds` when `status == Status.CashWon`. | `**Fix (Option A — validate)**:` + `**Fix (Option B — restrict)**:` |
| `G06` (`RaffleFactory._validateCreateParams`) | `L12-4`: `Enforce a maximum reserveEntries constant in RaffleFactory._validateCreateParams so every created raffle has a reachable reserve threshold.` (`L1-1` is a LEAD with no `fix:`) | 1 raw finding fix | Single `**Fix**` diff block |
| `G07` (`Raffle.enableRefunds`) | `L3-4`: `Add a startTime delay before buyEntries accepts purchases so the sponsor can call enableRefunds during a grace period after creation.`<br>`L11-4`: `Allow the sponsor to call enableRefunds before endTime when totalEntries is below reserveEntries, so buyers can claim full refunds in refundTickets.`<br>`L12-2`: `Allow the sponsor to cancel the raffle and refund all sold tickets before the sale ends if totalEntries is below reserveEntries.` | 2 distinct fixes (`L11-4` and `L12-2` are equivalent; `L3-4` differs in target and direction):<br>- Option A (`allow-and-handle`): allow `sponsor` to call `enableRefunds` before `endTime` when `totalEntries < reserveEntries`.<br>- Option B (`restrict`): enforce `block.timestamp >= startTime` in `buyEntries`. | `**Fix (Option A — allow-and-handle)**:` + `**Fix (Option B — restrict)**:` |
| `G08` (`Raffle.releaseSponsorPrize`) | `L12-5`: `Separate the quote-token recipient from the prize recipient, or use safeTransferFrom with a fallback address for prize delivery.` (`L9-3` is a LEAD with no `fix:`) | 1 raw finding fix | Single `**Fix**` diff block |
| `G09` (`Raffle.requestDraw`) | `L11-5`: `Escrow the native VRF fee from the sponsor in createRaffle, or reimburse the caller of requestDraw from unsettledPot before fee allocation.` | 1 raw finding fix | Single `**Fix**` diff block |
| `G10` (`Raffle._isProtocolDestination`) | `L5-1`: `Deploy clones with Clones.cloneDeterministic and a salt derived from block.prevrandao and msg.sender, and check _isProtocolDestination inside releaseSponsorPrize and redeemWinningTicket.`<br>`L12-1`: `Deploy clones with Clones.cloneDeterministic, verify recipient support in _update and initialize, and check _isProtocolDestination in releaseSponsorPrize.` | Demoted to `LEAD` at Gate 4 (no Fix block emitted for `LEAD` per `report-formatting.md`; both raw fixes preserved here in ledger) | `LEAD` (no Fix block) |

### 2.4 Completeness Gate Check (HARD GATE)

`Completeness: 13 unique (Contract, function) in raw, 13 covered in final.`

Every single `(Contract, function)` tuple present in any raw `FINDING` or `LEAD` across the 12 specialist leaves survives into the final gated set (`run-1.md`):
1. `(Raffle, _isProtocolDestination)` → `G10` (`LEAD`)
2. `(Raffle, buyEntries)` → `G03` (`FINDING`)
3. `(Raffle, enableRefunds)` → `G07` (`FINDING`)
4. `(Raffle, fulfillRandomWords)` → `G14` (`LEAD`)
5. `(Raffle, getVrfRequestPrice)` → `G15` (`LEAD`)
6. `(Raffle, initialize)` → `G16` (`LEAD`)
7. `(Raffle, releaseSponsorPrize)` → `G08` (`FINDING`)
8. `(Raffle, releaseSponsorProceeds)` → `G01` (`FINDING`), `G13` (`LEAD`)
9. `(Raffle, requestDraw)` → `G09` (`FINDING`), `G11` (`LEAD`), `G12` (`LEAD`)
10. `(Raffle, _settleWinningTicket)` → `G02` (`FINDING`), `G04` (`FINDING`)
11. `(RaffleFactory, constructor)` → `G17` (`LEAD`)
12. `(RaffleFactory, createRaffle)` → `G05` (`FINDING`)
13. `(RaffleFactory, _validateCreateParams)` → `G06` (`FINDING`)

Composite chains: `0` additional multi-finding chains beyond the self-contained traces in `G01`–`G09`.

---

## 3. Turn 4 Step 2 & Step 3 — Single-Pass Four-Gate Evaluation & Lead Promotion / Demotion

### `G01` — `Raffle | releaseSponsorProceeds | premature-sponsor-payout` (`L3-1`, `L11-6`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`, `RaffleFactory.sol:154–179`): `ALLOWS` — `_validateCreateParams` only checks `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` (`RaffleFactory.sol:172`).
  - `swap / buyEntries / requestDraw / fulfillRandomWords` (`Raffle.sol:209–273,509–524`): `ALLOWS` — transitions raffle to `Status.NftWon` when `totalEntries >= reserveEntries`.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `ALLOWS` — allocates `sponsorProceeds = grossPot - protocolFee` (95%) without transferring `prizeToken`.
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS` — `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` (`Raffle.sol:334`) reverts if `prizeToken` pauses or blocks transfers after escrow, while `enableRefunds` reverts with `InvalidStatus(Status.NftWon)` (`Raffle.sol:293`).
  - `liquidate / releaseSponsorProceeds` (`Raffle.sol:375–382`): `ALLOWS` — transfers `sponsorProceeds` to `sponsorRecipient` without checking `prizeClaimed` or `winnerRedeemed`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. No guard in `settleWinningTicket` (`Raffle.sol:304–306`) or `releaseSponsorProceeds` (`Raffle.sol:375–382`) checks `prizeClaimed` or `winnerRedeemed` when `status == Status.NftWon`.
- **Gate 2 — Reachability**: **CLEARS**. `RaffleFactory.createRaffle` accepts arbitrary ERC-721 contracts reporting `supportsInterface(0x80ac58cd)` (`RaffleFactory.sol:172`), so pausable, blocklist-enabled, or sponsor-controlled ERC-721 tokens are reachable in live deployment (`judging.md`: blacklisting/pausing is plausible for contracts accepting arbitrary tokens).
- **Gate 3 — Trigger**: **CLEARS**. Any unprivileged actor can call `createRaffle`, `settleWinningTicket`, and `releaseSponsorProceeds` profitably.
- **Gate 4 — Impact**: **CONFIRMED**. The sponsor extracts 95% of `unsettledPot` in USDC while the winning ticket holder cannot redeem the NFT (`redeemWinningTicket` reverts at `Raffle.sol:334`) or claim a refund (`enableRefunds` reverts at `Raffle.sol:293`).
- **Confidence**: `100 - 10` (requires specific achievable state: `prizeToken` transfer blocked/paused after escrow in `Status.NftWon`) = **`90`**.

### `G02` — `Raffle | _settleWinningTicket | premature-sponsor-proceeds-release` (`L12-3`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS`
  - `swap / buyEntries / requestDraw / fulfillRandomWords` (`Raffle.sol:209–273,509–524`): `ALLOWS` — sets `status = Status.NftWon`.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `ALLOWS` — sets `unsettledPot = 0` and `sponsorProceeds = sponsorAmount` (`Raffle.sol:552–553`) before `redeemWinningTicket` delivers `prizeToken`.
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS` — reverts at `Raffle.sol:334` if `prizeToken.transferFrom` is blocked or paused.
  - `liquidate / releaseSponsorProceeds` (`Raffle.sol:375–382`): `ALLOWS` — pays `sponsorProceeds` immediately after `_settleWinningTicket`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `_settleWinningTicket` (`Raffle.sol:533–558`) unconditionally credits `sponsorProceeds` in `Status.NftWon` without verifying `prizeClaimed`.
- **Gate 2 — Reachability**: **CLEARS**. Reachable with any ERC-721 `prizeToken` that pauses or restricts transfers after escrow.
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged caller triggers `settleWinningTicket` and `releaseSponsorProceeds`.
- **Gate 4 — Impact**: **CONFIRMED**. Material loss of 100% of buyer USDC (95% to sponsor, 5% to protocol) with no NFT delivered to the winner.
- **Confidence**: `100 - 10` (requires specific achievable state) = **`90`**.

### `G03` — `Raffle | buyEntries | sponsor-rebate-ticket-dilution` (`L3-2`, `L11-2`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS`
  - `swap / buyEntries` (`Raffle.sol:209–237`): `ALLOWS` — enforces no cap at `reserveEntries` (only `type(uint128).max - totalEntries` at `Raffle.sol:219`) and permits `sponsor` / `sponsorRecipient` to purchase entries up to `endTime - 1`.
  - `mint / fulfillRandomWords & _settleWinningTicket` (`Raffle.sol:509–558`): `ALLOWS` — `totalEntries >= reserveEntries` sets `Status.NftWon` (`Raffle.sol:521`), flipping `winnerProceeds` from 80% (`CashWon`) to 0% and `sponsorProceeds` from 15% to 95% (`Raffle.sol:543–549`).
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS`
  - `liquidate / releaseSponsorProceeds` (`Raffle.sol:375–382`): `ALLOWS` — returns 95% of `unsettledPot` (including 95% of the sponsor's own entry payment) to `sponsorRecipient`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. No check in `buyEntries` (`Raffle.sol:209–237`) blocks the sponsor or caps `totalEntries` at `reserveEntries`.
- **Gate 2 — Reachability**: **CLEARS**. Reachable in any active raffle during normal entry sales.
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged sponsor/buyer calls `buyEntries`, `settleWinningTicket`, and `releaseSponsorProceeds` profitably (20x entry cost asymmetry: 0.05 USDC net cost per entry for sponsor vs 1.00 USDC for buyers, plus 80%-to-95% reserve cliff capture).
- **Gate 4 — Impact**: **CONFIRMED**. Material loss to honest ticket buyers (win probability diluted to near zero or 80% `CashWon` pool captured by sponsor top-up at `endTime - 1`).
- **Confidence**: `100 - 10` (requires specific achievable state: honest entries in pot before `endTime`) = **`90`**.

### `G04` — `Raffle | _settleWinningTicket | sponsor-rebate-entry-dilution` (`L11-1`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS`
  - `swap / buyEntries` (`Raffle.sol:209–237`): `ALLOWS`
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `ALLOWS` — lines 540–544 compute `protocolFee = Math.mulDiv(grossPot, 500, 10_000)` and `sponsorAmount = grossPot - protocolFee` on the entire uncapped `grossPot`.
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS`
  - `liquidate / releaseSponsorProceeds` (`Raffle.sol:375–382`): `ALLOWS`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `_settleWinningTicket` (`Raffle.sol:540–544`) does not cap `sponsorProceeds` at `reserveEntries * ENTRY_PRICE`.
- **Gate 2 — Reachability**: **CLEARS**. Reachable in any `Status.NftWon` raffle where entries exceed `reserveEntries`.
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged sponsor/caller triggers `buyEntries` and `_settleWinningTicket`.
- **Gate 4 — Impact**: **CONFIRMED**. Material dilution of honest buyers' win odds at 5% net cost per entry to the sponsor.
- **Confidence**: `100 - 10` (requires specific achievable state) = **`90`**.

### `G05` — `RaffleFactory | createRaffle | unbounded-reserve-entries` (`L3-3`, `L11-3`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`RaffleFactory.sol:65–92`): `IRRELEVANT`
  - `setters / createRaffle & _validateCreateParams` (`RaffleFactory.sol:97–180`): `ALLOWS` — `createRaffle` accepts any `params.reserveEntries` up to `type(uint128).max` because `_validateCreateParams` only checks `if (params.reserveEntries == 0) revert ZeroReserveEntries()` (`RaffleFactory.sol:178`).
  - `swap / buyEntries & requestDraw & fulfillRandomWords` (`Raffle.sol:209–273,509–524`): `ALLOWS` — `totalEntries >= reserveEntries` at `Raffle.sol:521` is unreachable when `reserveEntries = type(uint128).max`, forcing `Status.CashWon`.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `ALLOWS` — allocates 80% to `winnerProceeds`, 5% to `protocolFees`, and 15% to `sponsorProceeds` (`Raffle.sol:546–548`).
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS`
  - `liquidate / releaseSponsorProceeds & releaseSponsorPrize` (`Raffle.sol:375–382,395–407`): `ALLOWS` — sponsor withdraws 15% of buyer deposits and reclaims `prizeTokenId`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. No upper bound on `params.reserveEntries` exists in `createRaffle` or `_validateCreateParams` (`RaffleFactory.sol:97–180`); per `judging.md`, "the caller would notice" is speculative and clears Gate 1.
- **Gate 2 — Reachability**: **CLEARS**. Directly reachable in any live deployment via `createRaffle`.
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged sponsor calls `createRaffle`, `requestDraw`, `settleWinningTicket`, `releaseSponsorProceeds`, and `releaseSponsorPrize`.
- **Gate 4 — Impact**: **CONFIRMED**. Buyers lose 20% of their deposits (15% to sponsor, 5% to protocol) in a raffle where `Status.NftWon` is mathematically impossible and the sponsor bears zero risk of losing the NFT.
- **Confidence**: `100 - 15` (bounded non-compounding impact: 15% sponsor rake / 20% buyer loss per raffle) = **`85`**.

### `G06` — `RaffleFactory | _validateCreateParams | unbounded-reserve-entries` (`L1-1`, `L12-4`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`RaffleFactory.sol:65–92`): `IRRELEVANT`
  - `setters / _validateCreateParams` (`RaffleFactory.sol:154–180`): `ALLOWS` — line 178 checks only `if (params.reserveEntries == 0) revert ZeroReserveEntries();` without bounding `params.reserveEntries * ENTRY_PRICE` against reachable supply.
  - `swap / buyEntries & fulfillRandomWords` (`Raffle.sol:209–237,509–524`): `ALLOWS` — `totalEntries >= reserveEntries` (`Raffle.sol:521`) is impossible when `reserveEntries * ENTRY_PRICE > quoteToken.totalSupply()`, guaranteeing `Status.CashWon`.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `ALLOWS` — allocates 15% of `grossPot` to `sponsorProceeds`.
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `ALLOWS`
  - `liquidate / releaseSponsorProceeds & releaseSponsorPrize` (`Raffle.sol:375–382,395–407`): `ALLOWS`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `_validateCreateParams` (`RaffleFactory.sol:178`) has no upper-bound check on `params.reserveEntries`.
- **Gate 2 — Reachability**: **CLEARS**. Reachable in any live deployment.
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged sponsor triggers `createRaffle`.
- **Gate 4 — Impact**: **CONFIRMED**. Material loss of 20% of buyer deposits with zero chance of winning the NFT.
- **Confidence**: `100 - 15` (bounded non-compounding impact) = **`85`**.

### `G07` — `Raffle | enableRefunds | empty-raffle-cancel-block` (`L3-4`, `L4-2`, `L11-4`, `L12-2`; `[agents: 4]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS`
  - `swap / buyEntries` (`Raffle.sol:209–237`): `ALLOWS` — attacker calls `buyEntries(attacker, 1)` for `1_000_000` raw USDC (`1 USDC`), setting `totalEntries = 1`.
  - `mint / enableRefunds` (`Raffle.sol:276–301`): `ALLOWS` — because `totalEntries != 0`, `enableRefunds` skips `if (totalEntries == 0)` (`Raffle.sol:280`) and enters the `else` branch (`deadline = drawRequestDeadline()`, `Raffle.sol:286–287`), reverting with `RefundsNotAvailable(deadline, block.timestamp)` until `endTime + 2 days`.
  - `burn / refundTickets & redeemWinningTicket` (`Raffle.sol:308–372`): `ALLOWS` — attacker later recovers `1.00 USDC` via `refundTickets` (cost `0 USDC`) or `0.80 USDC` via `redeemWinningTicket` in `CashWon` (cost `0.20 USDC`).
  - `liquidate / releaseSponsorPrize` (`Raffle.sol:395–407`): `ALLOWS` — reverts with `SponsorPrizeUnavailable(Status.Active)` until `endTime` / `drawRequestDeadline()`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `enableRefunds` (`Raffle.sol:280–288`) strictly requires `totalEntries == 0` for pre-`endTime` cancellation by `sponsor`.
- **Gate 2 — Reachability**: **CLEARS**. Reachable on every active raffle before `endTime`.
- **Gate 3 — Trigger**: **CLEARS**. Any unprivileged caller can call `buyEntries(attacker, 1)` for `1 USDC`.
- **Gate 4 — Impact**: **CONFIRMED**. Locks the sponsor's escrowed `prizeToken` for up to 32 days (`MAX_SALE_DURATION + DRAW_REQUEST_TIMEOUT`) at a net cost of `0` to `0.20 USDC`.
- **Confidence**: `100 - 15` (bounded non-compounding impact: temporary lock up to `endTime + 2 days`) `- 10` (requires specific state: sponsor attempting to cancel an empty raffle before `endTime`) = **`75`**.

### `G08` — `Raffle | releaseSponsorPrize | unsafe-prize-nft-transfer` (`L9-3`, `L12-5`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize & _validateCreateParams` (`Raffle.sol:176–206`, `RaffleFactory.sol:154–180`): `ALLOWS` — configures a single `sponsorRecipient` for both USDC and ERC-721 without verifying `IERC721Receiver`.
  - `swap / enableRefunds & fulfillRandomWords` (`Raffle.sol:276–301,509–524`): `ALLOWS` — transitions raffle to `Status.Refunding` or `Status.CashWon`.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `IRRELEVANT`
  - `burn / redeemWinningTicket` (`Raffle.sol:308–346`): `IRRELEVANT`
  - `liquidate / releaseSponsorPrize` (`Raffle.sol:395–407`): `ALLOWS` — permissionless `releaseSponsorPrize()` calls `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (`Raffle.sol:404`) instead of `safeTransferFrom`, bypassing `onERC721Received`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `releaseSponsorPrize` (`Raffle.sol:404`) uses `transferFrom` rather than `safeTransferFrom` and has no access restriction.
- **Gate 2 — Reachability**: **CLEARS** (or demotes and promotes at Step 3 under `[agents: 2]` Multi-agent convergence). Reachable whenever `sponsorRecipient` is a USDC treasury/splitter or vault contract that requires `onERC721Received` or lacks ERC-721 withdrawal logic.
- **Gate 3 — Trigger**: **CLEARS**. Any unprivileged caller can invoke `releaseSponsorPrize()` in `Status.CashWon` or `Status.Refunding`.
- **Gate 4 — Impact**: **CONFIRMED** (and converged `[agents: 2]`, Agents 9 & 12). Permanently strands `prizeTokenId` in a contract `sponsorRecipient` that cannot transfer ERC-721 tokens or relies on `onERC721Received` accounting.
- **Confidence**: `100 - 15` (bounded non-compounding single-raffle impact) `- 10` (requires specific state: contract `sponsorRecipient` incompatible with raw `transferFrom`) = **`75`** (also matches Step 3 `[agents: 2+]` convergence at `75`).

### `G09` — `Raffle | requestDraw | uncompensated-vrf-fee-asymmetry` (`L11-5`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS`
  - `swap / buyEntries & requestDraw` (`Raffle.sol:209–273`): `ALLOWS` — `requestDraw` (`Raffle.sol:242`) only checks `if (totalEntries == 0) revert NoEntriesSold()`, allowing `requestDraw` even when `0 < totalEntries < reserveEntries`, and charges `msg.sender` `paidPrice` in native currency with no reimbursement.
  - `mint / fulfillRandomWords & _settleWinningTicket` (`Raffle.sol:509–558`): `ALLOWS` — when `totalEntries < reserveEntries`, calling `requestDraw` prevents 100% refund via `enableRefunds` (`Raffle.sol:285–288`) and forces `Status.CashWon`, deducting 15% for `sponsorProceeds` and 5% for `protocolFees`.
  - `burn / refundTickets` (`Raffle.sol:349–372`): `ALLOWS` — if VRF times out after `callbackDeadline()`, `enableRefunds` refunds USDC while the `requestDraw` caller loses 100% of `paidPrice`.
  - `liquidate / releaseSponsorProceeds & releaseSponsorPrize` (`Raffle.sol:375–407`): `ALLOWS`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**. `requestDraw` (`Raffle.sol:240–273`) allows draws when `totalEntries < reserveEntries` and provides no VRF fee reimbursement.
- **Gate 2 — Reachability**: **CLEARS**. Reachable whenever `0 < totalEntries < reserveEntries` at `endTime` (or when `totalEntries >= reserveEntries` and `requestDraw` must be funded).
- **Gate 3 — Trigger**: **CLEARS**. Unprivileged sponsor/caller triggers `requestDraw`.
- **Gate 4 — Impact**: **CONFIRMED**. Converts a 100% buyer refund outcome into `Status.CashWon` (15% sponsor rake + 5% protocol fee deducted from buyers while sponsor keeps the NFT) or causes the `requestDraw` caller to forfeit `paidPrice` uncompensated.
- **Confidence**: `100 - 15` (bounded non-compounding impact) `- 10` (requires specific state) = **`75`**.

---

### `G10` — `Raffle | _isProtocolDestination | future-clone-sink-bypass` (`L1-2`, `L3-5`, `L4-1`, `L5-1`, `L8-1`, `L9-1`, `L10-1`, `L12-1`; `[agents: 8]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS` — `_isProtocolDestination` (`Raffle.sol:593–605`) returns `false` for `nextRaffle = computeCreateAddress(factory, nonce)` before `createRaffle` deploys `nextRaffle`, because `nextRaffle.code.length == 0` (`Raffle.sol:602`).
  - `swap / buyEntries & _update` (`Raffle.sol:209–237,497–502`): `ALLOWS` — `_update` calls `_isProtocolDestination(to, address(prizeToken))` which returns `false` before `nextRaffle` is deployed.
  - `mint / _settleWinningTicket` (`Raffle.sol:533–558`): `BLOCKS` third-party contagion — `_settleWinningTicket` (`Raffle.sol:304,533–558`) is permissionless, does not read `ownerOf(ticketId)`, and allocates `sponsorProceeds`, `protocolFees`, and `winnerProceeds` into independent storage slots.
  - `burn / redeemWinningTicket & refundTickets` (`Raffle.sol:308–372`): `BLOCKS` third-party contagion — `refundTickets` (`Raffle.sol:349–372`) burns and refunds each caller's own tickets independently; only a ticket that a user voluntarily minted/transferred to `nextRaffle` cannot be redeemed or refunded.
  - `liquidate / releaseSponsorProceeds & releaseSponsorPrize` (`Raffle.sol:375–407`): `BLOCKS` third-party contagion — `releaseSponsorProceeds` and `releaseSponsorPrize` only affect `sponsorRecipient`, which was chosen by `sponsor`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)** for bypassing `_isProtocolDestination` at `initialize` / `_update`, but `_settleWinningTicket` (`Raffle.sol:533–558`) and `refundTickets` (`Raffle.sol:349–372`) isolate each party's claim (`BLOCKS` cross-user lock).
- **Gate 2 — Reachability**: **CLEARS**. Precomputed `CREATE` addresses of future `Clones.clone` calls have `code.length == 0` before deployment.
- **Gate 3 — Trigger**: **CLEARS**. Any caller can pass `nextRaffle` as their own `sponsorRecipient` or ticket `recipient`.
- **Gate 4 — Impact**: **DEMOTE TO LEAD**. Because `settleWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, and `refundTickets` isolate each claim, a caller passing `nextRaffle` only strands their own `sponsorRecipient` payout/prize or their own ticket claim (no third-party victim harm proven, as Agents 1, 3, 4, 8, 9, and 10 all noted). However, `_isProtocolDestination` has a concrete time-of-check vs time-of-use code smell and is omitted in `releaseSponsorPrize`.
- **Step 3 Lead Promotion Check**: Under `dedup-and-assembly.md` Step 3 (`[agents: 2+] does NOT override a code path that interrupts attack before harm — demote to LEAD if execution uncertain`), claim isolation in `_settleWinningTicket` and `refundTickets` interrupts third-party harm, so `G10` remains a **`LEAD`** (`L5-1` and `L12-1` demoted to `LEAD`).

### `G11` — `Raffle | requestDraw | premature-in-flight-flag-reset` (`L5-2`, `L12-6`; `[agents: 2]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `IRRELEVANT`
  - `swap / requestDraw & fulfillRandomWords` (`Raffle.sol:240–273,509–524`): `BLOCKS` — `requestDraw` sets `_requestInFlight = false` (`Raffle.sol:260`) before the low-level native refund call (`Raffle.sol:267`), and `rawFulfillRandomWords` lacks `nonReentrant`, but `rawFulfillRandomWords` enforces `if (msg.sender != address(i_vrfV2PlusWrapper)) revert OnlyVRFWrapperCanFulfill(...)` and the canonical Chainlink VRF v2.5 wrapper (`requestConfirmations = 30`) does not fulfill synchronously inside `refundRecipient`'s `receive()`.
  - `mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **DEMOTE TO LEAD** (`onlyVRFWrapper` guard and asynchronous VRF fulfillment prevent `msg.sender` from re-entering `rawFulfillRandomWords` during the native refund call).
- **Step 3 Lead Promotion Check**: Both raw items (`L5-2`, `L12-6`) were emitted as `LEAD`s and `onlyVRFWrapper` interrupts direct reentrancy during the refund call (`[agents: 2+] does NOT override a code path that interrupts attack before harm — demote to LEAD if execution uncertain`). Retained as **`LEAD`**.

### `G12` — `Raffle | requestDraw | single-shot-vrf-request` (`L3-7`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` / `setters`: `IRRELEVANT`
  - `swap / requestDraw & enableRefunds` (`Raffle.sol:240–273,289–291`): `ALLOWS` — `requestDraw` transitions `status` from `Status.Active` to `Status.Drawing` (`Raffle.sol:252`) with no retry function if the VRF wrapper fails to fulfill before `callbackDeadline()`, after which `enableRefunds()` transitions to `Status.Refunding` and the `requestDraw` caller loses `paidPrice`.
  - `mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**.
- **Gate 2 — Reachability**: **DEMOTE TO LEAD** — requires the external Chainlink VRF wrapper to miss `callbackDeadline()` (`2 days`), which an unprivileged attacker cannot force.
- **Step 3 Lead Promotion Check**: `[agents: 1]`, no unprivileged trigger to force wrapper timeout. Retained as **`LEAD`**.

### `G13` — `Raffle | releaseSponsorProceeds | immutable-recipient-usdc-blacklist` (`L3-6`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / initialize` (`Raffle.sol:176–206`): `ALLOWS` — sets `sponsorRecipient` and `protocolTreasury` once with no setter or fallback address.
  - `swap / mint / burn`: `IRRELEVANT`
  - `liquidate / releaseSponsorProceeds & releaseProtocolFees` (`Raffle.sol:375–392,564–567`): `ALLOWS` — calls `quoteToken.safeTransfer(to, amount)` which reverts forever if `quoteToken` (USDC) blacklists `sponsorRecipient` or `protocolTreasury`.
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**.
- **Gate 2 — Reachability**: **DEMOTE TO LEAD** (`Requires privileged actions outside normal operation → DEMOTE`: requires external USDC token issuer to blacklist `sponsorRecipient` or `protocolTreasury`).
- **Step 3 Lead Promotion Check**: `[agents: 1]`, requires external privileged blacklist action. Retained as **`LEAD`**.

### `G14` — `Raffle | fulfillRandomWords | synchronous-vrf-callback-ignored` (`L9-4`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` / `setters`: `IRRELEVANT`
  - `swap / requestDraw & fulfillRandomWords` (`Raffle.sol:254,509–516`): `BLOCKS` in production — `requestDraw` sets `_requestInFlight = true` (`Raffle.sol:254`) before `requestRandomnessPayInNative`, and `fulfillRandomWords` ignores any callback while `_requestInFlight` is `true` (`Raffle.sol:511`), which would leave `status == Status.Drawing` if a wrapper fulfilled synchronously during `requestRandomnessPayInNative`, but the canonical Chainlink VRF v2.5 wrapper fulfills asynchronously in a later block.
  - `mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)** for the code smell in `fulfillRandomWords` (`Raffle.sol:510–516`).
- **Gate 2 — Reachability**: **DEMOTE TO LEAD** — unreachable with the production asynchronous Chainlink VRF v2.5 wrapper (`requestConfirmations = 30`).
- **Step 3 Lead Promotion Check**: `[agents: 1]`, non-production wrapper precondition. Retained as **`LEAD`**.

### `G15` — `Raffle | getVrfRequestPrice | zero-gasprice-quote-mismatch` (`L10-2`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` / `setters`: `IRRELEVANT`
  - `swap / getVrfRequestPrice & requestDraw` (`Raffle.sol:436–438,249–250,441–443`): `BLOCKS` — `getVrfRequestPrice()` calls `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (`Raffle.sol:437`), which uses `tx.gasprice` (zero in an off-chain `eth_call` unless gas price is specified, positive on-chain in `requestDraw`), whereas `estimateVrfRequestPrice(requestGasPriceWei)` (`Raffle.sol:442`) accepts an explicit gas price.
  - `mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **DEMOTE TO LEAD** — `requestDraw` reverts atomically with `InsufficientVrfFee` (`Raffle.sol:250`) if `msg.value < quotedFee` and `estimateVrfRequestPrice` is available for off-chain estimation.
- **Step 3 Lead Promotion Check**: `[agents: 1]`, no on-chain fund loss. Retained as **`LEAD`**.

### `G16` — `Raffle | initialize | asymmetric-input-validation` (`L8-2`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`Raffle.sol:158–169`): `IRRELEVANT`
  - `setters / _validateCreateParams & initialize` (`RaffleFactory.sol:154–180`, `Raffle.sol:176–206`): `BLOCKS` — `Raffle.initialize` (`Raffle.sol:187–189`) calls `_isProtocolDestination(params.sponsor, params.prizeToken)` whereas `RaffleFactory._validateCreateParams` only screens `params.prizeToken` and `params.sponsorRecipient`, so `createRaffle` reverts in `initialize` if `msg.sender` (`sponsor`) is the `prizeToken` contract itself.
  - `swap / mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **DEMOTE TO LEAD** — `initialize` reverts atomically during `createRaffle` (`Raffle.sol:188`), causing no harm to active raffles.
- **Step 3 Lead Promotion Check**: `[agents: 1]`, no exploit path against active raffles. Retained as **`LEAD`**.

### `G17` — `RaffleFactory | constructor | future-clone-treasury-collision` (`L9-2`; `[agents: 1]`)
- **Single-pass path trace**:
  - `constructor` (`RaffleFactory.sol:65–92`): `ALLOWS` — checks `protocolTreasury_` against `address(this)`, `quoteToken_`, `vrfWrapper_`, and `raffleImplementation` (`RaffleFactory.sol:80,90`), but does not check future `CREATE` clone addresses of `RaffleFactory`.
  - `setters / createRaffle & initialize` (`RaffleFactory.sol:97–148`, `Raffle.sol:190–192`): `ALLOWS` — if `protocolTreasury_` equals a future clone address `computeCreateAddress(factory, nonce)`, once that clone is deployed and `isRaffle[protocolTreasury]` becomes `true`, `_isProtocolDestination(protocolTreasury, prizeToken)` returns `true`, causing subsequent `initialize` and `releaseProtocolFees` calls to revert.
  - `swap / mint / burn / liquidate`: `IRRELEVANT`
- **Gate 1 — Attack execution**: **CLEARS (`ALLOWS`)**.
- **Gate 2 — Reachability**: **DEMOTE TO LEAD** (`Requires privileged actions outside normal operation → DEMOTE`: requires deployer to pass a future factory `CREATE` address as `protocolTreasury_` at factory construction).
- **Step 3 Lead Promotion Check**: `[agents: 1]`, requires deployment-time configuration collision. Retained as **`LEAD`**.

---

## 4. Summary of Promotions, Demotions, and Rejections

| Action | Items | Details |
| --- | --- | --- |
| **Confirmed Findings (`9`)** | `G01` (`conf=90`), `G02` (`conf=90`), `G03` (`conf=90`), `G04` (`conf=90`), `G05` (`conf=85`), `G06` (`conf=85`), `G07` (`conf=75`), `G08` (`conf=75`), `G09` (`conf=75`) | Cleared all 4 sequential gates in `judging.md`. Raw leads `L1-1` (`G06`), `L4-2` (`G07`), `L9-3` (`G08`), and `L11-6` (`G01`) merged into their confirmed `group_key` findings (`G08` also satisfies `[agents: 2]` Multi-agent convergence at `conf=75`). |
| **Demoted to Lead (`1` group / `2` raw findings)** | `G10` (`L5-1`, `L12-1` merged with `L1-2`, `L3-5`, `L4-1`, `L8-1`, `L9-1`, `L10-1`; `[agents: 8]`) | Demoted at Gate 4 and kept as `LEAD` at Step 3 because `_settleWinningTicket` and `refundTickets` isolate each user's claim, preventing third-party fund loss while leaving a concrete time-of-check vs time-of-use code smell in `_isProtocolDestination` and `releaseSponsorPrize`. |
| **Retained Leads (`7` groups / `8` raw leads)** | `G11` (`L5-2`, `L12-6`), `G12` (`L3-7`), `G13` (`L3-6`), `G14` (`L9-4`), `G15` (`L10-2`), `G16` (`L8-2`), `G17` (`L9-2`) | Concrete code smells where an external/deployment precondition or guard prevents a complete unprivileged exploit path in one pass; preserved under `## Leads` in `run-1.md`. |
| **Rejected Leads / Findings (`0` tuples dropped)** | `0` | Zero `(Contract, function)` tuples dropped (`Completeness: 13 unique (Contract, function) in raw, 13 covered in final`). |

---

## 5. Turn 4 Step 5a — Report Language (ASD-STE100) Verification

Every Finding title (≤ 12 words, 1 clause, active, present tense), Finding Description (1 sentence, ≤ 25 words, active, present tense, no `-ing` clause, names actor and effect), Lead title (≤ 12 words), Lead code smells (≤ 25 words/sentence, no `-ing` clause), and Lead description (1–2 sentences, ≤ 25 words/sentence, no `-ing` clause) was verified against `references/report-language.md`:

| ID | Kind | Title Word Count | Description Word Count (per sentence) | STE Self-Check (Actor+Effect / ≤25w & no `-ing` / Plain words / Identifiers+Label+Diff intact) |
| --- | --- | --- | --- | --- |
| `G01` | `FINDING` (`90`) | 9 words | 20 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G02` | `FINDING` (`90`) | 9 words | 21 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G03` | `FINDING` (`90`) | 12 words | 21 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G04` | `FINDING` (`90`) | 10 words | 24 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G05` | `FINDING` (`85`) | 8 words | 23 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G06` | `FINDING` (`85`) | 7 words | 22 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G07` | `FINDING` (`75`) | 10 words | 24 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G08` | `FINDING` (`75`) | 11 words | 20 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G09` | `FINDING` (`75`) | 11 words | 24 words (1 sentence) | Yes / Yes / Yes / Yes |
| `G10` | `LEAD` | 8 words | Smells: 13w · Desc: 17w, 10w (2 sentences) | Yes / Yes / Yes / Yes |
| `G11` | `LEAD` | 8 words | Smells: 19w · Desc: 18w, 6w (2 sentences) | Yes / Yes / Yes / Yes |
| `G12` | `LEAD` | 10 words | Smells: 21w · Desc: 15w, 13w (2 sentences) | Yes / Yes / Yes / Yes |
| `G13` | `LEAD` | 8 words | Smells: 14w · Desc: 15w, 10w (2 sentences) | Yes / Yes / Yes / Yes |
| `G14` | `LEAD` | 9 words | Smells: 18w · Desc: 13w, 9w (2 sentences) | Yes / Yes / Yes / Yes |
| `G15` | `LEAD` | 9 words | Smells: 17w · Desc: 20w, 6w (2 sentences) | Yes / Yes / Yes / Yes |
| `G16` | `LEAD` | 7 words | Smells: 13w · Desc: 14w, 10w (2 sentences) | Yes / Yes / Yes / Yes |
| `G17` | `LEAD` | 10 words | Smells: 19w · Desc: 20w, 6w (2 sentences) | Yes / Yes / Yes / Yes |


---

## 6. Turn 5 Native Assembly & Verification Record

- **Step 1 (Memory copy)**: Skipped (`memory = off`).
- **Step 2 (Native Assembler Execution)**:
  - **Executed command**: `bash .agents/skills/solidity-auditor/references/assemble.sh --dir .solidity-auditor/runs/2026-10-21-explicit-high-a04`
  - **Exit status**: `0`
  - **Stdout**: `assembled .solidity-auditor/runs/2026-10-21-explicit-high-a04/full-report.md — 9 findings, 8 leads, 1 run files`
  - **Stderr**: *(empty)*
  - **Assembled file SHA-256 (`.solidity-auditor/runs/2026-10-21-explicit-high-a04/full-report.md`)**: `8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802`
- **Step 3 (Count & Self-Check)**:
  - **Executed command**:
    ```bash
    awk '
    /^## Leads$/  { sec="leads"; next }
    /^## /        { sec="";      next }
    /^\[[0-9]+\]/ { F++; next }
    sec=="leads" && /^- \*\*/ { L++ }
    /Confidence: [0-9]+/ && /^`/ {
      match($0, /Confidence: [0-9]+/)
      c = substr($0, RSTART+12, RLENGTH-12) + 0
      if (c >= 90) A++; else if (c >= 75) B++; else C++
    }
    END { printf "%d %d %d %d %d\n", F, L, A, B, C }
    ' .solidity-auditor/runs/2026-10-21-explicit-high-a04/full-report.md
    ```
  - **Stdout**: `9 8 4 5 0` (`F=9`, `L=8`, `A=4`, `B=5`, `C=0`)
  - **Self-Check**: `A + B + C = 4 + 5 + 0 = 9 == F` (PASS).
  - **Branch Selected**: `F = 9 <= 20` (Step 3a — print `full-report.md` word-for-word).
- **Step 4 (`--file-output` Copy)**:
  - **Executed command**: `cp .solidity-auditor/runs/2026-10-21-explicit-high-a04/full-report.md "raffle-fun-pashov-ai-audit-report-2026-10-21-explicit-high-a04.md"`
  - **Copied file SHA-256 (`raffle-fun-pashov-ai-audit-report-2026-10-21-explicit-high-a04.md`)**: `8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802`
- **Step 5 (Auto-Clean)**:
  - **Command**: `rm -rf .audit-judge-inputs`
