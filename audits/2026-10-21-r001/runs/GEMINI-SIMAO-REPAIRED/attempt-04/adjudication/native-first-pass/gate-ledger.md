# SIMAO Turn 6 Adjudication & Gate Ledger — `raffle-fun`

## 1. Input Binding & Scope Verification

- **Binding Receipt**: `.native-leaf-results/binding.json` (`attempt: 4`, `leafCount: 12`, `verifiedCompleteCount: 12`). Historical transport metadata in `binding.json` is preserved unchanged (`leaf-03` and `leaf-06` record historical `rawTransportStatus: "ERROR"` with `rawTransportError: "Idle timeout: no output for 180s"` alongside `nativeMethodCompleted: true`).
- **Accepted Specialist Inputs**: `.native-leaf-results/leaf-01.md` through `.native-leaf-results/leaf-12.md` (40 raw `FINDING` and `LEAD` blocks total: 7 raw `FINDING` blocks and 33 raw `LEAD` blocks).
- **In-Scope Physical Source Files (`5 files, 2 contracts`)**:
  - `packages/contracts/src/Raffle.sol` (614 lines; offset `-13` lines relative to `.audit-judge-inputs/source.md` lines `14..627`)
  - `packages/contracts/src/RaffleFactory.sol` (186 lines; offset `-633` lines relative to `.audit-judge-inputs/source.md` lines `634..819`)
  - `packages/contracts/src/libraries/RaffleConstants.sol` (22 lines; `.audit-judge-inputs/source.md` lines `826..847`)
  - `packages/contracts/src/interfaces/IRaffle.sol` (212 lines; `.audit-judge-inputs/source.md` lines `854..1065`)
  - `packages/contracts/src/interfaces/IRaffleFactory.sol` (65 lines; `.audit-judge-inputs/source.md` lines `1072..1136`)

---

## 2. Complete Raw Observation Inventory (40 Raw Items Across 12 Leaves)

