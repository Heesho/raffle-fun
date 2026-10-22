# Entry Point Analysis: raffle.fun Raffle Contracts

**Stage:** Native S2 — Trail of Bits `entry-point-analyzer`  
**Analyzed:** 2026-10-21T10:47:40-07:00  
**Target root:** `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target`  
**Frozen target SHA:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`  
**Language detected:** Solidity  
**Focus:** Externally callable, non-`view`/non-`pure` runtime entry points; constructors reported separately  
**Runtime topology:** `RaffleFactory` plus canonical ERC-1167 `Raffle` clones  
**Route tuple:** `(model=gpt-daybreak-blue-latest, access_program=daybreak_blue, reasoning_effort=ultra, fallback=false)`  
**Accepted local selection:** `gpt-daybreak-blue-latest` / `daybreak_blue` / `ultra` / no fallback  
**Provider-returned identity:** `unknown`; no explicit identity was supplied by the JSON event stream

## Source-only exposure statement

This stage used manual source analysis permitted by the pinned skill. Slither was neither invoked nor read and its cross-check is deferred to S6. No test output, scanner output, prior-audit output, attempt-02 S2–S6 report, other-cell output, or peer-stage output was run or read. Only the five production Solidity files, the 31 dependencies in `target/dependency-hashes.json`, clean `target/DESIGN.md`, the pinned method resources, and the inherited S1 dossier were used.

No target, production, configuration, lock, freeze, or dossier file was modified.

## Method and provenance

The following resources were read in full before analysis:

| Resource | SHA-256 |
|---|---:|
| `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/entry-point-analyzer/skills/entry-point-analyzer/SKILL.md` | `0d0e2956bdf9bf5be7efdfcefc754cabd2c1deb015731f3341f919eae2a0e3ca` |
| `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/entry-point-analyzer/skills/entry-point-analyzer/references/solidity.md` | `831559ce437ce2b2e4c2070b4e4e0bb16e27092a4ff160832d2ee9309edde79b` |
| `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-TOB/attempt-03/artifacts/stages/01-audit-context/inherited/DOSSIER.md` | `854e2abd2863adb63f553f1fd4ac1a5e3b81acae38d9bbb2d1733c8a0fb7e0af` |
| `target/DESIGN.md` | `25b4248a342c3be6a48380cb692bbd8087801baee8ed85c4e5d584d1bb9cbba1` |
| `target/dependency-hashes.json` | `1447879cda291c3f34ffde9ab85a3fc094e49688fc90ecda0a858df6048d1141` |

All 31 dependency files matched the SHA-256 values in `target/dependency-hashes.json`. The snapshot contains no local Git metadata from which to derive a commit, so the frozen target SHA above is the controller-provided identity; the file hashes below provide independent content-level provenance.

## Runtime and classification model

The effective inheritance graph is:

```text
Raffle
├── IRaffle                         interface only
├── ERC721
│   ├── Context                    internal helpers only
│   ├── ERC165                     view-only external surface
│   ├── IERC721                    declarations only
│   └── IERC721Metadata            declarations only
├── ReentrancyGuard                modifier and constructor only
├── IERC721Receiver                declaration implemented by Raffle
└── VRFV2PlusWrapperConsumerBase   contributes rawFulfillRandomWords

