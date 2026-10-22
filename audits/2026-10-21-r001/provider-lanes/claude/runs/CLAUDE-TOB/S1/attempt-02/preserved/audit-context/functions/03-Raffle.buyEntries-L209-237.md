## `buyEntries` in packages/contracts/src/Raffle.sol (L209-L237)

```solidity
// L209-L237
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
    if (entryCount == 0) revert ZeroEntryCount();
    if (entryCount > type(uint128).max - totalEntries) {
        revert TotalEntriesOverflow(totalEntries, entryCount);
    }

    uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
    quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

    uint128 firstEntry = totalEntries + 1;
    uint128 lastEntry = totalEntries + entryCount;
    ticketId = uint256(ticketCount) + 1;

    totalEntries = lastEntry;
    ++ticketCount;
    _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
    unsettledPot += grossAmount;

    _safeMint(recipient, ticketId);
    emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
}
```

**Purpose:** This is the only way USDC enters a raffle clone and the only place a ticket is minted. It pulls
`entryCount × ENTRY_PRICE` raw USDC units from `msg.sender` and mints one ERC-721 ticket to `recipient`. The
ticket represents the next contiguous, inclusive range of global entry numbers.

- **Sole writer of the counters and ranges.** A grep of `src/` finds writes to `totalEntries`, `ticketCount`
  and `_ticketRanges` only at L230-L232.
- **Only function that increases `unsettledPot`** (L233). The other two writes, L297 and L553, set it to zero.
- **Origin of the range partition.** The partition that winner proof and refunds depend on is created here
  and nowhere else.

Every later lifecycle step reads what this function writes: `requestDraw` (L243), `fulfillRandomWords`
(L518, L521), `_requireWinningTicket` (L579-L585), `refundTickets` (L362-L368), `enableRefunds` (L280,
L296-L298) and `_settleWinningTicket` (L539-L555). If this function did not exist, a raffle would have no
entries and no pot. If its bookkeeping drifted, every downstream allocation would inherit the drift.

---

**Inputs & Assumptions:**