| Raw ID | Leaf File & Line | Type | Raw `group_key` (`Contract \| function \| bug-class`) | Raw Anchor(s) | Resolved Physical Anchor(s) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `L01-LEAD-1` | `leaf-01.md:155` | `LEAD` | `Raffle \| _isProtocolDestination \| accounting-desync` | `Raffle.sol:615-617` | `packages/contracts/src/Raffle.sol:602-604` |
| `L01-LEAD-2` | `leaf-01.md:162` | `LEAD` | `Raffle \| releaseSponsorPrize \| missing-check` | `Raffle.sol:408-420`, `578` | `packages/contracts/src/Raffle.sol:395-407`, `565` |
| `L02-FINDING-1` | `leaf-02.md:199` | `FINDING` | `Raffle \| releaseSponsorProceeds \| decoupled-settlement-claim` | `Raffle.sol:543-544,551-555`, `375-382`, `385-392`, `334-337`, `293` | `packages/contracts/src/Raffle.sol:543-544,551-555`, `375-382`, `385-392`, `334-337`, `293` |
| `L02-LEAD-1` | `leaf-02.md:214` | `LEAD` | `Raffle \| _isProtocolDestination \| precomputed-clone-destination-bypass` | `Raffle.sol:602-604`, `404`, `334`; `RaffleFactory.sol:106` | `packages/contracts/src/Raffle.sol:602-604`, `404`, `334`; `packages/contracts/src/RaffleFactory.sol:106` |
| `L02-LEAD-2` | `leaf-02.md:221` | `LEAD` | `Raffle \| redeemWinningTicket \| unsafe-erc721-prize-transfer` | `Raffle.sol:334`, `404`, `235` | `packages/contracts/src/Raffle.sol:334`, `404`, `235` |
| `L02-LEAD-3` | `leaf-02.md:228` | `LEAD` | `Raffle \| requestDraw \| vrf-gas-price-griefing` | `Raffle.sol:240-260` | `packages/contracts/src/Raffle.sol:240-260` |
| `L03-FINDING-1` | `leaf-03.md:155` | `FINDING` | `Raffle \| buyEntries \| cohort-dilution` | `Raffle.sol:209-237`, `544` | `packages/contracts/src/Raffle.sol:209-237`, `544` |
| `L03-FINDING-2` | `leaf-03.md:168` | `FINDING` | `Raffle \| _isProtocolDestination \| time-dependent-validation-bypass` | `Raffle.sol:602-604`, `404`, `334`, `565`; `RaffleFactory.sol:159,166` | `packages/contracts/src/Raffle.sol:602-604`, `404`, `334`, `565`; `packages/contracts/src/RaffleFactory.sol:159,166` |
| `L03-LEAD-1` | `leaf-03.md:181` | `LEAD` | `Raffle \| requestDraw \| single-buyer-cash-tax` | `Raffle.sol:243`; `RaffleFactory.sol:178` | `packages/contracts/src/Raffle.sol:243`; `packages/contracts/src/RaffleFactory.sol:178` |
| `L03-LEAD-2` | `leaf-03.md:188` | `LEAD` | `Raffle \| releaseSponsorProceeds \| unverified-prize-delivery-payout` | `Raffle.sol:375-382`, `543-555` | `packages/contracts/src/Raffle.sol:375-382`, `543-555` |
| `L04-LEAD-1` | `leaf-04.md:175` | `LEAD` | `Raffle \| _settleWinningTicket \| decoupled-settlement-solvency` | `Raffle.sol:556-568`, `388-395`, `347-350` | `packages/contracts/src/Raffle.sol:543-555`, `375-382`, `334-337` |
| `L04-LEAD-2` | `leaf-04.md:182` | `LEAD` | `Raffle \| _isProtocolDestination \| precomputed-clone-destination-bypass` | `Raffle.sol:615-617`, `417`; `RaffleFactory.sol:739-758` | `packages/contracts/src/Raffle.sol:602-604`, `404`; `packages/contracts/src/RaffleFactory.sol:106-125` |
| `L05-LEAD-1` | `leaf-05.md:153` | `LEAD` | `Raffle \| _isProtocolDestination \| deterministic-clone-destination-bypass` | `Raffle.sol:615`, `417`; `RaffleFactory.sol:713,739,792-799` | `packages/contracts/src/Raffle.sol:602`, `404`; `packages/contracts/src/RaffleFactory.sol:80,106,159-166` |
| `L05-LEAD-2` | `leaf-05.md:160` | `LEAD` | `Raffle \| _settleWinningTicket \| decoupled-escrow-settlement-without-prize-delivery` | `Raffle.sol:556-569`, `388-395`, `347` | `packages/contracts/src/Raffle.sol:543-556`, `375-382`, `334` |
| `L05-LEAD-3` | `leaf-05.md:167` | `LEAD` | `Raffle \| requestDraw \| single-shot-vrf-request-gas-pricing` | `Raffle.sol:265-270` | `packages/contracts/src/Raffle.sol:252-257` |
| `L05-LEAD-4` | `leaf-05.md:174` | `LEAD` | `RaffleFactory \| createRaffle \| callback-activation-before-creation-complete` | `RaffleFactory.sol:761`; `Raffle.sol:441` | `packages/contracts/src/RaffleFactory.sol:128`; `packages/contracts/src/Raffle.sol:428` |
| `L06-LEAD-1` | `leaf-06.md:163` | `LEAD` | `RaffleFactory \| createRaffle \| precision-and-scale` | `RaffleFactory.sol:811`; `Raffle.sol:534` | `packages/contracts/src/RaffleFactory.sol:178`; `packages/contracts/src/Raffle.sol:521` |
| `L07-FINDING-1` | `leaf-07.md:178` | `FINDING` | `Raffle \| enableRefunds \| front-running-griefing` | `Raffle.sol:280`, `209`, `230`, `285-287` | `packages/contracts/src/Raffle.sol:280`, `209`, `230`, `285-287` |
| `L07-FINDING-2` | `leaf-07.md:193` | `FINDING` | `Raffle \| _settleWinningTicket \| discrete-threshold-arbitrage` | `Raffle.sol:521`, `543-549`, `209` | `packages/contracts/src/Raffle.sol:521`, `543-549`, `209` |
| `L07-LEAD-1` | `leaf-07.md:208` | `LEAD` | `Raffle \| buyEntries \| missing-slippage-protection` | `Raffle.sol:209` | `packages/contracts/src/Raffle.sol:209` |
| `L07-LEAD-2` | `leaf-07.md:215` | `LEAD` | `Raffle \| releaseSponsorPrize \| inconsistent-destination-validation` | `Raffle.sol:404`, `565` | `packages/contracts/src/Raffle.sol:404`, `565` |
| `L07-LEAD-3` | `leaf-07.md:222` | `LEAD` | `Raffle \| requestDraw \| single-participant-draw-griefing` | `Raffle.sol:243` | `packages/contracts/src/Raffle.sol:243` |
| `L08-LEAD-1` | `leaf-08.md:205` | `LEAD` | `Raffle \| _isProtocolDestination \| precomputed-clone-destination-dos` | `Raffle.sol:615-617`, `408-420`, `578`; `RaffleFactory.sol:739,792,800` | `packages/contracts/src/Raffle.sol:602-604`, `395-407`, `565`; `packages/contracts/src/RaffleFactory.sol:106,159,167` |
| `L08-LEAD-2` | `leaf-08.md:212` | `LEAD` | `Raffle \| enableRefunds \| empty-raffle-cancellation-griefing` | `Raffle.sol:293-297`, `222` | `packages/contracts/src/Raffle.sol:280-284`, `209` |
| `L08-LEAD-3` | `leaf-08.md:219` | `LEAD` | `Raffle \| redeemWinningTicket \| untrusted-prize-token-settlement-asymmetry` | `Raffle.sol:546-571`, `388-395`, `347-350` | `packages/contracts/src/Raffle.sol:533-558`, `375-382`, `334-337` |
| `L08-LEAD-4` | `leaf-08.md:226` | `LEAD` | `Raffle \| requestDraw \| uncompensated-single-shot-vrf-request` | `Raffle.sol:253-286`, `449-451` | `packages/contracts/src/Raffle.sol:240-273`, `436-438` |
| `L09-FINDING-1` | `leaf-09.md:156` | `FINDING` | `Raffle \| releaseSponsorProceeds \| trust-boundary-violation` | `Raffle.sol:388`, `546`, `347`, `398` | `packages/contracts/src/Raffle.sol:375`, `533`, `334`, `385` |
| `L09-LEAD-1` | `leaf-09.md:171` | `LEAD` | `Raffle \| _isProtocolDestination \| access-control-bypass` | `Raffle.sol:615`, `417`; `RaffleFactory.sol:739` | `packages/contracts/src/Raffle.sol:602`, `404`; `packages/contracts/src/RaffleFactory.sol:106` |
| `L09-LEAD-2` | `leaf-09.md:178` | `LEAD` | `Raffle \| onERC721Received \| reentrancy` | `Raffle.sol:429`; `RaffleFactory.sol:761` | `packages/contracts/src/Raffle.sol:416`; `packages/contracts/src/RaffleFactory.sol:128` |
| `L10-FINDING-1` | `leaf-10.md:162` | `FINDING` | `Raffle \| releaseSponsorProceeds \| external-integration-untrusted-prize-token` | `Raffle.sol:375`, `543-554`, `334-336` | `packages/contracts/src/Raffle.sol:375`, `543-554`, `334-336` |
| `L10-LEAD-1` | `leaf-10.md:178` | `LEAD` | `Raffle \| releaseSponsorProceeds \| token-blacklist-immutable-recipient` | `Raffle.sol:375`, `385` | `packages/contracts/src/Raffle.sol:375`, `385` |
| `L10-LEAD-2` | `leaf-10.md:185` | `LEAD` | `Raffle \| _isProtocolDestination \| precomputed-clone-destination-bypass` | `Raffle.sol:602`, `395`; `RaffleFactory.sol:163,106` | `packages/contracts/src/Raffle.sol:602`, `395`; `packages/contracts/src/RaffleFactory.sol:163,106` |
| `L10-LEAD-3` | `leaf-10.md:192` | `LEAD` | `Raffle \| requestDraw \| vrf-requester-unreimbursed-fee-loss` | `Raffle.sol:240-273` | `packages/contracts/src/Raffle.sol:240-273` |
| `L11-LEAD-1` | `leaf-11.md:149` | `LEAD` | `Raffle \| _isProtocolDestination \| mid-flight-state-drift` | `Raffle.sol:606-618`, `408-420`; `RaffleFactory.sol:790-802` | `packages/contracts/src/Raffle.sol:593-605`, `395-407`; `packages/contracts/src/RaffleFactory.sol:157-169` |
| `L11-LEAD-2` | `leaf-11.md:156` | `LEAD` | `Raffle \| fulfillRandomWords \| threshold-boundary-cliff` | `Raffle.sol:534`, `556-562` | `packages/contracts/src/Raffle.sol:521`, `543-549` |
| `L11-LEAD-3` | `leaf-11.md:163` | `LEAD` | `RaffleFactory \| _validateCreateParams \| unbounded-threshold-parameter` | `RaffleFactory.sol:811`; `Raffle.sol:534` | `packages/contracts/src/RaffleFactory.sol:178`; `packages/contracts/src/Raffle.sol:521` |
| `L11-LEAD-4` | `leaf-11.md:170` | `LEAD` | `Raffle \| releaseSponsorProceeds \| terminal-state-blacklisted-recipient` | `Raffle.sol:211-212`, `388`, `398`, `408` | `packages/contracts/src/Raffle.sol:198-199`, `375`, `385`, `395` |
| `L12-LEAD-1` | `leaf-12.md:110` | `LEAD` | `Raffle \| _isProtocolDestination \| precomputed-clone-destination-asymmetry` | `Raffle.sol:615-617`, `347`, `417`, `578`; `RaffleFactory.sol:739` | `packages/contracts/src/Raffle.sol:602-604`, `334`, `404`, `565`; `packages/contracts/src/RaffleFactory.sol:106` |
| `L12-LEAD-2` | `leaf-12.md:117` | `LEAD` | `Raffle \| onERC721Received \| mid-creation-reentrancy-asymmetry` | `Raffle.sol:429-444`, `441`; `RaffleFactory.sol:761,769` | `packages/contracts/src/Raffle.sol:416-431`, `428`; `packages/contracts/src/RaffleFactory.sol:128,136` |
| `L12-LEAD-3` | `leaf-12.md:124` | `LEAD` | `RaffleFactory \| _validateCreateParams \| treasury-prize-validation-asymmetry` | `RaffleFactory.sol:790-794`; `Raffle.sol:203` | `packages/contracts/src/RaffleFactory.sol:157-161`; `packages/contracts/src/Raffle.sol:190` |

---

## 3. Unique `(Contract, function)` Completeness Table (12 Unique Tuples)

Every unique `(Contract, function)` appearing in any raw `FINDING` or `LEAD` is isolated below (HARD function isolation — zero merges across different `function:` fields):