RaffleFactory
├── IRaffleFactory                 interface only
└── ReentrancyGuard                modifier and constructor only
```

`RaffleFactory.createRaffle` creates an ERC-1167 proxy at `RaffleFactory.sol:L105-L106`; `Clones.clone` constructs a delegate proxy at `Clones.sol:L32-L62`. Consequently, each clone exposes the implementation’s direct and inherited runtime selectors, but none of the implementation’s Solidity constructors execute in clone storage.

Classification is based on caller identity:

- Lifecycle, time, value, balance, parameter, and one-time-state predicates are recorded but do not by themselves make an entry point role-restricted.
- A function is Public when arbitrary callers can successfully use an eligible execution path.
- `enableRefunds` is Public because its post-deadline paths admit any caller; its empty-raffle pre-end branch gives the sponsor earlier access and is recorded explicitly.
- Asset ownership or ERC-721 operator authority is treated as a role.
- Contract-Only classifications assume the canonical factory-created clone topology shown in the in-scope source.
- `receive()` is included because the pinned Solidity reference explicitly includes special entry points, although this implementation always reverts and cannot successfully mutate state.
- Interface declarations are not counted separately from their runtime implementations.

## Summary

| Category | Count |
|---|---:|
| Public (Unrestricted) | 10 |
| Role-Restricted | 6 |
| Restricted (Review Required) | 0 |
| Contract-Only | 3 |
| **Total recurring runtime entry points** | **19** |

Runtime reconciliation:

| Surface | Direct | Inherited ERC-721 | Inherited VRF gateway | Total |
|---|---:|---:|---:|---:|
| Canonical `Raffle` clone | 12 | 5 | 1 | 18 |
| `RaffleFactory` | 1 | 0 | 0 | 1 |
| **Total** | **13** | **5** | **1** | **19** |

Category arithmetic: `10 Public + 6 Role-Restricted + 0 Review Required + 3 Contract-Only = 19`.

## Complete entry-point reconciliation

| ID | Runtime surface | Function | Definition | Category |
|---|---|---|---|---|
| EP-01 | Raffle clone | `receive()` | `packages/contracts/src/Raffle.sol:L171-L173` | Public (Unrestricted) |
| EP-02 | Raffle clone | `initialize(RaffleInitParams)` | `packages/contracts/src/Raffle.sol:L176-L206` | Contract-Only |
| EP-03 | Raffle clone | `buyEntries(address,uint128)` | `packages/contracts/src/Raffle.sol:L209-L237` | Public (Unrestricted) |
| EP-04 | Raffle clone | `requestDraw()` | `packages/contracts/src/Raffle.sol:L240-L273` | Public (Unrestricted) |
| EP-05 | Raffle clone | `enableRefunds()` | `packages/contracts/src/Raffle.sol:L276-L301` | Public (Unrestricted) |
| EP-06 | Raffle clone | `settleWinningTicket(uint256)` | `packages/contracts/src/Raffle.sol:L304-L306` | Public (Unrestricted) |
| EP-07 | Raffle clone | `redeemWinningTicket(uint256)` | `packages/contracts/src/Raffle.sol:L309-L346` | Role-Restricted |
| EP-08 | Raffle clone | `refundTickets(uint256[])` | `packages/contracts/src/Raffle.sol:L349-L372` | Role-Restricted |
| EP-09 | Raffle clone | `releaseSponsorProceeds()` | `packages/contracts/src/Raffle.sol:L375-L382` | Public (Unrestricted) |
| EP-10 | Raffle clone | `releaseProtocolFees()` | `packages/contracts/src/Raffle.sol:L385-L392` | Public (Unrestricted) |
| EP-11 | Raffle clone | `releaseSponsorPrize()` | `packages/contracts/src/Raffle.sol:L395-L407` | Public (Unrestricted) |
| EP-12 | Raffle clone | `onERC721Received(address,address,uint256,bytes)` | `packages/contracts/src/Raffle.sol:L416-L431` | Contract-Only |
| EP-13 | Raffle clone, inherited | `approve(address,uint256)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L95` | Role-Restricted |
| EP-14 | Raffle clone, inherited | `setApprovalForAll(address,bool)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L105-L107` | Public (Unrestricted) |
| EP-15 | Raffle clone, inherited | `transferFrom(address,address,uint256)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L125` | Role-Restricted |
| EP-16 | Raffle clone, inherited | `safeTransferFrom(address,address,uint256)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L130` | Role-Restricted |
| EP-17 | Raffle clone, inherited | `safeTransferFrom(address,address,uint256,bytes)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L133-L136` | Role-Restricted |
| EP-18 | Raffle clone, inherited | `rawFulfillRandomWords(uint256,uint256[])` | `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107` | Contract-Only |
| EP-19 | RaffleFactory | `createRaffle(CreateRaffleParams)` | `packages/contracts/src/RaffleFactory.sol:L97-L148` | Public (Unrestricted) |

## Shared modifier and gate traces

### `nonReentrant`

The modifier is defined at `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`. It checks the shared guard and writes the entered state before the function body at `L88-L100`, then restores the guard at `L102-L106`.

It is applied to:

- EP-03 at `Raffle.sol:L209-L213`
- EP-04 at `Raffle.sol:L240`
- EP-05 at `Raffle.sol:L276`
- EP-06 at `Raffle.sol:L304`
- EP-07 at `Raffle.sol:L309`
- EP-08 at `Raffle.sol:L349`
- EP-09 at `Raffle.sol:L375`
- EP-10 at `Raffle.sol:L385`
- EP-11 at `Raffle.sol:L395`
- EP-19 at `RaffleFactory.sol:L97`

`nonReentrant` is an execution-state gate, not a caller role.

### Shared lifecycle and destination gates

- `_requireStatus` compares the stored status and reverts on mismatch at `packages/contracts/src/Raffle.sol:L573-L575`.
- `_isProtocolDestination` identifies the clone, factory, configured tokens/wrapper, implementation, and registered same-factory clones at `Raffle.sol:L593-L604`.
- The Raffle ERC-721 `_update` override applies destination screening before inherited ownership mutation at `Raffle.sol:L497-L502`.
- `_transferQuote` applies destination screening before quote-token transfer at `Raffle.sol:L564-L566`.

## Public Entry Points (Unrestricted)

| ID / Function | Caller and modifier trace | Other successful-path gates |
|---|---|---|
| EP-01 `receive()` | No caller check or modifier; declared `external payable` at `Raffle.sol:L171`. | Unconditionally reverts with `DirectNativeTransfer` at `Raffle.sol:L172`; therefore it has no successful state-changing path. |
| EP-03 `buyEntries(address,uint128)` | No caller-identity restriction; `msg.sender` is the payer at `Raffle.sol:L223-L224`. `nonReentrant` is applied at `L212`. | Requires `Active`, pre-end execution, nonzero recipient/count, and bounded total entries at `L215-L221`. Safe minting at `L235` reaches Raffle’s destination screen at `L497-L502` and `L593-L604`. |
| EP-04 `requestDraw()` | No caller-identity restriction; any caller may fund the request. `nonReentrant` is applied at `Raffle.sol:L240`. | Requires `Active`, sale ended, entries sold, execution before the request deadline, and sufficient native value at `L241-L250`; the wrapper-reported paid price is checked at `L257-L258`. |
| EP-05 `enableRefunds()` | `nonReentrant` at `Raffle.sol:L276`. No caller restriction on the sold-Active post-request-deadline branch or Drawing post-callback-deadline branch at `L285-L291`. | In an empty Active raffle, the sponsor may execute before `endTime`; a non-sponsor must wait until `endTime` (`L279-L284`). Other statuses revert at `L292-L294`. This fully resolved hybrid gate is classified Public because arbitrary callers have successful eligible paths. |
| EP-06 `settleWinningTicket(uint256)` | No caller check; `nonReentrant` at `Raffle.sol:L304`. | `_settleWinningTicket` requires unsettled state and an `NftWon`/`CashWon` result at `L533-L538`; `_requireWinningTicket` checks range containment at `L579-L584`. |
| EP-09 `releaseSponsorProceeds()` | No caller check; `nonReentrant` at `Raffle.sol:L375`. | Requires a nonzero bucket at `L376-L378`; payment is always sent to stored `sponsorRecipient` at `L379-L381`, subject to `_transferQuote` at `L564-L566`. |
| EP-10 `releaseProtocolFees()` | No caller check; `nonReentrant` at `Raffle.sol:L385`. | Requires a nonzero bucket at `L386-L388`; payment is always sent to stored `protocolTreasury` at `L389-L391`, subject to `_transferQuote` at `L564-L566`. |
| EP-11 `releaseSponsorPrize()` | No caller check; `nonReentrant` at `Raffle.sol:L395`. | Requires `CashWon` or `Refunding` and an unclaimed prize at `L396-L400`; delivery is fixed to `sponsorRecipient` and post-transfer ownership is checked at `L402-L406`. |
| EP-14 `setApprovalForAll(address,bool)` | No fixed caller role: `_msgSender()` becomes the owner of the approval namespace at `ERC721.sol:L105-L107`; `_msgSender()` resolves to `msg.sender` at `Context.sol:L17-L19`. | `_setApprovalForAll` rejects zero owner/operator, updates only that caller’s operator mapping, and emits the event at `ERC721.sol:L409-L417`. |
| EP-19 `createRaffle(CreateRaffleParams)` | No caller-identity restriction; caller becomes the sponsor at `RaffleFactory.sol:L109-L120`. `nonReentrant` is applied at `L97`. | Parameter/token/recipient/reserve checks are at `L98` and `L154-L179`; time bounds are at `L99-L104`; clone initialization, registration, prize transfer, custody/status checks, and emission are at `L105-L148`. |

## Role-Restricted Entry Points

| ID / Function | Role | Exact restriction and supporting path |
|---|---|---|
| EP-07 `redeemWinningTicket(uint256)` | Current winning-ticket owner | After terminal-state and settlement checks at `Raffle.sol:L310-L318`, `ownerOf(ticketId)` is read and `msg.sender` must equal that owner at `L320-L321`. `nonReentrant` is applied at `L309`. |
| EP-08 `refundTickets(uint256[])` | Current owner of every supplied ticket | Requires `Refunding` and a bounded nonempty batch at `Raffle.sol:L350-L354`; each ticket’s current owner is read and compared with `msg.sender` at `L357-L360`. `nonReentrant` is applied at `L349`. |
| EP-13 `approve(address,uint256)` | Ticket owner or operator approved for all of that owner’s tickets | Entry at `ERC721.sol:L93-L95` passes `_msgSender()` as `auth`. `_approve` obtains the owner and requires `auth == owner` or `isApprovedForAll(owner,auth)` at `L383-L391`; token-specific approval does not authorize granting a new approval. |
| EP-15 `transferFrom(address,address,uint256)` | Ticket owner, token-approved address, or operator approved for all | Entry and zero-recipient/from checks are at `ERC721.sol:L115-L125`. Raffle first screens the destination at `Raffle.sol:L497-L502` and `L593-L604`. The inherited `_update` checks `auth` at `ERC721.sol:L216-L245`; `_checkAuthorized` and `_isAuthorized` resolve owner/token approval/operator approval at `L164-L187`. |
| EP-16 `safeTransferFrom(address,address,uint256)` | Ticket owner, token-approved address, or operator approved for all | Entry at `ERC721.sol:L128-L130` dispatches to the data overload. It inherits EP-15’s authorization and Raffle destination screen. Contract-recipient acceptance is checked through `ERC721.sol:L133-L136` and `ERC721Utils.sol:L25-L48`. |
| EP-17 `safeTransferFrom(address,address,uint256,bytes)` | Ticket owner, token-approved address, or operator approved for all | Entry at `ERC721.sol:L133-L136` calls `transferFrom`, thereby applying EP-15’s authorization and Raffle destination screen, and then applies the contract-recipient callback check at `ERC721Utils.sol:L25-L48`. |

## Restricted (Review Required)

No entry point remains in this category after manual gate resolution.

The only mixed caller gate is EP-05 `enableRefunds`. Its source establishes the role and permissionless branches exactly: the sponsor receives pre-end authority only for an empty Active raffle, while any caller may execute the eligible post-deadline paths (`Raffle.sol:L279-L291`). It is therefore classified Public with the branch-specific sponsor acceleration documented, rather than left unresolved.

## Contract-Only Entry Points

| ID / Function | Expected contract caller | Verified caller and application gates |
|---|---|---|
| EP-02 `initialize(RaffleInitParams)` | Canonical `RaffleFactory` | Successful execution requires `initialized == false` and `msg.sender == factory` at `Raffle.sol:L176-L179`. The canonical implementation records its deploying factory at `L155-L162`; `RaffleFactory` deploys that implementation at `RaffleFactory.sol:L89` and creates its clones at `L105-L106`. Address and protocol-destination checks continue at `Raffle.sol:L181-L205`. |
| EP-12 `onERC721Received(address,address,uint256,bytes)` | Configured prize-token contract during factory escrow | The callback requires `AwaitingPrize`, `msg.sender == address(prizeToken)`, the configured token ID, `from == sponsor`, and `operator == factory` at `Raffle.sol:L416-L426`. The factory initiates the safe transfer at `RaffleFactory.sol:L127-L128`; factory validation requires code and claimed ERC-721 support at `L154-L177`. Only then does the callback activate the raffle at `Raffle.sol:L428-L430`. |
| EP-18 `rawFulfillRandomWords(uint256,uint256[])` | Configured Chainlink VRF wrapper | The inherited gateway reads the immutable wrapper and requires `msg.sender` to equal it at `VRFV2PlusWrapperConsumerBase.sol:L101-L106`. The wrapper immutable is established at `L40-L47`; the canonical factory validates wrapper code at `RaffleFactory.sol:L65-L67` and passes it into the implementation at `L89`. The internal Raffle handler separately requires no request in flight, `Drawing`, matching request ID, exactly one word, and a pre-deadline timestamp at `Raffle.sol:L509-L516`, then writes the result at `L518-L523`. |

## Deployment-Time Entry Points

Constructors are not included in the recurring count of 19.

| ID | Constructor | Evidence | Deployment-time behavior |
|---|---|---|---|
| D-01 | `RaffleFactory(address,address,address)` | `packages/contracts/src/RaffleFactory.sol:L65-L92` | Validates code presence through `_requireContract` at `L183-L185`, verifies quote-token decimals at `L70-L78`, screens the treasury at `L68-L83`, fixes configuration, and deploys the shared Raffle implementation at `L89-L91`. |
| D-02 | `Raffle(address,address)` | `packages/contracts/src/Raffle.sol:L155-L166` | Validates the wrapper through `_validatedVrfWrapper` at `L610-L613`, rejects a zero quote token at `L159`, records the deploying factory and quote token at `L161-L162`, and locks implementation storage at `L164-L165`. |
| D-03 | inherited `ERC721(string,string)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L39-L42` | Invoked during Raffle implementation deployment; initializes ERC-721 name/symbol storage. Raffle’s runtime `name` and `symbol` overrides are pure at `Raffle.sol:L477-L487`. |
| D-04 | inherited `ReentrancyGuard()` | `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L58-L60` | Invoked during each concrete RaffleFactory and Raffle implementation deployment; initializes the guard slot for those deployment contexts. |
| D-05 | inherited `VRFV2PlusWrapperConsumerBase(address)` | `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40-L47` | Invoked during Raffle implementation deployment; records the wrapper and reads its LINK-token address. |

ERC-1167 clones have no Solidity constructor invocation; their one-time runtime setup is EP-02 `initialize`.

## Production-file coverage

| File | SHA-256 | Runtime contribution |
|---|---:|---|
| `packages/contracts/src/Raffle.sol` | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` | 12 direct entries, EP-01 through EP-12. Inheritance is declared at `L28`; the effective clone total is 18 after EP-13 through EP-18 are added. |
| `packages/contracts/src/RaffleFactory.sol` | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` | 1 recurring entry, EP-19 at `L97-L148`; constructor D-01 at `L65-L92`. |
| `packages/contracts/src/interfaces/IRaffle.sol` | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` | 0 additional runtime entries. State-changing ABI declarations at `L303-L355` are implemented and counted once in `Raffle.sol`. View declarations at `L357-L520` are excluded. |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` | 0 additional runtime entries. `createRaffle` at `L104` is a declaration whose implementation is counted once as EP-19; `L106-L149` contains view declarations. |
| `packages/contracts/src/libraries/RaffleConstants.sol` | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` | 0. Library contains constants only at `L10-L43`. |

