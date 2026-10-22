# System Model Dossier: `packages/contracts/src` (raffle.fun v1)

> This document builds context for the hunting phase. It covers structure, state, flows, trust boundaries,
> cross-function invariants, unenforced assumptions and open questions. It does not name vulnerabilities,
> assign severity, propose fixes or describe exploits. An unenforced assumption is recorded as an unenforced
> assumption and nothing more.

---

## 0. Sources, scope and notation

**Scope.** `packages/contracts/src`:

- `RaffleFactory.sol` (186 lines)
- `Raffle.sol` (614)
- `interfaces/IRaffle.sol` (521)
- `interfaces/IRaffleFactory.sol` (150)
- `libraries/RaffleConstants.sol` (43)

Inherited code that is part of the deployed ABI or its behavior is included as context:

- OpenZeppelin Contracts 5.6.1: `ERC721`, `ERC721Utils`, `ReentrancyGuard`, `SafeERC20`, `Math`, `Clones`, `Context`.
- Chainlink contracts 1.5.0: `VRFV2PlusWrapperConsumerBase`, `IVRFV2PlusWrapper`, `VRFV2PlusClient`.

**Inputs:**

- the twelve per-function records (§1.2) under `audit-context/functions/`;
- the orientation supplied with this synthesis task;
- `DESIGN.md`;
- a direct reading of the source for code that has no record (§1.3).

**Build and deployment context:**

- Compiler: solc 0.8.36, EVM `cancun`, optimizer at 200 runs (`foundry.toml` L7-L10; `hardhat.config.ts` L14-L37).
- Configured networks: Sepolia and Ethereum mainnet, both `chainType: "l1"` (`hardhat.config.ts` L38-L57).
- Dependency pins: `package.json` L27-L30. Vendored file hashes: `dependency-hashes.json`.

**Citation key**

| Prefix | File |
| --- | --- |
| bare `Lnnn` | `packages/contracts/src/Raffle.sol` |
| `RF` | `src/RaffleFactory.sol` |
| `IR` / `IRF` | `src/interfaces/IRaffle.sol` / `src/interfaces/IRaffleFactory.sol` |
| `RC` | `src/libraries/RaffleConstants.sol` |
| `E` / `U` | OZ `token/ERC721/ERC721.sol` / `token/ERC721/utils/ERC721Utils.sol` |
| `RG` / `SE` / `CL` / `M` | OZ `utils/ReentrancyGuard.sol` / `token/ERC20/utils/SafeERC20.sol` / `proxy/Clones.sol` / `utils/math/Math.sol` |
| `VCB` / `IW` | Chainlink `vrf/dev/VRFV2PlusWrapperConsumerBase.sol` / `vrf/dev/interfaces/IVRFV2PlusWrapper.sol` |
| `DESIGN` | `DESIGN.md` (L2 is the whole specification paragraph; L4 is the provenance note) |
| `[NN]` | per-function record `audit-context/functions/NN-*.md` |
| `UA-NN`, `U-NN`, `S-NN`, `W-N`, `CFI-N` | unenforced assumption (§10), open question carried from records (§12.1), open question raised here (§12.2), external-call window (§3.3), cross-function invariant (§6) |

A statement marked **(derived)** is not made by any single record. It combines records, and it cites the records
and lines it rests on.

---

## 1. Inventory

### 1.1 Contracts and roles

| Unit | Role | Mutable state | Notes |
| --- | --- | --- | --- |
| `RaffleFactory` | Ownerless, non-upgradeable factory. It is the only caller allowed to initialize a clone, it acts as operator for the prize escrow, and it keeps the clone registry. | `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle`, guard slot | Immutables: `quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation` (RF L33-L42). Its only state-changing function is `createRaffle` (RF L97-L148). |
| `Raffle` implementation | Supplies the code for every clone. Its own storage is locked by the constructor. | none in use | Constructor sets `initialized = true` and `status = Refunding` (L164-L165). |
| `Raffle` clone (ERC-1167 proxy, deployed with CREATE) | Escrows one prize NFT, tracks five USDC buckets, issues the "raffle.fun Ticket" ERC-721, and consumes Chainlink VRF v2.5 with native payment. | All Raffle storage, the ERC-721 ledger, its own guard slot | Shares the implementation's immutables `factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `i_linkToken` (L55, L58; VCB L34-L35). |
| `IRaffle`, `IRaffleFactory` | ABI, events, errors, NatSpec | none | Trust-model text lives at IR L12-L15 and IRF L7-L9. |
| `RaffleConstants` | Fixed economics, timing and limits | none | See the table below. |

`RaffleConstants` values (RC L12-L42):

| Constant | Value |
| --- | --- |
| BPS (basis-point denominator) | 10_000 |
| Protocol fee | 500 bps |
| Cash-winner share | 8000 bps |
| Entry price | 1_000_000 (one USDC at 6 decimals) |
| Quote-token decimals | 6 |
| Refund batch limit | 100 tickets |
| Maximum sale duration | 30 days |
| Draw-request timeout | 2 days |
| Callback timeout | 2 days |
| VRF callback gas limit | 300_000 |
| VRF request confirmations | 30 |

### 1.2 Per-function records used

| Record | Function | Lines |
| --- | --- | --- |
| [01] | `Raffle.redeemWinningTicket` | L309-L346 |
| [02] | `Raffle._settleWinningTicket`, reached from `settleWinningTicket` (L304-L306) and from `redeemWinningTicket` (L315) | L533-L558 |
| [03] | `Raffle.buyEntries` | L209-L237 |
| [04] | `Raffle.refundTickets` | L349-L372 |
| [05] | `Raffle.enableRefunds` | L276-L301 |
| [06] | `Raffle.fulfillRandomWords`, reached from the inherited `rawFulfillRandomWords` (VCB L101-L107) | L509-L524 |
| [07] | `Raffle.requestDraw` | L240-L273 |
| [08] | `RaffleFactory.createRaffle` | RF L97-L148 |
| [09] | `Raffle.onERC721Received` | L416-L431 |
| [10] | `Raffle.releaseSponsorPrize` | L395-L407 |
| [11] | the `Raffle._update` override, plus the inherited ERC-721 paths that reach it | L497-L502 |
| [12] | `Raffle._isProtocolDestination` | L593-L605 |

### 1.3 Code without a dedicated record

The following code has no record of its own. This dossier describes it from the source and from the records of
its callers and callees.

- `RaffleFactory` constructor (RF L65-L92).
- `RaffleFactory._validateCreateParams` (RF L154-L179). Analysed inside [08].
- `Raffle` constructor (L155-L166).
- `initialize` (L176-L206). Analysed inside [08] and [12].
- `releaseSponsorProceeds` (L375-L382).
- `releaseProtocolFees` (L385-L392).
- `receive` (L171-L173).
- `_transferQuote` (L564-L567). Analysed inside [01], [04] and [12].
- The views `getVrfRequestPrice`, `estimateVrfRequestPrice`, `ticketRange`, `drawRequestDeadline`,
  `callbackDeadline`, `accountedQuoteBalance` and `grossSales` (L436-L475).

### 1.4 Repository facts that limit what can be resolved

- **No tests, scripts, deployment modules or off-chain consumers exist.**
  - DESIGN L4 says none are provided.
  - `foundry.toml` L3-L4 and `hardhat.config.ts` L9 name `test/` and `script/` directories. Neither exists.
  - `package.json` L15 and L22-L25 reference `scripts/check-coverage.mjs`, `slither.config.json`,
    `ignition/modules/RaffleFun.ts` and `scripts/write-deployment.ts`. None exists.
- **The Chainlink wrapper and coordinator source is not vendored.** `node_modules/@chainlink` contains only
  `IVRFV2PlusWrapper.sol`, `VRFV2PlusWrapperConsumerBase.sol`, `VRFV2PlusClient.sol` and
  `LinkTokenInterface.sol` ([06], [07]).
- **No USDC source exists in the repository** ([03]).
- **A grep over `src` finds no `selfdestruct`, `delegatecall`, `balanceOf`, `this.` call or `fallback`.** This
  matches [03], [10] and [12], and was re-run for this synthesis.

---

## 2. Architecture

### 2.1 Deployment topology

```
Deployer ──constructor(quote, wrapper, treasury)──► RaffleFactory   (ownerless; createRaffle is nonReentrant)
                                                     │ immutables: quoteToken, vrfWrapper, protocolTreasury,
                                                     │             raffleImplementation
                                                     │ storage:    raffleCount, raffleById, idByRaffle, isRaffle
                                                     ├─ CREATE @ factory nonce 1   ─► Raffle implementation
                                                     │                                (initialized=true, status=Refunding)
                                                     └─ CREATE @ factory nonce k+1 ─► clone with raffleId k
                                                                                     (ERC-1167 → DELEGATECALL to implementation;
                                                                                      own storage; shared immutables factory,
                                                                                      quoteToken, i_vrfV2PlusWrapper, i_linkToken)
Trusted externals:   USDC (quoteToken); Chainlink VRF v2.5 native wrapper (its coordinator is not vendored)
Untrusted externals: per-raffle prize ERC-721 (chosen by the sponsor); ticket recipients; draw requester;
                     sponsorRecipient
```

**(derived) Nonce labels.** The nonces in the diagram follow from four facts:

- A contract's nonce starts at 1 (EIP-161).
- RF L89 (the implementation) and RF L106 (clones) are the factory's only CREATE operations ([12] coupling 2).
- RF L89 runs once, in the constructor, and uses nonce 1.
- A reverted `createRaffle` rolls back both the `raffleCount` increment (RF L105) and the nonce increment
  ([08], [12]).

So raffle ID k is always deployed at factory nonce k+1. See CFI-12.

### 2.2 Clone ABI surface

- **Inheritance.** `Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase`
  (L28).
- **What Raffle overrides:**
  - `name` and `symbol` (`pure`, L479-L487);
  - `_update` (L497);
  - `fulfillRandomWords` (L509);
  - `onERC721Received` (L416).
- **What Raffle does not override:** `_ownerOf`, `transferFrom`, `safeTransferFrom`, `approve`,
  `setApprovalForAll`, `_msgSender` ([11]).
- **Guarded mutators.** These nine share one reentrancy slot per clone (RG L36-L37):

  | Function | Line |
  | --- | --- |
  | `buyEntries` | L212 |
  | `requestDraw` | L240 |
  | `enableRefunds` | L276 |
  | `settleWinningTicket` | L304 |
  | `redeemWinningTicket` | L309 |
  | `refundTickets` | L349 |
  | `releaseSponsorProceeds` | L375 |
  | `releaseProtocolFees` | L385 |
  | `releaseSponsorPrize` | L395 |

- **Unguarded external entry points:**
  - `initialize` (L176);
  - `onERC721Received` (L416);
  - `rawFulfillRandomWords` (VCB L101);
  - the ERC-721 functions `approve`, `setApprovalForAll`, `transferFrom` and both `safeTransferFrom` overloads
    (E L93-L136);
  - `receive`, which always reverts (L171-L173);
  - views, including the inherited `getBalance`, `getLinkToken`, `i_vrfV2PlusWrapper`, and `supportsInterface`
    (which reports IERC721, IERC721Metadata and IERC165, E L45-L50).

  There is no `fallback`.
- **Fresh clones.** A new clone's guard slot holds 0. The guard treats 0 as "not entered" because it only tests
  for the ENTERED value, 2 (RG L112-L114; [09]).

### 2.3 Lifecycle state machine

```
                         initialize (L205; factory-only, once)
 fresh clone (status 0) ─────────────────────────────────────► AwaitingPrize
                                                                   │ onERC721Received (L428), only inside RF L128
                                                                   ▼
            ┌──────────────────────────────────────────────────  Active  ────────────────────────────────────┐
            │ requestDraw (L252)                                    │ enableRefunds (L299)                    │
            │ E ≤ t < E+2d, totalEntries ≥ 1, fee paid              │ no sales: sponsor any t, or anyone t ≥ E │
            ▼                                                       │ sold:     anyone t ≥ E+2d               ▼
         Drawing ── enableRefunds (L299), anyone, t ≥ R+2d ─────────────────────────────────────────►  Refunding
            │ fulfillRandomWords (L521): wrapper only, t < R+2d, id match, 1 word, not in flight
            ▼
  NftWon (totalEntries ≥ reserveEntries)   or   CashWon (totalEntries < reserveEntries)

  Implementation instance: the constructor writes Refunding (L165). It has no outgoing transition.
  E = endTime, R = drawRequestedAt, t = block.timestamp.
```

