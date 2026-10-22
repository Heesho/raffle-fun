# Entry Point Analysis: raffle-fun (`packages/contracts`)

**Analyzed**: 2026-10-21T14:08:23-07:00
**Scope**: Full codebase (`packages/contracts/src/` — 5 owned Solidity files; `packages/contracts/node_modules/` — 31 local dependency Solidity files; 36 Solidity files / 43 pristine workspace inputs total; cross-referenced with `DESIGN.md`)
**Languages**: Solidity (`0.8.36` for owned contracts; `^0.8.0` / `^0.8.4` / `^0.8.19` / `^0.8.20` / `^0.8.24` across local Chainlink v1.5.0 and OpenZeppelin v5.6.1 dependencies)
**Focus**: State-changing functions only (`view` and `pure` functions excluded)
**Tooling**: Slither `0.11.6` (`slither . --print entry-points` + supplementary printers `contract-summary,function-summary,modifiers,vars-and-auth,require`) with Foundry `forge 1.7.1` and `solc 0.8.36+commit.8a079791.Darwin.appleclang` executed in isolated `scratch/contracts-unmodified` copy, supplemented by 100% manual line-by-line inspection.

## Summary

The `raffle-fun` protocol deploys two concrete contracts (`RaffleFactory` and the `Raffle` implementation + ERC-1167 minimal proxy clones). Across `Raffle` and `RaffleFactory`, there are **18 recurring state-changing entry points** (plus **1 special `receive()` entry point** that unconditionally reverts to reject unrequested native ETH transfers, and **2 one-time `constructor` initializers**, totaling the **21 rows** reported by `slither . --print entry-points`).

By explicit protocol design (`DESIGN.md:L16-L18`), there are **zero** `Admin / Owner`, `Governance`, or `Guardian / Pauser` functions (`0` mutable protocol configuration or upgrade entry points).

### Primary Audit Classification (18 Recurring State-Changing Entry Points)

| Category | Count | Breakdown |
|----------|-------|-----------|
| Public (Unrestricted) | 12 | 7 core permissionless protocol functions (`RaffleFactory.createRaffle`, `Raffle.buyEntries`, `Raffle.requestDraw`, `Raffle.settleWinningTicket`, `Raffle.releaseSponsorProceeds`, `Raffle.releaseProtocolFees`, `Raffle.releaseSponsorPrize`) + 5 inherited `ERC721` ticket transfer/approval functions (`setApprovalForAll`, `approve`, `transferFrom`, `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)`) |
| Role-Restricted | 2 | `Admin / Owner`: 0, `Governance`: 0, `Guardian / Pauser`: 0, `Other Roles (Ticket Owner)`: 2 (`Raffle.redeemWinningTicket`, `Raffle.refundTickets` — strict `msg.sender == ownerOf(ticketId)` check) |
| Restricted (Review Required) | 1 | `Raffle.enableRefunds` — hybrid time-conditional access control (`msg.sender == sponsor` required before `endTime` when `totalEntries == 0`; permissionless after applicable deadline) |
| Contract-Only | 3 | `Raffle.initialize` (`onlyFactory`), `Raffle.onERC721Received` (`prizeToken` callback during `factory` escrow), `Raffle.rawFulfillRandomWords` (inherited from `VRFV2PlusWrapperConsumerBase`, restricted to `i_vrfV2PlusWrapper`) |
| **Total (Recurring State-Changing)** | **18** | **17 on `Raffle` (11 defined in `Raffle.sol`, 5 inherited from `ERC721.sol`, 1 inherited from `VRFV2PlusWrapperConsumerBase.sol`) + 1 on `RaffleFactory`** |

### Reconciliation Across Counting Conventions

