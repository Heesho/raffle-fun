# Entry Point Analysis: raffle.fun Contracts (`RaffleFactory` / `Raffle`)

**Analyzed**: 2026-10-21T08:14:20Z
**Scope**: `packages/contracts/src`, limited to the five authorized production files: `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol` (interfaces in scope). Dependencies in `packages/contracts/node_modules` were read only as context, to resolve inherited entry points and modifiers.
**Languages**: Solidity (`pragma solidity 0.8.36`; `evm_version = cancun`, optimizer 200 runs, `via_ir = false`)
**Focus**: State-changing functions only (view/pure excluded)
**Specification**: repository-root `DESIGN.md` (clean protocol specification). Actual behavior below is taken from source.
**Tooling**:
- Slither 0.11.6 (`entry-points` and `vars-and-auth` printers) with crytic-compile 0.4.2
- solc 0.8.36+commit.8a079791
- Foundry forge 1.7.1, used for a compiled-ABI cross-check and 11 dynamic access-control spot checks

All builds ran on a byte-identical scratch copy in `/tmp`. Nothing under `packages/` was built, written, or modified.

> Path convention: `Raffle.sol:L209` means `packages/contracts/src/Raffle.sol`, line 209. Inherited code is cited relative to `packages/contracts/node_modules/` (for example `@openzeppelin/.../ERC721.sol:L115`).

## Summary

| Category | Count |
|----------|-------|
| Public (Unrestricted) | 9 |
| Role-Restricted | 6 |
| Restricted (Review Required) | 1 |
| Contract-Only | 3 |
| **Total** | **19** |

Counting rules:
- One row per externally callable non-view selector, plus `receive()`. Each is counted once, under its primary category. The sponsor-only branch of `enableRefunds()` is cross-listed under Role-Restricted but not counted twice.
- `RaffleFactory` contributes 1 entry point. `Raffle` contributes 18: 12 declared in `Raffle.sol`, 5 inherited from OpenZeppelin `ERC721`, and 1 inherited from Chainlink `VRFV2PlusWrapperConsumerBase`.
- Every canonical raffle is an ERC-1167 clone that delegates to one `Raffle` implementation, so all 18 apply to every clone. They also exist on the locked implementation, where they are inert (see Deployment-Only Entry Points).
- The two constructors are deployment-only. They are listed separately and not counted.
- Coverage was confirmed three ways with identical results: Slither on the project's own Foundry config, Slither on a direct-solc build, and the compiled ABI. No `fallback()` exists.

**Key observations**

1. **No administrator surface.** There are no owner, admin, governance, guardian, or pauser roles; no setters; and no upgrade, rescue, or sweep functions. There is no `delegatecall`, `selfdestruct`, or `tx.origin` in scope. Factory configuration is `immutable`, and per-raffle configuration is written once in `initialize`. This matches DESIGN.md: "No administrator, mutable configuration or upgrade."
2. **One caller-identity privilege besides ticket ownership.** The sponsor can close an *empty* raffle before `endTime` through `enableRefunds()`. DESIGN.md does not describe this; `IRaffle.sol:L322-323` does.
3. **Anyone can trigger asset movement.**
   - `releaseSponsorProceeds`, `releaseProtocolFees`, and `releaseSponsorPrize` pay fixed beneficiaries.
   - `requestDraw` refunds excess native value to its caller.
   - `buyEntries` and `createRaffle` pull the caller's own USDC or NFT.
4. **Ticket ownership is the main user role.** `redeemWinningTicket` and `refundTickets` require `msg.sender == ownerOf(id)`. ERC-721 approved operators can move tickets but cannot redeem or refund them (verified).
5. **Three contract-only gates.**
   - `initialize`: callable only by the factory.
   - `onERC721Received`: callable only by the configured prize token, and effective only inside `createRaffle`.
   - `rawFulfillRandomWords`: callable only by the VRF wrapper.
6. **Unguarded entry points stay reachable during callbacks.** Ten functions are `nonReentrant` (9 in `Raffle`, plus `createRaffle`). The other 9 entry points stay reachable while those functions make untrusted callbacks: the 5 ERC-721 functions, `onERC721Received`, `rawFulfillRandomWords`, `initialize`, and `receive`. See Trust Boundaries.

---

## Public Entry Points (Unrestricted)

State-changing functions callable by anyone. Prioritize these for attack-surface analysis. Status and time checks below are lifecycle conditions, not restrictions on who may call.

| Function | File | Notes |
|----------|------|-------|
| `createRaffle((address sponsorRecipient, address prizeToken, uint256 prizeTokenId, uint128 reserveEntries, uint64 endTime))` | `RaffleFactory.sol:L97` | `nonReentrant`. The caller becomes the raffle's `sponsor` (L112) and must own the prize and have approved the factory for it. Validation (L98-104, L154-179): the prize must be a contract that reports ERC-721 support via ERC-165; the prize and the recipient must not be protocol plumbing or registered raffles; `reserveEntries > 0`; `now < endTime <= now + 30 days`. Order of operations: clone the implementation with CREATE (L106), `initialize` (L109-121), register in `raffleById`/`idByRaffle`/`isRaffle` (L123-125), and only then pull the NFT with `prize.safeTransferFrom(msg.sender, raffle, id)` (L128). The untrusted prize contract therefore runs while the new clone is registered but still `AwaitingPrize`. The post-checks (`ownerOf == raffle` and `status == Active`, L129-134) rely on the prize contract's own answers. |
| `buyEntries(address recipient, uint128 entryCount)` | `Raffle.sol:L209` | `nonReentrant`. Requires `Active` and `now < endTime`. Pulls `entryCount * 1e6` USDC from `msg.sender` (L224). Writes all accounting first, then mints one range ticket to an arbitrary `recipient` with `_safeMint` (L235), which calls `recipient.onERC721Received` (untrusted). The `_update` override (L497-502) screens `recipient` against protocol destinations. |
| `requestDraw()` **payable** | `Raffle.sol:L240` | `nonReentrant`. Requires `Active`, `endTime <= now < endTime + 2 days`, `totalEntries > 0`, and `msg.value` at least the wrapper's quote. Sets `Drawing`, `drawRequestedAt`, and `vrfRequestId`. Refunds `msg.value - paidPrice` to `msg.sender` with an all-gas raw `call` (L262-270), which is an untrusted re-entry point; if that refund fails, the whole request reverts. The caller chooses only the timing; the randomness comes from VRF. |
| `settleWinningTicket(uint256 ticketId)` | `Raffle.sol:L304` → `_settleWinningTicket` `L533` | `nonReentrant`. Runs once, in `NftWon` or `CashWon`. The supplied ticket's historical range must contain `winningEntry` (L579-585). Storage-only: no external calls and no ownership read. Records `winningTicketId` and allocates `winnerProceeds`, `sponsorProceeds`, and `protocolFees`. Allocation rounds down with `mulDiv`; the sponsor receives the remainder. |
| `releaseSponsorProceeds()` | `Raffle.sol:L375` | `nonReentrant`. Any caller. Pays the entire `sponsorProceeds` balance to the fixed `sponsorRecipient` via `_transferQuote`, which screens the destination again at payout time (L565). The balance is non-zero only after settlement. |
| `releaseProtocolFees()` | `Raffle.sol:L385` | `nonReentrant`. Any caller. Pays the entire `protocolFees` balance to the fixed `protocolTreasury`, an immutable of the factory. The balance is non-zero only after settlement. |
| `releaseSponsorPrize()` | `Raffle.sol:L395` | `nonReentrant`. Any caller, in `CashWon` or `Refunding`, once (guarded by `prizeClaimed`). Calls the untrusted `prizeToken.transferFrom(this, sponsorRecipient, prizeTokenId)`, a non-safe transfer with no receiver hook, then checks `ownerOf` (L404-405). The recipient is not screened again at delivery (Trust-Boundary Note 2). |
| `setApprovalForAll(address operator, bool approved)` | `@openzeppelin/contracts/token/ERC721/ERC721.sol:L105` (inherited) | Affects only the caller's own tickets: sets operator approval over them, in any status. Operators are not screened, but this is harmless: no protocol contract can call transfers on tickets, because the factory rejects registered raffles and the implementation as prize tokens. |
| `receive()` **payable** | `Raffle.sol:L171` | Always reverts with `DirectNativeTransfer()`, so it cannot change state. There is no `fallback()`, so calls with unknown selectors revert. |