| Transition | Written at | Function | Gate | Caller |
| --- | --- | --- | --- | --- |
| deploy → Refunding | L165 | constructor | implementation only | factory constructor (RF L89) |
| fresh → AwaitingPrize | L205 | `initialize` | `!initialized` (L177) and `msg.sender == factory` (L178) | the factory, inside `createRaffle` (RF L109-L121) |
| AwaitingPrize → Active | L428 | `onERC721Received` | status, `msg.sender == prizeToken`, `tokenId`, `from == sponsor`, `operator == factory` (L421-L426) | the prize contract, inside RF L128 ([09]) |
| Active → Drawing | L252 | `requestDraw` | L241-L250 | anyone who pays the fee |
| Drawing → NftWon or CashWon | L521 | `fulfillRandomWords` | VCB L103; L510-L513 | the VRF wrapper |
| Active → Refunding | L299 | `enableRefunds` | L279-L288 | the sponsor or anyone (timing in §7) |
| Drawing → Refunding | L299 | `enableRefunds` | L289-L291 | anyone |

NftWon, CashWon and Refunding are absorbing. Every status writer requires a non-terminal source state (L177,
L241, L279-L294, L422, L511; [01] precondition table; [05] invariant 2).

### 2.4 Function availability by status (clone)

| Function | AwaitingPrize | Active | Drawing | NftWon | CashWon | Refunding |
| --- | --- | --- | --- | --- | --- | --- |
| `initialize` | fresh clone only (factory, once) | no | no | no | no | no |
| `onERC721Received` | prize contract with matching arguments | no | no | no | no | no |
| `buyEntries` | no | while t < E | no | no | no | no |
| `requestDraw` | no | while E ≤ t < E+2d, with at least one entry sold | no | no | no | no |
| `enableRefunds` | no | no sales: sponsor at any t, anyone at t ≥ E. Sold: anyone at t ≥ E+2d. | anyone at t ≥ R+2d | no | no | no |
| `rawFulfillRandomWords` (wrapper only) | ignored | ignored | resolves if L510-L513 all pass, otherwise ignored | ignored | ignored | ignored |
| `settleWinningTicket` | no | no | no | once | once | no |
| `redeemWinningTicket` | no | no | no | ticket owner, once | ticket owner, once | no |
| `refundTickets` | no | no | no | no | no | ticket owners |
| `releaseSponsorProceeds`, `releaseProtocolFees` | (0) | (0) | (0) | once each, after settlement | once each, after settlement | (0) |
| `releaseSponsorPrize` | no | no | no | no | once | once |
| ERC-721 transfers and approvals | (no tickets exist) | yes | yes | yes | yes | yes |

How to read the table:

- **(0):** the function has no status gate. It reverts on a zero balance, and the balance is always zero in that
  status (CFI-2).
- **Ignored:** the callback emits `VrfCallbackIgnored` and returns. It writes no state and does not revert (L514;
  [06]).
- **Wrapper only:** callers other than the wrapper revert at VCB L103.

### 2.5 Asset channels

**USDC** (accounted nominally)

- **Inflow.** `buyEntries` at L224: the payer sends `entryCount × 1e6` to the clone.
- **Outflows.** All go through `_transferQuote` (L564-L567), which screens the destination at payout time:
  - `refundTickets` L369, to the caller;
  - `redeemWinningTicket` L342, to the winner;
  - `releaseSponsorProceeds` L380, to `sponsorRecipient`;
  - `releaseProtocolFees` L390, to `protocolTreasury`.
- **Inflows outside these paths.** Direct transfers, and USDC sent to a future clone address before deployment.
  They create no liability and have no exit ([04], shared state).

**Prize NFT**

- **Inflow.** RF L128: sponsor to clone, moved by the prize contract. Both the acceptance (L422-L423) and the
  check (RF L129) rest on the prize contract's own reports.
- **Outflows.** Neither re-screens the destination.
  - `redeemWinningTicket` L334, to the winner (NftWon).
  - `releaseSponsorPrize` L404, to `sponsorRecipient` (CashWon, Refunding).
- **Inflows outside these paths.**
  - Other NFTs sent with plain `transferFrom`: unaccounted, with no exit (L409-L411).
  - Other NFTs sent with `safeTransferFrom`: rejected (L421-L426).

**Native ETH**

- **Inflow.** `requestDraw` `msg.value`.
- **Outflows.** VCB L84, `paidPrice` to the wrapper; L267, `excess` to `msg.sender`. On success the two add up
  to `msg.value` ([07]).
- **Inflows outside these paths.** Forced sends. A successful call never spends them, and they have no exit
  ([07]).

**Tickets** (these are claims, not escrowed assets)

- Minted at L235.
- Burned at L325 (winner) and L364 (refund).

---

## 3. Actors, trust boundaries and reach

### 3.1 Actor table

Trust labels follow the orientation. "Reaches in turn" lists what an actor's calls go on to execute.

| Actor | Trust | Entrypoints | Reaches in turn | Records |
| --- | --- | --- | --- | --- |
| Factory deployer | trusted | RF constructor | `quoteToken.decimals()` (try/catch); `new Raffle`, whose consumer-base constructor calls `wrapper.link()` (VCB L45); fixes every immutable. No powers after deployment. | none (source) |
| `RaffleFactory` contract | trusted | its own functions | Only caller of `initialize` (L178); acts as prize-escrow operator (RF L128); its registry is read by every clone (L601, L603) | [08], [12] |
| Chainlink VRF wrapper and coordinator | trusted | `rawFulfillRandomWords` | `fulfillRandomWords`, which has no guard and makes no external calls. Only writer of NftWon and CashWon. | [06], [07] |
| USDC | trusted | called at L224 and L566 | If it ever called back, only unguarded functions would be reachable. No callback is expected. | [03], [04] |
| Protocol treasury | trusted, passive | none required | Receives L390 (screened at payout, L565) | [12] |
| Sponsor (`createRaffle` caller) | semi-trusted | `createRaffle`; `enableRefunds` while no entries are sold | Chooses the prize contract, whose code runs inside RF L128 (W1); may close a raffle with no sales at any time (L282) | [05], [08], [09] |
| Sponsor recipient | untrusted, passive | none required | Receives USDC at L380 (screened at release) and the NFT at L404 (not screened at release; plain `transferFrom`, so no receiver hook) | [10], [12] |
| Prize ERC-721 contract | untrusted | calls `onERC721Received` as `msg.sender`; is called at RF L172, L128, L129 and at L334/L335, L404/L405 | Only writer of Active, based on its own report. Answers every custody check. Runs in W1 (clone Active and unguarded), W6 and W10 (clone guarded). | [01], [08], [09], [10] |
| Entry buyer / payer | untrusted | `buyEntries` | USDC pull; ticket mint; recipient hook in W3. Any payer can move `totalEntries` toward `reserveEntries`, including the sponsor, the sponsor recipient or the treasury. | [03] |
| Ticket recipient contract | untrusted | `onERC721Received` callbacks | W3 (clone guard held) or W11 (top-level transfer: guard not held) | [11] |
| Ticket holder | untrusted | `refundTickets`, `redeemWinningTicket`, ERC-721 transfers | USDC payout to itself (screened); prize delivery through the prize contract (W6) | [01], [04], [11] |
| Approved operator / per-token approvee | untrusted | ERC-721 transfers and approvals | Cannot refund or redeem in the same call, but can transfer the ticket to itself and then claim as owner | [01], [04], [11] |
| Draw requester | untrusted | `requestDraw` (payable) | Wrapper request carrying value (W4); full-gas refund call back to itself (W5); chooses the `tx.gasprice` that sets the fee | [07] |
| Permissionless keeper | untrusted | `enableRefunds` (after deadlines), `settleWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize` | Fixed-destination payouts; the prize contract via L404 (W10). Chooses only when these run, never where value goes. | [02], [05], [10] |
| Frontend / indexer | untrusted, advisory | views and events | none. See CFI-16 for flags and events that can run ahead of custody. | [03], [08], [09], [11] |
| Deployer of third-party proxies (not in the orientation) | untrusted | `Clones.clone(raffleImplementation)` from any contract | Proxies that can never be initialized (L178), are not registered, and pass the destination screens as ordinary contracts | [08], [12] |

### 3.2 Guard domains

- **Slots.** Each clone has one guard slot, shared by its nine guarded mutators. The factory has a separate slot
  that guards only `createRaffle`.
- **Guards do not span contracts.**
  - While `createRaffle` runs (factory slot ENTERED), every clone's guarded functions stay callable. That
    includes the new clone, whose slot is 0.
  - While a clone's guarded function runs, the factory's `createRaffle` and every function of every other clone
    stay callable ([08], [09], [11]).
- **Factory getters.** `raffleImplementation()` and `isRaffle()` have no guard (`nonReentrantView` at RG L83 is
  not used). Clone screens therefore keep working while the factory slot is ENTERED ([12]).

### 3.3 External-call windows

Each row is a point where control leaves the contract. "Committed" lists what the enclosing call has already
written. "Reachable" lists what code running at that point can still reach, meaning it is not blocked by a guard
or by a state gate.

| ID | Site | Callee (trust) | Guards during the call | Committed before the call | Reachable from inside | Records |
| --- | --- | --- | --- | --- | --- | --- |
| W1 | RF L128 `prize.safeTransferFrom` | prize contract (untrusted) | factory ENTERED; new clone 0 | `raffleCount`; registry including `isRaffle[clone]`; clone configuration; `AwaitingPrize`. After L428 runs: `Active`. | `onERC721Received` (the only writer of Active). Once Active: `buyEntries` (payer needs an allowance to the new clone); ticket ERC-721 functions; `enableRefunds` called from the sponsor address, then `releaseSponsorPrize`; all functions of other clones; factory getters. Not reachable: `createRaffle`. Reverting: `requestDraw` and `enableRefunds` from anyone except the sponsor (t < E). | [08], [09], [05], [10] |
| W2 | L224 `USDC.transferFrom` | USDC (trusted) | clone ENTERED | Nothing from this purchase; L230-L233 come after. | Unguarded functions only. No callback is expected. [05] notes that the guard is the only thing stopping a sponsor `enableRefunds` during the first purchase's pull. | [03], [05] |
| W3 | L235 → E L289 → `recipient.onERC721Received` | ticket recipient (untrusted) | clone ENTERED | Totals, range and pot (L230-L233); ticket owner (E L240) | Ticket ERC-721 functions (it can move the new ticket before L236 emits); other clones; `createRaffle`, unless this frame is nested inside W1 | [03], [11] |
| W4 | VCB L84 `wrapper.requestRandomWordsInNative{value}` | wrapper (trusted) | clone ENTERED | `Drawing`; `drawRequestedAt`; `_requestInFlight = true`. `vrfRequestId` is still 0. | A synchronous `rawFulfillRandomWords` is ignored at L511. | [07], [06] |
| W5 | L267 raw `call{value: excess}` to `msg.sender` (all gas, empty calldata) | draw requester (untrusted) | clone ENTERED | `Drawing`; `drawRequestedAt`; `vrfRequestId`; `_requestInFlight = false` | Unguarded ticket functions; other clones; `createRaffle`. A matching wrapper callback arriving here would be accepted by L510-L513; nothing in the repo excludes it (UA-26, UA-30). | [07], [06], [11] |
| W6 | L334 `prize.transferFrom`; L335 `ownerOf` (STATICCALL) | prize contract (untrusted) | clone ENTERED | Inline settlement (if it ran); `winnerRecipient`; `winnerRedeemed`; the burn; `prizeClaimed` | Unguarded functions on other tickets; other clones; `createRaffle`. `onERC721Received` reverts on status; `rawFulfillRandomWords` would be ignored. | [01], [11] |
| W7 | L566 via L342, `USDC.transfer` to the winner | USDC (trusted) | clone ENTERED | `winnerProceeds = 0`; the burn; flags | none expected | [01] |
| W8 | L566 via L369, `USDC.transfer` to the refunding owner | USDC (trusted) | clone ENTERED | The burns; the liability debit | none expected | [04] |
| W9 | L566 via L380 or L390 | USDC (trusted) | clone ENTERED | The bucket set to zero | none expected | [12] |
| W10 | L404 `prize.transferFrom`; L405 `ownerOf` | prize contract (untrusted) | clone ENTERED | `prizeClaimed = true` | Same as W6 | [10], [11] |
| W11 | E L135 → `recipient.onERC721Received`, after a ticket `safeTransferFrom` | ticket recipient (untrusted) | Whatever the enclosing frame holds. For a top-level transfer, the clone guard is not entered. | Ownership already moved; approval cleared | For a top-level transfer: every clone function, including guarded ones, as the new owner (it can refund or redeem inside the callback). | [11], [01], [05] |
| W12 | RF L172 `supportsInterface`; RF L129 `ownerOf`; L335 and L405 `ownerOf` | prize contract (untrusted, STATICCALL) | n/a | n/a | Read-only. It can revert, burn gas, or return any value. | [08], [01], [10] |
| W13 | factory getters (L601, L603); wrapper quotes (L437, L442, VCB L82); `link()` (VCB L45, implementation deployment only) | trusted (STATICCALL, except `link()` during construction) | n/a | n/a | n/a | [12], [07] |