| Counting Convention | Public (Unrestricted) | Role-Restricted (Other Roles) | Restricted (Review Required) | Contract-Only | Special (`receive` / `constructor`) | Total |
|---------------------|-----------------------|-------------------------------|------------------------------|---------------|-------------------------------------|-------|
| **1. Primary Audit Classification** *(ERC-721 transfers/approvals grouped under Public per `SKILL.md` checklist)* | 12 | 2 (`redeemWinningTicket`, `refundTickets`) | 1 (`enableRefunds`) | 3 (`initialize`, `onERC721Received`, `rawFulfillRandomWords`) | Excluded from recurring count (`1 receive` + `2 constructors` documented separately) | **18** |
| **2. Strict Caller-Authorization View** *(4 token-specific `ERC721` functions requiring `_isAuthorized` / owner/operator placed in Restricted)* | 8 (`7 core` + `setApprovalForAll`) | 2 (`redeemWinningTicket`, `refundTickets`) | 5 (`enableRefunds` + `approve`, `transferFrom`, `safeTransferFrom` x2) | 3 (`initialize`, `onERC721Received`, `rawFulfillRandomWords`) | Excluded from recurring count | **18** |
| **3. Including Special `receive()`** *(adds `Raffle.receive() external payable`)* | 13 (or 9 strict) | 2 | 1 (or 5 strict) | 3 | 1 (`Raffle.receive()` — reverts with `DirectNativeTransfer()`) | **19** |
| **4. Full Slither `--print entry-points` Row Count** *(adds `Raffle.constructor` & `RaffleFactory.constructor`)* | 13 (or 9 strict) | 2 | 1 (or 5 strict) | 3 | 3 (`Raffle.receive()`, `Raffle.constructor`, `RaffleFactory.constructor`) | **21** |

---

## Public Entry Points (Unrestricted)

State-changing functions callable by anyone—prioritize for attack surface analysis.

### Core Protocol Public Entry Points (7 Functions)