1. `Raffle | releaseSponsorProceeds` — 6 raw items (`L02-FINDING-1`, `L03-LEAD-2`, `L09-FINDING-1`, `L10-FINDING-1`, `L10-LEAD-1`, `L11-LEAD-4`) → Covered in final report (`M-1` + `## Unverified leads`).
2. `Raffle | _settleWinningTicket` — 3 raw items (`L07-FINDING-2`, `L04-LEAD-1`, `L05-LEAD-2`) → Covered in final report (`M-2` + `## Unverified leads`).
3. `Raffle | buyEntries` — 2 raw items (`L03-FINDING-1`, `L07-LEAD-1`) → Covered in final report (`M-3` + `## Unverified leads`).
4. `Raffle | enableRefunds` — 2 raw items (`L07-FINDING-1`, `L08-LEAD-2`) → Covered in final report (`L-1` + `## Unverified leads`).
5. `Raffle | requestDraw` — 6 raw items (`L02-LEAD-3`, `L05-LEAD-3`, `L08-LEAD-4`, `L10-LEAD-3`, `L03-LEAD-1`, `L07-LEAD-3`) → Covered in final report (`L-2` + `## Unverified leads`).
6. `Raffle | _isProtocolDestination` — 10 raw items (`L01-LEAD-1`, `L02-LEAD-1`, `L03-FINDING-2`, `L04-LEAD-2`, `L05-LEAD-1`, `L08-LEAD-1`, `L09-LEAD-1`, `L10-LEAD-2`, `L11-LEAD-1`, `L12-LEAD-1`) → Covered in final report (`I-1` + `## Unverified leads`).
7. `Raffle | releaseSponsorPrize` — 2 raw items (`L01-LEAD-2`, `L07-LEAD-2`) → Covered in final report (`I-2` + `## Unverified leads`).
8. `Raffle | redeemWinningTicket` — 2 raw items (`L02-LEAD-2`, `L08-LEAD-3`) → Covered in final report (`I-3` + `## Unverified leads`).
9. `Raffle | fulfillRandomWords` — 1 raw item (`L11-LEAD-2`) → Covered in final report (`I-4` + `## Unverified leads`).
10. `Raffle | onERC721Received` — 2 raw items (`L09-LEAD-2`, `L12-LEAD-2`) → Covered in final report (`I-5` + `## Unverified leads`).
11. `RaffleFactory | createRaffle` — 2 raw items (`L05-LEAD-4`, `L06-LEAD-1`) → Covered in final report (`I-6` + `## Unverified leads`).
12. `RaffleFactory | _validateCreateParams` — 2 raw items (`L11-LEAD-3`, `L12-LEAD-3`) → Covered in final report (`I-7` + `## Unverified leads`).

---

## 4. Deduplication, Mechanism/Mitigation Preservation & Single-Pass Gate Verdicts

### Group 1 — `Raffle | releaseSponsorProceeds` (`[lenses: 5]` across 2 sub-groups; `M-1` + Unverified Lead)

- **Merged Members**:
  - **Sub-group 1A (`Raffle | releaseSponsorProceeds | decoupled-settlement-claim`, `[lenses: 4]`)**: `L02-FINDING-1`, `L03-LEAD-2`, `L09-FINDING-1`, `L10-FINDING-1`.
  - **Sub-group 1B (`Raffle | releaseSponsorProceeds | token-blacklist-immutable-recipient`, `[lenses: 2]`)**: `L10-LEAD-1`, `L11-LEAD-4`.
- **Distinct Mechanisms Preserved**:
  - **Mechanism 1A-i (Untrusted ERC-721 `prizeToken` blocking winner redemption)**: Under `DESIGN.md` (`"arbitrary prize contracts and ticket recipients are untrusted"`), `RaffleFactory::createRaffle` (`RaffleFactory.sol:128-130, 171-177`) is permissionless and checks only `IERC165.supportsInterface(0x80ac58cd)` and initial `ownerOf(prizeTokenId) == raffle`. In `Status.NftWon`, `_settleWinningTicket` (`Raffle.sol:543-555`), `releaseSponsorProceeds` (`Raffle.sol:375-382`), and `releaseProtocolFees` (`Raffle.sol:385-392`) credit and release 95% of `unsettledPot` to `sponsorRecipient` and 5% to `protocolTreasury` without requiring `prizeClaimed == true`. When `redeemWinningTicket` (`Raffle.sol:334-337`) reverts on `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` or fails `ownerOf(deliveredPrizeTokenId) != winner`, the winner cannot claim the NFT and `enableRefunds` (`Raffle.sol:279-293`) reverts with `InvalidStatus(Status.NftWon)`.
  - **Mechanism 1A-ii (Stateful / expiring / pausable / transfer-restricted ERC-721 `prizeToken` during the up-to-34-day escrow window)**: Even for honest mainnet ERC-721 contracts — such as an ENS `.eth` domain on `BaseRegistrarImplementation` (`0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85`) whose `expiries[tokenId]` lapses during the up-to-30-day sale + 4-day draw window, an `ERC721Pausable` collection that pauses, or an `ERC721C` (`CreatorTokenTransferValidator` at `0x721C0078c2328597Ca70F5451ffF5A7B38D4E947`) token whose security policy restricts contract senders — `redeemWinningTicket` permanently reverts at `Raffle.sol:334` while `releaseSponsorProceeds` still transfers 95% of the USDC pot to `sponsorRecipient`.
  - **Mechanism 1B (Immutable `sponsorRecipient` / `protocolTreasury` blacklisted by Circle USDC `FiatTokenV2_2`)**: Unlike ERC-721 tickets (which remain transferable via `Raffle::_update` in terminal states so a blacklisted winner/buyer can transfer the ticket before claiming), `sponsorRecipient` and `protocolTreasury` are immutable (`Raffle.sol:124-125, 198-199`) with no fallback recipient in `releaseSponsorProceeds` (`Raffle.sol:375`), `releaseProtocolFees` (`Raffle.sol:385`), or `releaseSponsorPrize` (`Raffle.sol:395`). If Circle blacklists `sponsorRecipient` or `protocolTreasury` on `FiatTokenV2_2`, that cohort's own pull payout reverts without affecting ticket holders.
- **Distinct Raw Mitigations Preserved Verbatim**:
  - **Option A (`validate` — `L02-FINDING-1`, `leaf-02.md:210`)**:
    > In Status.NftWon, require `prizeClaimed == true` before `releaseSponsorProceeds` (`packages/contracts/src/Raffle.sol:375`) and `releaseProtocolFees` (`packages/contracts/src/Raffle.sol:385`) can transfer quote tokens, and allow transitioning from `Status.NftWon` to `Status.Refunding` if the winning ticket is not or cannot be redeemed within a bounded redemption window.
  - **Option B (`validate` — `L09-FINDING-1`, `leaf-09.md:167`)**:
    > In Raffle.sol:388 (releaseSponsorProceeds) and Raffle.sol:398 (releaseProtocolFees), when status == Status.NftWon, require prizeClaimed == true before releasing sponsorProceeds and protocolFees, and allow transitioning from Status.NftWon to Status.Refunding if prizeClaimed remains false after a redemption/delivery deadline
  - **Option C (`validate` — `L10-FINDING-1`, `leaf-10.md:174`)**:
    > In Raffle::releaseSponsorProceeds (Raffle.sol:375), require `if (status == Status.NftWon && !prizeClaimed) revert PrizeNotDelivered();` so sponsor proceeds in Status.NftWon cannot be withdrawn until the prize NFT has been verified as delivered to the winner (and allow transitioning from unredeemed Status.NftWon to Status.Refunding after a redemption liveness window if prizeToken delivery fails).
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:171-177`) checks only `supportsInterface(type(IERC721).interfaceId)` and `Raffle::initialize` (`Raffle.sol:176-206`) accepts any ERC-721 address.
  - `setters`: `IRRELEVANT` — No admin or parameter setters exist.
  - `deposit`: `ALLOWS` — `RaffleFactory::createRaffle` (`RaffleFactory.sol:128-130`) verifies `prize.ownerOf(params.prizeTokenId) == raffle` only at `t0`, and `Raffle::buyEntries` (`Raffle.sol:209-237`) escrows buyer USDC in `unsettledPot`.
  - `accrue`: `ALLOWS` — `Raffle::fulfillRandomWords` (`Raffle.sol:521`) sets `status = Status.NftWon` when `totalEntries >= reserveEntries`, and `Raffle::_settleWinningTicket` (`Raffle.sol:533-558`) moves 95% of `unsettledPot` to `sponsorProceeds` and 5% to `protocolFees` without touching `prizeToken`.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `ALLOWS` — `Raffle::enableRefunds` (`Raffle.sol:279-293`) reverts with `InvalidStatus(Status.NftWon)` once `Status.NftWon` is reached.
  - `withdraw`: `ALLOWS` — `Raffle::releaseSponsorProceeds` (`Raffle.sol:375-382`) transfers `sponsorProceeds` to `sponsorRecipient` without checking `prizeClaimed`, while `Raffle::redeemWinningTicket` (`Raffle.sol:334-337`) reverts when `prizeToken.transferFrom` reverts or fails `ownerOf(deliveredPrizeTokenId) == winner`.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — `settleWinningTicket` (`Raffle.sol:304`) and `releaseSponsorProceeds` (`Raffle.sol:375`) are completely decoupled from `redeemWinningTicket` (`Raffle.sol:309`).
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — Under `DESIGN.md`'s untrusted prize boundary, a sponsor can deploy a reverting/conditional ERC-721 at zero cost; under `IRaffle.sol`'s honest ERC-721 boundary, stateful ERC-721s (ENS `.eth` expiry, `ERC721Pausable`, `ERC721C` validator updates) can become untransferable during the up-to-34-day escrow window.
  - **Gate 3 (Harm to someone other than attacker)**: `ALLOWS` — Ticket buyers and the winning ticket holder lose 100% of the USDC pot while receiving neither the NFT nor a refund (for Mechanism 1B, `BLOCKS` cross-cohort harm because Circle blacklisting `sponsorRecipient` only affects `sponsorRecipient`'s own pull claim; kept as an unverified lead).
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` — 100% of buyers' USDC pot is lost (`95%` to `sponsorRecipient`, `5%` to `protocolTreasury`) with no NFT delivered.
- **Verdict & Severity**: Confirmed `FINDING` (`L03-LEAD-2` promoted and merged into `M-1`; `L10-LEAD-1`/`L11-LEAD-4` preserved in `M-1` notes and `## Unverified leads`). Rated **Medium (`M-1`)** per `severity-calibration.md` line 66 ("When genuinely torn between two severities, choose the lower and say why in one line"): while `DESIGN.md:5` treats arbitrary `prizeToken` contracts as untrusted (which would make this High), `IRaffle.sol:202` scopes supported prizes to honest, standards-compliant ERC-721s, under which the bug requires a stateful external token condition (such as ENS registration expiry or collection pause during escrow).

