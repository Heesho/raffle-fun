# `Raffle._update` override (L497-L502) and the inherited ERC-721 paths that reach it

File abbreviations. All paths are under `packages/contracts/`.

- **R**: `src/Raffle.sol`
- **F**: `src/RaffleFactory.sol`
- **IF**: `src/interfaces/IRaffleFactory.sol`
- **IR**: `src/interfaces/IRaffle.sol`
- **E**: `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` (OZ v5.6.0, E L2)
- **U**: `node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` (OZ v5.5.0, U L2)
- **Ctx**: `node_modules/@openzeppelin/contracts/utils/Context.sol`
- **RG**: `node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol`
- **C**: `node_modules/@openzeppelin/contracts/proxy/Clones.sol`
- **VB**: `node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`

---

## `_update` in packages/contracts/src/Raffle.sol (L497-L502)

This function is reached through OpenZeppelin's inherited `transferFrom` (E L115-L125), both `safeTransferFrom` overloads (E L128-L136), `_safeMint` → `_mint` (E L279-L290, L259-L267), and `_burn` (E L303-L308).

```solidity
// R L491-L502
/// @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected
///      before their ownership could make a claim unreachable. Burns pass the zero address and remain permitted.
/// ...
function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    previousOwner = super._update(to, ticketId, auth);
}
```

**Purpose:**

Every ticket mint, transfer and burn passes through this override:

- `_owners` is written in exactly one place, inside `ERC721._update` at E L240.
- Raffle does not override `_ownerOf`, `transferFrom`, `safeTransferFrom`, `approve`, `setApprovalForAll` or `_msgSender`. Its only ERC-721-level overrides are `name` (R L479), `symbol` (R L485) and `_update` (R L497).

Ticket ownership is what authorizes value:

- `redeemWinningTicket` delivers only when `ownerOf(ticketId) == msg.sender` (R L320-L321).
- `refundTickets` applies the same check to each ticket (R L359-L360).

The override adds one rule to OZ's logic. A non-zero recipient that `_isProtocolDestination` classifies as same-factory protocol plumbing is rejected (R L498-L500). The same predicate, called with the same `address(prizeToken)` argument, also gates quote-token payouts (R L565). The result is that any address that can become a ticket owner could also have received that ticket's USDC payout, as judged at the moment of the transfer.

Without the override, a plain `transferFrom` could leave a ticket at:

- the clone itself
- the factory
- USDC
- the VRF wrapper
- the implementation
- another registered clone

Plain `transferFrom` performs no receiver check (E L115-L125). Neither R nor F ever calls a ticket function on any raffle. R's external calls are listed under Invariant couplings. `_transferQuote` would also reject every one of those addresses as a payee (R L565).

Everything else on the path is OZ's unmodified code: the authorization check, approval clearing, balance bookkeeping and the `Transfer` event.

**Inputs & Assumptions:**

- `to` (address): the new owner, or `address(0)` for a burn.
  - Trust: **untrusted** on transfer paths, where the caller of `transferFrom`/`safeTransferFrom` chooses it (E L115, E L133).
  - Untrusted on mint, where it is the `recipient` argument of `buyEntries` (R L209).
  - Fixed to `address(0)` on burn (E L304).
- `ticketId` (uint256).
  - Trust: **untrusted** on transfer paths: any value. Nonexistent IDs fail at E L181-L182.
  - On mint it is `ticketCount + 1` (R L228).
  - On burn it is an ID the caller has just resolved through `ownerOf` (R L320, R L359).
- `auth` (address).
  - `_msgSender()`, which is `msg.sender`, on transfer paths (E L121; Ctx L17-L19).
  - `address(0)` on mint (E L263) and on burn (E L304).