### 3.4 Transitive reach

- **(derived) Registry growth.** `RaffleFactory.createRaffle` is the only operation that changes state every
  clone shares (`isRaffle`). Untrusted code can call it from any window except W1, because the factory guard is
  per factory and only W1 runs under it ([08]; [12] coupling 2; RF L97).
- **From W1.** Code cannot call `createRaffle`, but it can act on the new clone as an ordinary user would, with
  the clone Active and its guard open.
- **No clone calls another raffle.** Clones call only:
  - USDC;
  - the wrapper;
  - their own prize contract;
  - the factory getters;
  - the `requestDraw` caller (empty calldata);
  - ERC-721 receiver hooks.

  ([11] coupling 1; [12] coupling 4.) Interaction between clones therefore happens only through untrusted actors
  and the shared registry.

---

## 4. State model

### 4.1 Factory

| State | Writers | Readers | Cross-function meaning |
| --- | --- | --- | --- |
| `quoteToken`, `vrfWrapper`, `protocolTreasury` (immutable) | RF L85-L87 (constructor) | RF L114, L143-L144, L158, L164-L165. Clones receive `quoteToken` and the wrapper as implementation immutables through RF L89. | Identical in every clone. `initialize` copies the treasury into each clone's storage (L199). |
| `raffleImplementation` (immutable) | RF L91 | RF L106, L159, L166; every clone at L601 | (derived) Equals CREATE(factory, nonce 1). |
| `raffleCount` | RF L105 (`++`) | getter | Number of committed raffles. (derived) The next clone address is CREATE(factory, raffleCount + 2) (CFI-12). |
| `raffleById`, `idByRaffle`, `isRaffle` | written only at RF L123-L125 | RF L159, L166; every clone at L603 | A bijection over IDs 1..`raffleCount` at committed states. Only grows. Already true for the in-flight clone during W1 (CFI-13). |
| guard slot | RF L97 | RF L97 | Blocks only a nested `createRaffle`. |

### 4.2 Clone configuration (write-once)

| State | Writer | Readers | Notes |
| --- | --- | --- | --- |
| `initialized` | L164 (implementation), L179 | L177 | One-shot. Third-party proxies can never set it (L178). |
| `sponsor` | L197 | L282 (untimed close of a raffle with no sales), L423 (expected `from` of the prize transfer) | The `createRaffle` caller. Screened at L187. Never paid. |
| `sponsorRecipient` | L198 | L379 (screened again at L565), L402 (not screened) | For the NFT path, it is screened only at creation (RF L163-L169, L193). |
| `protocolTreasury` | L199 | L389 (screened at L565) | Copied from the factory immutable (RF L114). |
| `prizeToken`, `prizeTokenId` | L200-L201 | L332-L335, L404-L406, L422; `prizeToken` also at L498 and L565 | The prize contract is itself a protocol destination for this clone (L600). |
| `raffleId` | L202 | getter | none |
| `reserveEntries` | L203 | L521 | At least 1 (RF L178). No upper bound. `initialize` stores it without checking ([06]). |
| `endTime` | L204 | L216, L242, L281, L459 | Lies in (creation, creation + 30 days] (RF L100-L104). |

### 4.3 Sale and ticket state

**`totalEntries`, `ticketCount`, `_ticketRanges`** ([03])

- **Writers:** L230-L232 only, inside `buyEntries`, which requires Active and t < E.
- **Readers:**
  - L219, L226-L227, L243, L280, L474, L518, L521;
  - ranges are read through `ticketRange` (L451-L455) at L362 and L580.
- **Invariants:**
  - The ranges partition [1, totalEntries].
  - Ticket IDs run from 1 to `ticketCount`. ID 0, and any ID above `ticketCount`, reads as (0,0).
  - Ranges survive burns.
  - All three are frozen once t ≥ E.

**ERC-721 ledger** ([11])

- **Writers:**
  - owners at E L240;
  - balances at E L230 and E L236;
  - token approvals at E L227 and E L398;
  - operator approvals at E L416.

  These run through `_safeMint` (L235), `_burn` (L325, L364) and the inherited transfers and approvals.
- **Readers:**
  - ownership at L320 and L359;
  - authorization at E L164-L187.
- **Invariants:**
  - Every recipient is screened at mint and transfer (L498).
  - There is no status gate.
  - Ownership is read only at L320 and L359, and each read is followed by a burn with no external call in
    between.

### 4.4 Draw and resolution state

| State | Writer | Readers | Invariant |
| --- | --- | --- | --- |
| `drawRequestedAt` | L253 | L272; L464 (through `callbackDeadline`, called from L272, L290, L512) | Write-once. Lies in [E, E+2d), so it is at least 1 ([07]). |
| `_requestInFlight` | L254, L260 | L511 | True only during VCB L84. It cannot persist past a transaction ([06], [07]). |
| `vrfRequestId` | L259 | L511, L514 | Write-once. The value is not validated (UA-22, UA-29). |
| `winningEntry` | L519 | L581 | In [1, totalEntries] once resolved; 0 before. |
| `resolvedAt` | L520 | none in the contract | 0 before resolution. |

### 4.5 Accounting buckets

| Bucket | Increase | Decrease or reclassification | Readers |
| --- | --- | --- | --- |
| `unsettledPot` | L233: `+= n·1e6` | L297 moves it into the refund liability; L553 moves it into the three claim buckets | L296, L469, L539 |
| `remainingRefundLiability` | L298: set equal to the pot, once | L368: checked `-=` | L370, L469 |
| `winnerProceeds` | L548: set to 80%, once | L341: set to 0 | L339, L469 |
| `sponsorProceeds` | L554: set to the remainder, once | L378: set to 0 | L376, L469 |
| `protocolFees` | L555: set to 5%, once | L388: set to 0 | L386, L469 |

`accountedQuoteBalance()` is the sum of the five buckets (L468-L470). No code reads the clone's USDC
`balanceOf` ([02], [03]).

### 4.6 Settlement, redemption and prize flags

| Flag | Writer | Readers | Gate on the writer |
| --- | --- | --- | --- |
| `settlementComplete`, `winningTicketId` | L551, L552 | L314, L316-L317, L534 | NftWon or CashWon; once |
| `winnerRedeemed` | L324 | L310 | NftWon or CashWon; ticket owner; once |
| `winnerRecipient` | L323 | getter only | same as `winnerRedeemed` |
| `prizeClaimed` | L331 (NftWon), L403 (CashWon or Refunding) | L330, L400 | Status determines which of the two writers can run ([01], [10]) |

### 4.7 External and implicit state

| State | Held in | Changed by | Read by |
| --- | --- | --- | --- |
| Clone USDC balance | `quoteToken` | L224 (in), L566 (out), any third-party transfer | nothing in `src` |
| Prize custody | `prizeToken` | RF L128, L334, L404, and the prize contract itself | RF L129, L335, L405, all answered by the prize contract |
| Clone native balance | chain | `requestDraw` (transient), forced sends | the `getBalance` view only |
| Code at a destination address | chain | contract deployment, including RF L106 | L602, U L32, RF L184 |
| Block timestamp | chain | n/a | L216, L242, L245, L253, L281-L291, L512, L520, RF L99 |

### 4.8 Bucket values by lifecycle phase (derived)

n = `totalEntries` and P = 1_000_000. "Live entries" is the sum of the entry counts of tickets that have not been
burned.

| Phase | `unsettledPot` | `remainingRefundLiability` | `winnerProceeds` | `sponsorProceeds` | `protocolFees` |
| --- | --- | --- | --- | --- | --- |
| AwaitingPrize | 0 | 0 | 0 | 0 | 0 |
| Active or Drawing | n·P | 0 | 0 | 0 | 0 |
| NftWon or CashWon, before settlement | n·P | 0 | 0 | 0 | 0 |
| NftWon, after settlement | 0 | 0 | 0 | 950_000·n until released, then 0 | 50_000·n until released, then 0 |
| CashWon, after settlement | 0 | 0 | 800_000·n until redeemed, then 0 | 150_000·n until released, then 0 | 50_000·n until released, then 0 |
| Refunding | 0 | P × live entries | 0 | 0 | 0 |
| Implementation instance | 0 | 0 | 0 | 0 | 0 |

This table rests on:

- the only nonzero writers, and settlement running once ([02]);
- L233 being the only increment ([03]);
- the liability writers ([04], [05]);
- L341 ([01]);
- terminal states being absorbing (CFI-1).

---

## 5. End-to-end flows

### F0. Deployment (no record; read from source)

1. The deployer calls `RaffleFactory(quoteToken_, vrfWrapper_, protocolTreasury_)`.
2. Checks run:
   - code exists at `quoteToken_` and `vrfWrapper_` (RF L66-L67, L183-L185);
   - the treasury is non-zero (RF L68);
   - `decimals() == 6`, read inside try/catch (RF L70-L78);
   - the treasury is not the factory, the quote token or the wrapper (RF L80-L83).
3. The three immutables are stored (RF L85-L87).
4. `new Raffle(quoteToken_, vrfWrapper_)` runs (RF L89):
   - the wrapper must be non-zero (L610-L613);
   - the consumer-base constructor calls `wrapper.link()` and stores `i_linkToken` and `i_vrfV2PlusWrapper`
     (VCB L43-L46);
   - the reentrancy guard sets the implementation's own slot to 1 (RG L58-L60);
   - the constructor body requires a non-zero `msg.sender` and quote token (L159), sets `factory` (L161) and
     `quoteToken` (L162), and locks storage (L164-L165).
5. The treasury must differ from the implementation (RF L90). `raffleImplementation` is stored (RF L91).

### F1. Creation (`createRaffle`); records [08], [09], [12]

| Step | Code | State change | External interaction |
| --- | --- | --- | --- |
| 1 | RF L97 | factory guard ENTERED | none |
| 2 | RF L98 → L154-L179 | none | `prize.supportsInterface(IERC721)` STATICCALL (W12) |
| 3 | RF L99-L104 | none (checks endTime is in (now, now + 30 d]) | none |
| 4 | RF L105 | `raffleCount++` | none |
| 5 | RF L106 | new clone deployed (CREATE) | none |
| 6 | RF L109-L121 → L176-L206 | clone: `initialized`, configuration, `AwaitingPrize` | factory getters, by STATICCALL, for the screens at L187, L190, L193 |
| 7 | RF L123-L125 | `raffleById`, `idByRaffle`, `isRaffle = true` | none |
| 8 | RF L128 | prize ledger (external) | `prize.safeTransferFrom(sponsor, clone, id)` (W1). Expected hook: `onERC721Received(factory, sponsor, id)` → L428 sets Active, L429 emits `PrizeDeposited`. |
| 9 | RF L129-L131 | none | `prize.ownerOf(id) == clone`, STATICCALL, answered by the prize contract |
| 10 | RF L132-L134 | none | `clone.status() == Active` |
| 11 | RF L136-L147 | emits `RaffleCreated` | none |

- **Postconditions at the transaction boundary:**
  - the registry is consistent;
  - the clone's configuration matches the event;
  - the prize contract answered `ownerOf == clone`;
  - the clone reports Active.
- **Not postconditions:** `totalEntries`, the ticket count, and any balance ([08]).

### F2. Sale (`buyEntries`); records [03], [11], [12]

1. Guard taken. Checks:
   - status is Active (L215);
   - t < E (L216);
   - recipient ≠ 0 (L217);
   - n ≥ 1 (L218);
   - no `totalEntries` overflow (L219-L221).
