# Step 3 — visual security inspection: outputs and review

All three skill printers were executed in the isolated harness (`_generated/harness`):

| Printer (skill command) | Raw output | Visual output (rendered with Graphviz 14.1.3 WASM → SVG → PNG) |
|---|---|---|
| `slither . --print inheritance-graph` | `01-print-inheritance-graph.*`, DOT `inheritance-graph.dot` | `rendered/inheritance-graph.svg`, `png/inheritance-graph.png` (2558×5030) |
| same + `--include-interfaces` (corrective variant, see defect below) | `04-print-inheritance-graph-include-interfaces.*`, DOT `inheritance-graph.include-interfaces.dot` | `rendered/inheritance-graph.include-interfaces.svg`, `png/inheritance-graph.include-interfaces.png` (5028×7182) |
| `slither . --print function-summary` | `02-print-function-summary.{stderr(text table),json}` | derived `derived-dot/function-summary-access-map.dot` → `rendered/…svg`, `png/function-summary-access-map.png` |
| `slither . --print vars-and-auth` | `03-print-vars-and-auth.{stderr,json}` | derived `derived-dot/vars-and-auth-map.dot`, `factory-vars-and-auth-map.dot` → `png/vars-and-auth-map.png`, `png/factory-vars-and-auth-map.png` |

Supporting printers (`supplementary/`): `c3-linearization`, `variable-order`, `entry-points`, `modifiers`, `function-id`,
`human-summary`, `require`, `constructor-calls`, `echidna`, `call-graph` (Raffle/RaffleFactory call graphs rendered to
`png/supplementary/`). Tabular printer data was parsed (not re-run) into `06-parsed-printer-tables.{json,md}`; transitive
external interactions come from the custom Slither API inventory (`../04-properties/10-custom-slither-checks.json`).
Rendering toolchain: `_generated/bin/render_dot.cjs` (copied `@viz-js/viz` 3.25.0, hashes in
`../00-identity/viz-js-3.25.0-copied-files-sha256.txt`) and `_generated/bin/svg_to_png.sh` (macOS `sips`, 2× raster).
The first PNG attempt with `qlmanage` cropped non-square drawings; those files are kept, labeled, in
`png/superseded-quicklook-cropped/`.

## Tool defect found while reviewing the inheritance graph

Slither 0.11.6 `printers/inheritance/inheritance_graph.py:111-113` filters interfaces out of `immediate_inheritance`, but
when exactly one parent remains it draws the edge to `contract.immediate_inheritance[0]` of the **unfiltered** list. For
`RaffleFactory is IRaffleFactory, ReentrancyGuard` the canonical graph therefore shows an edge to an undeclared node
`c12663_IRaffleFactory` and **omits the real `RaffleFactory → ReentrancyGuard` edge** (visible in
`png/inheritance-graph.png`). The `--include-interfaces` variant does not hit that branch and is correct; the text
`inheritance` and `c3-linearization` printers agree with it. Conclusions below use the corrected graph.

## Inheritance graph review

- `Raffle → {IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase}`; depth 3 for concrete
  bases (Raffle → ERC721 → ERC165 → IERC165). `RaffleFactory → {IRaffleFactory, ReentrancyGuard}`.
- C3 linearization (`supplementary/print-c3-linearization.stderr.txt`): Raffle, VRFV2PlusWrapperConsumerBase,
  IERC721Receiver, ReentrancyGuard, ERC721, IERC721Errors, IERC721Metadata, IERC721, ERC165, IERC165, Context, IRaffle.
  Constructor order: ERC721 → ReentrancyGuard → VRFV2PlusWrapperConsumerBase → Raffle.
- Overrides (orange in the graph): `name`, `symbol` (pure constants replace ERC721 storage strings), `_update`
  (destination screen + `super._update`), `fulfillRandomWords`; IRaffle getters via `override`. No ambiguous diamond:
  `supportsInterface` resolves to ERC721's implementation (721, 721Metadata, 165). Slither's shadowing detectors
  (shadowing-state/-local/-abstract) reported nothing.
- **Clone-specific review (key security property revealed by the diagram):** none of the four constructors runs for
  an ERC-1167 clone. Each constructor writes either immutables (embedded in implementation code and therefore shared by
  clones: `i_vrfV2PlusWrapper`, `i_linkToken`, `factory`, `quoteToken`) or implementation-only storage that clones must
  NOT inherit: ERC721 `_name/_symbol` (dead — `name()/symbol()` are pure), ReentrancyGuard slot (clone value 0 is safe:
  the guard only tests `== ENTERED(2)`), Raffle `initialized=true, status=Refunding` (locks the implementation). All
  clone state is written by `initialize`. Storage layout (`supplementary/print-variable-order.stderr.txt`): a fresh clone
  reads `status=0 (AwaitingPrize)`, `initialized=false` until the factory's atomic `initialize`.

## Function-summary review (`png/function-summary-access-map.png`)

- Every Raffle state-changing entry point that moves value or calls untrusted code is `nonReentrant`: buyEntries,
  requestDraw, enableRefunds, settleWinningTicket, redeemWinningTicket, refundTickets, releaseSponsorProceeds,
  releaseProtocolFees, releaseSponsorPrize; factory `createRaffle`. Without the guard by design: `initialize`
  (factory-only, one-shot), `rawFulfillRandomWords` (wrapper-only; must never revert), `onERC721Received` (no external
  calls), `receive` (always reverts), inherited ERC721 transfer/approval functions (custom check C1 allowlist).
- Untrusted call surfaces (red): prize ERC-721 (redeem/releaseSponsorPrize/createRaffle), ticket-recipient
  `onERC721Received` (buyEntries, safeTransferFrom), native excess refund to `msg.sender` (requestDraw). All occur after
  state updates.
- Permissionless value movers push only to fixed recipients (`sponsorRecipient`, `protocolTreasury`) or to the
  authenticated ticket owner. Highest cyclomatic complexity: `redeemWinningTicket` (CC=10), `requestDraw` (8).
- Observation feeding Step 5: `_update` (the transfer hook) gates only destinations, not lifecycle state → tickets
  remain transferable during `Drawing` (S6-F1).

## Vars-and-auth review (`png/vars-and-auth-map.png`, `png/factory-vars-and-auth-map.png`)

- Per-raffle configuration (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`,
  `raffleId`, `reserveEntries`, `endTime`) is written only by `initialize` (`msg.sender != factory → revert`).
- `status` writers: initialize, onERC721Received, requestDraw, enableRefunds, rawFulfillRandomWords (callback), constructor.
- Only four authorization roles exist: factory (init), VRF wrapper (callback), sponsor (early close of an EMPTY raffle),
  current ticket owners (redeem/refund). Everything else is permissionless but deadline- or state-gated. Matches
  DESIGN.md "No administrator, mutable configuration or upgrade".
- Observation feeding Step 5: sponsor proceeds are allocated by permissionless `settleWinningTicket` and released by
  permissionless `releaseSponsorProceeds`, independently of whether the NFT prize can be delivered (S6-F2); the outcome
  type is a pure function of `totalEntries` vs `reserveEntries`, which anyone — including a sponsor-controlled address —
  can move until `endTime` (S6-F5).