| Function | File | Notes |
|----------|------|-------|
| `createRaffle(IRaffleFactory.CreateRaffleParams calldata params)` | `packages/contracts/src/RaffleFactory.sol:L97-L148` | `external nonReentrant returns (address raffle)`. Deploys an ERC-1167 clone of `raffleImplementation`, records registry mappings (`raffleCount`, `raffleById`, `idByRaffle`, `isRaffle`), calls `IRaffle(raffle).initialize(...)` with `sponsor = msg.sender`, and escrows `params.prizeTokenId` via `IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, verifying `status == Status.Active` and `prize.ownerOf(prizeTokenId) == raffle`. |
| `buyEntries(address recipient, uint128 entryCount)` | `packages/contracts/src/Raffle.sol:L209-L237` | `external nonReentrant returns (uint256 ticketId)`. Requires `status == Status.Active`, `block.timestamp < endTime`, `recipient != address(0)`, `entryCount > 0`, and no `uint128` overflow on `totalEntries + entryCount`. Updates `ticketCount`, `totalEntries`, `unsettledPot`, and `_ticketRanges[ticketId]`, pulls `entryCount * ENTRY_PRICE` (`1e6` per entry) of `quoteToken` from `msg.sender` via `safeTransferFrom`, and `_safeMint`s ERC-721 ticket `ticketId` to `recipient` (screened against `_isProtocolDestination` in `_update`). |
| `requestDraw()` | `packages/contracts/src/Raffle.sol:L240-L273` | `external payable nonReentrant returns (uint256 requestId)`. Requires `status == Status.Active`, `block.timestamp >= endTime`, `totalEntries > 0`, `block.timestamp < drawRequestDeadline()` (`endTime + 1 days`), and `msg.value >= getVrfRequestPrice()`. Sets `status = Status.Drawing`, `drawRequestedAt = uint64(block.timestamp)`, `_requestInFlight = true`, calls `requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs)` on Chainlink VRF v2.5 wrapper, sets `_requestInFlight = false`, and refunds any excess native ETH (`msg.value - paidPrice`) to `msg.sender` via low-level `.call{value: excess}("")`. |
| `settleWinningTicket(uint256 ticketId)` | `packages/contracts/src/Raffle.sol:L304-L306` | `external nonReentrant returns (uint256 cashAmount)`. Permissionless wrapper around private `_settleWinningTicket(ticketId)` (`Raffle.sol:L533-L558`). Requires `!settlementComplete`, `status` in `{Status.NftWon, Status.CashWon}`, and `_requireWinningTicket(ticketId)` (`winningEntry` within `[range.startEntry, range.endEntryExclusive)`). Sets `settlementComplete = true`, `winningTicketId = ticketId`, zeroes `unsettledPot`, and allocates `protocolFees` (`pot * 100 / 10_000`), `sponsorProceeds`, and (if `CashWon`) `winnerProceeds` (`pot * 5_000 / 10_000`). Performs no external calls. |
| `releaseSponsorProceeds()` | `packages/contracts/src/Raffle.sol:L375-L382` | `external nonReentrant returns (uint256 amount)`. Permissionless payout trigger: requires `sponsorProceeds > 0`, zeroes `sponsorProceeds`, and transfers `amount` of `quoteToken` to `sponsorRecipient` via `_transferQuote`. |
| `releaseProtocolFees()` | `packages/contracts/src/Raffle.sol:L385-L392` | `external nonReentrant returns (uint256 amount)`. Permissionless fee sweep: requires `protocolFees > 0`, zeroes `protocolFees`, and transfers `amount` of `quoteToken` to `protocolTreasury` via `_transferQuote`. |
| `releaseSponsorPrize()` | `packages/contracts/src/Raffle.sol:L395-L407` | `external nonReentrant`. Permissionless prize return trigger: requires `status` in `{Status.CashWon, Status.Refunding}` and `!prizeClaimed`. Sets `prizeClaimed = true`, transfers `prizeTokenId` to `sponsorRecipient` via `prizeToken.transferFrom(address(this), recipient, prizeTokenId)`, and verifies `prizeToken.ownerOf(prizeTokenId) == recipient`. |

### Inherited ERC-721 Ticket Transfer & Approval Entry Points on `Raffle` (5 Functions)

`Raffle` inherits OpenZeppelin's `ERC721` (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol`) to represent raffle tickets and overrides `_update(address to, uint256 ticketId, address auth)` (`packages/contracts/src/Raffle.sol:L497-L502`) to revert with `UnsafeProtocolDestination(to)` whenever `to != address(0)` and `_isProtocolDestination(to, address(prizeToken))` is true.

| Function | File | Notes |
|----------|------|-------|
| `setApprovalForAll(address operator, bool approved)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L105-L107` | `public virtual` (inherited by `Raffle`). Calls `_setApprovalForAll(_msgSender(), operator, approved)` (`ERC721.sol:L408-L414`), writing `_operatorApprovals[owner][operator]`. Unrestricted caller (`msg.sender` sets approvals for their own tickets). |
| `approve(address to, uint256 tokenId)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L95` | `public virtual` (inherited by `Raffle`). Calls `_approve(to, tokenId, _msgSender())` (`ERC721.sol:L376-L399`). Requires `auth == owner || isApprovedForAll(owner, auth)` (`ERC721InvalidApprover` otherwise); writes `_tokenApprovals[tokenId] = to`. |
| `transferFrom(address from, address to, uint256 tokenId)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L125` | `public virtual` (inherited by `Raffle`, calls overridden `Raffle._update` at `packages/contracts/src/Raffle.sol:L497-L502`). Requires `to != address(0)`, `!_isProtocolDestination(to, address(prizeToken))`, `_isAuthorized(owner, _msgSender(), tokenId)`, and `previousOwner == from`. |
| `safeTransferFrom(address from, address to, uint256 tokenId)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L130` | `public` (inherited by `Raffle`). Delegates to `safeTransferFrom(from, to, tokenId, "")`. |
| `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L133-L136` | `public virtual` (inherited by `Raffle`). Calls `transferFrom(from, to, tokenId)` (enforcing `Raffle._update` protocol-destination guard and `_checkAuthorized`) followed by `ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data)`.Note: Does not carry `nonReentrant`, though `Raffle` state-changing functions all carry `nonReentrant`. |