Also callable by anyone once its deadline passes: `enableRefunds()`. It is classified under Restricted (Review Required) because it has a sponsor-only branch.

---

## Role-Restricted Entry Points

### Admin / Owner
| Function | File | Restriction |
|----------|------|-------------|
| None | n/a | No `Ownable` or `AccessControl` inheritance and no `onlyOwner`-style checks. `RaffleFactory` configuration (`quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation`) is `immutable`. |

### Governance
| Function | File | Restriction |
|----------|------|-------------|
| None | n/a | None. |

### Guardian / Pauser
| Function | File | Restriction |
|----------|------|-------------|
| None | n/a | No pause, emergency, rescue, sweep, or upgrade entry points. |

### Other Roles
| Function | File | Restriction | Role |
|----------|------|-------------|------|
| `redeemWinningTicket(uint256 ticketId)` | `Raffle.sol:L309` | `nonReentrant`. Requires `NftWon` or `CashWon` and `!winnerRedeemed`. Settles inline if not yet settled; otherwise requires `ticketId == winningTicketId` (L314-318). Then requires `msg.sender == ownerOf(ticketId)` (L320-321). | **Winning-ticket owner.** This is a bearer role that moves with ERC-721 transfers; approved operators are rejected. The ticket is burned (L325) before delivery. Delivery is either the NFT, via the untrusted `prizeToken.transferFrom` plus an `ownerOf` post-check (L334-337), or USDC via `_transferQuote` (L342). A failed delivery reverts every effect, including the inline settlement (verified). |
| `refundTickets(uint256[] ticketIds)` | `Raffle.sol:L349` | `nonReentrant`. Requires `Refunding`, a batch of 1-100 IDs, and `msg.sender == ownerOf(id)` for every ID (L359-360). | **Owner of every ticket in the batch.** Approved operators are rejected. Each ticket is burned, and `entries * 1e6` USDC is paid to `msg.sender`. A duplicate ID reverts the batch, because `ownerOf` reverts on an already-burned ticket. |
| `approve(address to, uint256 tokenId)` | `@openzeppelin/.../ERC721.sol:L93` (inherited) | `_approve` with `auth = msg.sender`: the owner or an operator-for-all (`ERC721.sol:L383-391`) | Ticket owner / operator |
| `transferFrom(address from, address to, uint256 tokenId)` | `@openzeppelin/.../ERC721.sol:L115` (inherited) | `_isAuthorized` allows the owner, the token-approved address, or an operator (`ERC721.sol:L164-168`). The `Raffle._update` override (`Raffle.sol:L497-502`) rejects protocol destinations before the authorization check runs. | Ticket owner / approved / operator. No lifecycle check: tickets are transferable in every status until burned. |
| `safeTransferFrom(address from, address to, uint256 tokenId)` | `@openzeppelin/.../ERC721.sol:L128` (inherited) | Same as `transferFrom`, plus a callback to `to.onERC721Received` (untrusted) | Ticket owner / approved / operator |
| `safeTransferFrom(address from, address to, uint256 tokenId, bytes data)` | `@openzeppelin/.../ERC721.sol:L133` (inherited) | Same as above | Ticket owner / approved / operator |

Cross-listed sponsor branch (counted under Review Required): `enableRefunds()` at `Raffle.sol:L282`. The address that called `createRaffle` may move an empty raffle (`totalEntries == 0`) to `Refunding` before `endTime`.

#### Role inventory

| Role | How it is assigned | Can change? | Entry points it can call |
|------|--------------------|-------------|--------------------------|
| Anyone | n/a | n/a | The 9 public entry points, plus `enableRefunds()` once its deadlines pass |
| Sponsor | `msg.sender` of `createRaffle` (`RaffleFactory.sol:L112`), stored by `initialize` | No | The empty-raffle early close in `enableRefunds()` |
| Ticket owner | ERC-721 ownership: the mint `recipient`, then later transfers | Yes (bearer) | `redeemWinningTicket`, `refundTickets`, `approve`, `transferFrom`, both `safeTransferFrom` overloads |
| Ticket approved address / operator | The owner's `approve` or `setApprovalForAll` | Yes | `transferFrom` and both `safeTransferFrom` overloads, but not redeem or refund. An operator-for-all can also call `approve`. |
| RaffleFactory | The `factory` immutable, set to the implementation's deployer (`Raffle.sol:L161`) | No | `initialize` |
| Chainlink VRF v2.5 wrapper | The `i_vrfV2PlusWrapper` immutable (a factory constructor argument) | No | `rawFulfillRandomWords` |
| Prize token contract | `prizeToken`, chosen by the sponsor and stored by `initialize` | No | `onERC721Received`, effective only while `AwaitingPrize` |
| `sponsorRecipient`, `protocolTreasury` | A sponsor parameter / a factory immutable | No | None. They are passive payees of the permissionless release functions. |

---

## Restricted (Review Required)

Functions with access control patterns that need manual verification.

| Function | File | Pattern | Why Review |
|----------|------|---------|------------|
| `enableRefunds()` | `Raffle.sol:L276` | `nonReentrant`. Behavior depends on state. **`Active` with `totalEntries == 0`**: `if (msg.sender != sponsor && block.timestamp < endTime) revert` (L280-284). The sponsor may call at any time; anyone else from `endTime`. **`Active` with `totalEntries > 0`**: anyone from `endTime + 2 days` (L286-287). **`Drawing`**: anyone from `drawRequestedAt + 2 days` (L290-291). **Any other status** reverts with `InvalidStatus`. Effect: moves `unsettledPot` into `remainingRefundLiability` and sets `Refunding`. | **Mixed access**: a sponsor-only branch alongside time-gated public branches.<br>(1) The sponsor's early-close privilege is not in DESIGN.md ("No administrator… Refunds open at deadline"), though `IRaffle.sol:L322-323` documents it. Confirm it is intended. Its reach is limited: it works only before the first sale, and the first `buyEntries` disables it permanently (verified).<br>(2) **Race with VRF.** At `now == callbackDeadline()` the VRF callback is ignored (`>=`, L512) and refunds open in the same second. The two boundaries are consistent (verified). Still, anyone can force `Refunding` the instant a callback window lapses, and likewise at `endTime + 2 days` against `requestDraw`. |

---

## Contract-Only (Internal Integration Points)

Functions callable only by other contracts. These map the trust boundaries.