- Implicit reads:
  - `prizeToken` (R L70). Written once, in `initialize` (R L200). Re-initialization is blocked by R L177-L179.
  - Immutables:
    - `factory` (R L55). Set to the deployer at R L161. The deployer is the RaffleFactory, through `new Raffle` at F L89.
    - `quoteToken` (R L58).
    - `i_vrfV2PlusWrapper` (VB L35).
    - Immutables live in the implementation's runtime code, so every clone sees the same values.
  - `address(this)`, which is the clone's own address when running in a clone.
  - `to.code.length` (R L602).
  - Factory state:
    - `raffleImplementation`: immutable (F L42), set at F L91.
    - `isRaffle[to]` (F L54). F L125 is its only writer, and it only ever sets the value to `true`.
  - The OZ ledger maps (E L28-L34), read and written by `super._update`.
- Not read anywhere in R L497-L502 or E L216-L245:
  - `status`
  - the reentrancy-guard slot
  - `_ticketRanges`
  - any accounting variable
- Preconditions, and what establishes each:
  - **The burn caller is the ticket owner.**
    - Established only by the two callers: R L320-L321 and R L359-L360.
    - `_burn` passes `auth = 0` (E L304), and its own documentation says it does not check the sender (E L295).
    - The override skips the screen when `to == 0` (R L498).
  - **The mint is paid for and the accounting is already written.**
    - Established by `buyEntries` (R L215-L233), before `_safeMint` (R L235).
  - **The minted ID is fresh.**
    - Established by R L228 and by the checked increment at R L231.
    - Re-checked after the fact at E L264-L266.
  - **The transfer caller is authorized.**
    - Established inside `super._update` (E L220-L222).

**Outputs & Effects:**

- **Returns** the previous owner (E L217, E L244). This is `address(0)` for a mint.
- **Reverts:**
  - `UnsafeProtocolDestination(to)` when the screen matches (R L499; error declared at IR L268).
  - From `super._update`, only when `auth != 0`:
    - `ERC721NonexistentToken` (E L182)
    - `ERC721InsufficientApproval` (E L184)
  - Any revert from either factory call (R L601, R L603), bubbled up.
- **Storage writes.** All of them happen inside `super._update`; the override writes nothing itself.
  - `_tokenApprovals[ticketId] = 0`, when the ticket already existed (E L227 → E L398).
  - `_balances[from] -= 1`, unchecked (E L229-L231).
  - `_balances[to] += 1`, unchecked, when `to != 0` (E L234-L238).
  - `_owners[ticketId] = to` (E L240).
- **Events.**
  - `Transfer(from, to, ticketId)` (E L242).
  - Clearing the approval emits no `Approval` event, because E L227 passes `emitEvent = false` (see E L393).
- **External interactions.**
  - Up to two STATICCALLs to `factory`: `raffleImplementation()` (R L601) and `isRaffle(to)` (R L603). They happen only when `to != 0`.
  - There is no external call on a burn.
  - The override never calls the recipient. Recipient callbacks belong to `_safeMint` (E L289) and `safeTransferFrom` (E L135), and run after `_update` has returned.
- **Postcondition on success.**
  - `_owners[ticketId] == to`. For a burn, `to` is zero, so the ticket no longer exists.
  - A non-zero `to` passed the screen as it was evaluated during this call.

---

**Block-by-Block:**

```solidity
// R L498-L500
if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
    revert UnsafeProtocolDestination(to);
}
```

- **What:** Rejects a non-zero recipient that is classified as same-factory protocol plumbing.
- **Why here:**
  - It runs before `super._update`. The screen therefore fires before OZ's authorization check and before any ledger write.
  - The `to != address(0)` test comes first and `&&` short-circuits. Burns never evaluate the predicate and never make its factory calls.
- **Assumes:**
  - `factory` answers `raffleImplementation()` and `isRaffle()` truthfully. It is the RaffleFactory that deployed the implementation (R L161, F L89); the system model treats it as trusted.
  - `prizeToken` holds the configured prize (R L200).
    - It is zero before initialization, but no ticket can exist then: minting requires `Active` (R L215).
    - It is also zero on the implementation, where no ticket can exist either (Invariant coupling 5).
    - A zero `prizeToken_` can never equal a non-zero `to`, so the R L600 comparison is simply inert in those cases.