`target/DESIGN.md` is contextual prose and contributes no runtime entry point.

## Reachable-dependency coverage

| Dependency and SHA-256 | Recurring runtime contribution and disposition |
|---|---|
| `@openzeppelin/contracts/token/ERC721/IERC721.sol` — `ff0eb9902bf0ac099205615fac90eacf34fae637571b05aab3ea35dea53d5f17` | 0 additional. Interface declarations at `L11-L135`; the five state-changing selectors are counted from `ERC721.sol`, not again here. |
| `@openzeppelin/contracts/utils/introspection/IERC165.sol` — `9055c2994b37dea1a41b7b7926dcb510f05dbe2540b0aafc5fbee9558fffd0ca` | 0. Interface contains only the `view` declaration at `L15-L25`. |
| `@openzeppelin/contracts/token/ERC20/IERC20.sol` — `01b6f5c4fa45fd38822b286ecef6daf983d27306dd6362496fa71b3e4600b72c` | 0. Interface for the external quote token at `L9-L79`; its declarations are not Raffle or factory runtime functions. |
| `@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` — `a48aaaeaed60e65f04f6c8772e5673dda663dcfa7913fdadd14b412300b9d5f1` | 0. Interface at `L4-L83`; `requestRandomWordsInNative` at `L74-L79` is an outgoing call target on the wrapper, not a selector implemented by a Raffle clone. |
| `@openzeppelin/contracts/utils/math/Math.sol` — `bdfdbe133991c0c78042957ff5cd97167926fcaf6d15664f3835a076cb066457` | 0. Library functions at `L12-L763` are internal/private; `mulDiv` is inlined into settlement. |
| `@openzeppelin/contracts/utils/math/SafeCast.sol` — `5779bc848bde39f1ad7bc02b4f708a0040888e0083b1a33f119cd94639350134` | 0. Library functions at `L19-L1162` are internal pure helpers. |
| `@openzeppelin/contracts/utils/Panic.sol` — `270fc8401c1a13fae6a7a4a2dd6e381b95d658896701e51f0d3e2688acab3dec` | 0. Library helper is internal pure (`L26-L57`). |
| `@openzeppelin/contracts/utils/ReentrancyGuard.sol` — `94e409e8f6e3184236651a6cc2b1a6a3ea0f0a25eb85b71e524ad5791bb2fbc8` | 0 selectors. Contributes constructor D-04, `nonReentrant`, and internal/private guard helpers at `L32-L119`. |
| `@openzeppelin/contracts/utils/StorageSlot.sol` — `75704538dcb223239280c6726d9a31cf769a7816718517c997fc7d63bdb70778` | 0. Library accessors at `L34-L143` are internal pure helpers. |
| `@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` — `eafee3ffdc7cb2fba4bf6bd16fb28f8e5b4679742e81c2ad42a1b1df5c179feb` | 0 additional. Interface declaration at `L11-L28`; Raffle’s implementation is counted once as EP-12. |
| `@openzeppelin/contracts/token/ERC721/ERC721.sol` — `ef8e2398c78851bd2ec12bc48d923058c557889d5a3d5ee4919c17ff0fb3517e` | 5: EP-13 through EP-17 at `L93-L136`. Its other public functions are `view`, while remaining state-changing helpers are internal. |
| `@openzeppelin/contracts/interfaces/draft-IERC6093.sol` — `fa7068f56bc180571a6095be6eaef06d51dbe81e30cb128397d993c9599ecc30` | 0. Error-only interfaces at `L10-L162`; no functions. |
| `@openzeppelin/contracts/utils/introspection/ERC165.sol` — `61a2b12c96857aaa35f48aeda67a4281637a42494c0b3795be0ae976aa7b3793` | 0. Its only public function, `supportsInterface`, is `view` at `L20-L25`. |
| `@openzeppelin/contracts/utils/Strings.sol` — `e318709bbe73a7831d64c1351e8bdc43780b245f25191234e361e6ab9b98c67b` | 0. Library functions at `L14-L532` are internal/private and are reached only by excluded read-only metadata logic. |
| `@openzeppelin/contracts/utils/Bytes.sol` — `3ce9120a27934c75a074cb785d3a88868069ef6529dbe4dc6b845af0836f3c70` | 0. Library functions at `L11-L332` are internal/private. |
| `@openzeppelin/contracts/utils/math/SignedMath.sol` — `1ed50b1056af886752f0fb48a0165d381e69bb4a4b18b893b066dc144a7e08d7` | 0. Library functions at `L11-L68` are internal pure helpers. |
| `@openzeppelin/contracts/utils/Context.sol` — `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` | 0. Contains only internal view context helpers at `L16-L28`; `_msgSender` informs inherited ERC-721 authorization. |
| `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` — `b48e95db8c85866c1d88af8e82f346e0d22d24b5aac5b936079d958c72e13b9f` | 0. Internal receiver-check library at `L16-L50`; it does not add a target selector. |
| `@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` — `33223782ea652dca413702ce92f9f59d91d758a035065b24bbedb7dc60c63a78` | 0. Interface at `L12-L27`; added metadata declarations are read-only and inherited IERC-721 declarations are not recounted. |
| `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` — `c2394cb2a327f234711da34884947f4aa0f6dd2791d1d6303a0c7acfaf81bca3` | 0. Library functions at `L18-L280` are internal/private. Relevant transfer wrappers are `safeTransfer` at `L33-L37` and `safeTransferFrom` at `L43-L47`. |
| `@openzeppelin/contracts/interfaces/IERC1363.sol` — `9c3a75a925a6dac9e88b03cddc58d42fe3131b0aaaad84408521f3f7af2f991b` | 0. Transitively imported external-token interface at `L16-L86`; it is not implemented by a target contract. |
| `@openzeppelin/contracts/interfaces/IERC165.sol` — `dfb3f56fa928a7c6cae41a7ce2c86b9210fa18d33fa26389099d66a0fa790368` | 0. Import-forwarding unit only (`L1-L6`). |
| `@openzeppelin/contracts/interfaces/IERC20.sol` — `0158e2d3e0e28bedd99eec13dcf1a8aa3a70a5b7e4bb2ad709609c95fcc740d1` | 0. Import-forwarding unit only (`L1-L6`). |
| `@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` — `f3b89bb466c2a79b10c1816d342fbfbec49fe82695cba92bd46e7d31af698011` | 0. Library at `L5-L27`; `_argsToBytes` is internal pure, and the public constant does not become a Raffle selector. |
| `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` — `8cf045f295b8c6035d14012a9bc2e8ab2b5ce24749a199ca0190519c4bf2dcc0` | 1: EP-18 at `L101-L107`. Request helpers are internal at `L62-L89`; `getBalance` and `getLinkToken` are view functions at `L109-L117`. |
| `@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` — `f81ec96e909daa2cd27536274a30d916b26d5fc91261bed8d7a6a3e157f3825c` | 0. External LINK-token interface at `L5-L31`; not implemented by a target contract. |
| `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` — `0b7132f17d14d1d84b41b0bb429be62dafdff00fd3470f68724d8018eb07f57a` | 0. Interface at `L11-L26`; added functions are view, and inherited ERC-20 declarations belong to the external token. |
| `@openzeppelin/contracts/proxy/Clones.sol` — `06c768a2b794ea59dd6d6c1bfe33cf5098a4a8921aec14cf066576a2bffafce6` | 0 selectors. All library functions are internal/private at `L20-L294`; `clone` is reached internally from EP-19. |
| `@openzeppelin/contracts/utils/Errors.sol` — `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66` | 0. Library contains errors only at `L14-L34`. |
| `@openzeppelin/contracts/utils/Create2.sol` — `9623aa59745a23a72f313adc5adbf583968bf366a7cbf3fc43c1148d7d2c3c86` | 0. Library functions at `L18-L91` are internal and are not directly exposed by the target. |
| `@openzeppelin/contracts/utils/LowLevelCall.sol` — `e128cbe9c6c406d5a42c26e4079c0a95b369ce552f2d0c3dfd2fcb836c5708f2` | 0. Library functions at `L12-L127` are internal. |