| Function | File | Expected Caller | Gate and notes |
|----------|------|-----------------|----------------|
| `initialize((address sponsor, address sponsorRecipient, address protocolTreasury, address prizeToken, uint256 prizeTokenId, uint256 raffleId, uint128 reserveEntries, uint64 endTime))` | `Raffle.sol:L176` | `RaffleFactory`. Called from `createRaffle` (`RaffleFactory.sol:L109-121`), on the clone it just created, in the same transaction. | Checks the one-shot `!initialized` flag (L177), then `msg.sender == factory` (L178). `factory` is an immutable of the implementation, so every clone shares it. The factory itself sets `sponsor = msg.sender` and `protocolTreasury`; the sponsor supplies the remaining fields. `sponsor`, `sponsorRecipient`, and `protocolTreasury` are each screened by `_isProtocolDestination` (L187-195). The implementation is pre-locked (`initialized = true`, `status = Refunding`, L164-165). There is no front-running window, because canonical clones are created and initialized in one transaction and only the factory may call `initialize`. A clone of the implementation created by a third party can never be initialized and stays permanently inert. (Rejection verified; inertness by inspection.) Leaves the clone in `AwaitingPrize`. |
| `onERC721Received(address operator, address from, uint256 tokenId, bytes)` | `Raffle.sol:L416` | The configured `prizeToken`, during `createRaffle`'s `prize.safeTransferFrom(sponsor, raffle, prizeTokenId)` (`RaffleFactory.sol:L128`) | Requires `status == AwaitingPrize`, `msg.sender == prizeToken`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory` (L421-426). This is the **only** path from `AwaitingPrize` to `Active`, and `AwaitingPrize` exists only inside the atomic `createRaffle` transaction. After activation, every safe NFT transfer to the raffle reverts, even from the prize contract with exactly the expected arguments (verified). The caller is the sponsor-chosen prize contract, which DESIGN.md treats as untrusted (Trust-Boundary Note 1). |
| `rawFulfillRandomWords(uint256 requestId, uint256[] randomWords)` | `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101` (inherited) → `Raffle.fulfillRandomWords` `Raffle.sol:L509` | The Chainlink VRF v2.5 native direct-funding wrapper (`i_vrfV2PlusWrapper`), an immutable of the implementation shared by all clones | Requires `msg.sender == i_vrfV2PlusWrapper` (base contract, L102-105). Not `nonReentrant`. Storage-only, with no external calls. The following callbacks are ignored rather than reverted (L510-516; each emits `VrfCallbackIgnored`): one arriving during the request itself (a synchronous callback inside `requestDraw`, tracked by `_requestInFlight`, L254/L260); a late one (`>= callbackDeadline`); a wrong request ID; a wrong status; and any word count other than 1. An accepted callback writes only `winningEntry`, `resolvedAt`, and `status`. The status becomes `NftWon` if `totalEntries >= reserveEntries`, otherwise `CashWon`. |

### Deployment-Only Entry Points (not counted)

| Function | File | Notes |
|----------|------|-------|
| `constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_)` | `RaffleFactory.sol:L65` | Takes the configuration from the deployer and makes it permanently immutable. Requires code at the quote token and the wrapper, `decimals() == 6`, and a non-zero treasury that is not the factory, quote token, wrapper, or implementation. Deploys the implementation with `new Raffle(...)` (L89), using factory nonce 1. On-chain checks cannot prove the quote token is the official USDC (`IRaffleFactory.sol:L7-9`). |
| `constructor(address quoteToken_, address vrfWrapper_)` | `Raffle.sol:L155` | Runs once, from the factory constructor. Sets `factory = msg.sender` and `quoteToken`; the base constructor reads `vrfWrapper.link()`. Locks the implementation with `initialized = true` and `status = Refunding`. Clones never execute it. On the implementation, every lifecycle entry point reverts:<br>• `initialize` → `AlreadyInitialized`<br>• status- and balance-gated functions → `InvalidStatus` / `No*`<br>• `releaseSponsorPrize` → reverts calling the code-less zero-address `prizeToken`<br>• `refundTickets` → no tickets exist<br>Seven of these were verified dynamically; the rest by inspection. Only `setApprovalForAll`, which affects just the caller's own (nonexistent) tickets, can succeed there, and wrapper callbacks are ignored. |

---

## Lifecycle Gating Matrix

`Status` flow: `AwaitingPrize → Active → Drawing → (NftWon or CashWon)`. `Active` and `Drawing` can instead move to `Refunding`.

| Entry point | Callable in status | Other conditions | Effect / transition |
|-------------|--------------------|------------------|---------------------|
| `createRaffle` | n/a (factory) | Caller owns the prize and has approved the factory; parameters validated | New registered clone, ending in `Active` |
| `initialize` | Uninitialized clone | Factory only | → `AwaitingPrize` |
| `onERC721Received` | `AwaitingPrize` | Prize token; exact operator, from, and tokenId | → `Active` |
| `buyEntries` | `Active` | `now < endTime`; `entryCount > 0`; `recipient != 0` | Mint ticket; `unsettledPot += cost` |
| `requestDraw` | `Active` | `endTime <= now < endTime + 2 days`; `totalEntries > 0`; fee paid | → `Drawing` |
| `rawFulfillRandomWords` | Any (no-op unless `Drawing`) | Wrapper only; `now < drawRequestedAt + 2 days`; request ID matches; 1 word; not in flight | → `NftWon` / `CashWon` |
| `enableRefunds` | `Active`, `Drawing` | See Restricted (Review Required) | → `Refunding` |
| `settleWinningTicket` | `NftWon`, `CashWon` | Once; the ticket's range contains `winningEntry` | Allocate liabilities |
| `redeemWinningTicket` | `NftWon`, `CashWon` | Once; caller owns the winning ticket | Burn ticket; deliver prize or cash |
| `refundTickets` | `Refunding` | Caller owns every ID; 1-100 IDs | Burn tickets; pay `entries * 1e6` |
| `releaseSponsorProceeds` | Any (balance is set only by settlement) | `sponsorProceeds > 0` | Pay `sponsorRecipient` |
| `releaseProtocolFees` | Any (balance is set only by settlement) | `protocolFees > 0` | Pay `protocolTreasury` |
| `releaseSponsorPrize` | `CashWon`, `Refunding` | Once (`prizeClaimed`) | NFT → `sponsorRecipient` |
| `approve` / `transferFrom` / `safeTransferFrom` ×2 | Any | Ticket exists; ERC-721 authorization; destination filter on transfers | Ticket ownership or approval changes |
| `setApprovalForAll` | Any | `operator != 0` | Operator approval |
| `receive` | n/a | Always reverts | None |

Boundary consistency (verified):
- Sales close exactly when draw requests open, at `endTime`.
- Draw requests close exactly when refunds open for a sold raffle, at `endTime + 2 days`.
- VRF callbacks stop being accepted exactly when refunds open for a `Drawing` raffle, at `drawRequestedAt + 2 days`.

---

## Trust Boundaries and Reentrancy Surface