- **Establishes:** At the moment of this call, `to` is none of `address(this)`, `factory`, `quoteToken`, the VRF wrapper, `prizeToken` or `factory.raffleImplementation()`. If `to` has code, it is also not registered in `isRaffle` (R L599-L604).
- **Depended on by:** the owner-derived payouts.
  - `refundTickets` pays `msg.sender` (R L369) and `redeemWinningTicket` pays `winner` (R L342). Both go through `_transferQuote`, which applies the same predicate (R L565).
  - A ticket owner that passed R L498 also passes R L565, unless the predicate's answer changed in between. See Invariant coupling 1.
- **Ordering consequence:**
  - The screen runs before `_checkAuthorized` (E L221).
  - A call that names a protocol destination therefore reverts with `UnsafeProtocolDestination`, even when the caller is unauthorized or the ID does not exist.
  - In that case the factory STATICCALLs run before authorization is ever checked.

```solidity
// R L501
previousOwner = super._update(to, ticketId, auth);
```

- **What:** Hands control to OZ's `_update` (E L216-L245).
- **Why here:** It runs only after the screen has passed. Its return value flows back to three callers:
  - `transferFrom`'s owner check (E L122)
  - `_mint`'s freshness check (E L264)
  - `_burn`'s existence check (E L305)
- **Assumes / Establishes:** see the callee analysis directly below.
- **Depended on by:** E L122-L124, E L264-L266 and E L305-L307.

### Callee `ERC721._update` (external-source-available, E L216-L245)

I read the whole function. Its steps, in order:

1. `from = _ownerOf(tokenId)` (E L217). This reads `_owners[tokenId]` (E L146-L148); R does not override `_ownerOf`.
2. If `auth != 0`, it calls `_checkAuthorized(from, auth, tokenId)` (E L220-L222, E L179-L187).
   - `_isAuthorized` (E L164-L168) returns true when `auth != 0` and `auth` is one of:
     - `from` itself
     - an operator of `from` (`isApprovedForAll`, E L110-L112)
     - the address approved for this single token (`_getApproved`, E L153-L155)
   - Not authorized and `from == 0` → reverts `ERC721NonexistentToken` (E L181-L182). A never-minted or burned ID can never be transferred:
     - `_operatorApprovals[0][x]` cannot be set, because E L410-L412 rejects owner 0.
     - `_tokenApprovals[id]` is zero for such IDs. It was cleared at burn by E L227, and `approve` requires the token to exist (E L386).
   - Not authorized and `from != 0` → reverts `ERC721InsufficientApproval` (E L184).
   - `_isAuthorized` trusts its `owner` argument (E L161-L162). Here that argument is the live `_owners` value read at E L217.
3. If `from != 0`:
   - It calls `_approve(address(0), tokenId, address(0), false)` (E L227). Inside `_approve` (E L383-L399), `emitEvent == false` and `auth == 0` skip the owner read and the event. Only `_tokenApprovals[tokenId] = 0` runs (E L398).
   - Then it runs `_balances[from] -= 1` inside `unchecked` (E L229-L231).
4. If `to != 0`, it runs `_balances[to] += 1` inside `unchecked` (E L234-L238).
5. It writes `_owners[tokenId] = to` (E L240), emits `Transfer(from, to, tokenId)` (E L242), and returns `from` (E L244).

There is no external call anywhere in E L216-L245. The ledger is therefore consistent whenever control leaves this function.

What R depends on this function for:

- **Transfer authorization (step 2), only when `auth != 0`.**
  - `transferFrom` passes `msg.sender` (E L121). On-chain, `msg.sender` is never zero, so every on-chain transfer gets the check.
  - Mint and burn pass `auth == 0` by construction (E L263, E L304). Authorizing them is the caller's job.
- **Safety of the unchecked decrement (E L230).**
  - It relies on `_balances[from] >= 1` whenever `from != 0`.
  - That holds because `_owners` is written only at E L240, and every such write happens next to the balance updates in the same function.
  - R neither overrides `_ownerOf` nor calls `_increaseBalance`; a grep of `packages/contracts/src` finds neither.
- **Safety of the unchecked increment (E L236).**
  - The total ticket count bounds it. That count is at most `ticketCount`, a `uint128` (R L88) with a checked increment (R L231).

