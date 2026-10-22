# TOB-S1: audit-context-building index

Index of the dossier produced by the Trail of Bits `audit-context-building:audit-context` workflow.

- **Arguments:** `path: packages/contracts/src`, `outDir: audit-context`.
- **Run ID:** `wf_613f2bac-ec8`.
- **Agents:** 14 of 14 completed, with 0 errors, 0 skips and 0 empty results (about 65 minutes in total).

The dossier is context only. It does not name vulnerabilities, assign severity or propose fixes. Unenforced assumptions
are recorded as assumptions, not as findings.

## Scope

**In scope:**

- `packages/contracts/src/Raffle.sol`
- `packages/contracts/src/RaffleFactory.sol`
- `packages/contracts/src/interfaces/IRaffle.sol`
- `packages/contracts/src/interfaces/IRaffleFactory.sol`
- `packages/contracts/src/libraries/RaffleConstants.sol`

**Context only:**

- OpenZeppelin 5.6.1 and Chainlink 1.5.0 sources under `packages/contracts/node_modules`.
- `DESIGN.md`, used as the specification.

No file under `packages/` was modified. Every file the run wrote is under `audit-context/`.

## Files

| Path | Size | Contents |
| --- | --- | --- |
| [`audit-context/DOSSIER.md`](audit-context/DOSSIER.md) | 1,479 lines | System-model synthesis that draws on all 12 records |
| `audit-context/functions/NN-*.md` | 12 files, 5,500 lines | Per-function records, listed below |

## DOSSIER.md section map

| § | Line | Contents |
| --- | --- | --- |
| 0 | 10 | Sources, scope, build context, citation key (`L`, `RF`, `IR`, `RC`, `[NN]`, `UA-`, `U-`, `S-`, `W`, `CFI-`) |
| 1 | 58 | Inventory: contract roles, `RaffleConstants` values, record list, code without a record, repository limits |
| 2 | 135 | Architecture: deployment topology, clone ABI surface (9 guarded mutators), lifecycle state machine, function-by-status matrix, asset channels (USDC, prize NFT, ETH, tickets) |
| 3 | 301 | Actors and trust boundaries, guard domains, external-call windows W1–W13, transitive reach |
| 4 | 380 | State model: factory, clone config, sale and ticket state, draw state, accounting buckets, flags, bucket values by phase |
| 5 | 504 | End-to-end flows F0–F7: deploy, create, sale, draw request, resolution, refund branch, win branch, ticket circulation |
| 6 | 639 | Cross-function invariants CFI-1 to CFI-17 |
| 7 | 930 | Timeline model (sale end, request window, callback window, refund deadlines) |
| 8 | 951 | Destination screening (`_isProtocolDestination`) and prize admission model |
| 9 | 1018 | Divergences: between records, between the orientation and the records, and between documents and code (11 rows in §9.3) |
| 10 | 1105 | Unenforced assumptions UA-01 to UA-60, copied verbatim, with a cluster index |
| 11 | 1228 | Nine fragility clusters, where complexity concentrates |
| 12 | 1313 | Open questions U-01 to U-26 (from records) and S-01 to S-03 (raised in synthesis) |
| App. A | 1456 | Entrypoint quick reference: guard, gate, writes and external calls for each entrypoint |

## Per-function records

Every record uses the same sections:

1. Purpose
2. Inputs & Assumptions
3. Outputs & Effects
4. Block-by-Block
5. Cross-Function Dependencies (callees, callers, shared state, invariant couplings)
6. Open Questions

| # | Function | Source lines | Lines |
| --- | --- | --- | --- |
| [01](audit-context/functions/01-Raffle.redeemWinningTicket-L309-346.md) | `Raffle.redeemWinningTicket` | Raffle.sol L309–346 | 565 |
| [02](audit-context/functions/02-Raffle._settleWinningTicket-L533-558-reached-via-settleWinni.md) | `Raffle._settleWinningTicket`, reached from `settleWinningTicket` and `redeemWinningTicket` | Raffle.sol L533–558 | 448 |
| [03](audit-context/functions/03-Raffle.buyEntries-L209-237.md) | `Raffle.buyEntries` | Raffle.sol L209–237 | 521 |
| [04](audit-context/functions/04-Raffle.refundTickets-L349-372.md) | `Raffle.refundTickets` | Raffle.sol L349–372 | 524 |
| [05](audit-context/functions/05-Raffle.enableRefunds-L276-301.md) | `Raffle.enableRefunds` | Raffle.sol L276–301 | 430 |
| [06](audit-context/functions/06-Raffle.fulfillRandomWords-L509-524-reached-via-inherited-raw.md) | `Raffle.fulfillRandomWords`, reached via the inherited `rawFulfillRandomWords` | Raffle.sol L509–524 | 384 |
| [07](audit-context/functions/07-Raffle.requestDraw-L240-273.md) | `Raffle.requestDraw` | Raffle.sol L240–273 | 386 |
| [08](audit-context/functions/08-RaffleFactory.createRaffle-L97-148.md) | `RaffleFactory.createRaffle` (also covers `_validateCreateParams` and clone `initialize`) | RaffleFactory.sol L97–148 | 406 |
| [09](audit-context/functions/09-Raffle.onERC721Received-L416-431.md) | `Raffle.onERC721Received` | Raffle.sol L416–431 | 443 |
| [10](audit-context/functions/10-Raffle.releaseSponsorPrize-L395-407.md) | `Raffle.releaseSponsorPrize` | Raffle.sol L395–407 | 510 |
| [11](audit-context/functions/11-Raffle._update-override-L497-502-with-inherited-ERC721-trans.md) | `Raffle._update` override, plus the inherited ERC-721 transfer, mint and burn paths | Raffle.sol L497–502 | 488 |
| [12](audit-context/functions/12-Raffle._isProtocolDestination-L593-605.md) | `Raffle._isProtocolDestination` | Raffle.sol L593–605 | 395 |

## Code without a dedicated record

The workflow did not give these their own records. They are covered inside other records or in the dossier:

| Code | Covered in |
| --- | --- |
| `RaffleFactory` constructor (L65–92) | DOSSIER §5 F0, App. A |
| `RaffleFactory._validateCreateParams` (L154–179), `_requireContract` (L183–185) | [08] |
| `Raffle` constructor (L155–166), `_validatedVrfWrapper` (L610–613) | DOSSIER §1.1, §2.3, §9.2; [06], [07] |
| `Raffle.initialize` (L176–206) | [08], [12] |
| `releaseSponsorProceeds` (L375–382), `releaseProtocolFees` (L385–392) | DOSSIER §2.4, §2.5, App. A; [02], [12] |
| `_transferQuote` (L564–567) | [01], [04], [12] |
| `_requireWinningTicket` (L579–585), `_requireStatus` (L573–575) | [01], [02], [03], [04], [07] |
| `drawRequestDeadline` (L458–460), `callbackDeadline` (L463–465) | DOSSIER §7; [05], [06], [07] |
| `receive` and the remaining views | DOSSIER §1.3, §2.2, App. A (read from source) |
| `IRaffle`, `IRaffleFactory` (declarations and NatSpec) | DOSSIER §9.3, which compares documents with code |
| `RaffleConstants` | DOSSIER §1.1 (value table) |
| Chainlink `rawFulfillRandomWords` and `requestRandomnessPayInNative` (dependencies) | [06], [07] |