| Entry point | Guard | Outbound calls (trust level) |
|-------------|-------|------------------------------|
| `createRaffle` | `nonReentrant` (factory's own lock) | In order:<br>• `prizeToken.supportsInterface` (untrusted, inside try/catch)<br>• CREATE the clone<br>• `clone.initialize`, which calls back into the factory views `raffleImplementation` and `isRaffle` (trusted)<br>• `prizeToken.safeTransferFrom` (untrusted), which in turn calls `clone.onERC721Received`<br>• `prizeToken.ownerOf` (untrusted)<br>• `clone.status` |
| `buyEntries` | `nonReentrant` | `USDC.transferFrom` (trusted); factory views (trusted); `recipient.onERC721Received` if `recipient` has code (untrusted) |
| `requestDraw` | `nonReentrant` | `wrapper.calculateRequestPriceNative` (twice) and `wrapper.requestRandomWordsInNative{value}` (trusted); a native refund `call` to `msg.sender` forwarding all gas (untrusted) |
| `enableRefunds`, `settleWinningTicket` | `nonReentrant` | None |
| `redeemWinningTicket` | `nonReentrant` | `NftWon`: `prizeToken.transferFrom` and `ownerOf` (untrusted). `CashWon`: factory views and `USDC.transfer` (trusted). |
| `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees` | `nonReentrant` | Factory views and `USDC.transfer` (trusted) |
| `releaseSponsorPrize` | `nonReentrant` | `prizeToken.transferFrom` and `ownerOf` (untrusted) |
| `initialize` | None | Factory views (trusted) |
| `transferFrom` | None | Factory views, for destination screening (trusted) |
| `safeTransferFrom` ×2 | None | Factory views; `to.onERC721Received` if `to` has code (untrusted) |
| `onERC721Received`, `rawFulfillRandomWords`, `approve`, `setApprovalForAll`, `receive` | None | None |

- **One lock per clone.** Each clone has its own OpenZeppelin `ReentrancyGuard` slot (ERC-7201 slot `0x9b779b17…5f00`, stored in the clone's own storage). It works even though clone storage starts at zero, because OZ v5 tests for `== ENTERED`. The factory's lock is separate from the clones' locks.
- **Untrusted callbacks.** They come from three sources:
  - the prize token, in `createRaffle`, `redeemWinningTicket`, and `releaseSponsorPrize`
  - ticket recipients, in `buyEntries` and `safeTransferFrom`
  - the refund recipient, in `requestDraw`
- **What re-entry can reach.** During any of those callbacks, every guarded function on the same clone reverts. Only these remain reachable:
  - the ERC-721 `approve`, `setApprovalForAll`, `transferFrom`, and `safeTransferFrom` functions, limited to tickets the calling contract itself is authorized for
  - `onERC721Received`, which reverts unless the clone is `AwaitingPrize`
  - `initialize`, which is factory-only and one-shot
  - `rawFulfillRandomWords`, which is wrapper-only
  - `receive`, which always reverts
- **State is written before every untrusted call** (checks-effects-interactions):
  - `buyEntries` updates accounting before `_safeMint`.
  - `redeemWinningTicket` burns the ticket and sets its flags before delivery.
  - `releaseSponsorPrize` sets `prizeClaimed` before the transfer.
  - `requestDraw` writes its state before the refund.
- **The `createRaffle` window.** While `prizeToken.safeTransferFrom` runs, the new clone is already registered and initialized but still `AwaitingPrize`. The factory's lock blocks a nested `createRaffle`. Any interference that leaves the clone not `Active`, or not owning the prize, reverts the whole creation.

### Trust-boundary notes for follow-up

The mechanics below were verified. They are pointers for review, not findings.

1. **Prize authenticity depends entirely on the prize contract being honest.**
   - Activation (`onERC721Received`) and the factory's escrow checks (`ownerOf`, `status`) both rely on what the sponsor-selected prize contract reports.
   - DESIGN.md says "arbitrary prize contracts … are untrusted". `IRaffle.sol:L14-15`, however, assumes "Supported prizes are honest, standards-compliant ERC-721s".
   - A dishonest prize contract cannot be detected on-chain, so buyer protection relies on off-chain vetting (DESIGN.md: "Frontend discovery is advisory").
2. **Destination screening happens only at call time.**
   - Why it can be bypassed: `_isProtocolDestination` (`Raffle.sol:L593-605`) queries `isRaffle` only for addresses that already have code. Clones are deployed with CREATE, so their addresses are predictable in advance.
   - The verified scenario (`test_pointInTimeDestinationScreening_futureCloneRecipient`):
     - A sponsor sets `sponsorRecipient` to the address a future clone will occupy. It passes every check at creation.
     - Once that clone exists, `releaseSponsorProceeds()` reverts with `InvalidQuoteDestination`. There is no alternative payee, so the sponsor's USDC can never be released.
     - Anyone can call `releaseSponsorPrize()`, which moves the prize NFT into the other registered clone.
   - The underlying asymmetry: USDC payouts (`_transferQuote`) re-check the destination at payout time, but NFT deliveries do not. That covers `releaseSponsorPrize` and the `NftWon` branch of `redeemWinningTicket`.
   - Only the sponsor's own choice of recipient can cause this, so it is self-inflicted. It still bears on DESIGN.md's "Never move assets between raffle clones".
   - The same applies to ticket recipients in `buyEntries` and in transfers, self-inflicted by the holder.
3. **Permissionless push versus "claim".**
   - DESIGN.md says "Sponsor and treasury can claim independently after settlement." In the code, any caller can trigger all three release functions. Because the payees are fixed, a third party controls only the timing.
   - Independence holds: there are separate balances and separate functions, and the prize release does not wait for settlement (verified).
   - Confirm the push model is intended, particularly because `releaseSponsorPrize` uses a non-safe `transferFrom` into `sponsorRecipient`.
4. **Native value.**
   - `requestDraw` is the only function that accepts ETH (`receive()` is payable but always reverts). Its refund of excess value must succeed, so a requester contract that rejects ETH can request a draw only by sending exactly the fee.
   - Any other address can still request the draw, so this does not affect liveness.

---

## DESIGN.md Cross-Reference (access and gating only)

| DESIGN.md statement | Entry point(s) | Behavior in source | Status |
|---------------------|----------------|--------------------|--------|
| Immutable factory; ERC-1167 clones with an immutable implementation | `createRaffle`, constructors | Factory configuration is immutable; clones are created with `Clones.clone` (CREATE); there is no upgrade path | Consistent |
| No administrator, mutable configuration, or upgrade | All | No admin roles or setters. However, each raffle's sponsor holds the empty-raffle early-close branch. | **Review** (sponsor branch) |
| One entry costs 1,000,000 units; each purchase mints one transferable range ticket | `buyEntries`, ERC-721 functions | `entryCount * ENTRY_PRICE` is pulled from the caller; one ticket per purchase; tickets transferable in every status; protocol sinks filtered | Consistent |
| Exactly one ERC-721 prize is escrowed atomically at creation | `createRaffle` → `onERC721Received` | Activation happens only through the factory-operated safe transfer; the post-checks rely on the prize contract | Consistent (Trust-Boundary Note 1) |
| Draw-request window is `[sale end, end + 2 days)` | `requestDraw` | `endTime <= now < endTime + 2 days`; callable by anyone; at least one entry required | Consistent |
| Callback accepted strictly before request timestamp + 2 days | `rawFulfillRandomWords` | Ignored once `now >= drawRequestedAt + 2 days` | Consistent |
| Refunds open at the deadline | `enableRefunds` | Anyone at the deadline; empty raffles from `endTime`; the sponsor at any time while the raffle is empty | **Review** (sponsor branch) |
| The callback records the result only | `rawFulfillRandomWords` | Writes only `winningEntry`, `resolvedAt`, and `status` | Consistent |
| Settlement is permissionless and storage-only | `settleWinningTicket` | No caller check and no external calls | Consistent |
| Redemption requires the current ticket owner, burns atomically, and reverts all effects if delivery fails | `redeemWinningTicket` | Requires `msg.sender == ownerOf`; operators rejected; burn and delivery in one transaction; `ownerOf` post-check for the NFT | Consistent |
| Splits: 95/5 when the reserve is met, 80/15/5 when missed; fee rounded down; remainder allocated without loss | `settleWinningTicket` / `redeemWinningTicket` | `mulDiv` rounds down and the sponsor gets the remainder. Spot-checked: 950,000 / 50,000 and 1,600,000 / 300,000 / 100,000. | Consistent |
| Sponsor and treasury can claim independently after settlement | `releaseSponsorProceeds`, `releaseProtocolFees` | Anyone triggers; payees are fixed; the two are independent | **Review** (push versus claim, Trust-Boundary Note 3) |
| A refund outcome pays 100% per entry and returns the prize | `refundTickets`, `releaseSponsorPrize` | Refunds are owner-only at `1e6` per entry; anyone can push the prize to `sponsorRecipient` | Consistent |
| Never move assets between raffle clones | `_transferQuote`, `_update`, `releaseSponsorPrize`, `redeemWinningTicket` | USDC destinations are re-checked at payout; NFT deliveries are not; all screening is point-in-time | **Review** (Trust-Boundary Note 2) |
| The quote token and wrapper are trusted; prize contracts and ticket recipients are untrusted | See Trust Boundaries | Every untrusted callback is mapped in that section | Mapped |

---

## Interface Coverage (in-scope interfaces)

- `IRaffle.sol` declares 10 state-changing functions (L308-355): `initialize`, `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`. `Raffle` implements all 10 with `override` and the same mutability; `requestDraw` is `payable` in both.
- `Raffle` exposes **8 runtime entry points that `IRaffle` does not declare**: `receive`, `onERC721Received` (from `IERC721Receiver`), `rawFulfillRandomWords` (from the Chainlink base), and the 5 ERC-721 functions. Anyone working only from the `IRaffle` ABI will miss the ticket transfer and approval surface and both callbacks.
- `IRaffleFactory.sol` declares one state-changing function, `createRaffle` (L104), which `RaffleFactory` implements.
- View functions are excluded: 39 declared in `IRaffle` and 10 in `IRaffleFactory`. The compiled ABIs contain 50 view/pure functions for `Raffle` and 10 for `RaffleFactory`.

## Function Selectors (state-changing)

| Selector | Signature | Contract | Category |
|----------|-----------|----------|----------|
| `0x2001c3a9` | `createRaffle((address,address,uint256,uint128,uint64))` | RaffleFactory | Public |
| `0x633496b0` | `buyEntries(address,uint128)` | Raffle | Public |
| `0xa57848b6` | `requestDraw()` (payable) | Raffle | Public |
| `0xf826247d` | `settleWinningTicket(uint256)` | Raffle | Public |
| `0xdacb72e4` | `releaseSponsorProceeds()` | Raffle | Public |
| `0xada9191b` | `releaseProtocolFees()` | Raffle | Public |
| `0x66b15c78` | `releaseSponsorPrize()` | Raffle | Public |
| `0xa22cb465` | `setApprovalForAll(address,bool)` | Raffle (ERC721) | Public |
| (none) | `receive()` (payable; empty calldata) | Raffle | Public (always reverts) |
| `0x9eea8cec` | `redeemWinningTicket(uint256)` | Raffle | Role: ticket owner |
| `0x565b7d0e` | `refundTickets(uint256[])` | Raffle | Role: ticket owner |
| `0x095ea7b3` | `approve(address,uint256)` | Raffle (ERC721) | Role: ticket owner / operator |
| `0x23b872dd` | `transferFrom(address,address,uint256)` | Raffle (ERC721) | Role: ticket owner / approved / operator |
| `0x42842e0e` | `safeTransferFrom(address,address,uint256)` | Raffle (ERC721) | Role: ticket owner / approved / operator |
| `0xb88d4fde` | `safeTransferFrom(address,address,uint256,bytes)` | Raffle (ERC721) | Role: ticket owner / approved / operator |
| `0x8c52dc41` | `enableRefunds()` | Raffle | Review Required |
| `0x16a841a7` | `initialize((address,address,address,address,uint256,uint256,uint128,uint64))` | Raffle | Contract-Only (factory) |
| `0x150b7a02` | `onERC721Received(address,address,uint256,bytes)` | Raffle | Contract-Only (prize token) |
| `0x1fe543e3` | `rawFulfillRandomWords(uint256,uint256[])` | Raffle (VRF base) | Contract-Only (VRF wrapper) |

---

## Dynamic Verification (Foundry spot checks)

Result: 11 tests, **11 passed, 0 failed**.

- **Setup.** The tests ran on the scratch copy with three mocks: a minimal 6-decimal ERC-20, an OpenZeppelin-based ERC-721 prize, and a VRF wrapper.
- **Limits.** They confirm the access checks as written in source. They do not model real USDC or the production Chainlink wrapper.
- **Revert matching.** Each expected revert is matched against the exact 4-byte error selector.

| Test | Confirms |
|------|----------|
| `test_implementationIsLocked` | The implementation reports `initialized`, `status == Refunding`, and `factory() == RaffleFactory`. Each call reverts as expected:<br>• `initialize` from the factory → `AlreadyInitialized`<br>• `enableRefunds`, `buyEntries` → `InvalidStatus`<br>• release functions → `NoSponsorProceeds` / `NoProtocolFees`<br>• `releaseSponsorPrize` → empty revert (call into the code-less `prizeToken`)<br>• `refundTickets` → `ERC721NonexistentToken` |
| `test_initializeOnlyFactory` | A third-party clone is unregistered and uninitialized, reports the canonical `factory()`, and rejects `initialize` with `OnlyFactory`. A canonical clone is registered, its `sponsor()` is the `createRaffle` caller, and it is `Active`. Re-initializing it from the factory → `AlreadyInitialized`. |
| `test_enableRefunds_sponsorEarlyCloseOnlyWhenEmpty` | • A non-sponsor before `endTime` → `RefundsNotAvailable`.<br>• The sponsor before `endTime` on an empty raffle → `Refunding`.<br>• After one sale, the sponsor is rejected both before and after `endTime`.<br>• Anyone is rejected at `endTime + 2 days - 1` and accepted at `endTime + 2 days`.<br>• Anyone can close an empty raffle at `endTime`.<br>• A third-party `releaseSponsorPrize` returns the NFT to `sponsorRecipient`. |
| `test_requestDraw_permissionlessWindow` | Rejections: `NoEntriesSold` (empty raffle), `RaffleNotEnded` (before `endTime`), `DrawRequestWindowExpired` (at `endTime + 2 days`). An arbitrary caller succeeds at `endTime + 2 days - 1`. |
| `test_callbackGateAndDeadline` | A non-wrapper call to `rawFulfillRandomWords` → `OnlyVRFWrapperCanFulfill`. Refunds are rejected at `callbackDeadline - 1`. A wrapper callback at `callbackDeadline` is ignored (status stays `Drawing`), and refunds open in the same second. |
| `test_onERC721Received_onlyDuringFactoryEscrow` | After activation, each of these reverts with `UnexpectedPrize`: the prize contract calling with exactly the expected arguments, an arbitrary caller, and an unrelated safe NFT transfer. |
| `test_receiveReverts` | A plain ETH transfer → `DirectNativeTransfer` |
| `test_nftWon_redeemOwnerOnly` | • An operator-for-all cannot redeem (`NotTicketOwner`).<br>• Third-party settlement succeeds.<br>• A ticket transfer to the factory → `UnsafeProtocolDestination`.<br>• The operator transfers the ticket after the result. The former owner's redeem is then rejected, and the new owner receives the NFT.<br>• `releaseSponsorPrize` → `SponsorPrizeUnavailable`.<br>• Third-party releases pay 950,000 / 50,000. |
| `test_cashWon_paths` | A third-party `releaseSponsorPrize` succeeds in `CashWon` before settlement. A non-owner redeem reverts and rolls back the inline settlement. The owner's redeem pays 1,600,000. Third-party releases pay 300,000 / 100,000. |
| `test_refund_ownerOnly` | A non-owner and a token-approved operator are both rejected with `NotTicketOwner`. The owner is refunded 3,000,000 for 3 entries. A third party can return the prize in `Refunding`. |
| `test_pointInTimeDestinationScreening_futureCloneRecipient` | A `sponsorRecipient` set to the predicted next clone address passes creation. Once that clone exists, `releaseSponsorProceeds` → `InvalidQuoteDestination`, and `releaseSponsorPrize` moves the NFT into the other registered clone. |

---

## Files Analyzed

- `packages/contracts/src/Raffle.sol`: **18 state-changing entry points**, plus 1 deployment-only constructor.
  - Declared (12): `receive`, `initialize`, `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `onERC721Received`.
  - Inherited (6): `approve`, `setApprovalForAll`, `transferFrom`, both `safeTransferFrom` overloads, `rawFulfillRandomWords`.
  - Internal overrides relevant to access: `_update` (L497) and `fulfillRandomWords` (L509).
- `packages/contracts/src/RaffleFactory.sol`: **1 state-changing entry point** (`createRaffle`), plus 1 deployment-only constructor.
- `packages/contracts/src/interfaces/IRaffle.sol`: **0** (declarations only). Its 10 state-changing declarations are all implemented in `Raffle.sol`.
- `packages/contracts/src/interfaces/IRaffleFactory.sol`: **0** (declarations only). Its one state-changing declaration, `createRaffle`, is implemented in `RaffleFactory.sol`.
- `packages/contracts/src/libraries/RaffleConstants.sol`: **0**. It holds only `internal constant` values, and these supply every gate parameter:
  - `ENTRY_PRICE = 1_000_000`
  - `MAX_REFUND_TICKET_BATCH_SIZE = 100`
  - `MAX_SALE_DURATION = 30 days`
  - `DRAW_REQUEST_TIMEOUT = DRAW_CALLBACK_TIMEOUT = 2 days`
  - `PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8000`, `BPS = 10_000`
  - `VRF_CALLBACK_GAS_LIMIT = 300_000`, `VRF_REQUEST_CONFIRMATIONS = 30`
  - `QUOTE_TOKEN_DECIMALS = 6`

Source fingerprints (SHA-256) at analysis time:

```
6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617  src/Raffle.sol
d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace  src/RaffleFactory.sol
a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd  src/interfaces/IRaffle.sol
747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf  src/interfaces/IRaffleFactory.sol
0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6  src/libraries/RaffleConstants.sol
```

Context-only dependencies consulted (not in scope). All 31 files under `node_modules` match `dependency-hashes.json`, and there are no unlisted files.
- `@openzeppelin/contracts/token/ERC721/ERC721.sol`: the 5 inherited ticket entry points, plus the `_update`, `_isAuthorized`, and `_approve` authorization logic
- `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`: `rawFulfillRandomWords` and its wrapper check
- `@openzeppelin/contracts/utils/ReentrancyGuard.sol`: the `nonReentrant` implementation
- `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol`: the receiver callback and how it bubbles reverts
- `@openzeppelin/contracts/proxy/Clones.sol`: CREATE-based ERC-1167 deployment

## Analysis Warnings

- **No parse or compile failures.** Slither analyzed 36 contracts in both framework modes. `forge build` with the project's original `foundry.toml` and `remappings.txt` compiled 36 files.
- **Missing remapping entry.** `remappings.txt` has no `@chainlink/contracts/` entry. Foundry generates `@chainlink/=node_modules/@chainlink/` automatically (confirmed with `forge remappings`), so the imports resolve to the hash-verified files.
- **Missing Slither config.** The `slither` script in `package.json` refers to `slither.config.json`, which is not in the repository. Slither therefore ran with its default configuration, printers only; vulnerability detectors are outside this skill.
- **No project tests.** The repository has no tests or scripts, although `foundry.toml` points to `test/foundry` and `script`. The spot checks above are ad hoc, not the project's own test suite.
- **No changes under `packages/`.** All builds ran on scratch copies under `/tmp/tob-s2-epa.KGv9n9/`, which `cmp` confirmed were byte-identical to the originals. Directory modification times under `packages/` are unchanged.

## Methodology and Reproduction

1. Read every in-scope function line by line. Traced every `msg.sender` comparison, status check, time check, and modifier to its actual implementation, including inherited OpenZeppelin and Chainlink code, rather than inferring behavior from names.
2. Cross-checked the result against Slither's `entry-points` and `vars-and-auth` printers and against the compiled ABI.
3. Confirmed the non-obvious access checks dynamically, using the harness in the appendix.

```bash
SOLC=~/.solc-select/artifacts/solc-0.8.36/solc-0.8.36
SCR=$(mktemp -d /tmp/tob-s2-epa.XXXXXX); mkdir -p "$SCR/origcfg"
cp -R packages/contracts/{src,node_modules,foundry.toml,remappings.txt} "$SCR/origcfg/"
cd "$SCR/origcfg"

# 1. Canonical skill command against the project's own Foundry configuration
forge build --offline --use "$SOLC" --force --build-info
slither . --ignore-compile --print entry-points

# 2. Equivalent direct-solc run, plus the authorization printer
slither src/RaffleFactory.sol --solc "$SOLC" \
  --solc-remaps "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/ @chainlink/contracts/=node_modules/@chainlink/contracts/" \
  --solc-args "--optimize --optimize-runs 200 --evm-version cancun" \
  --print entry-points,vars-and-auth

# 3. ABI cross-check (all non-view selectors, including inherited ones)
"$SOLC" @openzeppelin/contracts/=node_modules/@openzeppelin/contracts/ @chainlink/contracts/=node_modules/@chainlink/contracts/ \
  --optimize --optimize-runs 200 --evm-version cancun --allow-paths . --combined-json abi,hashes src/RaffleFactory.sol

# 4. Dynamic spot checks. Place the appendix harness at test/AccessSpotChecks.t.sol in a scratch copy,
#    with the appendix foundry.toml, then run:
forge test --offline --use "$SOLC" -vv
```

## Appendix: Spot-Check Harness

This harness exists only in the scratch copy; it is not part of the audited codebase. Its source is reproduced verbatim below.

<details>
<summary>Scratch <code>foundry.toml</code> used for the spot checks</summary>

```toml
[profile.default]
src = "src"
test = "test"
out = "out"
cache_path = "cache"
libs = ["node_modules"]
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = false
remappings = [
  "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/",
  "@chainlink/contracts/=node_modules/@chainlink/contracts/",
]
```

</details>

<details>
<summary><code>test/AccessSpotChecks.t.sol</code> (11 tests, all passing)</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Scratch-only access-control spot checks for the entry-point report. Not part of the audited codebase.

import { RaffleFactory } from "../src/RaffleFactory.sol";
import { Raffle } from "../src/Raffle.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function deal(address, uint256) external;
}

contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function decimals() external pure returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockNFT is ERC721 {
    constructor() ERC721("Prize", "PRZ") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockWrapper {
    uint256 public constant PRICE = 0.01 ether;
    uint256 public lastRequestId = 100;
    mapping(uint256 requestId => address consumer) public consumerOf;

    function link() external pure returns (address) {
        return address(0);
    }

    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return PRICE;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external pure returns (uint256) {
        return PRICE;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        require(msg.value >= PRICE, "fee");
        requestId = ++lastRequestId;
        consumerOf[requestId] = msg.sender;
    }

    function fulfill(uint256 requestId, uint256 word) external {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        VRFV2PlusWrapperConsumerBase(consumerOf[requestId]).rawFulfillRandomWords(requestId, words);
    }
}

contract AccessSpotChecks {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bool public IS_TEST = true;

    address internal constant TREASURY = address(0x7EA5);
    address internal constant SPONSOR = address(0x5905);
    address internal constant RECIPIENT = address(0x5EC1);
    address internal constant BUYER = address(0xB0B);
    address internal constant OPERATOR = address(0x0FE7);
    address internal constant ANYONE = address(0xA11CE);
    address internal constant OTHER = address(0xC0C0);

    MockUSDC internal usdc;
    MockNFT internal nft;
    MockWrapper internal wrapper;
    RaffleFactory internal factory;

    function setUp() public {
        vm.warp(1_700_000_000);
        vm.deal(address(this), 100 ether);
        vm.deal(ANYONE, 100 ether);
        usdc = new MockUSDC();
        wrapper = new MockWrapper();
        nft = new MockNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
    }

    // Helpers

    function _create(uint256 tokenId, uint128 reserve, uint64 endTime) internal returns (Raffle raffle) {
        nft.mint(SPONSOR, tokenId);
        vm.prank(SPONSOR);
        nft.approve(address(factory), tokenId);
        vm.prank(SPONSOR);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: RECIPIENT,
                        prizeToken: address(nft),
                        prizeTokenId: tokenId,
                        reserveEntries: reserve,
                        endTime: endTime
                    })
                ))
        );
    }

    function _buy(Raffle raffle, address buyer, uint128 entries) internal returns (uint256 ticketId) {
        usdc.mint(buyer, uint256(entries) * 1e6);
        vm.prank(buyer);
        usdc.approve(address(raffle), type(uint256).max);
        vm.prank(buyer);
        ticketId = raffle.buyEntries(buyer, entries);
    }

    function _draw(Raffle raffle, uint256 word) internal {
        vm.warp(raffle.endTime());
        vm.prank(ANYONE);
        uint256 requestId = raffle.requestDraw{ value: 0.02 ether }();
        wrapper.fulfill(requestId, word);
    }

    function _initParams() internal view returns (IRaffle.RaffleInitParams memory params) {
        params = IRaffle.RaffleInitParams({
            sponsor: ANYONE,
            sponsorRecipient: ANYONE,
            protocolTreasury: ANYONE,
            prizeToken: address(nft),
            prizeTokenId: 77,
            raffleId: 77,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1 days)
        });
    }

    function _expectRevertSel(address caller, address target, uint256 value, bytes memory data, bytes4 selector)
        internal
    {
        vm.prank(caller);
        (bool ok, bytes memory ret) = target.call{ value: value }(data);
        require(!ok, "call unexpectedly succeeded");
        require(ret.length >= 4, "revert without selector");
        require(bytes4(ret) == selector, "unexpected revert selector");
    }

    function _expectRevertAny(address caller, address target, bytes memory data) internal returns (bytes memory ret) {
        vm.prank(caller);
        bool ok;
        (ok, ret) = target.call(data);
        require(!ok, "call unexpectedly succeeded");
    }

    // Spot checks

    /// Implementation is locked: no initializer, and every lifecycle path fails.
    function test_implementationIsLocked() public {
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        require(impl.initialized(), "impl not initialized");
        require(impl.status() == IRaffle.Status.Refunding, "impl status");
        require(impl.factory() == address(factory), "impl factory");

        IRaffle.RaffleInitParams memory params = _initParams();
        _expectRevertSel(
            address(factory),
            address(impl),
            0,
            abi.encodeCall(IRaffle.initialize, (params)),
            IRaffle.AlreadyInitialized.selector
        );
        _expectRevertSel(
            ANYONE, address(impl), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.InvalidStatus.selector
        );
        _expectRevertSel(
            ANYONE, address(impl), 0, abi.encodeCall(IRaffle.buyEntries, (ANYONE, 1)), IRaffle.InvalidStatus.selector
        );
        _expectRevertSel(
            ANYONE,
            address(impl),
            0,
            abi.encodeCall(IRaffle.releaseSponsorProceeds, ()),
            IRaffle.NoSponsorProceeds.selector
        );
        _expectRevertSel(
            ANYONE, address(impl), 0, abi.encodeCall(IRaffle.releaseProtocolFees, ()), IRaffle.NoProtocolFees.selector
        );
        bytes memory ret = _expectRevertAny(ANYONE, address(impl), abi.encodeCall(IRaffle.releaseSponsorPrize, ()));
        require(ret.length == 0, "expected empty revert from call into code-less prizeToken");
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        _expectRevertSel(
            ANYONE,
            address(impl),
            0,
            abi.encodeCall(IRaffle.refundTickets, (ids)),
            IERC721Errors.ERC721NonexistentToken.selector
        );
    }

    /// Only the immutable factory may initialize; canonical clones are initialized atomically in createRaffle.
    function test_initializeOnlyFactory() public {
        address rogue = Clones.clone(factory.raffleImplementation());
        require(!factory.isRaffle(rogue), "rogue registered");
        require(!IRaffle(rogue).initialized(), "rogue initialized");
        require(IRaffle(rogue).factory() == address(factory), "rogue clone factory immutable");
        IRaffle.RaffleInitParams memory params = _initParams();
        _expectRevertSel(ANYONE, rogue, 0, abi.encodeCall(IRaffle.initialize, (params)), IRaffle.OnlyFactory.selector);

        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        require(factory.isRaffle(address(raffle)), "not registered");
        require(raffle.sponsor() == SPONSOR, "sponsor is createRaffle caller");
        require(raffle.status() == IRaffle.Status.Active, "not active");
        _expectRevertSel(
            address(factory),
            address(raffle),
            0,
            abi.encodeCall(IRaffle.initialize, (params)),
            IRaffle.AlreadyInitialized.selector
        );
    }

    /// Sponsor may close an empty raffle before endTime; nobody may close a sold raffle before the request deadline.
    function test_enableRefunds_sponsorEarlyCloseOnlyWhenEmpty() public {
        uint64 end = uint64(block.timestamp + 1 days);
        Raffle empty = _create(1, 1, end);
        _expectRevertSel(
            ANYONE, address(empty), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.RefundsNotAvailable.selector
        );
        vm.prank(SPONSOR);
        empty.enableRefunds();
        require(empty.status() == IRaffle.Status.Refunding, "sponsor early close failed");
        vm.prank(ANYONE);
        empty.releaseSponsorPrize();
        require(nft.ownerOf(1) == RECIPIENT, "prize not returned");

        Raffle sold = _create(2, 1, end);
        _buy(sold, BUYER, 1);
        _expectRevertSel(
            SPONSOR, address(sold), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.RefundsNotAvailable.selector
        );
        vm.warp(end);
        _expectRevertSel(
            SPONSOR, address(sold), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.RefundsNotAvailable.selector
        );
        vm.warp(uint256(end) + 2 days - 1);
        _expectRevertSel(
            ANYONE, address(sold), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.RefundsNotAvailable.selector
        );
        vm.warp(uint256(end) + 2 days);
        vm.prank(ANYONE);
        sold.enableRefunds();
        require(sold.status() == IRaffle.Status.Refunding, "public refund enable failed");

        Raffle empty2 = _create(3, 1, uint64(block.timestamp + 1 days));
        vm.warp(empty2.endTime());
        vm.prank(ANYONE);
        empty2.enableRefunds();
        require(empty2.status() == IRaffle.Status.Refunding, "empty raffle not closable by anyone after end");
    }

    /// requestDraw is permissionless inside [endTime, endTime + 2 days) once entries exist.
    function test_requestDraw_permissionlessWindow() public {
        Raffle empty = _create(1, 1, uint64(block.timestamp + 1 days));
        vm.warp(empty.endTime());
        _expectRevertSel(
            ANYONE, address(empty), 0.01 ether, abi.encodeCall(IRaffle.requestDraw, ()), IRaffle.NoEntriesSold.selector
        );

        Raffle raffle = _create(2, 1, uint64(block.timestamp + 1 days));
        _buy(raffle, BUYER, 1);
        _expectRevertSel(
            ANYONE, address(raffle), 0.01 ether, abi.encodeCall(IRaffle.requestDraw, ()), IRaffle.RaffleNotEnded.selector
        );
        vm.warp(uint256(raffle.endTime()) + 2 days);
        _expectRevertSel(
            ANYONE,
            address(raffle),
            0.01 ether,
            abi.encodeCall(IRaffle.requestDraw, ()),
            IRaffle.DrawRequestWindowExpired.selector
        );
        vm.warp(uint256(raffle.endTime()) + 2 days - 1);
        vm.deal(OTHER, 1 ether);
        vm.prank(OTHER);
        raffle.requestDraw{ value: 0.01 ether }();
        require(raffle.status() == IRaffle.Status.Drawing, "not drawing");
    }

    /// Only the wrapper reaches fulfillRandomWords; late callbacks are ignored and refunds open at the deadline.
    function test_callbackGateAndDeadline() public {
        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        _buy(raffle, BUYER, 1);
        vm.warp(raffle.endTime());
        vm.prank(ANYONE);
        uint256 requestId = raffle.requestDraw{ value: 0.01 ether }();
        uint256[] memory words = new uint256[](1);
        words[0] = 7;
        _expectRevertSel(
            ANYONE,
            address(raffle),
            0,
            abi.encodeWithSelector(VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords.selector, requestId, words),
            VRFV2PlusWrapperConsumerBase.OnlyVRFWrapperCanFulfill.selector
        );
        uint256 deadline = raffle.callbackDeadline();
        vm.warp(deadline - 1);
        _expectRevertSel(
            ANYONE, address(raffle), 0, abi.encodeCall(IRaffle.enableRefunds, ()), IRaffle.RefundsNotAvailable.selector
        );
        vm.warp(deadline);
        wrapper.fulfill(requestId, 1);
        require(raffle.status() == IRaffle.Status.Drawing, "late callback resolved");
        vm.prank(ANYONE);
        raffle.enableRefunds();
        require(raffle.status() == IRaffle.Status.Refunding, "refunds not enabled at deadline");
    }

    /// onERC721Received activates only during factory escrow; afterwards every safe NFT transfer is rejected.
    function test_onERC721Received_onlyDuringFactoryEscrow() public {
        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        bytes memory data =
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector, address(factory), SPONSOR, 1, "");
        _expectRevertSel(address(nft), address(raffle), 0, data, IRaffle.UnexpectedPrize.selector);
        _expectRevertSel(ANYONE, address(raffle), 0, data, IRaffle.UnexpectedPrize.selector);
        nft.mint(ANYONE, 99);
        _expectRevertSel(
            ANYONE,
            address(nft),
            0,
            abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", ANYONE, address(raffle), 99),
            IRaffle.UnexpectedPrize.selector
        );
    }

    /// receive() rejects plain native transfers.
    function test_receiveReverts() public {
        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        _expectRevertSel(ANYONE, address(raffle), 1 wei, "", Raffle.DirectNativeTransfer.selector);
    }

    /// NftWon: settlement is permissionless; redemption is owner-only (operators rejected); tickets stay transferable.
    function test_nftWon_redeemOwnerOnly() public {
        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        uint256 ticketId = _buy(raffle, BUYER, 1);
        _draw(raffle, 12_345);
        require(raffle.status() == IRaffle.Status.NftWon, "not NftWon");

        vm.prank(BUYER);
        raffle.setApprovalForAll(OPERATOR, true);
        _expectRevertSel(
            OPERATOR,
            address(raffle),
            0,
            abi.encodeCall(IRaffle.redeemWinningTicket, (ticketId)),
            IRaffle.NotTicketOwner.selector
        );
        vm.prank(ANYONE);
        raffle.settleWinningTicket(ticketId);
        require(raffle.settlementComplete(), "not settled");

        _expectRevertSel(
            BUYER,
            address(raffle),
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", BUYER, address(factory), ticketId),
            IRaffle.UnsafeProtocolDestination.selector
        );
        vm.prank(OPERATOR);
        raffle.transferFrom(BUYER, OTHER, ticketId);
        _expectRevertSel(
            BUYER,
            address(raffle),
            0,
            abi.encodeCall(IRaffle.redeemWinningTicket, (ticketId)),
            IRaffle.NotTicketOwner.selector
        );
        vm.prank(OTHER);
        raffle.redeemWinningTicket(ticketId);
        require(nft.ownerOf(1) == OTHER, "prize not delivered to current owner");

        _expectRevertSel(
            ANYONE,
            address(raffle),
            0,
            abi.encodeCall(IRaffle.releaseSponsorPrize, ()),
            IRaffle.SponsorPrizeUnavailable.selector
        );
        vm.prank(ANYONE);
        raffle.releaseSponsorProceeds();
        vm.prank(ANYONE);
        raffle.releaseProtocolFees();
        require(usdc.balanceOf(RECIPIENT) == 950_000, "sponsor share");
        require(usdc.balanceOf(TREASURY) == 50_000, "treasury share");
    }

    /// CashWon: prize return and fee releases are permissionless pushes; cash redemption is owner-only.
    function test_cashWon_paths() public {
        Raffle raffle = _create(1, 5, uint64(block.timestamp + 1 days));
        uint256 ticketId = _buy(raffle, BUYER, 2);
        _draw(raffle, 0);
        require(raffle.status() == IRaffle.Status.CashWon, "not CashWon");

        vm.prank(ANYONE);
        raffle.releaseSponsorPrize();
        require(nft.ownerOf(1) == RECIPIENT, "prize not returned");
        _expectRevertSel(
            ANYONE,
            address(raffle),
            0,
            abi.encodeCall(IRaffle.redeemWinningTicket, (ticketId)),
            IRaffle.NotTicketOwner.selector
        );
        require(!raffle.settlementComplete(), "failed redeem must roll back inline settlement");
        vm.prank(BUYER);
        uint256 cash = raffle.redeemWinningTicket(ticketId);
        require(cash == 1_600_000 && usdc.balanceOf(BUYER) == 1_600_000, "cash prize");
        vm.prank(ANYONE);
        raffle.releaseSponsorProceeds();
        vm.prank(ANYONE);
        raffle.releaseProtocolFees();
        require(usdc.balanceOf(RECIPIENT) == 300_000, "sponsor share");
        require(usdc.balanceOf(TREASURY) == 100_000, "treasury share");
    }

    /// Destination screening is point-in-time: a code-less address that later becomes a registered clone passes
    /// validation at creation, after which sponsor quote releases revert and the prize can be pushed into that clone.
    function test_pointInTimeDestinationScreening_futureCloneRecipient() public {
        // Factory nonce 1 deployed the implementation; the first clone uses nonce 2, the next one nonce 3.
        address predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(factory), bytes1(0x03)))))
        );
        nft.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        nft.approve(address(factory), 1);
        vm.prank(SPONSOR);
        Raffle raffleA = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: predicted,
                        prizeToken: address(nft),
                        prizeTokenId: 1,
                        reserveEntries: 5,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );
        Raffle raffleB = _create(2, 1, uint64(block.timestamp + 1 days));
        require(address(raffleB) == predicted && factory.isRaffle(predicted), "prediction failed");

        uint256 ticketId = _buy(raffleA, BUYER, 1);
        _draw(raffleA, 0);
        require(raffleA.status() == IRaffle.Status.CashWon, "not CashWon");
        vm.prank(BUYER);
        raffleA.redeemWinningTicket(ticketId);
        _expectRevertSel(
            ANYONE,
            address(raffleA),
            0,
            abi.encodeCall(IRaffle.releaseSponsorProceeds, ()),
            IRaffle.InvalidQuoteDestination.selector
        );
        vm.prank(ANYONE);
        raffleA.releaseSponsorPrize();
        require(nft.ownerOf(1) == address(raffleB), "prize did not move into the other clone");
    }

    /// Refunding: refunds are owner-only (token-approved operators rejected).
    function test_refund_ownerOnly() public {
        Raffle raffle = _create(1, 1, uint64(block.timestamp + 1 days));
        uint256 ticketId = _buy(raffle, BUYER, 3);
        vm.warp(uint256(raffle.endTime()) + 2 days);
        vm.prank(ANYONE);
        raffle.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = ticketId;
        _expectRevertSel(
            ANYONE, address(raffle), 0, abi.encodeCall(IRaffle.refundTickets, (ids)), IRaffle.NotTicketOwner.selector
        );
        vm.prank(BUYER);
        raffle.approve(OPERATOR, ticketId);
        _expectRevertSel(
            OPERATOR, address(raffle), 0, abi.encodeCall(IRaffle.refundTickets, (ids)), IRaffle.NotTicketOwner.selector
        );
        vm.prank(BUYER);
        uint256 amount = raffle.refundTickets(ids);
        require(amount == 3_000_000 && usdc.balanceOf(BUYER) == 3_000_000, "refund");
        vm.prank(ANYONE);
        raffle.releaseSponsorPrize();
        require(nft.ownerOf(1) == RECIPIENT, "prize not returned");
    }
}
```

</details>