The `(to, auth, from)` combinations that R can actually reach:

| Caller chain | `to` | `auth` | `from` | Screen runs | Auth check runs |
|---|---|---|---|---|---|
| `transferFrom` / `safeTransferFrom` | ≠ 0 (E L116) | `msg.sender` (E L121) | anything | yes | yes |
| `buyEntries` → `_safeMint` → `_mint` | ≠ 0 (R L217, E L260) | 0 | 0, a fresh ID | yes | no |
| `refundTickets` / `redeemWinningTicket` → `_burn` | 0 | 0 | ≠ 0, after the caller's `ownerOf` check | no | no |

OZ has two other callers of `_update`: `_transfer` and `_safeTransfer` (E L321-L363). Neither is called from R; a grep for `_transfer(` and `_safeTransfer(` finds no call. So there is no path that moves an existing ticket to a non-zero address without an authorization check.

### Callee `Raffle._isProtocolDestination` (internal, R L593-L605)

I read the whole function. It is declared `view` (R L596), and IF L130 and IF L139 declare both factory getters `view`. Both factory calls are therefore STATICCALLs.

```solidity
// R L598-L604
IRaffleFactory canonicalFactory = IRaffleFactory(factory);
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```

Paths, given `destination != 0` (guaranteed by R L498):

1. One of the five local comparisons matches. The result is `true` and no external call is made, because `||` short-circuits (R L599-L600).
2. Otherwise it STATICCALLs `raffleImplementation()` (R L601). A match returns `true`.
3. Otherwise, if `destination` has no code, it returns `false` without consulting the registry (R L602).
4. Otherwise it STATICCALLs `isRaffle(destination)` (R L603) and returns that value.

Failure behavior: both calls are high-level Solidity calls.

- A revert inside the factory bubbles up.
- A malformed return value fails ABI decoding inside the clone.
- So the predicate can never answer `false` because a call failed.
- The canonical factory's two getters cannot revert under normal conditions: one is an immutable (F L42), the other a public mapping (F L54), and neither has a modifier.
- They stay callable while the factory holds its own `nonReentrant` lock (F L97). That matters for tickets minted inside `createRaffle`'s prize-transfer frame (F L128); see the callback windows table.

What the screen does not cover (read from R L599-L604):

- **Other factories.** Clones and implementations deployed by any other RaffleFactory pass. The registry is per factory: the NatSpec says "same-factory protocol plumbing" (R L587), and the lookup is `isRaffle` on this clone's own factory (R L603).
- **Addresses that are not on the list**, including:
  - `i_linkToken` (VB L34)
  - the protocol treasury
  - the sponsor
  - the sponsor recipient
  - the VRF coordinator behind the wrapper
  - precompiles
  - arbitrary contracts that cannot handle tickets
- **Addresses without code.** They are never looked up in the registry (R L602; NatSpec at R L589). That includes addresses where a future clone will later be deployed:
  - `Clones.clone` deploys with `CREATE` (C L57), so each clone address comes from the factory's address and nonce.
  - Such an address passes the screen until the clone is deployed (F L106) and registered (F L125).
  - `isRaffle` is only ever set to `true` (F L125 is its only writer), so the set of screened addresses only grows over time.
- **Approvals.** `approve` and `setApprovalForAll` targets are never screened (E L93-L95, E L105-L107). Neither function reaches `_update`.

### Inherited entrypoint `transferFrom(from, to, tokenId)` (E L115-L125)

```solidity
// E L115-L125
function transferFrom(address from, address to, uint256 tokenId) public virtual {
    if (to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    address previousOwner = _update(to, tokenId, _msgSender());
    if (previousOwner != from) {
        revert ERC721IncorrectOwner(from, tokenId, previousOwner);
    }
}
```

Paths:

1. `to == 0` → reverts `ERC721InvalidReceiver(0)` (E L116-L118). `_update` never runs, so a public burn is impossible.
2. The screen matches → reverts `UnsafeProtocolDestination(to)` (R L499).
3. The ID was never minted or is burned → reverts `ERC721NonexistentToken` (E L182).
4. The caller is not the owner, an operator or the approved address → reverts `ERC721InsufficientApproval` (E L184).
5. `from` is not the actual owner → reverts `ERC721IncorrectOwner` (E L122-L124).
   - This check runs after the ledger write. The revert undoes the write.
   - `_update` moves the ticket from its actual owner, which it read at E L217, not from the caller-supplied `from`.
6. Success: ownership moves, the single-token approval is cleared, and `Transfer` is emitted.
   - A transfer to oneself (`to == from`) nets the balance to zero change but still clears the approval.

The function has no modifier, and R does not override it. There is no status check, no reentrancy guard and no receiver check. Any address that passes the screen can become the owner, including:

- contracts with no code for handling tickets
- addresses without code that nobody controls

### Inherited entrypoint `safeTransferFrom` (E L128-L136)

- The 3-argument overload (E L128-L130) is not `virtual`. It forwards to the 4-argument overload with empty `data`.
- The 4-argument overload (E L133-L136):
  - calls `transferFrom` (E L134), so every path listed above applies;
  - then calls `ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data)` (E L135).

I read `checkOnERC721Received` (U L25-L49) in full. Its paths:

1. `to.code.length == 0` → no call is made and the transfer succeeds (U L32). EOAs and contracts still running their constructor take this path.
2. `to.onERC721Received(operator, from, tokenId, data)` returns the expected selector → success (U L33-L34).
3. It returns any other `bytes4` → reverts `ERC721InvalidReceiver(to)` (U L34-L37).
4. It reverts with empty data → reverts `ERC721InvalidReceiver(to)` (U L39-L41).
5. It reverts with data → that revert data bubbles up (U L42-L46).
6. It returns data that does not decode as `bytes4`. The decoding happens in the success branch of the `try` at U L33. Solidity does not send decode failures from that branch to the `catch` at U L38, so the transfer reverts.

The recipient is untrusted, external-black-box code. When it runs:

- Ownership has already been written: E L240 executes before E L135.
- Every OZ check has already completed. The owner check at E L122 runs inside `transferFrom`, before E L135.
- It receives nearly all remaining gas, because U L33 passes no gas argument.

`safeTransferFrom` reads no state after the callback. Whatever the recipient does during the callback stands, provided it then returns the selector. That includes:

- burning the ticket through `refundTickets` or `redeemWinningTicket`
- moving the ticket again

The callback has no guard of its own; E L133 has no modifier. It inherits whatever guard state the enclosing frame holds.

- **When `safeTransferFrom` is the top-level call**, the clone's guard slot does not hold `ENTERED`. It holds one of two values:
  - `NOT_ENTERED` (1), once any guarded call has completed (RG L102-L106);
  - 0, on a clone that has never run a guarded call. Clones do not execute the constructor that would write 1 (RG L58-L60).

  `_nonReentrantBeforeView` tests only `== ENTERED` (RG L89, RG L113), so both values let the call through. The recipient can call any `nonReentrant` function on the clone.
- **When `safeTransferFrom` is itself called from inside a guarded frame's callback** (see the callback windows table), the slot is `ENTERED`. The recipient is then limited to unguarded functions.

### Inherited internal path `_safeMint` → `_mint` (E L279-L290, E L259-L267), reached only from `buyEntries` (R L235)

1. `_mint` reverts `ERC721InvalidReceiver(0)` when `to == 0` (E L260-L262). Unreachable from R, because R L217 rejects a zero recipient first.
2. `_update(to, id, 0)` (E L263):
   - If the screen matches, it reverts `UnsafeProtocolDestination`. The whole `buyEntries` call reverts, including the USDC pull at R L224.
   - Otherwise, no authorization check runs and `from == 0`. The balance and owner are written, and `Transfer(0, to, id)` is emitted.
3. `_mint` reverts `ERC721InvalidSender(0)` when `previousOwner != 0` (E L264-L266). Unreachable in R:
   - `id = ticketCount + 1` (R L228).
   - `ticketCount` increments with checked arithmetic (R L231).
   - IDs are never reused, because burning never decrements `ticketCount`.