2. Pull n·P USDC from `msg.sender` (L224, W2).
3. Write the range, counters and pot (L226-L233).
4. `_safeMint` → `_update`, which screens the recipient (L498, using factory STATICCALLs) → ledger write (E L240).
5. Recipient hook (W3).
6. Emit `TicketPurchased` (L236).

### F3. Draw request (`requestDraw`); record [07]

1. Guard taken. Checks:
   - status is Active (L241);
   - E ≤ t (L242);
   - n ≥ 1 (L243);
   - t < E+2d (L244-L247).
2. Quote the fee and require `msg.value` to cover it (L249-L250).
3. Write `Drawing`, `drawRequestedAt` and `_requestInFlight = true` (L252-L254).
4. Re-quote, then send the request with value (VCB L82-L84, W4).
5. Require `paidPrice ≤ msg.value` (L258).
6. Write `vrfRequestId` and `_requestInFlight = false` (L259-L260).
7. Refund the excess to the caller (L262-L270, W5).
8. Emit `DrawRequested` (L272).

### F4. Resolution; record [06]

1. The wrapper calls `rawFulfillRandomWords`. The only check there is `msg.sender == wrapper` (VCB L101-L107).
2. The callback is ignored unless all of these hold (L510-L516):
   - `!_requestInFlight`;
   - status is Drawing;
   - `id == vrfRequestId`;
   - exactly one word;
   - t < R+2d.
3. Otherwise:
   - `winningEntry = word % n + 1` (L518-L519);
   - `resolvedAt` is recorded (L520);
   - `status = NftWon` if `n ≥ reserveEntries`, else CashWon (L521);
   - `RaffleResolved` is emitted.

### F5. Refund branch; records [05], [04], [10]

1. `enableRefunds` (timing in §7) moves `unsettledPot` into `remainingRefundLiability` and sets Refunding
   (L296-L300).
2. After that, two independent paths run in any order:
   - **Refunds.** Ticket owners call `refundTickets` with 1 to 100 IDs they own. Each call burns the tickets,
     debits the liability (checked) and pays the caller (L349-L372).
   - **Prize return.** Anyone calls `releaseSponsorPrize`, which sends the NFT to `sponsorRecipient`
     (L395-L407).
3. There is no deadline and no sweep.

### F6. Win branch; records [02], [01], [10], [12]

- **Settlement.**
  - Anyone calls `settleWinningTicket(id)`, or the ticket owner redeems and settlement runs inline (L314-L315).
  - `_settleWinningTicket` checks that the ticket's range contains the winning entry (L538), splits the pot
    exactly (L539-L555) and records `winningTicketId`.
- **Releases.**
  - After settlement, anyone may call `releaseSponsorProceeds` or `releaseProtocolFees`. Neither has a status
    gate; each only requires a nonzero balance.
  - Each pays its fixed recipient through `_transferQuote`, which screens the recipient at payout time (L565).
- **Redemption.** The current owner of the winning ticket calls `redeemWinningTicket`:
  1. inline settlement, if not already settled;
  2. owner check (L320-L321);
  3. writes `winnerRecipient` and `winnerRedeemed`, and burns the ticket (L323-L325);
  4. NftWon: sets `prizeClaimed`, calls `prize.transferFrom`, then checks `ownerOf` (L329-L337, W6);
  5. CashWon: sets `winnerProceeds = 0`, then calls `_transferQuote(winner)` (L339-L342, W7).
- **CashWon prize return.** Anyone may call `releaseSponsorPrize`, before or after settlement or redemption
  (L397).
- **Ordering constraints:**
  - the releases need settlement first;
  - redemption implies settlement;
  - neither the releases nor settlement need redemption;
  - in CashWon, the prize return is independent of everything else.

### F7. Ticket circulation; record [11]

- **Transfers.**
  1. An owner, operator or per-token approvee calls `transferFrom` or `safeTransferFrom`, in any status.
  2. `_update` runs the destination screen, then OZ authorization, then the ledger write.
  3. `safeTransferFrom` then calls the recipient hook (W11).
- **Approvals.**
  - `approve` may be called by the owner or an operator.
  - `setApprovalForAll` may be called by anyone for their own address.
  - Neither approval target is screened.

---

## 6. Cross-function invariants (derived)

Unless stated otherwise, each invariant holds at every committed state.

**CFI-1: The lifecycle is a write-once DAG with one writer per transition.**

- `status` is written only at L165, L205, L252, L299, L428 and L521. Each transition in §2.3 has exactly one
  writing line.
- Every writer's gate excludes NftWon, CashWon and Refunding.
- AwaitingPrize is written once per clone (L177-L179) and left once, since L428 requires it.
- Consequences:
  - each state is entered at most once per clone;
  - the three terminal states are absorbing.
- Every one-shot property builds on this DAG plus a local flag: a single draw request, a single resolution, a
  single settlement, a single redemption and a single prize release.
- Sources: [01] precondition table; [05] invariant 2 and coupling 4; [06] invariants 4-5; [07] invariant 5;
  [09] invariant 2 and coupling 2.

**CFI-2: Bucket values are fixed by status, settlement and releases.**

The full table is in §4.8. In addition:

- `winnerProceeds > 0` if and only if status is CashWon, `settlementComplete` is true and `winnerRedeemed` is
  false.
- `sponsorProceeds > 0` implies `settlementComplete`. It stays above 0 from settlement until the single
  successful `releaseSponsorProceeds`. The same holds for `protocolFees` and `releaseProtocolFees`.
- `remainingRefundLiability > 0` implies status is Refunding.
- `unsettledPot == grossSales()` while status is not Refunding and settlement has not happened. Otherwise
  `unsettledPot == 0`.

Sources:

- [02]: the only nonzero writers are L548, L554 and L555; settlement is one-shot (L534, L551); each amount is
  above 0 for n ≥ 1.
- [03]: L233 is the only increment; the pot and the entry count move together.
- [04]: the liability writers are L298 and L368; in Refunding, `accountedQuoteBalance` reduces to the liability.
- [05]: L296-L298.
- [01]: L341 runs in the same call as L324.

**CFI-3: Accounting changes at exactly five places, and clone code never pays out anything else.**

- Where `accountedQuoteBalance()` changes:
  - **Increase:** only at L233 (`+n·P`), right after the nominal pull at L224.
  - **Decreases:** only at L341, L368, L378 and L388. Each is followed, in the same call, by a nominal transfer
    of the same amount (L342, L369, L380, L390).
  - **Reclassifications:** L296-L298 and L539-L555 move value between buckets without changing the total.
- Suppose USDC moves exactly the nominal amounts. That premise is unenforced: UA-05, UA-09, UA-11, UA-15,
  UA-16 and UA-18. Then `balanceOf(clone) − accountedQuoteBalance()` is never reduced by clone code. It grows
  only through transfers that bypass the clone, and no code path reads or pays it.
- The same pattern holds for other assets:
  - a successful `requestDraw` never spends a forced native balance ([07]);
  - NFTs other than the configured prize, sent with plain `transferFrom`, stay unaccounted (L409-L411).
- Sources: [02] conservation coupling; [03] accounted-versus-actual coupling; [04] solvency coupling;
  [05] invariant 7; [07] native-balance coupling.

**CFI-4: The ticket ledger and the liabilities correspond phase by phase.**

- **Active or Drawing.** Every minted ticket is live, because neither burn site is reachable (L325 needs NftWon
  or CashWon; L364 needs Refunding). Total entries × P equals `unsettledPot`.
- **Refunding.**
  - After every successful call, `remainingRefundLiability` equals P × the entries of live tickets.
  - It reaches 0 exactly when every ticket has been burned.
  - The checked subtraction at L368 cannot underflow.
- **NftWon or CashWon.**
  - The winning ticket is live if and only if `winnerRedeemed` is false.
  - Every other ticket stays live, transferable and without any claim forever, because no burn site applies to
    it.
- **Transfers.** Moving a ticket never changes an accounting term. Value is bound to the stored range, not to the
  owner.
- Sources: [03] partition; [04] refund conservation, items (a)-(f); [01] coupling 3; [11] coupling 2.

**CFI-5: The claim flags form a lattice, and status alone chooses the prize's single exit.**

- `winnerRedeemed` implies `settlementComplete`, which implies status is NftWon or CashWon.
- **NftWon:** `prizeClaimed` if and only if `winnerRedeemed`. Both are written in the same successful call
  (L324, L331), and `releaseSponsorPrize` is excluded (L397).
- **CashWon:** `prizeClaimed` (L403) and `winnerRedeemed` (L324) are independent.
- **Refunding:** `winnerRedeemed` and `settlementComplete` are both false. `prizeClaimed` can only be set at L403.
- **AwaitingPrize, Active, Drawing:** all four flags are false, and no function moves the prize.
- **Prize exits:** NftWon only through L334; CashWon and Refunding only through L404.
- Sources: [01] invariants 11-13 and couplings 2-4; [10] invariants 1-3 and coupling 1; [02] prize-custody
  coupling.

**CFI-6: Settlement is deterministic and does not depend on the caller.**

- Exactly one ticket ID can pass the containment check (L579-L585, [02]). This follows from three facts:
  - the ticket ranges partition [1, n] ([03]);
  - `winningEntry` lies in [1, n], and n is frozen ([06]);
  - the containment check accepts only a range that contains `winningEntry`.
- The ID stays provable: ranges survive burns (L138), and nothing is burned before a terminal state.
- Whoever settles, the stored outcome is the same. Only the `settler` field of the event changes.
- Redemption is bound to the same ID (L316-L317).
- Anyone can find the ID from public views: the `winningEntry` getter, `ticketRange` (L451-L455) and
  `ticketCount`.
- Sources: [02] (P3, P4, settler coupling); [03] partition coupling; [06] coupling 1; [01] precondition 3.

**CFI-7: The economics are exact.**

| Amount | Value |
| --- | --- |
| Gross pot | n · 1e6 |
| Protocol fee | 50_000 · n |
| Sponsor share, NftWon | 950_000 · n |
| Winner share, CashWon | 800_000 · n |
| Sponsor share, CashWon | 150_000 · n |
| Refund per ticket | entries · 1e6 |

- For n ≥ 1, every allocation is above 0, and the three allocations add up to the gross pot.
- `Math.mulDiv` always takes its exact `high == 0` path here.
- Sources: [02] (mulDiv paths, exact amounts); [04] (refund term); RC L12-L21.

**CFI-8: Shared deadline functions partition time, and the time horizon is bounded.**

- **Three pairs share a deadline.** In each pair a given block lands on exactly one side.

  | Before the deadline | At or after the deadline | Shared deadline |
  | --- | --- | --- |
  | `buyEntries` at t < E | `enableRefunds` on a raffle with no sales, called by anyone other than the sponsor, at t ≥ E | `endTime` (L216 vs L281-L283) |
  | `requestDraw` at t < E+2d | `enableRefunds` on a sold raffle at t ≥ E+2d | `drawRequestDeadline` (L245 vs L287) |
  | callback accepted at t < R+2d | `enableRefunds` from Drawing at t ≥ R+2d | `callbackDeadline` (L512 vs L291) |

- **The sponsor's exit.** The sponsor's untimed exit for a raffle with no sales (L282) overlaps the sale window
  in time. Only state separates them: any purchase closes it.
- **Horizon.** At any t ≥ E + 4d, some caller can move every post-escrow clone into a terminal state, because
  R < E + 2d. Since E ≤ creation + 30 d, every clone is terminal, or can be made terminal by anyone, by
  creation + 34 d.
- **No deadlines in terminal states.**
  - Nothing transitions automatically.
  - No terminal-state function reads `block.timestamp` (L304-L407).
  - Redemption, refunds and releases therefore have no deadline.
- Sources: [05] window map and couplings 1 and 6; [06] coupling 2; [07] time-partition coupling; [03] L216;
  [08] time coupling.

**CFI-9: Each clone makes at most one VRF request, paid for by the requester alone.**

- Active is entered once, so `requestDraw` succeeds at most once.
- `vrfRequestId` and `drawRequestedAt` are each written once.
- At most one callback can match, so L521 runs at most once.
- The fee comes only from `msg.value` (VCB L84; L258). The pot is untouched.
- If Drawing times out:
  - `enableRefunds` leaves `vrfRequestId` and `drawRequestedAt` unchanged;
  - later callbacks are ignored by the status check (L511);
  - no code path returns the fee (U-09).
- Sources: [06] coupling 3; [07] single-request coupling; [05] open question 1.

**CFI-10: Untrusted calls come after all writes, and unguarded writers are gated by state.**