---

### Group 2 — `Raffle | _settleWinningTicket` (`[lenses: 3]` across 2 mechanisms; `M-2` + Unverified Lead)

- **Merged Members**:
  - **Mechanism 2A (`Raffle | _settleWinningTicket | discrete-threshold-arbitrage`, `[lenses: 1]`)**: `L07-FINDING-2` (`leaf-07.md:193-205`).
  - **Mechanism 2B (`Raffle | _settleWinningTicket | decoupled-settlement-solvency`, `[lenses: 2]`)**: `L04-LEAD-1` (`leaf-04.md:175-179`), `L05-LEAD-2` (`leaf-05.md:160-164`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 2A (Discrete 80% pot cliff at `totalEntries >= reserveEntries`)**: In `Raffle::_settleWinningTicket` (`Raffle.sol:543-549`) and `Raffle::fulfillRandomWords` (`Raffle.sol:521`), crossing `totalEntries >= reserveEntries` discontinuously jumps the sponsor's share of `unsettledPot` from `15%` (`Status.CashWon`, where the winning ticket receives `80%` cash) to `95%` (`Status.NftWon`, where the winning ticket receives the NFT and `0%` cash). Because `Raffle::buyEntries` (`Raffle.sol:209`) permits the sponsor (or any sybil) to purchase the remaining `reserveEntries - totalEntries` entries right before `endTime` at a net marginal cost of only `5%` (`$0.05`/entry, since `95%` of the top-up returns to `sponsorRecipient`), whenever `0.80 * organicPot > fairValue(NFT) + 0.05 * topUpCost`, the sponsor can top up the raffle to `reserveEntries`, extracting an extra `80%` of all prior buyers' USDC plus a `(reserveEntries - organicEntries) / reserveEntries` chance of winning their own NFT back.
  - **Mechanism 2B (Unconditional crediting of `sponsorProceeds` in `_settleWinningTicket` without prize delivery verification)**: In `Raffle::_settleWinningTicket` (`Raffle.sol:543-555`), `unsettledPot` is zeroed and `95%` is credited to `sponsorProceeds` in `Status.NftWon` before `redeemWinningTicket` (`Raffle.sol:334-337`) verifies that `prizeTokenId` can be transferred to `winner`.
- **Raw Mitigation Preserved (`L07-FINDING-2`, `leaf-07.md:204`)**:
  > In Status.CashWon or when totalEntries < reserveEntries, either refund 100% of unsettledPot to ticket holders on missed reserve (eliminating the 15%/80% CashWon cliff) or cap sponsorProceeds at reserveEntries * ENTRY_PRICE * 95% with excess routing to the winner/protocol.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `Raffle::initialize` (`Raffle.sol:176-206`) stores `reserveEntries` and `sponsorRecipient` without restricting sponsor entry purchases.
  - `setters`: `IRRELEVANT` — No setters exist.
  - `deposit`: `ALLOWS` — `Raffle::buyEntries` (`Raffle.sol:209-237`) permits the sponsor or any EOA to buy `reserveEntries - totalEntries` entries up to `endTime - 1`.
  - `accrue`: `ALLOWS` — `Raffle::fulfillRandomWords` (`Raffle.sol:521`) selects `Status.NftWon` at `totalEntries >= reserveEntries`, and `Raffle::_settleWinningTicket` (`Raffle.sol:543-549`) shifts the sponsor share from `15%` to `95%` across the entire `grossPot`.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `IRRELEVANT` — No liquidation path exists.
  - `withdraw`: `ALLOWS` — `Raffle::releaseSponsorProceeds` (`Raffle.sol:375-382`) transfers the 95% `sponsorProceeds` to `sponsorRecipient`.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — No check prevents the sponsor from buying the remaining `reserveEntries - totalEntries` entries right before `endTime`.
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — Reachable whenever `0 < totalEntries < reserveEntries` near `endTime` and `fairValue(NFT) < 0.80 * organicPot - 0.05 * topUpCost`; 95% of the top-up capital is immediately returned on settlement.
  - **Gate 3 (Harm to someone other than attacker)**: `ALLOWS` — Honest organic ticket buyers lose the 80% cash prize pool and have their winning odds diluted.
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` — Direct reallocation of 80% of prior buyers' cash pot to `sponsorRecipient`.
- **Verdict & Severity**: Confirmed `FINDING`, rated **Medium (`M-2`)** (value misallocated between cohorts under a specific state `0 < totalEntries < reserveEntries` where the NFT value is below the 80% cash prize). Also forms composite chain `Chain: [M-2] + [M-1]` when combined with `M-1`.

---

### Group 3 — `Raffle | buyEntries` (`[lenses: 2]` across 2 mechanisms; `M-3` + Unverified Lead)

- **Merged Members**:
  - **Mechanism 3A (`Raffle | buyEntries | cohort-dilution`, `[lenses: 1]`)**: `L03-FINDING-1` (`leaf-03.md:155-164`).
  - **Mechanism 3B (`Raffle | buyEntries | missing-slippage-protection`, `[lenses: 1]`)**: `L07-LEAD-1` (`leaf-07.md:208-212`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 3A (Uncapped post-reserve entry dilution by sponsor via 95% rebate)**: In `Raffle::buyEntries` (`Raffle.sol:209-237`), `totalEntries` has no maximum cap (beyond `type(uint128).max`), and neither `sponsor` nor `sponsorRecipient` is prevented from purchasing entries. Because `_settleWinningTicket` (`Raffle.sol:544`) returns 95% of all `grossPot` proceeds to `sponsorRecipient` in `Status.NftWon`, each additional entry bought by the sponsor after `reserveEntries` is met costs the sponsor only `$0.05` net (the 5% protocol fee) versus `$1.00` for honest buyers. Once honest buyers fund `reserveEntries` (e.g., `1,000` entries = `1,000e6` USDC), the sponsor can buy `19,000` additional entries at `endTime - 1` (`19,000e6` USDC) and recover all `19,000e6` USDC via `releaseSponsorProceeds()` (`95% * 20,000e6 = 19,000e6`), using the honest buyers' `1,000e6` USDC to pay the entire 5% protocol fee while diluting honest buyers' winning odds from `100%` down to `5%`.
  - **Mechanism 3B (Missing `maxTotalEntries` slippage parameter)**: `Raffle::buyEntries(address recipient, uint128 entryCount)` (`Raffle.sol:209`) lacks a `maxTotalEntries` (or `expectedFirstEntry`) parameter to bound entry dilution at the moment a buyer's transaction lands on-chain.
- **Raw Mitigation Preserved (`L03-FINDING-1`, `leaf-03.md:164`)**:
  > Enforce an immutable maximum entry cap (or cap entry sales at reserveEntries) in Raffle::buyEntries so the sponsor cannot uncap-dilute buyers after the reserve is met using the 95% sponsor rebate.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `Raffle::initialize` (`Raffle.sol:176-206`) sets `reserveEntries` as a minimum threshold with no `maxEntries` cap.
  - `setters`: `IRRELEVANT` — No setters exist.
  - `deposit`: `ALLOWS` — `Raffle::buyEntries` (`Raffle.sol:219-221`) checks only `entryCount > type(uint128).max - totalEntries` and allows unlimited post-reserve purchases by the sponsor or sybil addresses.
  - `accrue`: `ALLOWS` — `Raffle::_settleWinningTicket` (`Raffle.sol:540, 543-544`) returns 95% of the entire uncapped `grossPot` to `sponsorProceeds`.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `IRRELEVANT` — No liquidation path exists.
  - `withdraw`: `ALLOWS` — `Raffle::releaseSponsorProceeds` (`Raffle.sol:375-382`) pays the 95% rebate back to `sponsorRecipient`.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — No cap on `totalEntries` or restriction on sponsor rebates above `reserveEntries` exists.
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — Requires temporary capital before `endTime` (which is 95% refunded immediately after `fulfillRandomWords`), and is profitable whenever `fairValue(NFT) > $0.05 * reserveEntries`.
  - **Gate 3 (Harm to someone other than attacker)**: `ALLOWS` — Honest ticket buyers have their winning probability diluted (e.g., from 100% to 5%) by a counterparty paying 1/20th of the entry price.
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` — Expected-value transfer from honest ticket buyers to the sponsor cohort.
- **Verdict & Severity**: Confirmed `FINDING`, rated **Medium (`M-3`)** (economic value misallocation / dilution between buyer and sponsor cohorts requiring temporary capital at `endTime - 1`). `L07-LEAD-1` is also preserved in `M-3` and `## Unverified leads`.

---

### Group 4 — `Raffle | enableRefunds` (`[lenses: 2]`; `L-1` + Unverified Lead)

- **Merged Members**:
  - `L07-FINDING-1` (`leaf-07.md:178-190`, `front-running-griefing`)
  - `L08-LEAD-2` (`leaf-08.md:212-216`, `empty-raffle-cancellation-griefing`)
- **Mechanism Preserved (`[lenses: 2]`)**:
  In `Raffle::enableRefunds` (`Raffle.sol:280-284`), the sponsor's pre-`endTime` cancellation right is gated on `totalEntries == 0`, while `Raffle::buyEntries` (`Raffle.sol:209`) is immediately open from creation with a 1-entry (`1,000,000` USDC = 1 USDC) minimum purchase and no `startTime` cliff or pause mechanism. An attacker observing the sponsor's `enableRefunds()` transaction in the mempool can front-run it with `buyEntries(attacker, 1)` for 1 USDC, incrementing `totalEntries` to `1` (`Raffle.sol:230`) so `enableRefunds()` enters the `else` branch (`Raffle.sol:285-287`) and reverts with `RefundsNotAvailable(drawRequestDeadline(), block.timestamp)`. This locks the sponsor's escrowed NFT for up to `32 days` (`30 days` max `saleDuration` + `2 days` `DRAW_REQUEST_TIMEOUT`) at `0` to `0.20` USDC net cost to the attacker (or wins the NFT for 1 USDC if the sponsor was cancelling a misconfigured `reserveEntries == 1` raffle).
- **Raw Mitigation Preserved (`L07-FINDING-1`, `leaf-07.md:189`)**:
  > Add a configurable startTime parameter (where startTime >= block.timestamp and endTime > startTime) in RaffleInitParams so buyEntries() reverts while block.timestamp < startTime, giving the sponsor a front-run-proof window before startTime to cancel via enableRefunds().
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `Raffle::onERC721Received` (`Raffle.sol:428`) sets `status = Status.Active` immediately inside `createRaffle` with no `startTime` delay.
  - `setters`: `IRRELEVANT` — No setters exist.
  - `deposit`: `ALLOWS` — `Raffle::buyEntries` (`Raffle.sol:209-237`) accepts `entryCount = 1` (`1e6` USDC) immediately upon creation.
  - `accrue`: `IRRELEVANT` — Pre-draw cancellation path.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `ALLOWS` — `Raffle::enableRefunds` (`Raffle.sol:280-288`) reverts with `RefundsNotAvailable` whenever `totalEntries > 0` and `block.timestamp < drawRequestDeadline()`.
  - `withdraw`: `ALLOWS` — `Raffle::releaseSponsorPrize` (`Raffle.sol:395-407`) reverts with `InvalidStatus(Status.Active)` until `Status.Refunding` or `Status.CashWon` is reached.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — `totalEntries == 0` at `Raffle.sol:280` is invalidated by a 1-entry purchase in `buyEntries`.
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — Costs 1 USDC (`1,000,000` quoteToken units).
  - **Gate 3 (Harm to someone other than attacker)**: `ALLOWS` — Victim class is the `sponsor` attempting to cancel an empty raffle before `endTime`.
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` — Defeats the pre-`endTime` sponsor cancellation path (`Raffle.sol:280-284`).
- **Verdict & Severity**: Confirmed `FINDING` (`L08-LEAD-2` merged with `L07-FINDING-1`). Rated **Low (`L-1`)** per `severity-calibration.md` line 66 ("When genuinely torn between two severities, choose the lower and say why in one line"): buying 1 entry during `Status.Active` is valid participation by design and only griefs a sponsor who is actively attempting to cancel an empty raffle before any entries are sold.

---

### Group 5 — `Raffle | requestDraw` (`[lenses: 6]` across 2 sub-groups; `L-2` + Unverified Leads)

- **Merged Members**:
  - **Sub-group 5A (`Raffle | requestDraw | vrf-gas-price-griefing`, `[lenses: 4]`)**: `L02-LEAD-3` (`leaf-02.md:228-231`), `L05-LEAD-3` (`leaf-05.md:167-171`), `L08-LEAD-4` (`leaf-08.md:226-229`), `L10-LEAD-3` (`leaf-10.md:192-195`).
  - **Sub-group 5B (`Raffle | requestDraw | single-buyer-cash-tax`, `[lenses: 2]`)**: `L03-LEAD-1` (`leaf-03.md:181-185`), `L07-LEAD-3` (`leaf-07.md:222-225`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 5A-i (Single-shot `requestDraw` priced at caller's `tx.gasprice` with no retry/fee-bump path)**: `Raffle::requestDraw` (`Raffle.sol:240-260`) is permissionless, transitions `status` irreversibly from `Status.Active` to `Status.Drawing` (`Raffle.sol:252`), and prices the Chainlink VRF v2.5 native direct-funding request via `getVrfRequestPrice()` (`Raffle.sol:249, 436-438`) and `requestRandomnessPayInNative` (`Raffle.sol:257`) using the caller's `tx.gasprice` (`eth_call` with `tx.gasprice == 0` also underestimates the on-chain fee). With no retry or gas-bump path in `Status.Drawing`, a regretful sponsor submitting `requestDraw()` at a minimal `tx.gasprice` before a 2-day gas spike can stall callback fulfillment past `callbackDeadline()` (`drawRequestedAt + 2 days`) into `enableRefunds()`.
  - **Mechanism 5A-ii (Unreimbursed native VRF fee loss on callback timeout)**: `Raffle::requestDraw` (`Raffle.sol:249-260`) requires a permissionless caller to pay `paidPrice` in native ETH with no reimbursement from `unsettledPot` and no recovery if Chainlink VRF misses `callbackDeadline()` (`drawRequestedAt + 2 days`); `enableRefunds()` makes ticket buyers and the sponsor whole while the `requestDraw()` caller permanently loses `paidPrice`.
  - **Mechanism 5B (Single-buyer `CashWon` draw tax)**: `Raffle::requestDraw` (`Raffle.sol:243`) checks only `if (totalEntries == 0) revert NoEntries();` rather than requiring at least two distinct participants or `ticketCount > 1` when `totalEntries < reserveEntries`. When only a single buyer participates before `endTime` and `totalEntries < reserveEntries`, the sponsor can call `requestDraw()` (whenever `0.15 * unsettledPot > vrfFee`) to force a one-player `Status.CashWon` draw where the sole buyer wins against themselves and loses 20% of their own deposit (`15%` to `sponsorRecipient` and `5%` to `protocolTreasury` at `Raffle.sol:540, 546-549`) while the sponsor also reclaims the NFT via `releaseSponsorPrize()`.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `Raffle::initialize` (`Raffle.sol:176-206`) configures `callbackGasLimit` and `reserveEntries`.
  - `setters`: `IRRELEVANT` — No setters exist.
  - `deposit`: `ALLOWS` — Single buyer purchases entries (`totalEntries < reserveEntries`) in `Raffle::buyEntries` (`Raffle.sol:209-237`).
  - `accrue`: `ALLOWS` — `Raffle::requestDraw` (`Raffle.sol:243, 249-260`) only checks `totalEntries == 0`, transitions `status = Status.Drawing` once, and calls `requestRandomnessPayInNative` using `tx.gasprice`; `Raffle::fulfillRandomWords` (`Raffle.sol:521`) resolves `totalEntries < reserveEntries` to `Status.CashWon` and `_settleWinningTicket` (`Raffle.sol:540, 546-549`) deducts 15% `sponsorAmount` and 5% `protocolFee`.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `ALLOWS` — `Raffle::enableRefunds` (`Raffle.sol:286, 290`) blocks refunds until `endTime + 2 days` (`Active`) or `drawRequestedAt + 2 days` (`Drawing`) and does not reimburse `paidPrice`.
  - `withdraw`: `ALLOWS` — `Raffle::releaseSponsorProceeds` (`Raffle.sol:375`) and `Raffle::releaseSponsorPrize` (`Raffle.sol:395`) allow the sponsor to claim 15% of the sole buyer's deposit plus the returned NFT.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — Both paths exist directly in `Raffle::requestDraw` (`Raffle.sol:240-273`).
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — Mechanism 5B requires only a raffle where a single buyer bought entries (`totalEntries < reserveEntries`) and `0.15 * unsettledPot > vrfFee`; Mechanism 5A requires a 2-day VRF delay/timeout after `requestDraw()`.
  - **Gate 3 (Harm to someone other than attacker)**: `ALLOWS` — Victim class is the sole ticket buyer (Mechanism 5B, losing 20% of their deposit) or the honest `requestDraw()` caller / winning buyers (Mechanism 5A).
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` — Constrained economic loss (20% tax on a sole participant in a missed-reserve raffle, or lost native VRF fee on timeout).
- **Verdict & Severity**: Promoted (`[lenses: 4]` on Sub-group 5A and `[lenses: 2]` on Sub-group 5B) and rated **Low (`L-2`)** because Mechanism 5A requires an external 2-day VRF wrapper stall/timeout and Mechanism 5B applies only when a single participant enters a raffle that misses `reserveEntries`. Both sub-groups are also preserved in `## Unverified leads`.

---

### Group 6 — `Raffle | _isProtocolDestination` (`[lenses: 10]`; Demoted to `I-1` + Unverified Leads)

- **Merged Members**: `L01-LEAD-1`, `L02-LEAD-1`, `L03-FINDING-2`, `L04-LEAD-2`, `L05-LEAD-1`, `L08-LEAD-1`, `L09-LEAD-1`, `L10-LEAD-2`, `L11-LEAD-1`, `L12-LEAD-1`.
- **Mechanism Preserved (`[lenses: 10]`)**:
  In `Raffle::_isProtocolDestination` (`Raffle.sol:602-604`) and `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:159, 166`), `canonicalFactory.isRaffle(destination)` is only checked when `destination.code.length != 0` (and `isRaffle` only tracks already-deployed clones). However, `RaffleFactory::createRaffle` (`RaffleFactory.sol:106`) deploys clones via `Clones.clone(raffleImplementation)` using EVM `CREATE` (`keccak256(rlp([factory, nonce]))`). Before `RaffleFactory` reaches nonce $k$, the deterministic future clone address `futureRaffle` has `code.length == 0` and `isRaffle[futureRaffle] == false`, passing `_isProtocolDestination` in `initialize` (`sponsorRecipient`) and `_update` (ticket `recipient`). Once a subsequent `createRaffle` deploys `futureRaffle` at nonce $k$, `isRaffle[futureRaffle]` becomes `true`, causing `_transferQuote` (`Raffle.sol:565`) to revert permanently with `InvalidQuoteDestination(futureRaffle)` (freezing `sponsorProceeds`, `winnerProceeds`, or `remainingRefundLiability`), stranding any ticket owned by `futureRaffle` (and locking `prizeTokenId` in `raffle_1` if that ticket wins in `Status.NftWon`), while `releaseSponsorPrize` (`Raffle.sol:404`) omits `_isProtocolDestination` and transfers `prizeTokenId` into `futureRaffle`.
