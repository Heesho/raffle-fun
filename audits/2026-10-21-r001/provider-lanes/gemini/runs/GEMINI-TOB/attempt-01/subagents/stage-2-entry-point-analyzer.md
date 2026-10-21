# Entry Point Analysis: raffle.fun (`RaffleFactory.sol` & `Raffle.sol`)

**Analyzed**: 2026-10-21
**Scope**: `packages/contracts/src/RaffleFactory.sol`, `packages/contracts/src/Raffle.sol` (including inherited entry points from `@openzeppelin/contracts/token/ERC721/ERC721.sol` and `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`)
**Languages**: Solidity (`0.8.36`, EVM `cancun`)
**Focus**: State-changing functions only (`view` and `pure` functions excluded)

---

## Summary

| Category | Count | Functions |
|----------|-------|-----------|
| **Public (Unrestricted)** | 8 | `RaffleFactory.createRaffle`, `Raffle.buyEntries`, `Raffle.requestDraw`, `Raffle.settleWinningTicket`, `Raffle.releaseSponsorProceeds`, `Raffle.releaseProtocolFees`, `Raffle.releaseSponsorPrize`, `Raffle.setApprovalForAll` (inherited `ERC721`) |
| **Role-Restricted (Ticket Owner / Approved Operator)** | 6 | `Raffle.redeemWinningTicket`, `Raffle.refundTickets`, `Raffle.approve` (inherited `ERC721`), `Raffle.transferFrom` (inherited `ERC721`), `Raffle.safeTransferFrom(address,address,uint256)` (inherited `ERC721`), `Raffle.safeTransferFrom(address,address,uint256,bytes)` (inherited `ERC721`) |
| **Restricted (Review Required / Hybrid Access)** | 1 | `Raffle.enableRefunds` (Sponsor-only before `endTime` when `totalEntries == 0`; Public after applicable deadline) |
| **Contract-Only (Internal Integration / Callbacks)** | 3 | `Raffle.initialize` (Factory-only), `Raffle.onERC721Received` (Prize token callback via Factory), `Raffle.rawFulfillRandomWords` (Chainlink VRF Wrapper callback, inherited) |
| **Special / One-Time Entry Points** | 3 | `RaffleFactory.constructor`, `Raffle.constructor`, `Raffle.receive` (always reverts) |
| **Total State-Changing Entry Points** | **18** (+ 3 special/constructors) | Across `RaffleFactory.sol` (1 recurring + 1 constructor) and `Raffle.sol` (17 recurring + 1 `receive` + 1 constructor) |

---

## Public Entry Points (Unrestricted)

State-changing functions callable by any EOA or contract without caller-identity restrictions—primary attack surface.

| Function | File | Modifiers | Lifecycle Prerequisite (`Status`) | Brief Note |
|----------|------|-----------|-----------------------------------|------------|
| `createRaffle(CreateRaffleParams calldata params)` | `RaffleFactory.sol:L97` | `nonReentrant` | N/A (Factory) | Deploys ERC-1167 clone, initializes it, registers it, and escrows caller's ERC-721 prize via `safeTransferFrom`. |
| `buyEntries(address recipient, uint128 entryCount)` | `Raffle.sol:L209` | `nonReentrant` | `Status.Active` (`block.timestamp < endTime`) | Pulls `entryCount * 1e6` USDC from `msg.sender`, increments `unsettledPot`, mints sequential ERC-721 range ticket via `_safeMint(recipient, ticketId)`. |
| `requestDraw()` | `Raffle.sol:L240` | `payable`, `nonReentrant` | `Status.Active` (`endTime <= block.timestamp < drawRequestDeadline()`, `totalEntries > 0`) | Pays native VRF fee to `i_vrfV2PlusWrapper`, transitions to `Status.Drawing`, refunds excess native ETH to `msg.sender`. |
| `settleWinningTicket(uint256 ticketId)` | `Raffle.sol:L304` | `nonReentrant` | `Status.NftWon` or `Status.CashWon` (`!settlementComplete`) | Storage-only proof that `ticketId` covers `winningEntry`; allocates `unsettledPot` into `winnerProceeds`, `sponsorProceeds`, and `protocolFees`. |
| `releaseSponsorProceeds()` | `Raffle.sol:L375` | `nonReentrant` | Any post-settlement (`sponsorProceeds > 0`) | Permissionless pull-over-push release of full `sponsorProceeds` in USDC to immutable `sponsorRecipient`. |
| `releaseProtocolFees()` | `Raffle.sol:L385` | `nonReentrant` | Any post-settlement (`protocolFees > 0`) | Permissionless pull-over-push release of full `protocolFees` in USDC to immutable `protocolTreasury`. |
| `releaseSponsorPrize()` | `Raffle.sol:L395` | `nonReentrant` | `Status.CashWon` or `Status.Refunding` (`!prizeClaimed`) | Permissionless return of escrowed ERC-721 prize to immutable `sponsorRecipient` via `prizeToken.transferFrom`. |
| `setApprovalForAll(address operator, bool approved)` | `ERC721.sol:L105` (inherited by `Raffle`) | *(none)* | Any | Grants/revokes operator approval for `msg.sender`'s own tickets. Reverts only if `operator == address(0)`. |