4. `checkOnERC721Received(msg.sender of buyEntries, address(0), to, id, "")` (E L289). Paths 1-6 above apply.
   - `buyEntries` is `nonReentrant` (R L212), so the guard is `ENTERED` during this callback.
   - `totalEntries`, `ticketCount`, `_ticketRanges[id]` and `unsettledPot` are already written by then (R L230-L233).
   - `TicketPurchased` (R L236) is emitted only after the callback returns.

The consequence:

- Inside the mint callback, the recipient already owns the ticket. It can move it on through the unguarded `transferFrom` or `safeTransferFrom`, and each such move runs `_update` again, screen included.
- `TicketPurchased.recipient` (R L236) is the mint recipient. It can differ from `ownerOf(id)` at the moment `buyEntries` returns.
- The logs then appear in this order:
  1. `Transfer(0, recipient, id)`
  2. any `Transfer(recipient, X, id)` emitted during the callback
  3. `TicketPurchased`

### Inherited internal path `_burn` (E L303-L308), reached only from `redeemWinningTicket` (R L325) and `refundTickets` (R L364)

1. `_update(address(0), id, 0)` (E L304) runs.
   - The screen is skipped (R L498), so there is no external call.
   - No authorization check runs (E L220).
   - The function clears the approval, decrements the balance, sets `_owners[id] = 0`, and emits `Transfer(from, 0, id)`.
2. `_burn` reverts `ERC721NonexistentToken` when `previousOwner == 0` (E L305-L307). This is unreachable from both callers: each calls `ownerOf(id)` first (R L320, R L359), and `ownerOf` reverts for a nonexistent ID (E L61-L63, E L426-L432).

Both callers compare `msg.sender` with the owner before burning (R L321, R L360). Neither makes an external call between reading the owner and calling `_burn`:

- **`redeemWinningTicket`.** R L320-L325 contains only storage writes. `_settleWinningTicket` (called at R L315; body R L533-L558) makes no external call.
- **`refundTickets`.** R L359-L364 contains only `ticketRange` (an internal view, R L451-L455) and arithmetic.

An approved operator cannot burn a ticket directly. It can, however, first `transferFrom` the ticket to itself and then call either function as the owner.

---

**Cross-Function Dependencies:**

Callees:

- **`Raffle._isProtocolDestination`** (internal, R L593-L605). The screen predicate. Its four paths are listed above, and it fails closed when a factory call fails.
- **`IRaffleFactory.raffleImplementation()`** (external-source-available; F L42, IF L130). Returns the immutable implementation address. It is called on every non-burn update where none of the five local comparisons matched.
- **`IRaffleFactory.isRaffle(address)`** (external-source-available; F L54, IF L139). Registry lookup; values only ever move to `true` (F L125). It is called only for recipients that have code and missed all six comparisons.
- **`ERC721._update`** (external-source-available, E L216-L245). It:
  - checks authorization when `auth != 0`;
  - clears the single-token approval;
  - updates balances without overflow checks;
  - writes the owner;
  - emits `Transfer`.

  It makes no external calls.
- **`ERC721._checkAuthorized`, `_isAuthorized`, `isApprovedForAll`, `_getApproved`** (external-source-available; E L110-L112, E L153-L187). Transfer authorization, used only on paths where `auth != 0`.
- **`ERC721._approve(address,uint256,address,bool)`** (external-source-available, E L383-L399). Called with `(0, id, 0, false)`, it does nothing except write `_tokenApprovals[id] = 0`.
- **`Context._msgSender()`** (external-source-available, Ctx L17-L19). Returns `msg.sender`; R has no meta-transaction override.
- **`ERC721Utils.checkOnERC721Received`** (external-source-available, U L25-L49). The mint and safe-transfer wrappers call it after `_update` returns. Every outcome reverts except "the recipient has no code" and "the recipient returned the correct selector".
- **`IERC721Receiver(to).onERC721Received`** (external-black-box). Untrusted code. It may:
  - revert;
  - return garbage, which causes a revert;
  - consume nearly all forwarded gas;
  - re-enter the clone, at which point `to` already owns the ticket.