- **Raw Mitigation Preserved (`L03-FINDING-2`, `leaf-03.md:177`)**:
  > Check _isProtocolDestination(recipient, address(prizeToken)) in releaseSponsorPrize() and the NftWon branch of redeemWinningTicket(), and use safeTransferFrom for prize delivery so Raffle::onERC721Received rejects inter-clone NFT transfers while disallowing unverified future clone destinations.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` — `Raffle::initialize` (`Raffle.sol:187-195`) and `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:159, 166`) accept `futureRaffle` before nonce $k$ is reached.
  - `setters`: `IRRELEVANT` — No setters exist.
  - `deposit`: `ALLOWS` — `Raffle::buyEntries` (`Raffle.sol:235`) and `Raffle::_update` (`Raffle.sol:498`) allow minting/transferring tickets to `futureRaffle` while `futureRaffle.code.length == 0`.
  - `accrue`: `ALLOWS` — Subsequent `RaffleFactory::createRaffle` (`RaffleFactory.sol:106, 123`) deploys `futureRaffle` and sets `isRaffle[futureRaffle] = true`.
  - `borrow`: `IRRELEVANT` — No borrow path exists.
  - `liquidate`: `IRRELEVANT` — No liquidation path exists.
  - `withdraw`: `ALLOWS` — `_transferQuote` (`Raffle.sol:565`) reverts with `InvalidQuoteDestination(futureRaffle)`; `releaseSponsorPrize` (`Raffle.sol:404`) transfers `prizeTokenId` into `futureRaffle`.
  - `cross-chain receive`: `IRRELEVANT` — Single-chain protocol.
- **4-Gate Calibration Verdicts**:
  - **Gate 1 (Code path check)**: `ALLOWS` — `_isProtocolDestination` (`Raffle.sol:602`) short-circuits when `destination.code.length == 0`.
  - **Gate 2 (Preconditions reachable)**: `ALLOWS` — `CREATE` addresses of `RaffleFactory` are deterministic from `(address(factory), nonce)`.
  - **Gate 3 (Harm to someone other than attacker)**: `BLOCKS` non-self-harm exploit against honest users' funds — `sponsorRecipient` is chosen by the sponsor at creation and ticket `recipient` is chosen by the buyer/holder; even if an attacker buys a ticket for `futureRaffle` and that ticket wins in `Status.NftWon`, permissionless `settleWinningTicket` (`Raffle.sol:304`) still allows the sponsor to withdraw `sponsorProceeds`, so only the attacker's own won prize/refund is locked.
  - **Gate 4 (Real value vs theatre)**: `ALLOWS` as an invariant/robustness defect (`DESIGN.md` rule never to move assets between raffle clones or allow protocol destinations to hold tickets).
- **Verdict & Severity**: Per Turn 6 Step 3 ("`[lenses: 2+]` does NOT override a code path that actually interrupts the attack before harm — demote instead") and `severity-calibration.md` line 58 ("**Info** — correctness, consistency, or robustness with no exploit path. Include these; his real reports carry many"), `L03-FINDING-2` and its 9 sibling leads (`[lenses: 10]`) are demoted to **Info (`I-1`)** and also recorded in `## Unverified leads`.