### Special Native-Value & Deployment Entry Points (Reported by Slither `--print entry-points`)

| Function | File | Notes |
|----------|------|-------|
| `receive() external payable` | `packages/contracts/src/Raffle.sol:L171-L173` | Special native ETH receiver on `Raffle`. Unconditionally reverts with `DirectNativeTransfer()` (`Raffle.sol:L172`) so `Raffle` only accepts native ETH inside `requestDraw()`. |
| `constructor(address quoteToken_, address vrfWrapper_)` | `packages/contracts/src/Raffle.sol:L155-L166` | One-time deployment initializer for the `Raffle` implementation contract (invoked inside `RaffleFactory.constructor` at `RaffleFactory.sol:L79`). Sets immutables `factory = msg.sender`, `quoteToken = IERC20(quoteToken_)`, `i_vrfV2PlusWrapper`, `i_linkToken`, and locks the implementation contract by setting `initialized = true` and `status = Status.Refunding`. |
| `constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_)` | `packages/contracts/src/RaffleFactory.sol:L65-L92` | One-time deployment initializer for `RaffleFactory`. Validates `quoteToken_` (`decimals() == 6`, contract check), `vrfWrapper_` (contract check), and `protocolTreasury_` (non-zero, not `this`/`quoteToken_`/`vrfWrapper_`/`raffleImplementation`), and deploys the singleton `Raffle` implementation. |

---

## Role-Restricted Entry Points

### Admin / Owner
| Function | File | Restriction |
|----------|------|-------------|
| *None (0 functions)* | — | Protocol is immutable and ownerless by design (`DESIGN.md:L16-L18`) |

### Governance
| Function | File | Restriction |
|----------|------|-------------|
| *None (0 functions)* | — | No governance role or parameter mutation exists in the codebase |

### Guardian / Pauser
| Function | File | Restriction |
|----------|------|-------------|
| *None (0 functions)* | — | No pause mechanism or guardian role exists in the codebase |

### Other Roles
| Function | File | Restriction | Role |
|----------|------|-------------|------|
| `redeemWinningTicket(uint256 ticketId)` | `packages/contracts/src/Raffle.sol:L309-L346` | `address winner = ownerOf(ticketId); if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);` (`L320-L321`) + `nonReentrant` | **Winning Ticket Owner** (`ownerOf(ticketId)`). Strictly requires `msg.sender == ownerOf(ticketId)` (ERC-721 approved operators cannot redeem). Lazily invokes `_settleWinningTicket(ticketId)` if `!settlementComplete`, verifies `ticketId == winningTicketId` and `!winnerRedeemed`, sets `winnerRedeemed = true` and `winnerRecipient = winner`, burns `ticketId` via `_burn(ticketId)`, and either transfers `prizeTokenId` (`Status.NftWon`) or `winnerProceeds` in `quoteToken` (`Status.CashWon`) to `winner`. |
| `refundTickets(uint256[] calldata ticketIds)` | `packages/contracts/src/Raffle.sol:L349-L372` | `address owner = ownerOf(ticketId); if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);` (`L359-L360`) + `nonReentrant` | **Ticket Owner** (`ownerOf(ticketId)` for all `ticketId` in batch). Strictly requires `msg.sender == ownerOf(ticketId)` (ERC-721 approved operators cannot refund), `status == Status.Refunding`, and `1 <= ticketIds.length <= MAX_REFUND_TICKET_BATCH_SIZE` (`100`). Burns each ticket via `_burn(ticketId)`, decrements `remainingRefundLiability`, and transfers total refund `amount` of `quoteToken` to `msg.sender`. |