- `recipient` (address): the address that owns the new ticket. Trust: **untrusted** (DESIGN.md L2: "ticket
  recipients are untrusted").
  - L217 checks that it is non-zero.
  - Inside the mint, L498-L500 screen it against protocol destinations.
  - If it has code, it receives an `onERC721Received` callback (ERC721Utils L32-L33).
- `entryCount` (uint128): the number of entries. Trust: **untrusted**.
  - L218 rejects zero, and L219 rejects any value above `type(uint128).max - totalEntries`.
  - Because the parameter is `uint128` (L209), the solc 0.8.36 ABI decoder (L2; foundry.toml L7) rejects an
    out-of-range calldata word before the body runs.
  - No other upper bound applies, per call or per buyer.
- Implicit `msg.sender`: the payer. Trust: **untrusted**.
  - It is never screened. The sponsor, sponsorRecipient, protocolTreasury or any contract can pay.
  - It needs a USDC allowance to the clone of at least `grossAmount`.
  - It becomes the `operator` argument of the recipient callback. ERC721 L289 passes `_msgSender()`, which
    returns `msg.sender` (Context L17-L19), and `src/` contains no override of `_msgSender`.
- Implicit storage reads: `status` (L574), `endTime` (L216), `totalEntries` (L219-L220, L226-L227),
  `ticketCount` (L228), `unsettledPot` (read-modify-write at L233), `prizeToken` (L498) and ERC-721
  `_owners[ticketId]` (ERC721 L217).
- Implicit immutables: these live in the implementation's code and every clone shares them.
  - `quoteToken`: declared L58, set L162.
  - `factory`: declared L55. L161 sets it to the deployer, and RaffleFactory deploys the implementation
    (RaffleFactory L89).
  - `i_vrfV2PlusWrapper`: VRFV2PlusWrapperConsumerBase L35, set at L46.
- Clock: `block.timestamp` (L216).

Preconditions, and what establishes each:

- **`status == Active`.** Set only by `onERC721Received` at L428. That function requires `AwaitingPrize` and
  the exact `(prizeToken, prizeTokenId, sponsor, factory)` tuple (L421-L426).
  - On a canonical clone, this happens inside `RaffleFactory.createRaffle` at L128.
  - The implementation's status is fixed at `Refunding` (L165).
  - A clone created outside the factory stays in `AwaitingPrize`, because `initialize` is factory-only (L178).
    `buyEntries` is unreachable on such a clone.
- **The prize NFT is in this clone's custody while `Active`.** This is checked only at creation, by
  RaffleFactory L129-L134.
  - L129 calls `prize.ownerOf`, and the sponsor-chosen prize contract answers that call itself.
  - L132 calls `status()`.
  - Nothing in L209-L237 checks custody again.
- **`endTime` is fixed and lies in `(creationTime, creationTime + 30 days]`.** RaffleFactory L100-L104 bound
  it. L204 writes it once, behind the `initialized` lock (L177-L179).
- **`quoteToken` has code.** Established by RaffleFactory L66. It matters because SafeERC20 treats an empty
  return as success only when the token has code (SafeERC20 L239).
- **USDC moves exactly `grossAmount`, with no fee, no rebasing and no callback.** **Nothing found** on-chain
  enforces this.
  - The trust is written down at IRaffle L13-L15, Raffle L560-L561 and DESIGN.md L2.
  - RaffleFactory's constructor checks only that the token has code (L66) and that `decimals() == 6`
    (L71-L78).
  - IRaffleFactory L7-L9 assigns the job of confirming the token's identity to deployment tooling.

---

**Outputs & Effects:**

- **Return value:** `ticketId = ticketCount_before + 1` (L228).
- **Storage writes, all of them before any untrusted code runs (L230-L233):**
  - `totalEntries = lastEntry`
  - `++ticketCount`
  - `_ticketRanges[ticketId] = {firstEntry, lastEntry}`
  - `unsettledPot += grossAmount`
- **Storage writes inside `_safeMint`:**
  - `_balances[recipient] += 1`, unchecked (ERC721 L235-L237)
  - `_owners[ticketId] = recipient` (ERC721 L240)
- **Reentrancy guard slot:** set to `ENTERED` for the whole body, then reset to `NOT_ENTERED`
  (ReentrancyGuard L99, L105).
- **External interactions, in execution order:**
  1. `quoteToken.transferFrom(msg.sender, address(this), grossAmount)` through SafeERC20 (L224; SafeERC20
     L43-L47, L212-L244). The callee is trusted, and its source is not in the repo.
  2. `factory.raffleImplementation()`. Because `||` short-circuits, this runs only when every earlier
     comparison at L599-L601 is false.
  3. `factory.isRaffle(recipient)`, only if the recipient is still unflagged and has code (L602-L604).
     Calls 2 and 3 are declared `view` (IRaffleFactory L130, L139), so they are STATICCALLs to a trusted
     factory.
  4. `recipient.onERC721Received(msg.sender, address(0), ticketId, "")`, only when
     `recipient.code.length > 0` (ERC721Utils L32-L33). The callee is untrusted, and it receives all
     remaining gas.
- **Events, in emission order:**
  1. The USDC `Transfer`, emitted inside the token.
  2. ERC-721 `Transfer(address(0), recipient, ticketId)` (ERC721 L242).
  3. Any events the recipient callback causes, including a `Transfer` of the new ticket.
  4. `TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount)`
     (L236; IRaffle L72-L80).
- **Postconditions on success:**
  - `totalEntries' = totalEntries + entryCount`
  - `ticketCount' = ticketId`
  - `_ticketRanges[ticketId] = [totalEntries + 1, totalEntries']`
  - `unsettledPot' = unsettledPot + entryCount × 1_000_000`
  - Ticket `ticketId` exists. Its owner at L240 is `recipient`, but the callback can move it before the
    function returns.
- **Atomicity:** a revert anywhere in the body or in a callee undoes every effect, including the USDC pull.
  The function has no try/catch of its own.

---

**Block-by-Block:**

```solidity
// L209-L214
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
```
- **What:** an external entry point, wrapped in OpenZeppelin's storage-slot reentrancy guard.
- **Why here:** the guard is set before L215 and cleared after L236. It is therefore held across both external
  calls, L224 and L235.
- **Assumes:** the guard slot is separate for each clone (ReentrancyGuard L36-L37). Clones never run the
  constructor (ReentrancyGuard L58-L60), so a fresh clone's slot holds 0. The check compares only against
  `ENTERED` (L89, L113), so 0 counts as not entered. After the first guarded call the slot holds 1 (L105).
- **Establishes:** while the body runs, no `nonReentrant` function of this clone can be entered. The guarded
  functions are `buyEntries` (L212), `requestDraw` (L240), `enableRefunds` (L276), `settleWinningTicket`
  (L304), `redeemWinningTicket` (L309), `refundTickets` (L349), `releaseSponsorProceeds` (L375),
  `releaseProtocolFees` (L385) and `releaseSponsorPrize` (L395). The following remain callable:
  - the inherited ERC-721 `approve`, `setApprovalForAll`, `transferFrom` and `safeTransferFrom`
    (ERC721 L93-L136)
  - `onERC721Received` (L416)
  - `rawFulfillRandomWords`, which only the wrapper can call (VRFV2PlusWrapperConsumerBase L101-L107)
  - `receive`, which always reverts (L171-L173)
  - views
- **Depended on by:** the argument that L219 and L226-L227 read the same value, and the callback analysis at
  L235.

```solidity
// L215
_requireStatus(Status.Active);
```
- **What:** reverts with `InvalidStatus(status)` unless `status == Active` (L573-L575). There is only one path.
- **Why here:** it is the first and cheapest gate. It excludes the implementation (`Refunding`, L165),
  unactivated clones (`AwaitingPrize`) and every post-sale state.
- **Assumes:** being `Active` means the prize is in custody. See Preconditions; only creation-time checks
  establish this.
- **Establishes:** the raffle is in its sale and draw-initiation state. Together with L216, it is inside the
  sale window.
- **Depended on by:** the coupling between `unsettledPot` and `totalEntries`. The only other writers of
  `unsettledPot` run when leaving Active or Drawing for Refunding (L297, with the transition at L299), or in
  NftWon or CashWon (L553, gated at L536).

```solidity
// L216
if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
```
- **What:** sales are open for `[activation, endTime)`. The end is exclusive.
- **Why here:** together with L215, this freezes `totalEntries` once `block.timestamp >= endTime`.
  - `requestDraw` requires `block.timestamp >= endTime` (L242). A purchase and a draw request therefore
    cannot both succeed in the same block, and after a request the status is `Drawing` (L252).
  - As a result, `fulfillRandomWords` reads a final `totalEntries` (L518, L521).
- **Assumes:** `endTime` is written once (L204, behind the `initialized` lock at L177-L179) and bounded by
  RaffleFactory L100-L104.
- **Establishes:** `totalEntries` changes only while `block.timestamp < endTime`.
- **Depended on by:** `requestDraw` (L242-L243), `enableRefunds` (L280-L288, whose branch depends on whether
  `totalEntries == 0`) and `fulfillRandomWords` (L518-L521).
- **Ordering note:** `enableRefunds` lets the sponsor move an Active raffle with zero entries to `Refunding`
  before `endTime` (L280-L284). Against the first purchase, only ordering decides the outcome:
  - If the purchase executes first, `totalEntries != 0` and the sponsor branch is closed (L280; the else
    branch at L285-L288 waits until `endTime + 2 days`).
  - If `enableRefunds` executes first, L215 rejects the purchase.

```solidity
// L217-L218
if (recipient == address(0)) revert InvalidRecipient();
if (entryCount == 0) revert ZeroEntryCount();
```
- **What:** rejects a mint to the zero address and an empty purchase.
- **Why here:** both checks run before any external call. L217 repeats the check in ERC721 `_mint`
  (L260-L262), but raises the protocol's own error.
- **Establishes:** `entryCount ≥ 1`. It follows that `firstEntry ≤ lastEntry` at L226-L227, and that
  `ticketCount ≤ totalEntries` after L230-L231.
- **Depended on by:** the partition (no ticket is empty) and `refundTickets` L363 (each ticket contributes at
  least one entry).

```solidity
// L219-L221
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}
```
- **What:** a headroom check, so that `totalEntries + entryCount ≤ 2^128 - 1`.
- **Why here:** it runs before the token pull, so a failed purchase moves no funds. The subtraction cannot
  underflow because `totalEntries ≤ type(uint128).max`.
- **Assumes:** `totalEntries` has the same value at L226-L227 as here. This holds because its only writer is
  L230 and the guard at L212 blocks re-entry into `buyEntries` during the L224 call.
- **Establishes:** none of the counter arithmetic overflows.
  - L227 cannot overflow.
  - L226 cannot overflow: if `totalEntries == max`, every `entryCount ≥ 1` reverts here.
  - L231 (`++ticketCount`) cannot overflow on any reachable path. By L218, `ticketCount ≤ totalEntries`, so
    `ticketCount == max` would require `totalEntries == max`, which this check rejects first.
- **Depended on by:** the arithmetic at L226-L231.
- **Note:** the contract compiles with checked arithmetic (0.8.36, L2), so L227 would revert without this
  check. The check exists to give the failure a named error.
- **Practical bound:** `totalEntries × 10^6` cannot exceed the USDC this clone holds, because no USDC leaves
  the clone while it is Active or Drawing. `_transferQuote` has four callers, each gated:
  - L342 runs only in NftWon or CashWon (L312).
  - L369 runs only in Refunding (L350).
  - L380 requires `sponsorProceeds != 0` (L377), and that value is written only at L554.
  - L390 requires `protocolFees != 0` (L387), and that value is written only at L555.

  L554 and L555 are inside `_settleWinningTicket`, which is gated to NftWon or CashWon (L536). The bound holds
  only if L224 actually delivers funds.

```solidity
// L223-L224
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```
- **What:** computes the nominal price and pulls it from the payer.
- **Why here:** the interaction comes before the effects. None of this function's writes have happened yet,
  so during the token call the raffle is still in its pre-purchase state, and the clone's USDC balance can only
  be equal to or greater than what it has accounted for. Because a revert undoes everything, this ordering
  does not affect correctness. It affects only what a re-entrant observer could see during the call, and the
  token is trusted.
- **Assumes:**
  - `ENTRY_PRICE = 1_000_000` (L44 refers to RaffleConstants L21). The product is below `2^148`, so it cannot
    overflow.
  - What SafeERC20 treats as success: the call did not revert, and the token either returned a first 32-byte
    word equal to 1, or returned no data while having code (SafeERC20 L227-L240). Success does **not** mean
    the clone's balance rose by `grossAmount`.
  - **Exact delivery (no fee, no rebasing): nothing found.** No `balanceOf` is read before or after the
    transfer.
  - **No callback from the token into the payer, the recipient or this clone: nothing found in the code.** If
    a callback happened, L212 would block every guarded function. The unguarded ticket functions would have
    nothing to act on, because the ticket does not exist until L235.
- **Establishes:** if execution continues, the token has reported success for `grossAmount`.
- **Depended on by:** L233, which credits `grossAmount` to `unsettledPot`, and L236, which reports it. Both
  use the nominal amount.
- **Payer screening:** only token-level rules can stop this call: allowance, balance, and the issuer's
  blacklist and pause controls, none of which are in the repo. The recipient takes no part in the USDC
  transfer.

```solidity
// L226-L228
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;
```
- **What:** allocates the next contiguous range and the next sequential ID.
- **Why here:** after the token pull. Both values come from storage at execution time, so the buyer cannot
  choose a range. Transaction ordering decides it.
- **Establishes:**
  - `firstEntry = old totalEntries + 1`, so the new range is adjacent to the previous one.
  - `lastEntry ≥ firstEntry` (from L218).
  - `ticketId ≥ 1`, so ticket ID 0 is never minted.
- **Depended on by:** L230-L236.

```solidity
// L230-L233
totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```
- **What:** records the purchase in storage.
- **Why here:** all four writes land before the only untrusted call (L235). The recipient callback therefore
  sees committed, self-consistent state.
- **Assumes:** `_ticketRanges[ticketId]` has never been written. This holds because `ticketId` strictly
  increases and L232 is the only writer. ERC721 `_mint` (L263-L266) also rejects an ID that already has an
  owner.
- **Establishes:** the following, by induction. The base case is a clone's zeroed storage; `initialize`
  (L197-L205) never touches these fields.
  - **Range partition.** For tickets 1 through `ticketCount`:
    - ticket 1's range starts at 1;
    - each range starts one past the previous range's end, `range(t+1).first = range(t).last + 1`;
    - the last range ends at `totalEntries`;
    - every range is non-empty.

    For ID 0 and for IDs above `ticketCount`, the range reads `(0,0)` (L451-L455; IRaffle L369). Ranges
    survive burns (L138).
  - **Pot coupling.** `unsettledPot == totalEntries × ENTRY_PRICE == grossSales()` (L473-L475) for as long as
    the status is Active or Drawing.
  - **Counter coupling.** `ticketCount` equals the ID of the most recent mint (IRaffle L455).
- **Depended on by:**
  - `_requireWinningTicket` (L579-L585). `winningEntry ∈ [1,totalEntries]` (L518), and the partition
    guarantees exactly one ticket contains it.
  - `refundTickets` (L362-L368). Refunded ranges sum to at most `remainingRefundLiability`, which is set from
    `unsettledPot` at L296-L298. The checked subtraction at L368 depends on this.
  - `_settleWinningTicket` (L539-L555), which allocates `unsettledPot`.
  - `accountedQuoteBalance` (L469).
- **Coupling detail:** `refundTickets` computes `last - first + 1` (L363). For an unminted ID's `(0,0)` range
  that evaluates to 1. Only the `ownerOf` check at L359 keeps unminted IDs out: `ownerOf` (ERC721 L61-L63)
  calls `_requireOwned` (L426-L432), which reverts when the owner is 0. The coupling therefore relies on this
  function writing a range only for an ID it actually mints (L232 together with L235).

```solidity
// L235
_safeMint(recipient, ticketId);
```
- **What:** mints the ticket. If the recipient has code, the recipient must accept it as an ERC-721 receiver.
- **Why here:** this is the last state-changing step, so the only untrusted call runs after every protocol
  write.
- **Call path (every step was read):**
  1. ERC721 `_safeMint(to, id)` (L279-L281) calls `_safeMint(to, id, "")` (L287-L290).
  2. `_mint` (L259-L267) reverts with `ERC721InvalidReceiver` if `to == 0`, which L217 already rules out. It
     then calls `_update(to, id, address(0))`, and reverts with `ERC721InvalidSender(0)` if the ID already had
     an owner, which cannot happen for a fresh ID.
  3. Virtual dispatch reaches `Raffle._update` (L497-L502). It reverts with `UnsafeProtocolDestination(to)` if
     `to != 0 && _isProtocolDestination(to, address(prizeToken))`.
  4. `_isProtocolDestination` (L593-L605) rejects `address(this)`, `factory`, `quoteToken`,
     `i_vrfV2PlusWrapper`, `prizeToken` and `factory.raffleImplementation()`. Because `||` short-circuits, the
     external call is made only when every earlier comparison is false. If the recipient is still unflagged and
     has code, it then rejects `factory.isRaffle(to)`.
  5. `ERC721._update` (L216-L245):
     - `from = _owners[id]`, which is 0;
     - `auth == 0`, so the authorization check is skipped (L220);
     - `from == 0`, so the approval clear and the balance decrement are skipped (L225);
     - `_balances[to] += 1`, unchecked (L235-L237);
     - `_owners[id] = to` (L240);
     - emits `Transfer(0,to,id)` (L242).
  6. `ERC721Utils.checkOnERC721Received(msg.sender, address(0), to, id, "")` (L25-L49):
     - if `to.code.length == 0`, it does nothing;
     - otherwise it calls `onERC721Received` inside a `try`;
     - a return value other than the selector reverts with `ERC721InvalidReceiver(to)`;
     - a revert with an empty reason also reverts with `ERC721InvalidReceiver(to)`;
     - a revert with data is bubbled up.
- **Assumes:**
  - **The factory answers honestly, and the screen cannot change state.** `raffleImplementation` is immutable
    (RaffleFactory L42, L91). `isRaffle` is written only in `createRaffle` (L125). Both are `view`
    (IRaffleFactory L130, L139), so they are called with STATICCALL.
  - **The recipient can later act on the ticket** (refund it, redeem it or transfer it): **nothing found.**
    - Only the zero address (L217) and protocol destinations known at mint time (L498-L500) are excluded.
    - Code-less recipients skip the acceptance check entirely (ERC721Utils L32). These include EOAs,
      precompiles, burn addresses, contracts still under construction and counterfactual addresses.
  - **A recipient's protocol-destination status never changes after mint: nothing found.** The screen runs
    only at mint time.
    - Clone addresses are derived with CREATE from the factory's nonce (Clones L57; RaffleFactory L106), so
      they can be predicted in advance.
    - `isRaffle` is queried only for addresses that have code (L602).
    - A recipient that later becomes a registered raffle passes the screen, and nothing re-screens owners.
- **Establishes:**
  - The ticket exists.
  - If the recipient has code, it explicitly accepted the ticket.
  - At the time of the mint, the recipient is not a known protocol sink.
- **What the callback can do:** untrusted code runs at this point.
  - Guarded functions revert.
  - The recipient is the ticket's current owner (ERC721 L240), so it can `transferFrom`, `safeTransferFrom`,
    `approve` or `setApprovalForAll` the new ticket. These functions are unguarded (ERC721 L93-L136), and
    their destinations are screened by L497-L502.
  - `onERC721Received` on this clone reverts, because the status is Active (L421-L426).
  - Views show the completed purchase.
  - Calls into other clones hit separate guard slots and separate state.
  - If the callback reverts, the whole purchase reverts, including the USDC pull.
- **Depended on by:** `refundTickets` (L359-L360) and `redeemWinningTicket` (L320-L321), which both gate on
  `ownerOf` at the time of the call.

```solidity
// L236
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```
- **What:** the purchase log.
- **Why here:** after the callback. Every field is a local variable or parameter, and none is re-read from
  storage, so the callback cannot change what the event contains.
- **Caveat:** the event's `recipient` is the address the ticket was minted to, not necessarily its owner when
  the transaction ends. If the callback transferred the ticket at L235, that `Transfer` log comes before this
  event.
- **Establishes:** for off-chain consumers, `grossAmount = entryCount × ENTRY_PRICE`, a nominal figure
  (IRaffle L71).

---

**Cross-Function Dependencies:**

Callees:

- **`nonReentrant`** (external-source-available; OpenZeppelin ReentrancyGuard v5.5.0, L69-L106). It blocks
  re-entry into this clone's guarded functions across both L224 and L235. Paths:
  - if the slot is 2, revert;
  - otherwise set it to 2, run the body, and set it to 1;
  - a revert anywhere rolls the slot back.

  It does not cover the inherited ERC-721 functions or `onERC721Received`.
- **`_requireStatus`** (internal, L573-L575). One path: revert unless the status equals `Active`.
- **`SafeERC20.safeTransferFrom`** (external-source-available; OpenZeppelin v5.5.0, L43-L47 and L212-L244).
  - It succeeds when the call did not revert and either the first 32 bytes returned equal 1, or no data was
    returned and the token has code.
  - If the token reverts, the reason is bubbled up (L232-L234).
  - If the token returns false or malformed data, it reverts with `SafeERC20FailedOperation` (L44-L46).

  The caller relies on it only for "the token reported success", never for "the amount arrived".
- **`IERC20(quoteToken).transferFrom`** (external-black-box; no USDC source in the repo; trusted per
  DESIGN.md L2). Arguments: `(msg.sender, address(this), grossAmount)`. Outcomes the code does not rule out:
  - delivery of less than `grossAmount`, for example through a fee or a token upgrade;
  - success with nothing moved;
  - a callback, which standard USDC does not make but the code does not exclude;
  - a revert for allowance, balance, blacklist or pause reasons, which simply aborts the purchase.
- **`ERC721._safeMint` and `_mint`** (external-source-available; OpenZeppelin v5.6.0, L259-L290).
  - They mint only an ID that has never had an owner (L264-L266).
  - They do not stop a burned ID from being minted again. L228 never reuses an ID, so this does not arise.
- **`Raffle._update`** (internal, L497-L502), which calls **`_isProtocolDestination`** (internal, L593-L605),
  which calls **`IRaffleFactory.raffleImplementation()` and `isRaffle()`** (external-source-available;
  RaffleFactory L42 and L54; trusted; STATICCALL).
  - `_isProtocolDestination` defines the full set of protocol sinks: this clone, the factory, the quote token,
    the VRF wrapper, the prize token, the implementation, and registered raffles from the same factory (the
    last only for addresses with code).
  - The sponsor, sponsorRecipient, treasury, LINK, the VRF coordinator, precompiles and burn addresses are not
    in the set.
- **`ERC721Utils.checkOnERC721Received`** (external-source-available; OpenZeppelin v5.5.0, L25-L49). It
  requires the magic return value from recipients that have code, and makes no call to code-less recipients.
- **`IERC721Receiver(recipient).onERC721Received`** (external-black-box; untrusted). Arguments:
  `(operator = msg.sender, from = address(0), tokenId = ticketId, data = "")`. Outcomes not ruled out:
  - a revert or a wrong selector, which reverts the purchase;
  - a transfer of the ticket, or new approvals on it, before L236 runs;
  - calls into other contracts, including other raffle clones.
- **`Context._msgSender`** (external-source-available; OpenZeppelin Context L17-L19). It returns `msg.sender`,
  and `src/` does not override it.

Callers:

- No internal callers. A grep of `src/` finds only the definition at L209 and the interface at IRaffle L314.
- Externally, any EOA or contract holding a USDC allowance can call it, while the raffle is Active and before
  `endTime`.
- What callers can rely on:
  - The returned `ticketId` holds the assigned range.
  - The range is assigned at execution, not chosen by the caller.
- What callers cannot rely on: that `recipient` still owns the ticket when the call returns, if `recipient` is
  a contract that moves it in the callback.

Shared state:

| State | Read here | Written here | Other writers | Other readers |
| --- | --- | --- | --- | --- |
| `status` | yes | no | `onERC721Received` L428, `requestDraw` L252, `fulfillRandomWords` L521, `enableRefunds` L299 | |
| `endTime` | yes | no | `initialize` L204, once | |
| `totalEntries` | yes | only writer | none | `requestDraw` L243, `enableRefunds` L280, `fulfillRandomWords` L518 and L521, `grossSales` L474 |
| `ticketCount` | yes | only writer | none | public getter only |
| `_ticketRanges` | no | only writer | none | `ticketRange` L451-L455, which feeds `_requireWinningTicket` L580 and `refundTickets` L362 |
| `unsettledPot` | yes | incremented here | zeroed by `enableRefunds` L297 and `_settleWinningTicket` L553 | `accountedQuoteBalance` L469 |

- ERC-721 ledger: tickets are minted here. Inherited ERC-721 functions transfer and approve them, and
  `refundTickets` (L364) and `redeemWinningTicket` (L325) burn them.
- The clone's USDC balance rises here and falls only in terminal states.

Invariant couplings:

- **Partition and winner proof.** `fulfillRandomWords` produces `winningEntry ∈ [1,totalEntries]` (L518).
  Because the ranges partition `[1,totalEntries]`, exactly one minted ticket ID passes L582. Settlement is
  therefore always possible, and only one ticket can settle.
- **Partition, pot coupling and refund accounting.** On entering Refunding, `remainingRefundLiability`
  is set to `unsettledPot`, which equals `totalEntries × ENTRY_PRICE` (L296-L298). Each ticket can be burned
  only once (ERC721 `_burn` L303-L307), and the ranges are disjoint, so refunds sum to at most that liability.
  The checked subtraction at L368 relies on this.
- **Accounted versus actual balance.** `accountedQuoteBalance()` (L469) matches the clone's USDC balance only
  if L224 delivers exactly `grossAmount`. Nothing on-chain reconciles the two.
- **Reserve.** This function is the only path that moves `totalEntries` toward `reserveEntries`, which decides
  the outcome at L521. Anyone can pay, including the sponsor, the sponsorRecipient and the treasury: nothing
  at L215-L224 restricts who calls.

---

**Open Questions:**

- Unclear; need to inspect the target chain's deployed USDC implementation behind its proxy to confirm that
  `transferFrom` moves exactly `value` and has no hooks. L224 has no balance-delta check, and the repo contains
  no USDC source.
- Unclear; need to inspect the `redeemWinningTicket` and `refundTickets` analyses to learn what happens to a
  claim whose owner can never call them. Examples include code-less addresses that nobody controls, contracts
  with no way to make those calls, and clone addresses predicted from CREATE that are deployed later.
  `buyEntries` excludes only the zero address and the protocol sinks it can see at mint time (L217,
  L498-L500, L602).
- Unclear; need to reconcile the trust model for prizes. `buyEntries` accepts USDC on the premise that
  `Active` means the prize is in custody. That premise rests on RaffleFactory L129, an `ownerOf` call the prize
  contract answers itself, and nothing in this function checks it again. IRaffle L14-L15 calls prizes
  "honest", while DESIGN.md L2 calls them "untrusted".
- Unclear; need to inspect off-chain consumers, none of which are in this tree, to see whether any assume
  `TicketPurchased.recipient` is the final owner or that `TicketPurchased` comes before later `Transfer` logs
  for the same ticket. L236 is emitted after the callback at L235, which can already have transferred the
  ticket.
- Unclear; need to inspect how EIP-7702-delegated EOAs behave as recipients. Such accounts have non-empty
  code, so ERC721Utils L32 calls into their delegate, and `_isProtocolDestination` L602 queries `isRaffle` for
  them. Whether a given delegate accepts the ticket depends on code outside this repo.