---

### Group 7 — `Raffle | releaseSponsorPrize` (`[lenses: 2]`; Demoted to `I-2` + Unverified Leads)

- **Merged Members**: `L01-LEAD-2` (`leaf-01.md:162-165`), `L07-LEAD-2` (`leaf-07.md:215-218`).
- **Mechanism Preserved (`[lenses: 2]`)**:
  In `Raffle::releaseSponsorPrize` (`Raffle.sol:395-407`), `prizeToken.transferFrom(address(this), recipient, deliveredPrizeTokenId)` at `Raffle.sol:404` transfers the escrowed prize NFT to `sponsorRecipient` without calling `_isProtocolDestination(recipient, address(prizeToken))` and uses `transferFrom` instead of `safeTransferFrom`, whereas `_transferQuote` (`Raffle.sol:565`) re-checks `_isProtocolDestination(to, address(prizeToken))` on every quote-token payout.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` → `setters`: `IRRELEVANT` → `deposit`: `ALLOWS` → `accrue`: `IRRELEVANT` → `borrow`: `IRRELEVANT` → `liquidate`: `ALLOWS` → `withdraw`: `ALLOWS` (`releaseSponsorPrize` at `Raffle.sol:404` omits `_isProtocolDestination` and uses raw `transferFrom`) → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` — `releaseSponsorPrize` (`Raffle.sol:404`) has no `_isProtocolDestination` call.
  - **Gate 2**: `ALLOWS` — Reachable via a precomputed future `CREATE` clone address or contract `sponsorRecipient`.
  - **Gate 3**: `BLOCKS` non-self-harm exploit — `sponsorRecipient` is selected by the sponsor creating the raffle.
  - **Gate 4**: `ALLOWS` as a destination-validation consistency / defense-in-depth issue (`Info`).