---

## Restricted (Review Required)

Functions with conditional, hybrid, or dynamic access control patterns that require manual audit verification.

| Function | File | Pattern | Why Review |
|----------|------|---------|------------|
| `enableRefunds()` | `packages/contracts/src/Raffle.sol:L276-L301` | `if (msg.sender != sponsor && block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);` (`L282-L284`) + `nonReentrant` | **Hybrid Sponsor / Permissionless Time-Gated Transition**: Access control depends on both `status`, `totalEntries`, and `block.timestamp`. (1) When `status == Status.Active && totalEntries == 0`, `deadline = endTime`: before `endTime`, **only `sponsor`** can call `enableRefunds()` to cancel an empty raffle early; at or after `endTime`, **anyone** can call it. (2) When `status == Status.Active && totalEntries > 0`, `deadline = drawRequestDeadline()` (`endTime + 1 days`): **anyone** (including `sponsor`) is blocked before `deadline` and **anyone** can call it at or after `deadline`. (3) When `status == Status.Drawing`, `deadline = callbackDeadline()` (`drawRequestedAt + 1 days`): **anyone** can call it at or after `deadline` if VRF callback has not resolved. Transitions `status` to `Status.Refunding` and moves `unsettledPot` into `remainingRefundLiability`. |
| `redeemWinningTicket(uint256 ticketId)` | `packages/contracts/src/Raffle.sol:L309-L346` | `if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);` (`L320-L321`) where `winner = ownerOf(ticketId)` | **Dynamic NFT Ownership Gate & Destination Screening**: Caller authorization moves dynamically with ERC-721 ownership of `ticketId` (`transferFrom` / `safeTransferFrom` remain open even after draw resolution until `redeemWinningTicket` burns `ticketId`). Also performs external ERC-721 transfer (`prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)`) or ERC-20 transfer (`_transferQuote(winner, cashAmount)`). |
| `refundTickets(uint256[] calldata ticketIds)` | `packages/contracts/src/Raffle.sol:L349-L372` | `if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);` (`L359-L360`) where `owner = ownerOf(ticketId)` | **Dynamic NFT Ownership Gate in Batch Loop**: Caller authorization moves dynamically with ERC-721 ticket ownership; burning `ticketId` inside the loop (`_burn(ticketId)` at `L364`) clears `_owners[ticketId]`, naturally preventing duplicate `ticketId` entries in the same `ticketIds` array (`ownerOf` reverts with `ERC721NonexistentToken` on duplicate). |
| `approve(address to, uint256 tokenId)` / `transferFrom(...)` / `safeTransferFrom(...)` | `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L136` + `packages/contracts/src/Raffle.sol:L497-L502` | `_checkAuthorized(owner, _msgSender(), tokenId)` (`ERC721.sol:L221-L229`) + `Raffle._update` destination filter (`Raffle.sol:L497-L502`) | **Per-Token Owner/Operator Authorization & Protocol-Address Blacklist**: While standard ERC-721 entry points are categorized as Public in the primary summary, transfers/approvals of an existing `ticketId` require `_msgSender()` to be the ticket owner, approved address, or operator, and `Raffle._update` blocks transfers to `_isProtocolDestination(to, address(prizeToken))` (any `Raffle` clone, `factory`, `raffleImplementation`, `quoteToken`, `vrfWrapper`, or `prizeToken`). Note also that `safeTransferFrom` invokes `IERC721Receiver(to).onERC721Received(...)` without the `nonReentrant` modifier on `ERC721.safeTransferFrom` itself (all `Raffle` custom state-changing functions have `nonReentrant`). |

---

## Contract-Only (Internal Integration Points)

Functions only callable by other contracts—useful for understanding trust boundaries.