---

## Role-Restricted Entry Points

### Admin / Owner / Governance / Guardian / Pauser
*None.* Neither `RaffleFactory` nor `Raffle` has an administrator, owner, governance role, pauser, or upgrade authority.

### Ticket Owner (`msg.sender == ownerOf(ticketId)`)

| Function | File | Modifiers | Restriction Pattern | Lifecycle Prerequisite (`Status`) |
|----------|------|-----------|---------------------|-----------------------------------|
| `redeemWinningTicket(uint256 ticketId)` | `Raffle.sol:L309` | `nonReentrant` | `if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner)` where `winner = ownerOf(ticketId)` (`Raffle.sol:L320-321`) | `Status.NftWon` or `Status.CashWon` (`!winnerRedeemed`; auto-settles if `!settlementComplete`) |
| `refundTickets(uint256[] calldata ticketIds)` | `Raffle.sol:L349` | `nonReentrant` | Loop check: `if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner)` where `owner = ownerOf(ticketId)` (`Raffle.sol:L359-360`) | `Status.Refunding` (`1 <= ticketIds.length <= 100`) |

### Ticket Owner or Approved Operator (Inherited `ERC721` Bearer Ticket Operations)

| Function | File | Modifiers | Restriction Pattern | Lifecycle Prerequisite (`Status`) |
|----------|------|-----------|---------------------|-----------------------------------|
| `approve(address to, uint256 tokenId)` | `ERC721.sol:L93` | *(none)* | `owner == _msgSender() \|\| isApprovedForAll(owner, _msgSender())` in `_approve` (`ERC721.sol:L389`) | Any (ticket must exist / not be burned) |
| `transferFrom(address from, address to, uint256 tokenId)` | `ERC721.sol:L115` (hooks `Raffle._update` at `Raffle.sol:L497`) | *(none)* | `_checkAuthorized(from, _msgSender(), tokenId)` in `ERC721._update` (`ERC721.sol:L220`) + `!_isProtocolDestination(to, address(prizeToken))` in `Raffle._update` (`Raffle.sol:L498`) | Any (ticket must exist / not be burned) |
| `safeTransferFrom(address from, address to, uint256 tokenId)` | `ERC721.sol:L128` | *(none)* | Delegates to 4-arg `safeTransferFrom` | Any (ticket must exist / not be burned) |
| `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)` | `ERC721.sol:L133` | *(none)* | Same as `transferFrom` + `ERC721Utils.checkOnERC721Received` on `to` | Any (ticket must exist / not be burned) |

---

## Restricted (Review Required)

Functions with conditional/inline access control patterns that depend on contract state and timestamp.

| Function | File | Modifiers | Pattern | Why Review |
|----------|------|-----------|---------|------------|
| `enableRefunds()` | `Raffle.sol:L276` | `nonReentrant` | Conditional branch on `status` and `totalEntries` (`Raffle.sol:L279-294`):<br>1. `Status.Active && totalEntries == 0`: requires `msg.sender == sponsor \|\| block.timestamp >= endTime`.<br>2. `Status.Active && totalEntries > 0`: permissionless once `block.timestamp >= drawRequestDeadline()`.<br>3. `Status.Drawing`: permissionless once `block.timestamp >= callbackDeadline()`. | Dual access model: acts as a privileged `sponsor`-only cancellation before `endTime` when zero entries are sold, and as a permissionless liveness recovery function after the applicable timeout (`endTime`, `drawRequestDeadline()`, or `callbackDeadline()`). |

---

## Contract-Only (Internal Integration Points)

Functions callable only by specific protocol or external dependency contracts—critical trust boundary gates.