Callers of the override:

- `ERC721.transferFrom` (E L121). Reached directly, and through `safeTransferFrom` (E L129, E L134). `auth` is `msg.sender`.
- `ERC721._mint` (E L263), reached as `Raffle.buyEntries` (R L235) → `_safeMint` (E L280, E L288) → `_mint`.
- `ERC721._burn` (E L304), reached from `Raffle.redeemWinningTicket` (R L325) and `Raffle.refundTickets` (R L364).
- What each caller relies on:
  - `buyEntries` relies on the screen to reject protocol-plumbing recipients. It only checks `recipient != 0` itself (R L217).
  - `redeemWinningTicket` and `refundTickets` rely on ownership having been established through the screened ledger. Their own guarantee comes from the owner check placed immediately before the burn.

Shared state:

- `_owners` (E L28).
  - Written only at E L240.
  - Read through `ownerOf` (E L61-L63) at R L320 and R L359.
  - Also read by `approve`, `getApproved` and `tokenURI` (E L386, E L99, E L77).
- `_balances` (E L30). Written at E L230 and E L236. Read by `balanceOf` (E L53-L58), which no R logic calls.
- `_tokenApprovals` (E L32). Written by `approve` (E L93-L95 → E L398). Cleared by every `_update` where `from != 0` (E L227).
- `_operatorApprovals` (E L34).
  - Written by `setApprovalForAll` (E L105-L107 → E L416).
  - Read inside the authorization check (E L167).
  - Keyed by owner, not by ticket. Operator rights therefore follow the owner and survive transfers.
- `prizeToken` (R L70). Written at R L200. Read at R L498, at R L565, and at the prize-delivery sites.
- Factory `isRaffle` (F L54, written at F L125) and `raffleImplementation` (F L42, written at F L91).
- Immutables `factory` (R L55), `quoteToken` (R L58) and `i_vrfV2PlusWrapper` (VB L35).
- The clone's reentrancy slot (RG L36-L37). `_update` never reads it, but it decides what an untrusted callback is allowed to call (see the table below).

**Callback windows:** where ticket transfers and approvals stay callable while another function is still running.

`_update` checks neither the status nor the guard (R L497-L502), and the four ticket entrypoints are unguarded (E L93-L136). Every untrusted callback below can therefore move any ticket that the callee owns or is approved for. The only state such a move writes is the ERC-721 ledger.

| Untrusted call | Clone guard | Already written when it runs | Ticket state at that moment |
|---|---|---|---|
| Mint receiver `onERC721Received` (R L235 → E L289 → U L33) | `ENTERED` (R L212) | totals, range and `unsettledPot` (R L230-L233); ticket owner (E L240) | the recipient owns the new ticket; `TicketPurchased` has not been emitted yet |
| Native refund `call` to the `requestDraw` caller (R L267) | `ENTERED` (R L240) | `status = Drawing`, `drawRequestedAt`, `vrfRequestId`, `_requestInFlight` cleared (R L252-L260) | `requestDraw` reads no ticket state |
| `prizeToken.transferFrom` / `ownerOf` in `redeemWinningTicket` (R L334-L335) | `ENTERED` (R L309) | `winnerRecipient`, `winnerRedeemed`, the burn, `prizeClaimed` (R L323-L333) | the winning ticket is already burned |
| `prizeToken.transferFrom` / `ownerOf` in `releaseSponsorPrize` (R L404-L405) | `ENTERED` (R L395) | `prizeClaimed` (R L403) | nothing ticket-specific |
| Safe-transfer receiver (E L135 → U L33) | whatever the enclosing frame holds | ownership already moved (E L240) | if the transfer was a top-level call, the recipient can call guarded functions |
| Prize `safeTransferFrom` inside `createRaffle` (F L128) | clone slot is 0 (fresh clone; RG L89, RG L113 test only for `ENTERED`); factory `ENTERED` (F L97) | the clone is `Active` once R L428 has run | `buyEntries` → `_update` → the factory getters still work, since they have no modifiers (F L42, F L54) |