| Function | File | Expected Caller |
|----------|------|-----------------|
| `initialize(IRaffle.RaffleInitParams calldata params)` | `packages/contracts/src/Raffle.sol:L176-L206` | **`RaffleFactory` (`factory`)**. Enforced by `if (initialized) revert AlreadyInitialized(); if (msg.sender != factory) revert OnlyFactory();` (`Raffle.sol:L177-L178`). Because `factory` is an `immutable` set to `msg.sender` in `Raffle.constructor` (`Raffle.sol:L161`) and the implementation itself sets `initialized = true` in `Raffle.constructor` (`Raffle.sol:L164`), only `RaffleFactory.createRaffle` (`RaffleFactory.sol:L122-L133`) can call `initialize` on a freshly cloned `Raffle` instance. Sets `status = Status.AwaitingPrize`. |
| `onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)` | `packages/contracts/src/Raffle.sol:L416-L431` | **`prizeToken` ERC-721 Contract (via `RaffleFactory.createRaffle`)**. Enforced by `if (status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId || from != sponsor || operator != factory) revert UnexpectedPrize(msg.sender, tokenId, from, operator);` (`Raffle.sol:L421-L428`). Transitions `status` from `Status.AwaitingPrize` to `Status.Active` (`L429`) when `RaffleFactory.createRaffle` executes `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:L135`). Any other `safeTransferFrom` of any NFT to `Raffle` reverts. |
| `rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)` | `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107` (dispatches to `Raffle.fulfillRandomWords` at `packages/contracts/src/Raffle.sol:L509-L524`) | **Chainlink VRF v2.5 Wrapper (`i_vrfV2PlusWrapper`)**. Enforced by `address vrfWrapperAddr = address(i_vrfV2PlusWrapper); if (msg.sender != vrfWrapperAddr) revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);` (`VRFV2PlusWrapperConsumerBase.sol:L102-L105`). Calls `Raffle.fulfillRandomWords(requestId, randomWords)` (`Raffle.sol:L509-L524`), which checks `!_requestInFlight && status == Status.Drawing && requestId == vrfRequestId && randomWords.length == 1 && block.timestamp < callbackDeadline()`. If any check fails, it emits `VrfCallbackIgnored(requestId, status)` and returns without reverting; otherwise it computes `winningEntry = uint128(randomWords[0] % uint256(totalEntries))`, sets `resolvedAt = uint64(block.timestamp)`, and transitions `status` to `Status.NftWon` (`totalEntries >= reserveEntries`) or `Status.CashWon` (`totalEntries < reserveEntries`). |

---

## Files Analyzed

### Owned Solidity Files (`packages/contracts/src/` — 5 Files)

- `packages/contracts/src/Raffle.sol` (**11 defined recurring state-changing entry points** + **6 inherited recurring state-changing entry points** [5 from `ERC721.sol`, 1 from `VRFV2PlusWrapperConsumerBase.sol`] = **17 recurring state-changing entry points**; plus **1 `receive()` payable entry point** and **1 `constructor`** = **19 Slither entry-point rows**; 11 `public`/`external` `view`/`pure` functions + 31 public state-variable getters excluded)
- `packages/contracts/src/RaffleFactory.sol` (**1 defined recurring state-changing entry point** [`createRaffle`] + **1 `constructor`** = **2 Slither entry-point rows**; 10 public state-variable getters excluded)
- `packages/contracts/src/interfaces/IRaffle.sol` (**0 concrete entry points**; interface declaring 10 `external` state-changing function signatures implemented by `Raffle` and 38 `external view` function signatures)
- `packages/contracts/src/interfaces/IRaffleFactory.sol` (**0 concrete entry points**; interface declaring 1 `external` state-changing function signature [`createRaffle`] implemented by `RaffleFactory` and 10 `external view` function signatures)
- `packages/contracts/src/libraries/RaffleConstants.sol` (**0 state-changing entry points**; library defining 11 `internal constant` protocol parameters)

### Local Dependency Solidity Files (`packages/contracts/node_modules/` — 31 Files)