| Function | File | Modifiers | Expected Caller & Restriction Pattern | Lifecycle Prerequisite (`Status`) |
|----------|------|-----------|---------------------------------------|-----------------------------------|
| `initialize(RaffleInitParams calldata params)` | `Raffle.sol:L176` | *(none)* | **Canonical `RaffleFactory` only**: `if (initialized) revert AlreadyInitialized(); if (msg.sender != factory) revert OnlyFactory();` (`Raffle.sol:L177-178`) | Uninitialized clone (`!initialized`, `status == Status.AwaitingPrize` default `0`) |
| `onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)` | `Raffle.sol:L416` | *(none)* | **Configured `prizeToken` contract only**: `if (status != Status.AwaitingPrize \|\| msg.sender != address(prizeToken) \|\| tokenId != prizeTokenId \|\| from != sponsor \|\| operator != factory) revert UnexpectedPrize(...)` (`Raffle.sol:L421-426`) | `Status.AwaitingPrize` (called during `RaffleFactory.createRaffle`) |
| `rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)` | `VRFV2PlusWrapperConsumerBase.sol:L101` -> `Raffle.fulfillRandomWords` (`Raffle.sol:L509`) | *(none)* | **Chainlink VRF Wrapper (`i_vrfV2PlusWrapper`) only**: `if (msg.sender != vrfWrapperAddr) revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);` (`VRFV2PlusWrapperConsumerBase.sol:L103-105`) | `Status.Drawing` (`!_requestInFlight`, `requestId == vrfRequestId`, `randomWords.length == 1`, `block.timestamp < callbackDeadline()`); otherwise emits `VrfCallbackIgnored` and no-ops without reverting. |

---

## Special & One-Time Entry Points

| Function | File | Visibility / Mutability | Behavior & Security Notes |
|----------|------|-------------------------|---------------------------|
| `constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_)` | `RaffleFactory.sol:L65` | `payable: false` | Validates code presence on `quoteToken_` and `vrfWrapper_`, verifies `IERC20Metadata(quoteToken_).decimals() == 6`, checks `protocolTreasury_` against protocol addresses, and deploys the singleton `Raffle` implementation (`new Raffle(quoteToken_, vrfWrapper_)`). |
| `constructor(address quoteToken_, address vrfWrapper_)` | `Raffle.sol:L155` | `payable: false` | Runs on singleton `raffleImplementation` deployment. Validates `vrfWrapper_ != address(0)`, queries `vrfWrapper_.link()` inside `VRFV2PlusWrapperConsumerBase`, sets `factory = msg.sender`, `quoteToken = IERC20(quoteToken_)`, and locks implementation storage with `initialized = true` and `status = Status.Refunding`. |
| `receive()` | `Raffle.sol:L171` | `external payable` | Unconditionally reverts with `DirectNativeTransfer()`. Prevents accidental native ETH transfers outside `requestDraw()`. Note: `RaffleFactory` has neither `receive()` nor `fallback()`, so direct ETH transfers to `RaffleFactory` also revert. |

---

## Comprehensive Entry Point Profiles & Attack Surface Analysis