- **Untrusted calls.** Every call into untrusted code (W1, W3, W5, W6, W10, W11, and the read-only W12) happens
  after the enclosing function's last storage write. Only STATICCALL checks and event emission follow.
- **Calls that precede writes.** Two calls come before some of their enclosing function's writes, and both go to
  trusted dependencies:
  - the USDC pull at L224, which comes before L230-L233;
  - the wrapper request at VCB L84, which comes before L259-L260.

  Both run with the clone guard held. W4 is also covered by `_requestInFlight`.
- **Unguarded entry points that write state:**

  | Entry point | Writes | Why no guarded frame is affected |
  | --- | --- | --- |
  | `initialize` | configuration | Factory-only and once, before any untrusted code touches the clone |
  | `onERC721Received` | status | Needs AwaitingPrize, and no guarded frame can run in AwaitingPrize ([09]) |
  | `rawFulfillRandomWords` | resolution state | Needs the wrapper and Drawing. The only guarded frame that runs in Drawing is `requestDraw`: W4 is neutralized by `_requestInFlight`, W5 is not covered by Raffle code. |
  | ERC-721 transfers and approvals | ticket ledger only | Raffle reads the ledger only at L320 and L359, and both burn before any external call |

- **Result.** The only point where an unguarded state writer can run inside a guarded frame, after that frame's own
  checks, is W5. `requestDraw` writes nothing after W5.
- Sources: [01], [03], [07] ordering invariants; [06] outcome 6; [09] reentrancy-guard notes; [10] callees;
  [11] callback-window table; [04] coupling 5.

**CFI-11: Every prize-custody fact comes from the prize contract.**

- **Who answers each custody check.** All of these are answered by the sponsor-chosen prize contract:
  - escrow acceptance, where L422-L423 compare arguments that the prize contract itself supplies;
  - escrow verification (RF L129);
  - both delivery checks (L335, L405).
- **The clone's own calls.** The clone never grants an approval on the prize. Its only calls on it are
  `transferFrom` and `ownerOf` ([10]).
- **Two trust models give different results:**
  - Under IR L14-L15 (honest prizes), custody runs from RF L128 until L334 or L404.
  - Under DESIGN L2 (untrusted prizes), no on-chain observation establishes custody at any point.
- **Combined with CFI-5 and CFI-9.**
  - In NftWon, the prize contract accepting the L334 transfer is the only exit for the NFT.
  - The 95% and 5% USDC allocations become releasable at settlement regardless. DESIGN L2 describes this
    independence as intended; UA-07 records the opposite as an assumption (see §9.1).
- Sources: [09] coupling 1; [08] assumptions 1-3 and coupling 2; [01] coupling 5; [10] coupling 2.

**CFI-12: Destination screening happens at a point in time, only tightens, and is predictable.**

- **Where the predicate runs:**
  - at `initialize`, for the sponsor, the treasury and `sponsorRecipient`;
  - at every ticket mint or transfer (`_update`);
  - at every USDC payout (`_transferQuote`).
- **Where it does not run:**
  - NFT deliveries. L334 relies on the screen that ran when the holder received the ticket. L404 relies on L193.
  - The native refund (L267).
  - Approvals.
- **How the result can change.** For a fixed clone and address, the result can only change from false to true.
  That happens only when this factory deploys a clone at that address. Before that, the address had no code and
  no private key ([12] coupling 2).
- **(derived) Clone addresses are predictable.** At every committed state, `raffleById[k] == CREATE(factory,
  k+1)`, and the next clone will be `CREATE(factory, raffleCount + 2)`. This follows from four facts:
  - EIP-161 starts the factory's nonce at 1;
  - RF L89 uses nonce 1;
  - RF L106 is the only other CREATE;
  - a reverted `createRaffle` rolls back both `raffleCount` (RF L105) and the nonce.

  Every future clone address can therefore be computed from public state.
- **Consequences the records describe, by outflow:**
  - An owner screened when receiving a ticket is never screened again ([11], [12]).
  - If `sponsorRecipient` or the treasury later becomes a registered clone, USDC releases to it revert at L565.
    The NFT release at L404 does not screen ([10] coupling 3; [12] coupling 4).
  - If the treasury equals a future clone's address, that clone's `initialize` reverts at L190. The nonce does
    not advance, so every later `createRaffle` targets the same address ([08] open question 1; [12] coupling 4).
- Sources: [11] coupling 1; [12] couplings 1-5; [03] open question 2; [04] coupling 3; [10] coupling 3; [08].

**CFI-13: The registry is consistent, only grows, and is the only mutable state shared across clones.**

- At committed states, the set of addresses with `isRaffle` true equals {`raffleById[k]` : 1 ≤ k ≤ `raffleCount`},
  and `idByRaffle` is the inverse. All three are written together at RF L123-L125 and nowhere else.
- During W1, the in-flight clone is already in all three maps. Compare IRF L138.
- `createRaffle` can be called from every untrusted window except W1, because of the factory guard. The registry,
  and with it every clone's screen, can therefore grow in the middle of another clone's transaction.
- Sources: [08] postconditions and coupling 1; [12] callee notes; §3.4.

**CFI-14: Claims are bearer claims bound to ranges.**

- **Who holds the rights.** Refund and redemption rights belong to whoever `ownerOf` returns at call time
  (L320-L321, L359-L360).
- **Operators and approvees.** They cannot claim in the same call, but they can transfer the ticket to themselves
  first.
- **Approval lifetimes:**
  - operator approvals are keyed by owner and survive transfers (E L416);
  - every transfer clears the per-token approval (E L227).
- **Value.** Value is bound to the stored range (L362-L363, L579-L585), so moving a ticket never changes the
  accounting.
- Sources: [01] coupling 6; [04] coupling 6; [11] couplings 2 and 4.

**CFI-15: The implementation and third-party proxies are inert.**

- **The implementation** is locked at Refunding and already initialized:

  | Call | Result |
  | --- | --- |
  | `initialize` | reverts at L177 |
  | `buyEntries` | reverts at L215 |
  | `requestDraw` | reverts at L241 |
  | `enableRefunds` | reverts at L293 |
  | `settleWinningTicket` | reverts at L536 |
  | `redeemWinningTicket` | reverts at L312 |
  | `refundTickets` | reverts at L359 |
  | `releaseSponsorProceeds` | reverts at L377 |
  | `releaseProtocolFees` | reverts at L387 |
  | `releaseSponsorPrize` | reverts at L404 (call to `address(0)`) |
  | `onERC721Received` | reverts at L422 |
  | ticket transfers | revert (no tickets exist) |
  | `setApprovalForAll` | succeeds; writes only the implementation's own operator map (derived from E L105-L107 and E L409-L418) |
  | wrapper callback | emits `VrfCallbackIgnored` only |

- **Third-party ERC-1167 proxies of the implementation:**
  - can never be initialized (L178);
  - stay AwaitingPrize with `prizeToken == 0`;
  - cannot accept a prize (L422);
  - are not registered;
  - are not on the denylist ([08] coupling 3; [12] coupling 5).
- Sources: [01], [04], [05]; [10] invariants 8-9; [11] coupling 5; [12] coupling 6.

**CFI-16: Observable flags and events can run ahead of custody or differ from it.**

| # | What can be observed | Source |
| --- | --- | --- |
| 1 | `isRaffle(newClone)` is true from RF L125, before the escrow at RF L128-L134 | [08], [12] |
| 2 | `PrizeDeposited` (L429) and `RaffleCreated` (RF L136) are emitted on the prize contract's reports | [09] |
| 3 | `TicketPurchased` logs can come before `RaffleCreated`, from purchases made inside W1 | [08], [09] |
| 4 | `TicketPurchased.recipient` can differ from the owner at return; `Transfer` logs from W3 come before `TicketPurchased` | [03], [11] |
| 5 | A synchronous ignored callback emits `VrfCallbackIgnored` before `DrawRequested`. A resolving callback during W5 would emit `RaffleResolved` before `DrawRequested`. | [07], [06] |
| 6 | During W6, `winnerRedeemed`, `prizeClaimed` and `winnerRecipient` already read as set, and `ownerOf(winning ticket)` reverts, all before delivery | [01] |
| 7 | During W10, `prizeClaimed` reads true before delivery | [10] |
| 8 | `WinningTicketRedeemed` and `SponsorPrizeReleased` rest on the prize contract's `ownerOf` answer | [01], [10] |
| 9 | Clearing an approval on transfer emits no `Approval` event (E L227) | [11] |

**CFI-17: Who decides the outcome.**

- L521 picks NftWon or CashWon by comparing two numbers:
  - `reserveEntries`, chosen by the sponsor (at least 1, no upper bound);
  - `totalEntries`, which any payer can raise, including the sponsor, the sponsor recipient and the treasury.
- The VRF word alone picks the winning entry (`word % n + 1`, L518). Any `uint256` is accepted.
- The split follows status alone (L543-L549).
- Sources: [02] outcome coupling; [03] reserve coupling; [06] coupling 5 and P8.

---

## 7. Timeline model

E = `endTime`, R = `drawRequestedAt`, d = 172,800 seconds (two days). Both timeouts are 2 d (RC L33, L36).

| Time t | Active, no sales | Active, sold | Drawing |
| --- | --- | --- | --- |
| creation ≤ t < E | `buyEntries`; sponsor `enableRefunds` | `buyEntries` | cannot be Drawing yet (Drawing needs t ≥ E) |
| E ≤ t < E+2d | anyone may call `enableRefunds` | only `requestDraw` can leave Active | callback accepted while t < R+2d |
| t ≥ E+2d | anyone may call `enableRefunds` | anyone may call `enableRefunds` | callback accepted while t < R+2d; `enableRefunds` from R+2d, which is before E+4d |