R reads ticket ownership in exactly two places, R L320 and R L359. Both are inside guarded functions, and each read is followed by `_burn` with no external call in between. So no R function depends on ownership staying fixed across one of its own external calls.

Invariant couplings:

1. **The ticket screen sits inside the payout screen.**
   - `_update` (R L498) and `_transferQuote` (R L565) call the same predicate with the same `address(prizeToken)`. Any address accepted as an owner would therefore have been accepted as a payee at the same moment.
   - The two answers can only diverge later if `isRaffle` grows (F L125).
   - That can only add an address that had no code when the ticket arrived (C L57, F L106).
   - Before deployment, such an address has no code. After deployment it becomes a clone, and a clone cannot act on another clone's ticket. R's external calls go only to:
     - `quoteToken` (R L224, R L566)
     - the wrapper (R L257, R L437, R L442)
     - `prizeToken` (R L334-L335, R L404-L405)
     - the factory (R L601, R L603)
     - the `requestDraw` caller, with empty calldata (R L267)
     - ERC-721 receivers (E L135, E L289)
   - `prizeToken` cannot be a registered clone (F L159). It also cannot be the new clone, because it must already have code before that clone exists (F L155).
2. **Value is bound to the ticket's range, not to its owner.**
   - The refund amount (R L362-L363, R L367) and winner selection (R L579-L585) read `_ticketRanges`, which `_update` never touches.
   - A transfer moves the whole claim and changes no accounting. `remainingRefundLiability` and `unsettledPot` do not depend on how often tickets move.
3. **Winner rights have one exit.**
   - Settlement never reads ownership (R L533-L558; IR L327-L328). Redemption requires `msg.sender == ownerOf(winningTicketId)` (R L320-L321).
   - In `NftWon`, `releaseSponsorPrize` is unavailable (R L397).
   - So if the winning ticket sits at an address that cannot call `redeemWinningTicket`, the prize stays escrowed and nothing else can deliver it.
   - The screen is the only on-chain filter on who that holder can be, and it excludes only the listed protocol plumbing.
4. **Approval clearing.**
   - Every transfer and burn clears the single-token approval (E L227).
   - Operator approvals persist per owner (E L416).
   - "Operators cannot refund or redeem" is true for any single call (R L321, R L360). An operator can still move a ticket to itself and then refund or redeem, either in a later call or within the same transaction through a contract.
5. **The implementation instance.**
   - No ticket can ever exist there:
     - `status` is fixed at `Refunding` (R L165);
     - `buyEntries` requires `Active` (R L215);
     - `initialize` is locked (R L164, R L177).
   - A `transferFrom` call on the implementation runs the screen with `prizeToken == 0`, then reverts at E L182.
6. **Event consumers.**
   - Ownership changes are visible only through `Transfer` events (E L242).
   - Approval clears emit nothing (E L227).
   - `TicketPurchased.recipient` (R L236) records the mint recipient, not the owner after the call.

---

**Open Questions:**

- Unclear; need to inspect deployment plans to know whether more than one RaffleFactory, or any other deployment of Raffle-compatible clones, will exist on the same chain. No deployment-script directory exists under `packages/contracts`. The screen recognizes only same-factory clones and the same-factory implementation (R L587, R L601-L603).
- Unclear; need design intent on whether the prize contract may act as a ticket operator.
  - The prize contract is not allowed to own a ticket (R L600).
  - Nothing stops it from being approved through `approve` or `setApprovalForAll` (E L93-L107).
  - It also executes inside the `redeemWinningTicket` and `releaseSponsorPrize` frames (R L334, R L404), where unguarded ticket transfers remain callable.
- Unclear; need to inspect the off-chain indexer and frontend sources, which are not in the workspace (only `packages/contracts` exists). The question is whether they treat `TicketPurchased.recipient` (R L236) as the current owner, given that `Transfer` events from inside the mint callback (E L289) come before it.
- Unclear whether the code-length gate at R L602 is meant to let not-yet-deployed `CREATE` addresses of future clones (C L57, F L106) bypass the registry screen. The only stated rationale is "Code-less addresses are not queried in the registry" (R L589).