### 1. `RaffleFactory.createRaffle(CreateRaffleParams calldata params)`
- **Location**: `RaffleFactory.sol:L97-148` (Bundle `L730-781`)
- **Access Control**: Public (Unrestricted)
- **Reentrancy Protection**: `nonReentrant` (on `RaffleFactory` storage slot)
- **Input / State Prerequisites**:
  - `params.prizeToken.code.length != 0`
  - `params.sponsorRecipient != address(0)`
  - `params.prizeToken` is not `address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, or `isRaffle[params.prizeToken]`
  - `params.sponsorRecipient` is not `address(this)`, `quoteToken`, `vrfWrapper`, `params.prizeToken`, `raffleImplementation`, or `isRaffle[params.sponsorRecipient]`
  - `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) == true` (via `try/catch`)
  - `params.reserveEntries > 0`
  - `block.timestamp < params.endTime <= block.timestamp + 30 days`
- **State Mutations (`RaffleFactory`)**:
  - `uint256 raffleId = ++raffleCount;`
  - `raffleById[raffleId] = raffle;`
  - `idByRaffle[raffle] = raffleId;`
  - `isRaffle[raffle] = true;`
- **External Calls**:
  1. `IERC165(params.prizeToken).supportsInterface(0x80ac58cd)` — `staticcall` to **untrusted** `params.prizeToken`.
  2. `Clones.clone(raffleImplementation)` — `CREATE` deployment of ERC-1167 minimal proxy.
  3. `IRaffle(raffle).initialize(...)` — call to newly deployed clone.
  4. `IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` — call to **untrusted** `params.prizeToken` (which should invoke `raffle.onERC721Received`).
  5. `IERC721(params.prizeToken).ownerOf(params.prizeTokenId)` — `staticcall` to **untrusted** `params.prizeToken`.
  6. `IRaffle(raffle).status()` — `staticcall` to clone.
- **Attack Surface & Audit Notes**:
  - **Untrusted `prizeToken` execution after `onERC721Received`**: During `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, the clone's `onERC721Received` sets `raffle.status = Status.Active`. If `prizeToken` executes malicious code after calling `onERC721Received` (before returning to `createRaffle`), `RaffleFactory`'s `nonReentrant` guard is active, but `raffle`'s `nonReentrant` guard is NOT active. Post-transfer verification `if (IRaffle(raffle).status() != IRaffle.Status.Active) revert PrizeEscrowVerificationFailed(...)` prevents `sponsor`/`prizeToken` from immediately cancelling the raffle into `Status.Refunding` via `enableRefunds()` during `createRaffle`. However, `buyEntries` could theoretically be called on `raffle` inside `prize.safeTransferFrom` after `onERC721Received` (keeping `status == Status.Active`), which would emit `TicketPurchased` before `RaffleCreated`.
  - **Pre-computed future `Raffle` clone address as `sponsorRecipient` (Cross-Function Finding Candidate)**: `Clones.clone` uses standard `CREATE`, meaning future raffle addresses (`keccak256(rlp(address(factory), factory_nonce))`) are deterministic and publicly predictable before deployment. When creating Raffle #1, if a sponsor passes `params.sponsorRecipient = predictedRaffle2Address` (the address of a future Raffle #2), `predictedRaffle2Address.code.length == 0` and `isRaffle[predictedRaffle2Address] == false` at Raffle #1 creation time. Thus, both `RaffleFactory._validateCreateParams` and `Raffle.initialize`'s `_isProtocolDestination` pass. Once Raffle #2 is subsequently created at `predictedRaffle2Address`, `isRaffle[predictedRaffle2Address]` becomes `true`. Thereafter, in Raffle #1:
    1. `releaseSponsorProceeds()` will permanently revert with `InvalidQuoteDestination(sponsorRecipient)` because `_transferQuote` re-checks `_isProtocolDestination(to, address(prizeToken))` at claim time, permanently locking sponsor USDC proceeds in Raffle #1.
    2. `releaseSponsorPrize()` (which uses `prizeToken.transferFrom` without calling `_isProtocolDestination`) will transfer Raffle #1's ERC-721 prize into Raffle #2 (`predictedRaffle2Address`), violating the design invariant *"Never move assets between raffle clones"* and permanently stranding the NFT in Raffle #2.

---

### 2. `Raffle.initialize(RaffleInitParams calldata params)`
- **Location**: `Raffle.sol:L176-206` (Bundle `L189-219`)
- **Access Control**: Contract-Only (`msg.sender == factory` and `!initialized`)
- **Reentrancy Protection**: Single-use boolean lock (`initialized = true` set before any external view calls in `_isProtocolDestination`).
- **State Prerequisites**: `initialized == false` (fresh clone; implementation contract sets `initialized = true` in constructor).
- **State Mutations**:
  - `initialized = true`
  - `sponsor = params.sponsor`
  - `sponsorRecipient = params.sponsorRecipient`
  - `protocolTreasury = params.protocolTreasury`
  - `prizeToken = IERC721(params.prizeToken)`
  - `prizeTokenId = params.prizeTokenId`
  - `raffleId = params.raffleId`
  - `reserveEntries = params.reserveEntries`
  - `endTime = params.endTime`
  - `status = Status.AwaitingPrize`
- **External Calls**:
  - Calls `_isProtocolDestination` for `sponsor`, `protocolTreasury`, and `sponsorRecipient`, which calls `IRaffleFactory(factory).raffleImplementation()` and (if `destination.code.length != 0`) `IRaffleFactory(factory).isRaffle(destination)`.
- **Attack Surface & Audit Notes**:
  - Cannot be front-run on clones because `Clones.clone` and `IRaffle(raffle).initialize` happen atomically in `RaffleFactory.createRaffle`, and `msg.sender != factory` prevents any non-factory caller even if a clone were deployed separately.
  - Note on `ReentrancyGuard` in clones: `ReentrancyGuard`'s constructor sets slot `0x9b779b...5f00` to `NOT_ENTERED = 1` only on the implementation contract. On a fresh clone, this slot starts at `0`. Because `_reentrancyGuardEntered()` checks `value == ENTERED (2)`, the first `nonReentrant` call on a clone still functions properly (incurring a one-time zero-to-nonzero `SSTORE` gas cost).

---

