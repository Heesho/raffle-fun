# S6 visual security review

Actual Slither printers were run for `inheritance-graph`, `function-summary`, and `vars-and-auth`. The raw inheritance DOT was emitted by Slither. The latter two printers emit terminal tables rather than DOT, so their raw tables were preserved and narrowly transcribed into supplemental DOT views without changing the underlying results. Because host `dot` was absent, Graphviz was installed in a disposable Debian container reached through the authorized Lima Docker socket; DOT, PNG, and PDF were produced for all three views.

## Inheritance and linearization

`Raffle` inherits `IRaffle`, OpenZeppelin `ERC721`, `ReentrancyGuard`, `IERC721Receiver`, and Chainlink `VRFV2PlusWrapperConsumerBase`. The observed override points are deliberate: fixed `name`/`symbol`, destination-checking `_update`, prize receiver callback, and internal `fulfillRandomWords`. `RaffleFactory` inherits only `IRaffleFactory` and `ReentrancyGuard`.

No state-variable shadowing or ambiguous security-sensitive override was found. C3 linearization leaves ERC-721 authorization in OpenZeppelin’s `_update` path and wrapper caller authentication in `rawFulfillRandomWords`. The clone does not execute implementation constructors, so its namespaced `ReentrancyGuard` slot begins at zero; OpenZeppelin treats only `ENTERED == 2` as reentrant and normalizes the slot on the first guarded exit. The implementation itself is constructor-locked.

## Callable surface and access controls

- `initialize`: factory-only and one-time.
- `buyEntries`: permissionless payer, caller-selected recipient; `Active`, time, quantity, transfer, and receiver gates; guarded.
- `requestDraw`: permissionless funded keeper within a fixed window; guarded; wrapper external call.
- `enableRefunds`: sponsor-only only for early empty cancellation, otherwise permissionless at the exact timeout; guarded.
- `settleWinningTicket` and releases: permissionless triggers with range/status gates and fixed or owner-derived recipients; guarded.
- `redeemWinningTicket` and `refundTickets`: exact current owner must call; tickets burn atomically; guarded.
- inherited approvals/transfers: standard ERC-721 owner/operator authority plus `_update` destination screening.
- `rawFulfillRandomWords`: immutable wrapper-only in the Chainlink base; the internal handler then applies state/ID/shape/time gates.
- `onERC721Received`: exact prize token/token ID/sponsor/factory tuple, but unguarded activation allows sponsor-selected prize code to call back into the now-active clone before factory publication.

Slither’s `vars-and-auth` table is syntactic and frequently displays no direct `msg.sender` condition when authorization lives in a modifier, helper, inherited method, or a subsequent ownership read. The source-level review above is the controlling interpretation.

## State writers and authority

- Factory immutables are constructor-only; `raffleCount` and all registry mappings are written only by guarded `createRaffle`.
- Clone configuration fields and `AwaitingPrize` are written only in `initialize`; `Active` only in the exact prize callback.
- Entry count, ticket count, ranges, and unsettled pot are written only by guarded purchases.
- Drawing/request fields are written only by guarded `requestDraw`; resolution fields only through wrapper-authenticated callback flow.
- Refund liability only arises through guarded timeout/cancellation transition and decreases with owner-authorized burns.
- Winner/sponsor/protocol liabilities are allocated once by guarded settlement and cleared before guarded external payouts.
- ERC-721 ownership/approval state is inherited from OpenZeppelin and funnels ownership mutation through the overridden `_update`.

## Artifacts reviewed

- `diagrams/inheritance-graph.dot`, `.png`, `.pdf`
- `diagrams/function-summary.dot`, `.png`, `.pdf`; raw Slither table in `tool-output/03-printer-function-summary.stderr`
- `diagrams/vars-and-auth.dot`, `.png`, `.pdf`; raw Slither table in `tool-output/03-printer-vars-and-auth.stderr`

All nine rendered/source artifacts were generated successfully in the final Graphviz attempt and recorded with file type and SHA-256 in `tool-output/03-diagram-artifact-manifest.stdout`.