- **Boundaries.** Each one compares the same `block.timestamp` against the same deadline function on both sides
  (CFI-8). DESIGN L2 ("Request window [sale end, end+2days); callback accepted strictly before request
  timestamp+2days. Refunds open at deadline") matches the code ([05] documentation alignment).
- **Creation.** RF L100-L104 keep `requestDraw` closed, and `enableRefunds` closed to everyone except the sponsor,
  for the whole creation transaction ([08] time coupling).
- **Terminal states** have no time conditions.
- **Unenforced environmental premises:** UA-28 and UA-34 (`uint64` timestamp conversions); U-15
  (block-timestamp rules).

---

## 8. Destination screening and admission model

### 8.1 The predicate

`_isProtocolDestination(destination, prizeToken_)` (L593-L605) returns true when:

- the destination is one of the five local values: `address(this)`, `factory`, `quoteToken`,
  `i_vrfV2PlusWrapper`, `prizeToken_` (L599-L600); or
- it equals `factory.raffleImplementation()` (L601). This STATICCALL is made only if all five local comparisons
  miss; or
- it has code and `factory.isRaffle(destination)` is true (L602-L603).

That makes seven members (records count them the same way, [12] UA-60). The function is `view`, and a failed
factory call makes it revert, so it fails closed ([11]).

### 8.2 When it is evaluated

| Caller | Who is screened | When | Effect of `true` |
| --- | --- | --- | --- |
| `initialize` L187, L190, L193 | sponsor, treasury, `sponsorRecipient` (passing the proposed prize) | once, at creation | `UnsafeProtocolDestination`, which reverts creation |
| `_update` L498 | every non-zero ticket recipient (mint and transfer) | each mint or transfer; runs before OZ authorization | `UnsafeProtocolDestination` |
| `_transferQuote` L565 | every USDC payee (refunder, winner, `sponsorRecipient`, treasury) | each payout | `InvalidQuoteDestination`, which also reverts the liability write |
| not called | NFT to the winner (L334); NFT to `sponsorRecipient` (L404); native excess (L267); approval targets (E L93-L107) | n/a | n/a |

Sources: [12] callers and outflow list; [11].

### 8.3 Monotonicity and predictability

See CFI-12. The result can flip only from false to true, and only at an address with no code and no key that is a
future CREATE output of this factory. Such an address is computable as `CREATE(factory, raffleCount + 2 + j)` for
j ≥ 0 (derived).

### 8.4 Addresses the predicate never compares ([12] coupling 5)

- `i_linkToken` (VCB L34, set at L45 from `wrapper.link()`).
- The wrapper's coordinator, and any other address behind the wrapper.
- Any address behind `quoteToken` other than `quoteToken` itself.
- Other raffles' prize contracts.
- Clones of the implementation created by anyone other than the factory.
- Clones registered in a different `RaffleFactory` deployment.
- By design, the payees it screens: `protocolTreasury`, `sponsor` and `sponsorRecipient`.

### 8.5 Creation-time checks split between factory and clone ([08], [12])

| Subject | Factory checks it against (RF L155-L178) | `initialize` adds (L181-L195) |
| --- | --- | --- |
| `prizeToken` | Must have code. Not the factory, quote token, wrapper, implementation, or a registered raffle (registry check not gated on code). Must self-report IERC721. | Not the treasury (L190). Not the sponsor (L187). |
| `sponsorRecipient` | Non-zero. Not the factory, quote token, wrapper, prize, implementation, or a registered raffle. | Not the new clone (L599). |
| `sponsor` (`msg.sender`) | no checks | Non-zero; passes the full predicate, including not being the prize contract (L187). |
| `protocolTreasury` | Constructor only: not the factory, quote token, wrapper or implementation (RF L80, L90) | Not the new clone, the prize, or a registered raffle (L190) |
| `reserveEntries`, `endTime` | `≥ 1`; (now, now + 30 d] | stored unchecked (L203-L204) |

### 8.6 (derived) Raffle tickets from other deployments meet prize admission

- A clone registered in a different `RaffleFactory` meets every admission rule:
  - it has code;
  - it reports IERC721 through the inherited `supportsInterface` (E L45-L50);
  - this factory's registry does not contain it.
- RF L159 excludes only clones registered in this factory.
- So a ticket from another deployment can satisfy the prize admission rules at RF L154-L179. Whether escrowing one
  is intended is open (S-02, which relates to U-22).
- Third-party proxies of this implementation also pass admission, but cannot complete an escrow:
  - no token exists on them;
  - their own `_update` screen sees the new clone as registered (RF L125 runs before RF L128).

---

## 9. Divergences

No two records make contradictory claims about what the code does. The differences below concern which evidence a
record accepts, which grounds it cites, and labels. Each is stated with both sides; this synthesis does not pick
one.

### 9.1 Between records

1. **Evidence that "Active means the prize is held".**
   - [03] counts `onERC721Received` L421-L428, together with RF L128-L134, as establishing that status Active
     means the clone holds the prize.
   - [09] (assumption 1, "nothing found") and [08] (the assumption that `status() == Active` at L132 "shows that a
     real deposit happened") treat the hook's arguments as reports from the prize contract itself. On that view
     they are not evidence of a transfer.
   - [08] and [09] also show that `buyEntries` can be reached inside RF L128, after L428 but before RF L129. At
     that point even the prize contract's own `ownerOf` answer does not exist yet.
2. **Why `drawRequestedAt ≠ 0` while Drawing.**
   - The grounds differ:
     - [05]: `requestDraw` L252-L253, plus a positive chain timestamp.
     - [06]: L253 writes `uint64(block.timestamp)`; a non-zero value is "a chain property, not a check".
     - [07]: derived from RF L100 and L242, so `drawRequestedAt ≥ endTime ≥ 1`.
   - The records agree on the mechanics but frame a hypothetical zero differently:
     - [06] calls it "fail-closed", because callbacks would be ignored at L512.
     - [05] notes that the same value would let `enableRefunds` pass immediately at L291.
   - [07]'s derivation means the zero case cannot occur for clones the factory creates.
3. **UA-07 against the rest of the record set and DESIGN.**
   - [01] lists "In NftWon, the sponsor's 95% and the treasury's 5% are released only after the winner receives
     the NFT" as an assumption established by nothing.
   - [01]'s own coupling 5, and [02] (the release functions are "not status-gated" and independent of
     redemption), describe the code as not linking the two.
   - DESIGN L2 says "Sponsor and treasury can claim independently after settlement".
   - UA-07 is carried verbatim in §10 as instructed. The tension is with the design text, which describes the
     independence as intended.
4. **UA-45 is partly established elsewhere.**
   - The harness lists [09]'s assumption as established by nothing: "The factory immutable is the RaffleFactory
     that clones and initializes this raffle and that calls safeTransferFrom, so a conforming prize reports
     operator == factory".
   - [09]'s own entry, and [03], [11] and [12], establish the factory-identity part (L161 with RF L89).
   - What remains unestablished is how a prize that does not follow OpenZeppelin fills in `operator`.
   - Carried verbatim.
5. **UA-21 is partly established elsewhere.**
   - Address equality is enforced at VCB L103.
   - [06] and [07] record further checks: non-zero (L611), code present (RF L67), and a successful `link()` call
     (VCB L45).
   - Only the wrapper's identity and behavior remain unestablished.
   - Carried verbatim.
6. **OpenZeppelin version labels.**
   - [01], [02] and [11] label `ERC721.sol` and `Math.sol` as v5.6.0.
   - [03], [08] and [11] label `ReentrancyGuard`, `SafeERC20`, `Clones` and `ERC721Utils` as v5.5.0. [08]'s key
     attaches v5.5.0 to the `ERC721.sol`/`ERC721Utils.sol` pair.
   - The orientation says 5.6.1.
   - These are per-file "last updated" headers (E, M: v5.6.0; RG, SE, CL, U: v5.5.0) inside a package pinned at
     5.6.1 (`package.json` L29). The difference is labeling only.
7. **[06] corrects the selection summary that dispatched it.** That summary is not reproduced in this task. The
   corrections:
   - the ignore path is not silent; it emits `VrfCallbackIgnored` (L514);
   - "wrapper authentication" is address equality only (VCB L103), and the wrapper's identity rests on trust in
     the deployer.

### 9.2 Between the orientation and the records

| Orientation statement | What the records add | Records |
| --- | --- | --- |
| `vrfWrapper` is "checked only for code" | It is also checked non-zero (L610-L613), and `wrapper.link()` must succeed during implementation deployment (VCB L45). | [06], [07] |
| `unsettledPot` is "gross USDC held before a terminal state" | It stays at n·P in NftWon and CashWon until settlement zeroes it (L553). IR L459 ("before settlement or refund activation") states this exactly. | [02], [03] |
| "Clone native balance: only transient, inside requestDraw" | True for `msg.value`. Forced balances can exist and are never touched. | [07] |
| "Approved ticket operators: can move tickets but cannot refund or redeem" | True within a single call. An operator can transfer the ticket to itself and then claim as owner. | [01], [04], [11] |
| Every clone "STATICCALLs raffleImplementation() and isRaffle()" | `raffleImplementation()` is called only when the five local comparisons miss. `isRaffle()` is called only for destinations with code. | [12] |

### 9.3 Between documents and code (as reported by the records)

| Document statement | Code behavior | Records |
| --- | --- | --- |
| IR L14-L15, IR L40, IRF L16: supported prizes are "honest, standards-compliant" ERC-721s | DESIGN L2 calls arbitrary prize contracts untrusted. On-chain admission checks only for code, excludes protocol plumbing, and takes an ERC-165 self-report (RF L154-L179). | [01], [03], [08], [09], [10] |
| IRF L138: `isRaffle` is "True only for a successfully created canonical clone" | True from RF L125, during W1, before escrow is verified. Holds only for committed state. | [08], [12] |
| IRF L30 and L101-L103: the clone is "initialized, registered, funded, and active" | "Funded" rests only on RF L129 and L132. Entries may already have been sold. | [08], [09] |
| DESIGN L2: "Exactly one ERC721 prize is escrowed atomically at creation" | Established at creation only as far as RF L129 and L132 establish it. | [08] |
| L409: the hook "Accepts only the exact configured prize deposited by the factory for the sponsor" | It accepts the configured caller reporting the configured `(tokenId, from, operator)`. | [09] |
| IR L197: `UnexpectedPrize` describes a mismatch | Also raised for any callback after the clone leaves AwaitingPrize. | [09] |
| IR L322-L323: refunds are enabled "after" the deadlines | The code admits a caller at the deadline (`>=`), as IR L243 states. | [05] |
| IR L410, IRF L33: the sponsor is the "pre-end empty-raffle refund authority" | The sponsor may close a raffle with no sales at any time, including after E. | [05] |
| IR L32: "the sponsor may recover the prize NFT" | The prize goes to `sponsorRecipient`, which may differ from `sponsor`, and anyone can trigger the release. | [10] |
| L587: the denylist is "same-factory protocol plumbing" | DESIGN L2 says "Never move assets between raffle clones", with no same-factory limit. | [12] |
| IR L510-L516: `winnerRedeemed` and `prizeClaimed` mean the prize was delivered | They read true during the delivery call (W6, W10). After a successful commit the meaning holds. | [01], [10] |

---

## 10. Unenforced assumptions (verbatim)

The workflow harness flagged these assumptions as "established by nothing". They are copied verbatim and grouped
by the function whose record raised them. They are not findings. Cross-record notes are kept separate, in §10.2.

### 10.1 List

**`Raffle.redeemWinningTicket`**

- **UA-01**: prizeToken.transferFrom(clone, winner, prizeTokenId) actually moves the escrowed NFT to winner.
- **UA-02**: prizeToken.ownerOf reports custody truthfully. The L335 delivery check is answered by the same untrusted contract that did the transfer.
- **UA-03**: The prize contract does not revert, exhaust gas, or restrict a transfer from the clone to the winner. In NftWon there is no other way out for the NFT and no redemption deadline.
- **UA-04**: The clone still owns the prize NFT at redemption time.
- **UA-05**: The clone's USDC balance is at least winnerProceeds at L342.
- **UA-06**: quoteToken.transfer to winner succeeds (no issuer blocklist or pause). On failure every effect reverts and the ticket stays transferable.
- **UA-07**: In NftWon, the sponsor's 95% and the treasury's 5% are released only after the winner receives the NFT.
- **UA-08**: External readers do not treat winnerRedeemed, prizeClaimed or winnerRecipient as proof of delivery while L334 is running.

**`Raffle._settleWinningTicket`**

- **UA-09**: The clone actually holds at least grossPot USDC, so the allocations can be paid.
- **UA-10**: status correctly selects 95/5 vs 80/15/5, and the sponsor-chosen reserveEntries has an upper bound.

**`Raffle.buyEntries`**

- **UA-11**: USDC transferFrom delivers exactly grossAmount to the clone (fee-free, non-rebasing).
- **UA-12**: USDC transferFrom makes no callback into the payer, the recipient or the clone.
- **UA-13**: The recipient can later act on the ticket (refund, redeem or transfer it).
- **UA-14**: A recipient's protocol-destination status does not change after mint.

**`Raffle.refundTickets`**

- **UA-15**: The clone's USDC balance >= remainingRefundLiability, so L369 does not fail for insufficient balance.
- **UA-16**: A non-reverting quoteToken.transfer moved exactly `amount` to msg.sender.
- **UA-17**: The quote token does not refuse the transfer to msg.sender (blacklist, pause).

**`Raffle.enableRefunds`**

- **UA-18**: The clone's USDC balance is at least the liability moved into remainingRefundLiability.
- **UA-19**: Only the sponsor's own controller can make msg.sender equal sponsor at L282.
- **UA-20**: Someone calls enableRefunds after the applicable deadline. Refund and prize-return availability (L350, L397) depend on that call.

**`Raffle.fulfillRandomWords` (reached via inherited `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords`)**

- **UA-21**: i_vrfV2PlusWrapper is the genuine Chainlink VRF v2.5 wrapper for the chain
- **UA-22**: The requestId passed to rawFulfillRandomWords equals the ID returned by requestRandomWordsInNative and stored at L259, and IDs are non-zero and unique
- **UA-23**: The wrapper routes each callback only to the requesting clone and delivers at most once; an ignored live callback is not re-delivered
- **UA-24**: Exactly one word is delivered for the numWords=1 request (L257)
- **UA-25**: randomWords[0] is unpredictable before the fulfillment transaction and not chosen by any party
- **UA-26**: No matching callback arrives between L260 and the end of requestDraw, where L267 calls the untrusted requester with full gas
- **UA-27**: The callback receives enough gas for the fixed-cost body
- **UA-28**: uint64(block.timestamp) at L520 does not truncate

**`Raffle.requestDraw`**

- **UA-29**: The requestId returned by the wrapper is non-zero, unique, and is the ID the wrapper will later pass to this clone's rawFulfillRandomWords. IRaffle L100/L484 use 0 to mean 'no request'.
- **UA-30**: No authenticated callback for requestId reaches this clone after L260 in the same transaction, in particular during the L267 call to msg.sender. fulfillRandomWords L510-L513 would accept such a callback, because in-flight is false, status is Drawing, the IDs match and the deadline has not passed.
- **UA-31**: The wrapper keeps exactly requestPrice and sends no native value back to the clone.
- **UA-32**: calculateRequestPriceNative returns the same value at L437 and at VRFV2PlusWrapperConsumerBase.sol L82 within one transaction.
- **UA-33**: The configured wrapper accepts callbackGasLimit 300_000, requestConfirmations 30, numWords 1 and nativePayment extraArgs throughout [endTime, endTime + 2d). If it does not, no draw is possible and only enableRefunds (L285-L288) remains.
- **UA-34**: uint64(block.timestamp) at L253 does not truncate.
- **UA-35**: Enough gas remains after the L267 call to run L269, L272 and the guard reset. If the recipient burns all forwarded gas, only the EIP-150 retained 1/64 is left.
- **UA-36**: msg.sender can accept native value when excess != 0.

**`RaffleFactory.createRaffle`**

- **UA-37**: prize.safeTransferFrom at L128 actually moves prizeTokenId from msg.sender to the clone.
- **UA-38**: ownerOf == clone at L129 reflects real custody that lasts until R L334 or R L404 delivers the prize.
- **UA-39**: supportsInterface(IERC721) == true means the contract follows ERC-721 transfer and ownership semantics.
- **UA-40**: protocolTreasury differs from every clone address this factory will deploy.
- **UA-41**: Contracts reached during L128 do not treat isRaffle(clone) == true as proof that the escrow was verified.
- **UA-42**: The clone has no sold entries when RaffleCreated is emitted.

**`Raffle.onERC721Received`**

- **UA-43**: The (operator, from, tokenId) arguments describe a real transfer of prizeTokenId from sponsor into this clone, made by the factory.
- **UA-44**: The prize contract is honest and standards-compliant (IRaffle L14-L15, IRaffleFactory L16).
- **UA-45**: The factory immutable is the RaffleFactory that clones and initializes this raffle and that calls safeTransferFrom, so a conforming prize reports operator == factory.

**`Raffle.releaseSponsorPrize`**

- **UA-46**: The clone owns prizeTokenId on entry.
- **UA-47**: prizeToken.transferFrom moves the NFT from the clone to recipient and does nothing else.
- **UA-48**: prizeToken.ownerOf reports the true owner.
- **UA-49**: sponsorRecipient is not protocol plumbing (this clone, factory, implementation, USDC, VRF wrapper, prize token, or any registered clone of this factory) at release time.
- **UA-50**: sponsorRecipient can hold and later move an ERC-721.
- **UA-51**: The prize contract accepts a transfer to sponsorRecipient whenever release is attempted (not paused, recipient not blocked, token not locked).

**`Raffle._update` (override) reached via inherited ERC721 `transferFrom` / `safeTransferFrom` (x2) / `_safeMint`->`_mint` / `_burn`**

- **UA-52**: An address that passes the screen stays outside the protocol-destination set for as long as it holds the ticket.
- **UA-53**: The screen covers every address whose ownership would make a ticket claim unreachable.
- **UA-54**: TicketPurchased.recipient equals ownerOf(ticketId) when buyEntries returns.
- **UA-55**: A safe-transfer recipient cannot call guarded Raffle functions during its onERC721Received callback.

**`Raffle._isProtocolDestination`**

- **UA-56**: An address that passes the screen now will not later become a registered clone.
- **UA-57**: A ticket owner remains a non-protocol destination after receiving the ticket.
- **UA-58**: sponsorRecipient is still a non-protocol destination when the prize NFT is returned.
- **UA-59**: protocolTreasury is not the address of a future factory clone.
- **UA-60**: The seven predicates cover every protocol-adjacent address that cannot use a ticket or a USDC claim.

### 10.2 Cluster index and cross-record notes

These notes describe how the assumptions relate to each other and to the record set. They do not change the
status of any assumption.

| Cluster | UAs | Related | Cross-record note |
| --- | --- | --- | --- |
| A. Prize-contract behavior and custody | 01, 02, 03, 04, 37, 38, 39, 43, 44, 45, 46, 47, 48, 51 | CFI-11, W1, W6, W10, U-01 | One premise seen from creation, redemption and release: the prize contract both moves the prize and reports where it is. The documents disagree on which trust model applies (§9.3). UA-45 is partly established (§9.1 item 4). |
| B. USDC semantics and solvency | 05, 06, 09, 11, 12, 15, 16, 17, 18 | CFI-3, W2, W7-W9, U-02 | Every accounting amount is nominal and no `balanceOf` is read. Issuer controls (UA-06, UA-17) apply equally to the fixed payees at L380 and L390. |
| C. VRF wrapper behavior | 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33 | CFI-9, CFI-10, W4, W5, U-11 to U-19 | UA-26 and UA-30 state the same premise from the two sides of the request (W5). UA-22 and UA-29 likewise. UA-21 is partly established (§9.1 item 5). |
| D. Stability and coverage of the destination screen | 14, 40, 49, 52, 53, 56, 57, 58, 59, 60 | CFI-12, §8, U-06, U-20, U-22, U-24, U-25 | UA-14, UA-52, UA-56 and UA-57 are one premise: an address that passes stays outside the set. A flip needs an address with no code and no key, at a CREATE output of this factory that can be computed in advance. If UA-40 or UA-59 is violated, every `createRaffle` reverts at that nonce rather than a destination being screened wrongly ([08], [12]). UA-49 and UA-58 concern the unscreened NFT path at L404. |
| E. Holder and recipient capability; liveness | 03, 13, 20, 36, 50 | CFI-8, U-03, U-10, U-26 | Terminal states have no deadlines, and nothing transitions automatically. UA-36 concerns only the requester's own transaction. |
| F. Observers: event and flag meaning | 08, 41, 42, 54 | CFI-16, U-04, U-07, U-21 | The record set itself shows code paths where UA-42 and UA-54 do not hold: purchases inside W1 ([08], [09]) and transfers inside W3 ([11]). They are recorded because off-chain readers may rely on them. |
| G. Reentrancy premises | 12, 26, 30, 55 | CFI-10, W2, W5, W11 | [11] notes that UA-55 holds only when the enclosing frame holds the guard. A recipient of a top-level `safeTransferFrom` is not covered. |
| H. Environment: timestamps and gas | 27, 28, 34, 35 | §7, U-13, U-15 | `uint64` conversions hold while `block.timestamp < 2^64`. Callback gas depends on how the wrapper forwards gas. |
| I. Actor identity and design parameters | 10, 19 | CFI-17, U-05, S-01 | `reserveEntries` has no upper bound. The sponsor's account type is not restricted. |
| J. Coupling that runs against stated intent | 07 | §9.1 item 3 | DESIGN L2 describes the sponsor and treasury claiming independently after settlement. |

---

## 11. Fragility clusters (where complexity concentrates)

These areas guide the hunting phase. They are not findings.

1. **Prize custody is self-reported.**
   - Where: RF L127-L134, L416-L431, L329-L337, L395-L407.
   - Why:
     - The sponsor-chosen contract answers every custody fact, for escrow acceptance, escrow checks and delivery
       checks. Nothing observes custody independently.
     - The two trust documents disagree on whether that is acceptable.
     - In NftWon, a single external `transferFrom` is the only exit for the NFT, while the sponsor and treasury
       USDC are released independently.
   - Related: CFI-5, CFI-11, W1, W6, W10, W12; cluster A; U-01.
2. **The creation window (W1).**
   - Where: RF L128, between L428 and RF L129-L132.
   - Why:
     - Sponsor-chosen code runs while the new clone is already registered and Active, with its guard open.
     - Reachable in that window: `buyEntries`, ticket transfers and approvals, and an `enableRefunds` driven by
       the sponsor.
     - RF L132 checks only status, so purchases survive. Events come out in an order indexers may not expect.
   - Related: CFI-13, CFI-16; UA-41, UA-42; U-07, U-21, S-01.
3. **The destination screen is evaluated at a point in time.**
   - Where: L593-L605, its callers (L187-L195, L498, L565), and the unscreened outflows (L334, L404, L267,
     approvals).
   - Why:
     - Each outflow is screened at a different moment.
     - The result flips from false to true for future clone addresses, which are computable.
     - The screen covers only same-factory plumbing.
     - USDC to `sponsorRecipient` is screened again at release; the NFT is not.
     - If the treasury equals a future clone address, creation halts at that nonce.
   - Related: CFI-12, §8; cluster D; U-06, U-20, U-22, U-24, U-25.
4. **The VRF request and callback boundary.**
   - Where: L240-L273, L509-L524, VCB L76-L107.
   - Why:
     - `_requestInFlight` covers only W4.
     - W5 is a full-gas call to the untrusted requester, made after `Drawing` and `vrfRequestId` are set. It is
       the one place where Raffle code does not rule out an unguarded state writer running inside a guarded
       frame.
     - Request-ID semantics, routing, re-delivery, gas forwarding, value returned by the wrapper, configuration
       bounds and the requester's choice of gas price all depend on wrapper code that is not vendored.
   - Related: CFI-9, CFI-10; cluster C; U-09, U-11 to U-19.
5. **Terminal-state claims are decoupled.**
   - Where: L304-L392, L533-L558.
   - Why:
     - Settlement is permissionless and touches only storage.
     - Redemption is a bearer claim with no deadline and no alternative claimant.
     - The sponsor and treasury releases do not depend on winner delivery.
     - One-shot flags shared between functions are kept apart only by status, and they read true before the
       prize contract runs.
   - Related: CFI-2, CFI-5, CFI-6, CFI-16; UA-03, UA-07, UA-08; U-03, U-04.
6. **USDC accounting is nominal.**
   - Where: L223-L233, L296-L298, L363-L369, L539-L555, L564-L567.
   - Why:
     - No amount is reconciled against a balance.
     - Issuer controls can block a fixed payee or a holder.
     - Unclaimed liabilities and unsolicited surplus have no sweep and no deadline.
   - Related: CFI-3, CFI-4, CFI-7; cluster B; U-02.
7. **The unguarded ERC-721 surface.**
   - Where: E L93-L136 through L497-L502; the mint hook at L235 → E L289.
   - Why:
     - Tickets move in every status, with no status gate.
     - Top-level transfer hooks run with the clone guard not entered.
     - Operator approvals survive transfers.
     - Raffle reads ownership in only two places, and each read is immediately followed by a burn.
   - Related: CFI-10, CFI-14; W3, W11; UA-13, UA-53, UA-54, UA-55; U-06, U-23.
8. **Timeline hand-offs and dependence on keepers.**
   - Where: L216, L242-L247, L276-L301, L458-L465, L512.
   - Why:
     - Three hand-offs each depend on one deadline function shared by both sides.
     - The sponsor's untimed exit overlaps the sale window.
     - Nothing transitions automatically and there is no incentive to call, so refunds and the prize return wait
       for someone to call `enableRefunds`.
     - The block producer's timestamp decides which side a boundary block falls on.
   - Related: CFI-8; UA-20, UA-33; U-10, U-15, S-01.
9. **Creation-time validation split between factory and clone.**
   - Where: RF L154-L179 and L176-L206.
   - Why:
     - Different checks live in different contracts (§8.5).
     - Admission accepts tickets from other deployments' raffles as prizes (§8.6).
     - `reserveEntries` has no upper bound.
     - The clone stores the factory-validated parameters without checking them again.
   - Related: CFI-17; UA-10, UA-39, UA-40; U-05, U-22, S-02.

---

## 12. Open questions

### 12.1 Carried from the records

Every open question from [01]-[12] is mapped below. Where several records raise the same question, they are
merged and all sources are listed.

- **U-01. Which prize trust model applies?** [01], [03], [08], [09], [10]
  - The candidates: IR L14-L15, IR L40 and IRF L16 ("honest, standards-compliant") versus DESIGN L2 ("arbitrary
    prize contracts ... are untrusted").
  - On-chain admission (RF L154-L179) only requires code, excludes protocol plumbing, and takes an ERC-165
    self-report. There is no allowlist and there are no tests.
  - The answer decides:
    - whether the self-reported `ownerOf` checks at RF L129, L335 and L405 are the intended custody boundary;
    - whether transfer-restricted prizes are in scope: pausable, blocklisting, transfer validators, upgradeable
      proxies, soulbound locks. Such behavior can permanently block L334 (the only exit in NftWon) or L404.
- **U-02. How does USDC on the target chain behave?** [01], [02], [03], [04]
  - Does the deployed USDC (proxy and current implementation) move exactly the nominal amount, with no fee,
    rebase or hook, in `transferFrom` (L224) and `transfer` (L566)?
  - When does it revert or return false (sender or recipient blocklist, pause)?
  - Can that be permanent for a fixed payee (`sponsorRecipient`, treasury) or for a holder (L342, L369)?
  - No USDC source is in the repository, and no `balanceOf` is read.
- **U-03. What happens to a winning ticket that is never redeemed?** [01]
  - Is any off-chain or out-of-scope mechanism expected to handle a holder who never redeems (lost key, or a
    contract with no call path)?
  - In scope there is no deadline and no alternative claimant:
    - L334 is the only exit for the NFT in NftWon (L397);
    - `winnerProceeds` has one consumer.
- **U-04. Are flags or events treated as proof?** [01], [09], [10]
  - Do integrators or indexers treat any of these as proof of escrow or delivery: `winnerRedeemed`,
    `prizeClaimed`, `winnerRecipient`, `PrizeDeposited`, `RaffleCreated`, `SponsorPrizeReleased`?
  - The flags are written before the prize call (L323-L331, L403).
  - The events rest on the prize contract's own answers (L429, RF L129, L405).
- **U-05. Is `reserveEntries` meant to have an upper bound?** [02]
  - Only `≠ 0` is enforced (RF L178).
  - The sponsor decides at creation whether NftWon (L543) can be reached.
- **U-06. What is intended for ticket holders that can never act?** [03], [11]
  - Examples: addresses with no code that nobody controls, contracts with no call path, and future clone addresses
    predicted from CREATE.
  - `buyEntries` excludes only the zero address and the sinks it can see at mint time (L217, L498-L500, L602).
  - Related: is the code-length gate at L602 meant to let future clone CREATE addresses, not yet deployed, bypass
    the registry screen? The only stated rationale is L589.
- **U-07. How should indexers read events, and is selling during creation intended?** [03], [08], [09], [11]
  - How do off-chain consumers (none exist in this tree) handle:
    - `TicketPurchased.recipient` differing from the final owner (L236 is emitted after the W3 hook);
    - `TicketPurchased` logs emitted inside the creation window, before `RaffleCreated`;
    - `Transfer` logs that come before `TicketPurchased`?
  - Is selling entries inside RF L128 intended? RF L132 reads only status, and the sponsor's early-cancel path
    requires `totalEntries == 0`.
- **U-08. Does the target chain support EIP-7702?** [03], [08]
  - Does the deployment chain support delegation designators?
  - A delegated EOA has non-empty code, so it:
    - receives ticket hooks (U L32);
    - triggers the `isRaffle` query (L602);
    - passes `_requireContract` as `prizeToken` (RF L184).
  - Its code can be re-pointed after creation, which bears on whether custody lasts.
- **U-09. What happens to the VRF fee when a draw times out?** [05]
  - If `enableRefunds` runs from Drawing, can the outstanding request still be fulfilled later?
  - Is the native fee paid at VCB L84 ever returned?
  - Raffle ignores such callbacks (L511) and has no reimbursement path.
- **U-10. Who operates the keeper role?** [05]
  - Who is expected to call `enableRefunds` once a deadline passes?
  - There is no incentive and no automation. `refundTickets` (L350) and `releaseSponsorPrize` (L397) wait on that
    call.
- **U-11. What are the VRF request-ID semantics?** [06], [07]
  - Does the ID returned by `requestRandomWordsInNative`, stored unvalidated at L259, equal the ID later passed to
    `rawFulfillRandomWords`?
  - Are IDs non-zero, unique across consumers, and bound to the requesting clone?
  - Are callbacks routed only to the requester and delivered at most once?
  - Does the delivered array length equal `numWords` (1)?
  - IR L100 and L484 use 0 to mean "no request".
- **U-12. Can a callback arrive in the same transaction, and is an ignored callback re-delivered?** [06], [07]
  - Can a callback arrive synchronously inside VCB L84? (`_requestInFlight` neutralizes that case.)
  - Can one arrive between L260 and L272, in particular during the L267 refund call, where L510-L513 would accept
    it?
  - Is an ignored callback ever re-delivered?
- **U-13. Does the callback receive its gas?** [06]
  - How does the wrapper forward gas, and how does it handle a consumer revert or out-of-gas?
  - Does the 300_000 limit (RC L39) actually reach the body?
- **U-14. Can wrapper administration interfere after a request?** [06] Can the wrapper owner disable the wrapper,
  or change its coordinator, after a request is accepted, pushing a Drawing raffle into Refunding?
- **U-15. What are the block-timestamp rules?** [06] The block producer's timestamp decides which side of L512 and
  L291 a transaction lands on, and likewise for L216 and L245/L287. What are the target chain's rules?
- **U-16. Are the two price quotes consistent?** [07]
  - Does `calculateRequestPriceNative` return the same value at L437 and at VCB L82 within one transaction?
  - A difference changes which `InsufficientVrfFee` check fires and the size of `excess`.
- **U-17. Does the wrapper return any value?** [07] Does it keep exactly `requestPrice`, or can it send value back?
  The clone's `receive` reverts and there is no `fallback`.
- **U-18. What are the wrapper and coordinator configuration bounds?** [07] Can they reject the fixed parameters
  (300_000 gas, 30 confirmations, 1 word, native extra args) for the entire [E, E+2d) window? That would leave
  `enableRefunds` (L285-L288) as the only path out of Active.
- **U-19. Are requests at caller-chosen gas prices fulfilled?** [07]
  - Does the oracle network fulfil requests priced at an arbitrary `tx.gasprice` (IW L27-L28) within
    `DRAW_CALLBACK_TIMEOUT` (RC L36)?
  - Raffle sets no floor beyond the wrapper's own quote (L250, L258).
- **U-20. Could the treasury equal a future clone address?** [08], [12]
  - How does deployment tooling choose `protocolTreasury_` relative to the factory's future CREATE addresses?
  - The constructor checks only addresses that exist at construction (RF L80, L90).
  - If the treasury equals a future clone address, that `createRaffle` reverts. The nonce does not advance, so
    every later call reverts too.
  - The tooling is not in the workspace.
- **U-21. Is `isRaffle` meant to be true during escrow?** [08]
  - `isRaffle(newClone) == true` throughout RF L128, because registration (RF L125) happens before escrow.
  - Is that intended, given IRF L138 ("True only for a successfully created canonical clone")?
  - Which integrators consult `isRaffle`?
- **U-22. Will there be other deployments on the same chain?** [11], [12]
  - Will other `RaffleFactory` deployments, or other Raffle-compatible clones, exist on the same chain?
  - Do they count as "raffle clones" under DESIGN L2?
  - The screen recognizes only same-factory clones and the same-factory implementation (L587, L601-L603).
- **U-23. May the prize contract be a ticket operator?** [11]
  - The prize contract cannot own a ticket (L600).
  - Approvals are not screened (E L93-L107).
  - The prize contract runs inside W6 and W10, where unguarded ticket transfers remain callable.
- **U-24. Should the denylist include LINK and the coordinator?** [12] Were `i_linkToken` (VCB L45) and the
  wrapper's coordinator meant to be denylist members? Neither is compared.
- **U-25. Why is `sponsorRecipient` screened at different times for different assets?** [10], [12]
  - USDC is screened at release (L380 → L565). The NFT is screened only at initialization (L193, then L402-L404).
  - Does anything off-chain reject a `sponsorRecipient` that is a not-yet-used CREATE address of this factory?
    DESIGN L2 says "Never move assets between raffle clones".
- **U-26. What recovery is intended if the prize return keeps failing?** [10]
  - The case: L404 keeps reverting in CashWon or Refunding.
  - The recipient is write-once (L198), status is terminal, and L24-L25 rule out any rescue path.

### 12.2 Raised by this synthesis

These questions come from cross-function observations. No single record raised them.

- **S-01. What kinds of sponsor account are expected?** (Basis: UA-19, [05], [09] case f.)
  - Are sponsors expected to be EOAs?
  - A contract sponsor (smart wallet, multisig module, EIP-7702 delegate) with a path third parties can call
    would let others use the untimed exit for a raffle with no sales (L282), including from inside W1.
- **S-02. Are other deployments' raffle tickets meant to be accepted as prizes?** (Basis: §8.6; [08] admission
  path; [12] coupling 5; relates to U-22.)
  - Clones registered in another `RaffleFactory` deployment are ERC-721 contracts with code that report IERC721
    (E L45-L50).
  - RF L159 excludes only clones registered in this factory.
  - While the new clone holds such a ticket, the ticket's claim on its own raffle can only be used after delivery.
- **S-03. How should losing tickets be presented?** (Basis: [01], [04], [11].)
  - After resolution, losing tickets stay live and transferable with no claim, and cannot be burned (CFI-4).
  - How are frontends and indexers meant to present them?

---

## Appendix A. Entrypoint quick reference

Trust: T = trusted, U = untrusted, S = STATICCALL.

| Entrypoint | Guard | Gate | Writes | External calls | Records |
| --- | --- | --- | --- | --- | --- |
| `RaffleFactory` constructor | none | deployer, once | immutables; deploys the implementation | `quote.decimals()` (T); `new Raffle` → `wrapper.link()` (T) | none |
| `createRaffle` | factory | parameter screen; endTime window | `raffleCount`, registry; clone configuration and status | `prize.supportsInterface` (U, S); CREATE; `clone.initialize` → factory getters (S); `prize.safeTransferFrom` (U, W1); `prize.ownerOf` (U, S); `clone.status()` (S) | [08] |
| `initialize` | none | factory, once | configuration, AwaitingPrize | factory getters (S) | [08], [12] |
| `onERC721Received` | none | AwaitingPrize plus four argument matches | Active | none | [09] |
| `buyEntries` | clone | Active, t < E, recipient ≠ 0, n ≥ 1, no overflow | totals, range, pot, mint | `USDC.transferFrom` (T, W2); factory getters (S); recipient hook (U, W3) | [03], [11] |
| `requestDraw` | clone | Active, E ≤ t < E+2d, sold, fee covered | Drawing, `drawRequestedAt`, in-flight flag, `vrfRequestId` | wrapper quote ×2 (T, S); `requestRandomWordsInNative{value}` (T, W4); `msg.sender.call{value: excess}` (U, W5) | [07] |
| `rawFulfillRandomWords` | none | `msg.sender == wrapper`, then L510-L513 | `winningEntry`, `resolvedAt`, status | none | [06] |
| `enableRefunds` | clone | timing in §7 | pot → liability; Refunding | none | [05] |
| `settleWinningTicket` | clone | NftWon or CashWon; not yet settled; range contains the winning entry | settlement fields; buckets | none | [02] |
| `redeemWinningTicket` | clone | not yet redeemed; NftWon or CashWon; caller owns the ticket | inline settlement; `winnerRecipient`; `winnerRedeemed`; burn; `prizeClaimed` or `winnerProceeds` | NftWon: `prize.transferFrom` (U, W6) then `prize.ownerOf` (U, S). CashWon: screen (S), then `USDC.transfer` (T, W7). | [01] |
| `refundTickets` | clone | Refunding; 1 to 100 IDs owned by the caller | burns; liability | screen (S); `USDC.transfer` (T, W8) | [04] |
| `releaseSponsorProceeds` | clone | `sponsorProceeds > 0` | `sponsorProceeds = 0` | screen (S); `USDC.transfer` (T, W9) | [02], [12] |
| `releaseProtocolFees` | clone | `protocolFees > 0` | `protocolFees = 0` | screen (S); `USDC.transfer` (T, W9) | [02], [12] |
| `releaseSponsorPrize` | clone | CashWon or Refunding; prize not yet claimed | `prizeClaimed` | `prize.transferFrom` (U, W10); `prize.ownerOf` (U, S) | [10] |
| ERC-721 `transferFrom` / `safeTransferFrom` | none | owner, operator or approvee; destination screen | ticket ledger | screen (S); with `safeTransferFrom`, the recipient hook (U, W11) | [11] |
| ERC-721 `approve` / `setApprovalForAll` | none | owner or operator / any caller for itself | approvals | none | [11] |
| `receive` | none | none | always reverts | none | none |
| views (`getVrfRequestPrice`, `estimateVrfRequestPrice`, and others) | none | none | none | wrapper quotes (T, S) for the two price views | none |