### 3. `Raffle.onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)`
- **Location**: `Raffle.sol:L416-431` (Bundle `L429-444`)
- **Access Control**: Contract-Only / Callback-Restricted (`msg.sender == address(prizeToken)`, `operator == factory`, `from == sponsor`, `tokenId == prizeTokenId`)
- **Reentrancy Protection**: State-machine one-way transition (`status` must be `Status.AwaitingPrize` and is immediately set to `Status.Active`).
- **State Prerequisites**: `status == Status.AwaitingPrize`.
- **State Mutations**: `status = Status.Active`.
- **External Calls**: None.
- **Attack Surface & Audit Notes**:
  - Strictly rejects any unsolicited `safeTransferFrom` of other NFTs or after activation. Unsolicited NFTs sent via raw `transferFrom` bypass `onERC721Received` and are permanently unrecoverable (documented in NatSpec).

---

### 4. `Raffle.buyEntries(address recipient, uint128 entryCount)`
- **Location**: `Raffle.sol:L209-237` (Bundle `L222-250`)
- **Access Control**: Public (Unrestricted)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - `status == Status.Active`
  - `block.timestamp < endTime`
  - `recipient != address(0)`
  - `entryCount > 0`
  - `entryCount <= type(uint128).max - totalEntries`
  - `!_isProtocolDestination(recipient, address(prizeToken))` (enforced inside `_safeMint` -> `_mint` -> `Raffle._update`)
- **State Mutations**:
  - `totalEntries = totalEntries + entryCount`
  - `++ticketCount`
  - `_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry })`
  - `unsettledPot += grossAmount` (`uint256(entryCount) * ENTRY_PRICE`)
  - ERC-721 state via `_safeMint(recipient, ticketId)`: `_balances[recipient] += 1`, `_owners[ticketId] = recipient`
- **External Calls**:
  1. `quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount)` — call to **trusted** USDC (`quoteToken`).
  2. `_isProtocolDestination(recipient, address(prizeToken))` — `staticcall` to **trusted** `factory`.
  3. `ERC721Utils.checkOnERC721Received(msg.sender, address(0), recipient, ticketId, "")` (inside `_safeMint`) — call to **untrusted** `recipient` if `recipient.code.length > 0`.
- **Attack Surface & Audit Notes**:
  - **Callback Reentrancy on `_safeMint`**: All `Raffle` state updates (`totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`, `_owners`, `_balances`) occur *before* `checkOnERC721Received` calls `recipient.onERC721Received`. `nonReentrant` blocks reentrancy into all `Raffle` business functions (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `release*`).
  - **Cross-Function Reentrancy into Inherited `ERC721` Functions**: Because `ERC721.transferFrom`, `safeTransferFrom`, `approve`, and `setApprovalForAll` do **not** have the `nonReentrant` modifier, a contract `recipient` can call `transferFrom` or `approve` on the newly minted `ticketId` from inside `onERC721Received`. Since `_mint` and all accounting updates have already completed before `onERC721Received`, this only transfers/approves the recipient's own already-minted ticket and does not corrupt accounting (though `Transfer(recipient, nextOwner, ticketId)` will be emitted before `TicketPurchased`).
  - **Pre-computed Future Raffle Address as `recipient`**: As noted under `createRaffle`, if `recipient` is a predicted `CREATE` address of a not-yet-deployed `Raffle` clone, `recipient.code.length == 0` at purchase time, so both `_isProtocolDestination` and `_safeMint` succeed. Once that clone is deployed, `isRaffle[recipient]` becomes `true` and the clone has no way to transfer, redeem, or refund the ticket.

---

### 5. `Raffle.requestDraw()`
- **Location**: `Raffle.sol:L240-273` (Bundle `L253-286`)
- **Access Control**: Public (Unrestricted), `payable`
- **Reentrancy Protection**: `nonReentrant` + `_requestInFlight = true` guard around the VRF wrapper call
- **State Prerequisites**:
  - `status == Status.Active`
  - `endTime <= block.timestamp < drawRequestDeadline()` (`endTime + 2 days`)
  - `totalEntries > 0`
  - `msg.value >= getVrfRequestPrice()`
- **State Mutations**:
  - `status = Status.Drawing`
  - `drawRequestedAt = uint64(block.timestamp)`
  - `_requestInFlight = true` (transiently during call, then reset to `false`)
  - `vrfRequestId = requestId`
