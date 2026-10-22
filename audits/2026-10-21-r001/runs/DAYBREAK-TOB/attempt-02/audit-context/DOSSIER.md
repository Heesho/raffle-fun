# Audit Context Dossier — INCOMPLETE

**Target:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`  
**Native workflow status:** Orient complete; Analyze 1/12 complete; Synthesize not executed before the time bound.

This is a context record, not a vulnerability report. The completed orientation mapped 14 modules, 81 externally reachable functions/getters (including inherited entrypoints), 14 actors, 31 persistent-state groups, and 23 ranked candidates. The native default cut selected the first 12. Only `enableRefunds()` returned a schema-valid per-function record before the controller stopped the remaining 11 invocations at the stated time bound.

## System model

- `RaffleFactory` is ownerless and fixes quote-token, VRF-wrapper, treasury, and implementation addresses at construction (`RaffleFactory.sol:L21-L92`). `createRaffle` validates sponsor-selected data, clones and initializes `Raffle`, registers it, then asks the configured prize contract to transfer the selected token and verifies reported ownership/status (`RaffleFactory.sol:L97-L148`).
- Each `Raffle` clone stores isolated configuration, ticket ranges, lifecycle, request/resolution state, and quote liabilities. Its inherited ERC-721 ticket is a transferable bearer claim (`Raffle.sol:L52-L142`, `L209-L237`, `L497-L502`).
- The lifecycle is `AwaitingPrize -> Active -> Drawing -> NftWon|CashWon`, with `Active|Drawing -> Refunding` timeout branches (`IRaffle.sol:L20-L34`; `Raffle.sol:L176-L206`, `L240-L300`, `L509-L524`).
- Quote accounting is split among `unsettledPot`, refund liability, winner proceeds, sponsor proceeds, and protocol fees; `accountedQuoteBalance` sums them (`Raffle.sol:L91-L106`, `L468-L470`).
- The trusted quote token and VRF wrapper are black-box boundaries under the supplied design. Prize ERC-721 contracts and ticket recipients are untrusted boundaries (`DESIGN.md:L2`).

## Trust boundaries

- Sponsor -> `RaffleFactory.createRaffle` -> validation, clone registry, untrusted prize ERC-721 calls.
- Buyer -> `Raffle.buyEntries` -> trusted quote-token pull, ticket-range accounting, untrusted ERC-721 receiver callback.
- Permissionless requester -> `requestDraw` -> trusted VRF wrapper and native excess refund.
- Trusted wrapper -> inherited `rawFulfillRandomWords` -> internal `fulfillRandomWords` state transition.
- Permissionless settler -> `_settleWinningTicket` -> storage-only liability allocation.
- Current ticket owner -> `redeemWinningTicket` -> ticket burn and untrusted prize transfer or trusted quote transfer.
- Permissionless release caller -> sponsor/treasury recipients through `_transferQuote`.

## Completed function analysis

See `audit-context/functions/08-enableRefunds.md`. Its record establishes the mutually exclusive Active-empty, Active-nonempty, and Drawing deadline branches and the atomic conversion of `unsettledPot` to `remainingRefundLiability`. It records three assumptions, including reliance on factory-only initialization and on the callback path never changing pot/liability values.

## Unresolved coverage

The following selected functions were started but did not return schema-valid compact records: `createRaffle`, `buyEntries`, `requestDraw`, inherited `rawFulfillRandomWords`, `fulfillRandomWords`, `_settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `initialize`, `onERC721Received`, and `_update`. Their raw JSONL and stderr streams are preserved under `artifacts/raw/context-functions/` and are not treated as completed analyses.

Cross-function synthesis, contradiction reconciliation, and a complete unenforced-assumption list are therefore unavailable. No clean or complete-context claim is made.