- **Verdict & Severity**: Demoted per Turn 6 Step 3 to **Info (`I-2`)** and preserved in `## Unverified leads`.

---

### Group 8 — `Raffle | redeemWinningTicket` (`[lenses: 2]` across 2 mechanisms; Demoted to `I-3` + Unverified Leads)

- **Merged Members**:
  - **Mechanism 8A (`Raffle | redeemWinningTicket | unsafe-erc721-prize-transfer`, `[lenses: 1]`)**: `L02-LEAD-2` (`leaf-02.md:221-225`).
  - **Mechanism 8B (`Raffle | redeemWinningTicket | untrusted-prize-token-settlement-asymmetry`, `[lenses: 1]`)**: `L08-LEAD-3` (`leaf-08.md:219-223`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 8A**: `Raffle::redeemWinningTicket` (`Raffle.sol:334`) (and `Raffle::releaseSponsorPrize` at `Raffle.sol:404`) delivers `prizeTokenId` via `prizeToken.transferFrom` instead of `safeTransferFrom`, whereas `Raffle::buyEntries` (`Raffle.sol:235`) uses `_safeMint`. Smart-contract winners or vaults that rely on `IERC721Receiver.onERC721Received` hooks to register incoming ERC-721 assets do not receive the callback.
  - **Mechanism 8B**: In `Status.NftWon`, `Raffle::redeemWinningTicket` (`Raffle.sol:334-337`) reverts if `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` reverts or fails `ownerOf(deliveredPrizeTokenId) == winner`, with no fallback path to `Status.Refunding` while `releaseSponsorProceeds` remains independently callable.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` → `setters`: `IRRELEVANT` → `deposit`: `ALLOWS` → `accrue`: `ALLOWS` → `borrow`: `IRRELEVANT` → `liquidate`: `ALLOWS` → `withdraw`: `ALLOWS` (`redeemWinningTicket` at `Raffle.sol:334-337` calls `prizeToken.transferFrom` without `_isProtocolDestination` or `safeTransferFrom` and reverts if `prizeToken` reverts) → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` — `Raffle.sol:334` calls `prizeToken.transferFrom`.
  - **Gate 2**: `ALLOWS` — Reachable when a contract winner requires `onERC721Received` (Mechanism 8A) or when `prizeToken` reverts on outbound transfer (Mechanism 8B).
  - **Gate 3**: `BLOCKS` standalone exploit for Mechanism 8A (contract ticket owners can transfer the ticket via `_update` before calling `redeemWinningTicket`, and using `transferFrom` avoids revert griefing by non-receiver contracts), while Mechanism 8B's fund extraction is already captured at the payout root cause in `M-1` (`Raffle::releaseSponsorProceeds`).
  - **Gate 4**: `ALLOWS` as an interface/redemption consistency observation (`Info`).
- **Verdict & Severity**: Included as **Info (`I-3`)** and preserved in `## Unverified leads`.

---

### Group 9 — `Raffle | fulfillRandomWords` (`[lenses: 1]`; Demoted to `I-4` + Unverified Lead)

- **Merged Members**: `L11-LEAD-2` (`leaf-11.md:156-160`, `threshold-boundary-cliff`).
- **Mechanism Preserved (`[lenses: 1]`)**:
  In `Raffle::fulfillRandomWords` (`Raffle.sol:521`), `status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;` enforces a discontinuous binary regime switch where crossing from `reserveEntries - 1` to `reserveEntries` shifts 80% of the entire prior quote-token pot from the winning ticket holder (`CashWon`: 80% winner / 15% sponsor) to the sponsor (`NftWon`: 95% sponsor / 0% cash to winner).
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` → `setters`: `IRRELEVANT` → `deposit`: `ALLOWS` → `accrue`: `ALLOWS` (`fulfillRandomWords` at `Raffle.sol:521` sets `Status.NftWon` vs `Status.CashWon` at the `reserveEntries` cliff) → `borrow`: `IRRELEVANT` → `liquidate`: `IRRELEVANT` → `withdraw`: `ALLOWS` → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` — `Raffle.sol:521` implements the binary threshold check.
  - **Gate 2**: `ALLOWS` — Reachable at `totalEntries == reserveEntries`.
  - **Gate 3**: `ALLOWS` — The economic extraction mechanism is already rated in `M-2` on `Raffle::_settleWinningTicket`; under HARD function isolation, `Raffle::fulfillRandomWords` is preserved separately without double-counting severity.
  - **Gate 4**: `ALLOWS` as a state-transition boundary observation (`Info`).
- **Verdict & Severity**: Included as **Info (`I-4`)** and preserved in `## Unverified leads`.

---

### Group 10 — `Raffle | onERC721Received` (`[lenses: 2]`; Demoted to `I-5` + Unverified Leads)

- **Merged Members**: `L09-LEAD-2` (`leaf-09.md:178-181`, `reentrancy`), `L12-LEAD-2` (`leaf-12.md:117-120`, `mid-creation-reentrancy-asymmetry`).
- **Mechanism Preserved (`[lenses: 2]`)**:
  In `Raffle::onERC721Received` (`Raffle.sol:416-431`), `onERC721Received` lacks the `nonReentrant` modifier and sets `status = Status.Active` (`Raffle.sol:428`) inside `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:128`) before `RaffleFactory::createRaffle` finishes its post-transfer checks (`RaffleFactory.sol:129-134`) and emits `RaffleCreated` (`RaffleFactory.sol:136`). An untrusted `prizeToken` contract can call `raffle.buyEntries` mid-transfer after `onERC721Received`, causing `PrizeDeposited` and `TicketPurchased` to be emitted before `RaffleCreated`.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` → `setters`: `IRRELEVANT` → `deposit`: `ALLOWS` (`onERC721Received` at `Raffle.sol:416-431` activates the clone without `nonReentrant` before `safeTransferFrom` returns to `RaffleFactory.sol:128`) → `accrue`: `IRRELEVANT` → `borrow`: `IRRELEVANT` → `liquidate`: `IRRELEVANT` → `withdraw`: `IRRELEVANT` → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` for event-order inversion; `BLOCKS` state corruption because `RaffleFactory.sol:129-134` checks `prize.ownerOf(params.prizeTokenId) == raffle` and `raffle.status() == Status.Active` after `safeTransferFrom` returns.
  - **Gate 2**: `ALLOWS` — Reachable by an untrusted `prizeToken` during `createRaffle`.
  - **Gate 3**: `BLOCKS` fund loss — No user funds are stolen or locked; only event emission order (`PrizeDeposited`/`TicketPurchased` before `RaffleCreated`) is inverted.
  - **Gate 4**: `ALLOWS` as a callback/event-ordering hygiene item (`Info`).