- **External Calls**:
  1. `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (called in `getVrfRequestPrice()` and again inside `requestRandomnessPayInNative()`) — `staticcall` to **trusted** wrapper.
  2. `i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(callbackGasLimit, requestConfirmations, 1, extraArgs)` — payable call to **trusted** wrapper.
  3. `call(gas(), msg.sender, excess, 0, 0, 0, 0)` (inline assembly) — native ETH transfer to **untrusted** `msg.sender` when `msg.value > paidPrice`.
- **Attack Surface & Audit Notes**:
  - **Synchronous Callback Defense**: `_requestInFlight` is set to `true` before calling `requestRandomnessPayInNative`, and `vrfRequestId` is assigned only after it returns. If `i_vrfV2PlusWrapper` ever triggered `rawFulfillRandomWords` synchronously during `requestRandomWordsInNative`, `fulfillRandomWords` sees `_requestInFlight == true` and ignores the callback.
  - **Excess ETH Refund**: Uses assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` with 0 output buffer size, preventing return-data bombing (`returndatacopy` griefing). If `msg.sender` reverts on receiving ETH, `NativeRefundFailed` reverts `msg.sender`'s own transaction without affecting other callers.

---

### 6. `Raffle.rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)` (Inherited from `VRFV2PlusWrapperConsumerBase`)
- **Location**: `VRFV2PlusWrapperConsumerBase.sol:L101-107` -> `Raffle.fulfillRandomWords` at `Raffle.sol:L509-524` (Bundle `L1785-1791`, `L522-537`)
- **Access Control**: Contract-Only / Wrapper-Restricted (`msg.sender == address(i_vrfV2PlusWrapper)`)
- **Reentrancy Protection**: None (`nonReentrant` not present on inherited `rawFulfillRandomWords`), protected by `_requestInFlight`, `status == Status.Drawing`, and zero external calls.
- **State Prerequisites**:
  - Soft-checked (emits `VrfCallbackIgnored` and returns without reverting if violated):
    - `!_requestInFlight`
    - `status == Status.Drawing`
    - `requestId == vrfRequestId`
    - `randomWords.length == 1`
    - `block.timestamp < callbackDeadline()` (`drawRequestedAt + 2 days`)
- **State Mutations**:
  - `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`
  - `resolvedAt = uint64(block.timestamp)`
  - `status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon`
- **External Calls**: None.
- **Attack Surface & Audit Notes**:
  - O(1) gas execution well within `VRF_CALLBACK_GAS_LIMIT = 300_000`.
  - Soft-return on invalid/late callback guarantees the wrapper does not revert on late fulfillment after `callbackDeadline()`.

---

### 7. `Raffle.enableRefunds()`
- **Location**: `Raffle.sol:L276-301` (Bundle `L289-314`)
- **Access Control**: Hybrid (Role-Restricted to `sponsor` before `endTime` when `totalEntries == 0`; Public after applicable deadline)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - Branch 1 (`status == Status.Active && totalEntries == 0`): `msg.sender == sponsor || block.timestamp >= endTime`
  - Branch 2 (`status == Status.Active && totalEntries > 0`): `block.timestamp >= drawRequestDeadline()` (`endTime + 2 days`)
  - Branch 3 (`status == Status.Drawing`): `block.timestamp >= callbackDeadline()` (`drawRequestedAt + 2 days`)
- **State Mutations**:
  - `unsettledPot = 0`
  - `remainingRefundLiability = liability` (previous `unsettledPot`)
  - `status = Status.Refunding`
- **External Calls**: None.
- **Attack Surface & Audit Notes**:
  - Strictly enforces liveness recovery windows. Once `status = Status.Refunding`, late VRF callbacks are ignored (`status != Status.Drawing`), and both `refundTickets` and `releaseSponsorPrize` become available.

---

### 8. `Raffle.settleWinningTicket(uint256 ticketId)`
- **Location**: `Raffle.sol:L304-306` & `_settleWinningTicket` at `Raffle.sol:L533-558` (Bundle `L317-319`, `L546-571`)
- **Access Control**: Public (Unrestricted)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - `!settlementComplete`
  - `status == Status.NftWon || status == Status.CashWon`
  - `_ticketRanges[ticketId].firstEntry <= winningEntry <= _ticketRanges[ticketId].lastEntry`
- **State Mutations**:
  - `settlementComplete = true`
  - `winningTicketId = ticketId`
  - `unsettledPot = 0`
  - `protocolFees = Math.mulDiv(grossPot, 500, 10_000)`
  - `sponsorProceeds = grossPot - protocolFee` (if `NftWon`) or `grossPot - protocolFee - cashAmount` (if `CashWon`)
  - `winnerProceeds = Math.mulDiv(grossPot, 8000, 10_000)` (if `CashWon`)