## Exclusions

- All explicit `view` and `pure` functions, including generated public-variable getters, ERC-721 metadata/ownership getters, ERC-165 support checks, and Chainlink base balance/token getters.
- Interface declarations, except as corroborating ABI evidence; runtime implementations are counted once.
- Internal/private functions, including `Raffle.fulfillRandomWords` at `Raffle.sol:L509-L524`. Its only external gateway is EP-18.
- Internal mint, burn, update, settlement, transfer, clone, and utility helpers.
- Constructors from the recurring total; they are listed separately.
- External quote-token, prize-token, wrapper, LINK-token, and ticket-recipient implementations. Their interfaces and call boundaries are in scope, but their deployed runtime code is not present.
- No fallback function exists in either production contract.
- Clean `DESIGN.md` supplied context but did not supersede source behavior.

## Per-function depth gaps

“Complete locally” means all in-scope implementation, inheritance, modifier, and inline caller gates were traced. It is not a vulnerability or behavioral judgment about code outside the supplied source.

| ID | Local trace | Boundary or depth gap |
|---|---|---|
| EP-01 | Complete locally | None; path always reverts. |
| EP-02 | Complete locally | Concrete deployment provenance for the immutable `factory` is outside the snapshot; Contract-Only classification uses the canonical construction path in source. |
| EP-03 | Complete locally | Concrete quote-token transfer behavior and any recipient contract’s ERC-721 callback implementation are absent. |
| EP-04 | Complete locally | Concrete wrapper pricing/request behavior and any native-refund recipient fallback implementation are absent. |
| EP-05 | Complete locally | No external-code depth gap; timestamp is an execution-environment input. |
| EP-06 | Complete locally | None within the supplied source. |
| EP-07 | Complete locally | Concrete prize-token or quote-token delivery behavior is absent, depending on result branch. |
| EP-08 | Complete locally | Concrete quote-token transfer behavior is absent. |
| EP-09 | Complete locally | Concrete quote-token transfer behavior is absent. |
| EP-10 | Complete locally | Concrete quote-token transfer behavior is absent. |
| EP-11 | Complete locally | Concrete prize-token transfer and ownership-reporting behavior is absent. |
| EP-12 | Complete locally | The configured prize token’s transfer ordering and callback-field provenance are outside the supplied implementation set. |
| EP-13 | Complete locally | None within the supplied ERC-721 implementation. |
| EP-14 | Complete locally | None within the supplied ERC-721 implementation. |
| EP-15 | Complete locally | Canonical factory registry calls used by destination screening are traced; no additional local gap remains. |
| EP-16 | Complete locally | Destination contract’s `onERC721Received` implementation is external and absent. |
| EP-17 | Complete locally | Destination contract’s `onERC721Received` implementation is external and absent. |
| EP-18 | Complete locally | Concrete wrapper identity, scheduling, request binding, and randomness implementation are absent; the gateway and local acceptance filters are fully traced. |
| EP-19 | Complete locally | Sponsor-selected prize-token behavior and concrete deployed dependency identities are absent. |

## Analysis warnings and unresolved leads

1. The enumeration is a manual source-only result. No file failed manual parsing, but the Slither cross-check required by the broader workflow remains deferred to S6.
2. The target snapshot has no Git metadata. The commit identity is therefore the controller-provided frozen SHA, supplemented by the SHA-256 file provenance above.
3. Contract-Only classifications for EP-02, EP-12, and EP-18 use the canonical `RaffleFactory → implementation → registered clone` topology. Independently deployed implementations or noncanonical proxies are not established by the supplied deployment provenance.
4. The concrete quote-token, prize-token, Chainlink wrapper, LINK token, and arbitrary receiver implementations are not present. Their missing call depth is mapped per entry point above.
5. Interface functions such as `IVRFV2PlusWrapper.requestRandomWordsInNative` and IERC-20/IERC-721 declarations describe external callees; they are not additional Raffle or factory runtime selectors.
6. EP-01 is retained solely under the pinned reference’s special-entry-point rule; its body always reverts.
7. No source-level recurring entry-point candidate remains unresolved: the manual reconciliation accounts for all 12 direct Raffle paths, five inherited ERC-721 paths, one inherited Chainlink gateway, and one factory path.