- **Verdict & Severity**: Demoted per Turn 6 Step 3 to **Info (`I-5`)** and preserved in `## Unverified leads`.

---

### Group 11 — `RaffleFactory | createRaffle` (`[lenses: 2]` across 2 mechanisms; Demoted to `I-6` + Unverified Leads)

- **Merged Members**:
  - **Mechanism 11A (`RaffleFactory | createRaffle | callback-activation-before-creation-complete`, `[lenses: 1]`)**: `L05-LEAD-4` (`leaf-05.md:174-177`).
  - **Mechanism 11B (`RaffleFactory | createRaffle | precision-and-scale`, `[lenses: 1]`)**: `L06-LEAD-1` (`leaf-06.md:163-166`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 11A**: In `RaffleFactory::createRaffle` (`RaffleFactory.sol:128-147`), `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` triggers `Raffle::onERC721Received` (`status = Status.Active`) before `createRaffle` finishes its post-escrow assertions (`RaffleFactory.sol:129-134`) and emits `RaffleCreated` (`RaffleFactory.sol:136`), allowing an untrusted `prizeToken` to call `raffle.buyEntries` and emit `TicketPurchased` before `RaffleCreated`.
  - **Mechanism 11B**: `RaffleFactory::createRaffle` (via `_validateCreateParams` at `RaffleFactory.sol:178`) enforces `params.reserveEntries != 0` and `saleDuration <= 30 days` (`RaffleFactory.sol:101`), but places no upper bound on `uint128 reserveEntries`, allowing a sponsor to set `reserveEntries` up to `type(uint128).max` (`3.4028e38` USDC, exceeding total USDC supply) so that `Status.NftWon` is unreachable and any resolved draw is forced into `Status.CashWon` (15% sponsor cut + returned NFT).
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` (`createRaffle` at `RaffleFactory.sol:97-148` accepts any non-zero `uint128 reserveEntries` and emits `RaffleCreated` after `prize.safeTransferFrom`) → `setters`: `IRRELEVANT` → `deposit`: `ALLOWS` → `accrue`: `ALLOWS` → `borrow`: `IRRELEVANT` → `liquidate`: `IRRELEVANT` → `withdraw`: `IRRELEVANT` → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` — Neither `RaffleFactory::createRaffle` nor `_validateCreateParams` upper-bounds `reserveEntries`, and `RaffleCreated` is emitted at `RaffleFactory.sol:136` after `safeTransferFrom`.
  - **Gate 2**: `ALLOWS` — Any sponsor can pass `reserveEntries = type(uint128).max` or a custom `prizeToken`.
  - **Gate 3**: `BLOCKS` direct exploit against buyers who read on-chain state because `reserveEntries` is immutably stored and publicly readable via `Raffle::reserveEntries()` before any buyer calls `buyEntries`.
  - **Gate 4**: `ALLOWS` as parameter-bound and event-ordering hardening (`Info`).
- **Verdict & Severity**: Included as **Info (`I-6`)** and preserved in `## Unverified leads`.

---

### Group 12 — `RaffleFactory | _validateCreateParams` (`[lenses: 2]` across 2 mechanisms; Demoted to `I-7` + Unverified Leads)

- **Merged Members**:
  - **Mechanism 12A (`RaffleFactory | _validateCreateParams | unbounded-threshold-parameter`, `[lenses: 1]`)**: `L11-LEAD-3` (`leaf-11.md:163-166`).
  - **Mechanism 12B (`RaffleFactory | _validateCreateParams | treasury-prize-validation-asymmetry`, `[lenses: 1]`)**: `L12-LEAD-3` (`leaf-12.md:124-127`).
- **Distinct Mechanisms Preserved**:
  - **Mechanism 12A**: `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:178`) checks `if (params.reserveEntries == 0) revert InvalidReserveEntries();` with no upper bound on `params.reserveEntries` (`uint128` up to `3.4028e38` entries), allowing raffles whose `Status.NftWon` threshold exceeds circulating USDC supply.
  - **Mechanism 12B**: `RaffleFactory::_validateCreateParams` (`RaffleFactory.sol:157-161`) checks `params.prizeToken` against `address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, and `isRaffle[params.prizeToken]`, but omits `params.prizeToken == protocolTreasury` unlike `Raffle::initialize` (`Raffle.sol:190`), deferring the revert to `Raffle::initialize` and reverting with `UnsafeProtocolDestination(params.protocolTreasury)` instead of `InvalidPrizeToken()`.
- **Single-Pass Code-Path Walk (Fixed Order)**:
  - `constructor/initialize`: `ALLOWS` for Mechanism 12A (`_validateCreateParams` at `RaffleFactory.sol:178` has no upper bound on `reserveEntries`); `BLOCKS` exploit for Mechanism 12B because `Raffle::initialize` (`Raffle.sol:190`) atomically reverts with `UnsafeProtocolDestination(params.protocolTreasury)` in the same `createRaffle` call (`RaffleFactory.sol:109`).
  - `setters`: `IRRELEVANT` → `deposit`: `IRRELEVANT` → `accrue`: `IRRELEVANT` → `borrow`: `IRRELEVANT` → `liquidate`: `IRRELEVANT` → `withdraw`: `IRRELEVANT` → `cross-chain receive`: `IRRELEVANT`.
- **4-Gate Calibration Verdicts**:
  - **Gate 1**: `ALLOWS` for Mechanism 12A (unbounded `reserveEntries`) and error-selector asymmetry for Mechanism 12B (`Raffle.sol:190` blocks actual creation when `prizeToken == protocolTreasury`).
  - **Gate 2**: `ALLOWS`.
  - **Gate 3**: `BLOCKS` fund loss (`reserveEntries` is visible on-chain prior to `buyEntries`, and `prizeToken == protocolTreasury` reverts in `Raffle::initialize`).
  - **Gate 4**: `ALLOWS` as validation consistency / input-bound hygiene (`Info`).
- **Verdict & Severity**: Included as **Info (`I-7`)** and preserved in `## Unverified leads`.

---

## 5. Composite Chains

- **`Chain: [M-2] + [M-1]` (`Raffle::_settleWinningTicket` threshold top-up + `Raffle::releaseSponsorProceeds` decoupled payout on untransferable `prizeToken`)**:
  - **Precondition Link**: `M-1` (`Raffle::releaseSponsorProceeds` paying 95% of `unsettledPot` without `prizeClaimed == true`) requires the raffle to reach `Status.NftWon` (`totalEntries >= reserveEntries`). `M-2` (`Raffle::_settleWinningTicket` / `Raffle::buyEntries` allowing the sponsor to buy the remaining `reserveEntries - totalEntries` entries right before `endTime` and reclaim 95% of their own top-up) allows a malicious sponsor to force `totalEntries >= reserveEntries` (`Status.NftWon`) even when honest buyers purchased fewer than `reserveEntries` entries.
  - **Combined Impact**: Whenever honest buyers purchase entries with `totalEntries > 0.0527 * reserveEntries`, a malicious sponsor using an untrusted/blocking `prizeToken` can top up the remaining `reserveEntries - totalEntries` entries at `endTime - 1`, force `Status.NftWon`, and call `settleWinningTicket` + `releaseSponsorProceeds` to steal up to 95% of the honest buyers' USDC while `redeemWinningTicket` permanently reverts.