- **External Calls**: None.
- **Attack Surface & Audit Notes**:
  - Decouples liability allocation from asset transfers and ticket ownership checks. Even if the winning ticket has already been burned? Wait: a ticket can only be burned in `redeemWinningTicket` (which settles first) or `refundTickets` (only in `Status.Refunding`), so the winning ticket is guaranteed to exist when `status` is `NftWon` or `CashWon`.
  - Unminted `ticketId`s have `(0, 0)` range, and since `winningEntry >= 1`, `winningEntry > lastEntry (0)` always reverts with `TicketDoesNotContainWinningEntry`.

---

### 9. `Raffle.redeemWinningTicket(uint256 ticketId)`
- **Location**: `Raffle.sol:L309-346` (Bundle `L322-359`)
- **Access Control**: Role-Restricted (`msg.sender == ownerOf(ticketId)`)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - `!winnerRedeemed`
  - `status == Status.NftWon || status == Status.CashWon`
  - If `!settlementComplete`, settles `ticketId`; else requires `ticketId == winningTicketId`
  - `msg.sender == ownerOf(ticketId)`
- **State Mutations**:
  - (If `!settlementComplete`: mutates settlement variables as in `settleWinningTicket`)
  - `winnerRecipient = winner`
  - `winnerRedeemed = true`
  - Burns `ticketId` via `_burn(ticketId)` (`_owners[ticketId] = address(0)`, `_balances[winner] -= 1`, clears approval)
  - If `Status.NftWon`: `prizeClaimed = true`
  - If `Status.CashWon`: `winnerProceeds = 0`
- **External Calls**:
  - If `Status.NftWon`:
    1. `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` — call to **untrusted** `prizeToken`.
    2. `prizeToken.ownerOf(deliveredPrizeTokenId)` — `staticcall` to **untrusted** `prizeToken` (verifies `ownerOf == winner`).
  - If `Status.CashWon`:
    1. `_isProtocolDestination(winner, address(prizeToken))` — `staticcall` to **trusted** `factory`.
    2. `quoteToken.safeTransfer(winner, cashAmount)` — call to **trusted** `quoteToken`.
- **Attack Surface & Audit Notes**:
  - Strict CEI pattern: `winnerRedeemed = true`, `_burn(ticketId)`, and `prizeClaimed = true` / `winnerProceeds = 0` are all written before external token transfers.
  - Uses `prizeToken.transferFrom` rather than `safeTransferFrom` so contract winners that do not implement `IERC721Receiver` are not bricked from claiming an NFT prize, while `prizeToken.ownerOf(deliveredPrizeTokenId) != winner` guards against non-reverting failed transfers.

---

### 10. `Raffle.refundTickets(uint256[] calldata ticketIds)`
- **Location**: `Raffle.sol:L349-372` (Bundle `L362-385`)
- **Access Control**: Role-Restricted (`msg.sender == ownerOf(ticketIds[i])` for all `i`)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - `status == Status.Refunding`
  - `1 <= ticketIds.length <= 100` (`MAX_REFUND_TICKET_BATCH_SIZE`)
  - Every `ticketId` in `ticketIds` is currently owned by `msg.sender`
- **State Mutations**:
  - Burns each `ticketId` in the loop via `_burn(ticketId)`
  - `remainingRefundLiability -= amount` (where `amount = aggregateEntries * ENTRY_PRICE`)
- **External Calls**:
  1. `_isProtocolDestination(msg.sender, address(prizeToken))` — `staticcall` to **trusted** `factory`.
  2. `quoteToken.safeTransfer(msg.sender, amount)` — call to **trusted** `quoteToken`.
- **Attack Surface & Audit Notes**:
  - Calling `_burn(ticketId)` inside each loop iteration sets `_owners[ticketId] = address(0)` immediately, so duplicate `ticketId` entries in `ticketIds` revert on the second iteration with `ERC721NonexistentToken(ticketId)`.

---

### 11. `Raffle.releaseSponsorProceeds()`
- **Location**: `Raffle.sol:L375-382` (Bundle `L388-395`)
- **Access Control**: Public (Unrestricted; transfers only to configured `sponsorRecipient`)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**: `sponsorProceeds > 0` (only non-zero after `_settleWinningTicket` in `NftWon` or `CashWon`)
- **State Mutations**: `sponsorProceeds = 0`
- **External Calls**:
  1. `_isProtocolDestination(sponsorRecipient, address(prizeToken))` — `staticcall` to **trusted** `factory`.
  2. `quoteToken.safeTransfer(sponsorRecipient, amount)` — call to **trusted** `quoteToken`.

---