#### Chainlink Contracts v1.5.0 (4 Files)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` (**1 `external` state-changing entry point** [`rawFulfillRandomWords(uint256,uint256[])`] inherited by `Raffle`; 3 `internal` state-changing functions [`requestRandomness`, `requestRandomnessPayInNative`, `fulfillRandomWords`], 1 `internal constructor`, and 2 `public view` functions [`getBalance`, `getLinkToken`] excluded)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` (**0 concrete entry points**; interface declaring 1 `external payable` state-changing function [`requestRandomWordsInNative`] and 7 `external view` functions)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` (**0 state-changing entry points**; library with 1 `internal pure` helper `_argsToBytes`)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` (**0 concrete entry points**; interface declaring 6 `external` state-changing functions and 6 `external view` functions)

#### OpenZeppelin Contracts v5.6.1 (27 Files)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` (**5 `public` state-changing entry points** [`approve`, `setApprovalForAll`, `transferFrom`, `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)`] inherited by `Raffle`; 1 `internal constructor`, 12 `internal` state-changing helpers, 7 `public view` functions, and 6 `internal view`/`pure` helpers excluded)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol` (**0 concrete entry points**; interface declaring 5 `external` state-changing functions and 4 `external view` functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` (**0 concrete entry points**; interface declaring 1 `external` state-changing function [`onERC721Received`] implemented by `Raffle`)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` (**0 concrete entry points**; interface declaring 3 `external view` functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` (**0 externally callable entry points**; library with 1 `internal` state-changing function `checkOnERC721Received`)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol` (**0 concrete entry points**; interface declaring 3 `external` state-changing functions and 3 `external view` functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` (**0 concrete entry points**; interface declaring 3 `external view` functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` (**0 externally callable entry points**; library with 10 `internal` and 3 `private` state-changing functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol` (**0 externally callable entry points**; library with 8 `internal` state-changing deployment functions, 5 `internal view`/`pure` functions, and 1 `private pure` helper)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` (**0 externally callable entry points**; abstract contract inherited by `Raffle` and `RaffleFactory` providing `nonReentrant` and `nonReentrantView` modifiers, 1 `internal constructor`, 2 `private` state-changing helpers, and 3 `internal`/`private view`/`pure` helpers)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol` (**0 state-changing entry points**; abstract contract with 3 `internal view`/`pure` helpers)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol` (**0 state-changing entry points**; abstract contract with 1 `public view` function `supportsInterface`)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol` (**0 state-changing entry points**; interface with 1 `external view` function `supportsInterface`)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol` (**0 state-changing entry points**; error-only interfaces `IERC20Errors`, `IERC721Errors`, `IERC1155Errors`)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol` (**0 concrete entry points**; interface declaring 6 `external` state-changing functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol` (**0 state-changing entry points**; re-export file)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol` (**0 state-changing entry points**; re-export file)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol` (**0 state-changing entry points**; library with 4 `internal` memory-mutating helpers and 16 `internal`/`private pure` helpers)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol` (**0 externally callable entry points**; library with 1 `internal` state-changing function `deploy` and 2 `internal view`/`pure` functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol` (**0 state-changing entry points**; custom error library)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol` (**0 externally callable entry points**; library with 6 `internal` state-changing call/delegatecall helpers and 6 `internal view`/`pure` helpers)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol` (**0 state-changing entry points**; library with 1 `internal pure` function `panic`)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol` (**0 state-changing entry points**; library with 9 `internal pure` slot pointer helpers)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol` (**0 state-changing entry points**; library with 31 `internal`/`private pure` string/parsing functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol` (**0 state-changing entry points**; library with 2 `internal view` `modExp` helpers and 34 `internal`/`private pure` math functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol` (**0 state-changing entry points**; library with 65 `internal pure` type-casting functions)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol` (**0 state-changing entry points**; library with 5 `internal pure` math functions)