### 12. `Raffle.releaseProtocolFees()`
- **Location**: `Raffle.sol:L385-392` (Bundle `L398-405`)
- **Access Control**: Public (Unrestricted; transfers only to configured `protocolTreasury`)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**: `protocolFees > 0` (only non-zero after `_settleWinningTicket` in `NftWon` or `CashWon` when `grossPot >= 20` raw units; since 1 entry = `1,000,000` units, `protocolFees` is at least `50,000` units whenever settled)
- **State Mutations**: `protocolFees = 0`
- **External Calls**:
  1. `_isProtocolDestination(protocolTreasury, address(prizeToken))` — `staticcall` to **trusted** `factory`.
  2. `quoteToken.safeTransfer(protocolTreasury, amount)` — call to **trusted** `quoteToken`.

---

### 13. `Raffle.releaseSponsorPrize()`
- **Location**: `Raffle.sol:L395-407` (Bundle `L408-420`)
- **Access Control**: Public (Unrestricted; transfers only to configured `sponsorRecipient`)
- **Reentrancy Protection**: `nonReentrant`
- **State Prerequisites**:
  - `status == Status.CashWon || status == Status.Refunding`
  - `!prizeClaimed`
- **State Mutations**: `prizeClaimed = true`
- **External Calls**:
  1. `prizeToken.transferFrom(address(this), sponsorRecipient, prizeTokenId)` — call to **untrusted** `prizeToken`.
  2. `prizeToken.ownerOf(prizeTokenId)` — `staticcall` to **untrusted** `prizeToken` (verifies `ownerOf == sponsorRecipient`).
- **Attack Surface & Audit Notes**:
  - Unlike `_transferQuote`, `releaseSponsorPrize()` does **not** re-check `_isProtocolDestination(sponsorRecipient, address(prizeToken))`. If `sponsorRecipient` was set to a pre-computed future `Raffle` clone address before that clone was deployed, `releaseSponsorPrize()` will transfer the prize NFT into that other `Raffle` clone (whereas `releaseSponsorProceeds()` will revert with `InvalidQuoteDestination`).

---

### 14–18. Inherited `ERC721` Entry Points on `Raffle` (`approve`, `setApprovalForAll`, `transferFrom`, `safeTransferFrom` x2)
- **Location**: `ERC721.sol:L93-136` + overridden `Raffle._update` at `Raffle.sol:L497-502` (Bundle `L2734-2777`, `L510-515`)
- **Access Control**:
  - `setApprovalForAll(address operator, bool approved)`: Public (Unrestricted for caller's own approvals)
  - `approve(address to, uint256 tokenId)`: Ticket Owner or Approved-for-All Operator
  - `transferFrom` / `safeTransferFrom`: Ticket Owner, Approved Address, or Approved-for-All Operator
- **Reentrancy Protection**: **None** (`nonReentrant` is not applied to inherited `ERC721` functions)
- **State Prerequisites**:
  - Ticket must exist (`_owners[tokenId] != address(0)`)
  - For transfers (`to != address(0)`): `!_isProtocolDestination(to, address(prizeToken))` in `Raffle._update`
- **State Mutations**:
  - `_tokenApprovals`, `_operatorApprovals`, `_owners`, `_balances`
- **External Calls**:
  - In `Raffle._update`: `_isProtocolDestination(to, address(prizeToken))` -> `staticcall` to `factory.raffleImplementation()` and `factory.isRaffle(to)`.
  - In `safeTransferFrom`: `ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data)` -> external call to **untrusted** `to` if `to.code.length > 0`.
- **Attack Surface & Audit Notes**:
  - Note that `approve(to, tokenId)` and `setApprovalForAll(operator, true)` do **not** call `_update` and therefore do not check `_isProtocolDestination` at approval time; however, any actual transfer to a protocol destination will revert in `Raffle._update`.
  - Because `safeTransferFrom` is not `nonReentrant` and updates `_owners[tokenId] = to` before calling `to.onERC721Received`, a contract recipient `to` can immediately call `redeemWinningTicket(tokenId)` or `refundTickets([tokenId])` inside `onERC721Received`. Since `to` is already the legitimate new owner of `tokenId`, this is benign and preserves all accounting invariants.

---

## Files Analyzed

- `packages/contracts/src/RaffleFactory.sol` (1 recurring state-changing entry point + 1 constructor)
- `packages/contracts/src/Raffle.sol` (11 direct recurring state-changing entry points + 6 inherited recurring state-changing entry points + 1 `receive` + 1 constructor)
  - Inherited from `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` (1 state-changing entry point: `rawFulfillRandomWords`)
  - Inherited from `@openzeppelin/contracts/token/ERC721/ERC721.sol` (5 state-changing entry points: `approve`, `setApprovalForAll`, `transferFrom`, `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)`)
