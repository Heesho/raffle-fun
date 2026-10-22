## `buyEntries` in target/packages/contracts/src/Raffle.sol (L209-L237)

**Purpose:** Converts one accepted quote-token payment into one sequential ERC-721 bearer ticket whose stored inclusive range represents every entry in that purchase. It is the only writer of `totalEntries`, `ticketCount`, and `_ticketRanges`, and it adds the purchase value to the unallocated quote-token liability before safely minting the ticket (`Raffle.sol:L84-L91`, `L138-L139`, `L209-L236`).

**Inputs & Assumptions:**
- `recipient` (`address`): buyer-selected initial ticket recipient. Trust: **untrusted**. The function rejects zero at `Raffle.sol:L217`; the mint path later rejects known protocol destinations through `Raffle._update` and `_isProtocolDestination` (`Raffle.sol:L235`, `L497-L501`, `L593-L604`). If it has code when checked, its receiver callback is untrusted and executes after the ticket and purchase accounting have been written (`ERC721.sol:L287-L290`; `ERC721Utils.sol:L25-L48`).
- `entryCount` (`uint128`): buyer-selected number of entries. Trust: **untrusted**. It must be nonzero and must fit in the remaining `uint128` global-entry space (`Raffle.sol:L218-L221`).
- Implicit `msg.sender`: untrusted payer and event `buyer`; `grossAmount` is pulled from this address and it is emitted in `TicketPurchased` (`Raffle.sol:L224`, `L236`; `IRaffle.sol:L64-L80`).
- Implicit lifecycle and clock: `status` must be `Active`, and `block.timestamp` must be strictly less than the immutable-per-raffle `endTime` (`Raffle.sol:L215-L216`). `initialize` writes `endTime` and `AwaitingPrize`, while the authenticated prize callback is the transition to `Active` (`Raffle.sol:L197-L205`, `L421-L430`).
- Implicit shared accounting: the current `totalEntries`, `ticketCount`, `_ticketRanges`, and `unsettledPot` determine the next range, ticket ID, and liability (`Raffle.sol:L84-L91`, `L138-L139`, `L226-L233`). All four purchase-side values are written only by this function in the target source (`Raffle.sol:L230-L233`).
- Implicit quote-token contract: trusted by the design as canonical six-decimal, standard, non-rebasing, fee-free USDC (`IRaffle.sol:L12-L15`; `DESIGN.md:L2`). Its implementation is not present; factory construction checks code and six-decimal metadata, while the interface assigns canonical-token identity verification to deployment tooling (`RaffleFactory.sol:L66-L78`; `IRaffleFactory.sol:L7-L9`).
- Implicit canonical factory registry: mint destination screening reads the immutable implementation and, for a code-bearing destination not matched locally, its registration flag (`Raffle.sol:L598-L604`). The factory fixes the implementation at construction and only adds registered raffles during creation (`RaffleFactory.sol:L41-L54`, `L89-L91`, `L105-L125`).
- Precondition: no protected Raffle call is already executing. The inherited modifier rejects only the `ENTERED` value, then holds the shared guard in `ENTERED` for the full body and restores `NOT_ENTERED` on normal exit (`ReentrancyGuard.sol:L69-L72`, `L88-L105`). A fresh clone's zero-valued guard slot also passes the first equality check and is set to `ENTERED` by that first call (`ReentrancyGuard.sol:L50-L51`, `L88-L100`).
- Precondition: `msg.sender` has sufficient balance/allowance and the configured token implements an accepted `transferFrom` result. This is established only by the external token on a particular call; SafeERC20 accepts returned `true`, or empty return data from an address with code, and rejects/bubbles the other outcomes (`SafeERC20.sol:L40-L47`, `L212-L244`).
- Precondition: SafeERC20 success corresponds to an exact `grossAmount` increase in raffle custody. SafeERC20 does not measure a balance delta (`SafeERC20.sol:L212-L244`); this is supplied by the canonical, fee-free quote-token trust assumption (`IRaffle.sol:L12-L15`; `DESIGN.md:L2`).

**Outputs & Effects:**
- Returns the next one-based `ticketId`, computed from the pre-call `ticketCount` (`Raffle.sol:L213`, `L228`).
- External quote-token interaction: invokes `transferFrom(msg.sender, address(this), grossAmount)` through SafeERC20 before changing purchase accounting (`Raffle.sol:L223-L224`; `SafeERC20.sol:L43-L47`, `L212-L244`).
- Storage writes: advances `totalEntries` to the new last entry, increments `ticketCount`, stores the nonempty inclusive range, and increases `unsettledPot` by `grossAmount` (`Raffle.sol:L226-L233`).
- ERC-721 effects: the mint path screens `recipient`, increments its balance, records it as owner, and emits `Transfer(address(0), recipient, ticketId)` before any receiver callback (`Raffle.sol:L235`, `L497-L501`; `ERC721.sol:L216-L244`, `L259-L290`).
- External receiver interaction: code-bearing recipients receive `onERC721Received(msg.sender, address(0), ticketId, "")`; code-less recipients are not called (`ERC721.sol:L279-L290`; `Context.sol:L17-L19`; `ERC721Utils.sol:L25-L48`). Correct-selector return accepts; a wrong selector, empty-data failure, or bubbled revert rejects the mint (`ERC721Utils.sol:L32-L47`).
- Event: after receiver acceptance, emits `TicketPurchased` with the payer, originally supplied recipient, assigned range, entry count, and gross amount (`Raffle.sol:L235-L236`; `IRaffle.sol:L64-L80`). Because a receiver already owns the ticket during its callback, inherited approval or transfer calls can change its ownership before this event; the event's `recipient` remains the original mint destination (`ERC721.sol:L92-L136`, `L216-L244`, `L287-L290`; `Raffle.sol:L236`).
- Postcondition on an accepted payment and mint: the new range is `[oldTotalEntries + 1, oldTotalEntries + entryCount]`, so it is nonempty and directly follows the preceding global entry; `totalEntries`, `ticketCount`, and `unsettledPot` each advance once (`Raffle.sol:L218-L233`).
- Every revert path before normal return rolls back this call's token transfer, storage writes, mint, callback effects, and logs as one transaction; the possible rejection points are the modifier, local gates, token call, destination screen, pre-existing-token check, and receiver acceptance path (`Raffle.sol:L209-L237`; `ReentrancyGuard.sol:L69-L72`; `SafeERC20.sol:L43-L47`; `ERC721.sol:L259-L290`; `ERC721Utils.sol:L32-L47`).

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
- **What:** Exposes permissionless purchase and wraps the complete body in the shared storage guard (`Raffle.sol:L209-L214`; `ReentrancyGuard.sol:L69-L72`).
- **Why here:** The guard is entered before either untrusted external interaction: quote-token `transferFrom` and ticket-recipient acceptance (`Raffle.sol:L212-L235`).
- **Assumes:** The fixed guard slot is not already `ENTERED`; a nested protected call is rejected by `_nonReentrantBeforeView` (`ReentrancyGuard.sol:L88-L100`).
- **Establishes:** Every Raffle entrypoint carrying the same modifier is unavailable during both external calls; unguarded inherited ERC-721 entrypoints are outside that guarantee (`Raffle.sol:L209-L212`, `L240`, `L276`, `L304`, `L309`, `L349`, `L375`, `L385`, `L395`; `ERC721.sol:L92-L136`).
- **Depended on by:** The payment and safe-mint blocks, which both hand execution to external contracts (`Raffle.sol:L223-L235`).

```solidity
// L215-L221
_requireStatus(Status.Active);
if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
if (recipient == address(0)) revert InvalidRecipient();
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}
```
- **What:** Gates lifecycle/time, rejects the zero recipient and zero-sized purchase, and bounds the resulting global entry number (`Raffle.sol:L215-L221`).
- **Why here:** All deterministic rejection paths precede the quote-token call and all purchase state writes (`Raffle.sol:L215-L233`).
- **Assumes:** `_requireStatus` compares the current authoritative status without side effects; its complete body does exactly that (`Raffle.sol:L571-L575`).
- **Establishes:** On continuation, sales are open, `recipient != address(0)`, `entryCount >= 1`, and `totalEntries + entryCount <= type(uint128).max` (`Raffle.sol:L215-L221`).
- **Depended on by:** The additions at `L226-L227`, the positive range width, `ticketCount` progression, and safe mint (`Raffle.sol:L226-L235`).

```solidity
// L223-L224
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```
- **What:** Prices the purchase at the fixed `1_000_000` raw units per entry and asks the quote token to move that amount from the payer (`Raffle.sol:L223-L224`; `RaffleConstants.sol:L20-L21`).
- **Why here:** The accepted token call precedes issuance of the range, liability, or ticket (`Raffle.sol:L224-L235`). During this call the purchase state is still at its pre-call values, but the shared guard is already entered (`Raffle.sol:L212-L224`; `ReentrancyGuard.sol:L94-L100`).
- **Assumes:** An accepted SafeERC20 result means the raffle actually received exactly `grossAmount`; the wrapper checks call/return behavior rather than balances (`SafeERC20.sol:L43-L47`, `L212-L244`), and exact fee-free semantics come from the quote-token trust model (`IRaffle.sol:L12-L15`).
- **Establishes:** SafeERC20 either bubbles the token revert, raises `SafeERC20FailedOperation`, or returns after an accepted result (`SafeERC20.sol:L43-L47`, `L227-L244`). It does not itself establish a custody balance delta (`SafeERC20.sol:L212-L244`).
- **Depended on by:** `unsettledPot += grossAmount` and every later refund/settlement liability derived from that stored amount (`Raffle.sol:L233`, `L296-L299`, `L539-L555`).

```solidity
// L226-L228
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;
```
- **What:** Derives the next contiguous global entry range and next sequential ticket identifier from pre-write counters (`Raffle.sol:L226-L228`).
- **Why here:** All three values use the same pre-purchase snapshot before counters advance (`Raffle.sol:L226-L231`).
- **Assumes:** `ticketCount <= totalEntries`; both begin at zero in clone storage and each successful purchase increments `ticketCount` once while adding a positive `entryCount` to `totalEntries` (`Raffle.sol:L84-L88`, `L218`, `L226-L231`). No other target function writes either value (`Raffle.sol:L84-L88`, `L230-L231`).
- **Establishes:** `firstEntry` is one after the old last entry; `lastEntry >= firstEntry`; and the new `ticketId` is one after the old count (`Raffle.sol:L218`, `L226-L228`). The `uint128` entry additions are within range because of `L219-L221`.
- **Depended on by:** The counter writes, stored range, mint, return value, and purchase event (`Raffle.sol:L230-L236`).

```solidity
// L230-L233
totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```
- **What:** Commits the new global endpoint, ticket count, historical ticket range, and unallocated quote liability (`Raffle.sol:L230-L233`).
- **Why here:** These effects land after accepted payment but before the safe-mint receiver can inspect or interact with the raffle (`Raffle.sol:L224-L235`; `ERC721.sol:L287-L290`).
- **Assumes:** The derived `ticketId` is fresh. The inductive counter/range discipline establishes this: only this function increments `ticketCount`, each successful call uses old count plus one, and no path decrements it (`Raffle.sol:L87-L88`, `L228-L232`).
- **Establishes:** Public accounting and `ticketRange(ticketId)` already reflect the new purchase when receiver code runs (`Raffle.sol:L230-L235`, `L451-L455`; `ERC721.sol:L287-L290`).
- **Depended on by:** Draw eligibility and winner selection use `totalEntries`; refunds and winner proof use stored ranges; refund/settlement allocation consumes `unsettledPot` (`Raffle.sol:L243`, `L296-L299`, `L362-L369`, `L518-L521`, `L538-L555`, `L579-L584`).

```solidity
// L235-L236
_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```
- **What:** Mints the range ticket, requires contract-recipient acceptance when applicable, and records the completed purchase (`Raffle.sol:L235-L236`; `ERC721.sol:L279-L290`; `ERC721Utils.sol:L25-L48`).
- **Why here:** Mint and callback observe fully committed purchase accounting; the purchase event is emitted only after acceptance returns (`Raffle.sol:L230-L236`).
- **Assumes:** Destination classification from `_isProtocolDestination` is available from local immutable/configuration comparisons and the canonical factory getters (`Raffle.sol:L593-L604`; `RaffleFactory.sol:L41-L54`). For a code-bearing recipient, successful completion further assumes it returns the required selector (`ERC721Utils.sol:L32-L47`).
- **Establishes:** Before callback, the token owner is `recipient` and a `Transfer` event has been emitted (`ERC721.sol:L216-L244`, `L259-L290`). After callback, acceptance—not continued ownership—is established: receiver code can use inherited approval/transfer calls while it owns the ticket (`ERC721.sol:L92-L136`, `L287-L290`).
- **Depended on by:** Callers and indexers receive the returned `ticketId` and final `TicketPurchased` record only after the safe-mint path completes (`Raffle.sol:L213`, `L235-L236`; `IRaffle.sol:L64-L80`).

---

**Cross-Function Dependencies:**
- **Callee `ReentrancyGuard.nonReentrant` chain (internal, `ReentrancyGuard.sol:L69-L105`):** `_nonReentrantBeforeView` rejects exactly `ENTERED`; `_nonReentrantBefore` writes `ENTERED`; `_nonReentrantAfter` writes `NOT_ENTERED` after the body (`ReentrancyGuard.sol:L88-L105`). `buyEntries` depends on that state spanning both external calls (`Raffle.sol:L212-L235`). A recipient callback cannot enter any other protected Raffle function, but can call inherited ERC-721 functions without this modifier (`Raffle.sol:L240`, `L276`, `L304`, `L309`, `L349`, `L375`, `L385`, `L395`; `ERC721.sol:L92-L136`).
- **Callee `_requireStatus` (internal, `Raffle.sol:L571-L575`):** read in full. Its sole path compares `status` with the requested value and reverts with the actual state on mismatch; continuation establishes `status == Active` at `L215`.
- **Callee `SafeERC20.safeTransferFrom` / `_safeTransferFrom` (internal, `SafeERC20.sol:L40-L47`, `L212-L244`):** read in full. The nested low-level call forwards all remaining gas to `quoteToken.transferFrom(msg.sender, address(this), grossAmount)` (`SafeERC20.sol:L219-L227`). A failed call bubbles its revert because `bubble` is true; a successful call returning word `1` is accepted; empty return data is accepted only when the token has code; other non-reverting results produce `SafeERC20FailedOperation` through the outer wrapper (`SafeERC20.sol:L43-L47`, `L227-L244`). None of these paths measures the raffle's token balance.
- **Callee `IERC20.transferFrom` (external-black-box, `IERC20.sol:L69-L78`):** implementation source is absent. The call receives payer, raffle, and `grossAmount` (`Raffle.sol:L223-L224`). Failure and nonstandard return paths are handled as above; successful return without an exact balance change is not excluded by SafeERC20 (`SafeERC20.sol:L212-L244`). Re-entry before purchase writes is possible at the call boundary, with protected Raffle paths rejected by the already-entered guard (`ReentrancyGuard.sol:L88-L100`).
- **Callee `ERC721._safeMint` chain (internal, `ERC721.sol:L259-L290`):** the two-argument overload forwards empty data, `_mint` dispatches to the Raffle override of `_update`, and then `ERC721Utils.checkOnERC721Received` runs (`ERC721.sol:L259-L290`). `buyEntries` depends on the complete chain either succeeding or reverting.
- **Callee `Raffle._update` / `_isProtocolDestination` (internal, `Raffle.sol:L497-L502`, `L593-L605`):** every nonzero mint destination is compared with this raffle, factory, quote token, wrapper, prize token, implementation, and—when code exists and no earlier match—factory registry membership (`Raffle.sol:L598-L604`). A match reverts before the inherited ledger update (`Raffle.sol:L497-L501`).
- **Callees `RaffleFactory.raffleImplementation()` and `isRaffle(address)` (external-source-available, `RaffleFactory.sol:L41-L54`):** public getters read factory immutable/registry state. Factory construction fixes `raffleImplementation`, and `createRaffle` sets registration before prize activation can make a clone `Active` (`RaffleFactory.sol:L89-L91`, `L105-L128`; `Raffle.sol:L421-L430`).
- **Callee `ERC721._update` (internal, `ERC721.sol:L216-L245`):** on the mint path `auth == address(0)`, so no authorization check runs; it reads the old owner, increments the recipient balance, writes ownership, and emits `Transfer` (`ERC721.sol:L216-L244`). `_mint` then requires the returned previous owner to be zero and otherwise reverts (`ERC721.sol:L259-L267`).
- **Callee `ERC721Utils.checkOnERC721Received` / `IERC721Receiver.onERC721Received` (external-black-box at the receiver, `ERC721Utils.sol:L25-L48`):** code-less recipients take the no-call path (`L32`). Code-bearing recipients are called after ownership/accounting writes; correct selector accepts, wrong selector reverts, empty revert data maps to `ERC721InvalidReceiver`, and nonempty revert data is bubbled (`L32-L47`). Receiver code may read the new range/liability and may approve or transfer the ticket before returning because those inherited entrypoints are public and unguarded (`Raffle.sol:L230-L235`, `L451-L455`; `ERC721.sol:L92-L136`, `L287-L290`).
- **Callers:** `buyEntries` is itself an `external` entrypoint callable by any address subject to its gates (`Raffle.sol:L209-L214`; `IRaffle.sol:L310-L314`). No internal source callsite exists in the target; the only other occurrence is the interface declaration (`IRaffle.sol:L314`).
- **Shared state — lifecycle:** `initialize` supplies `endTime` and `AwaitingPrize`, `onERC721Received` changes the raffle to `Active`, `requestDraw` changes it to `Drawing`, `enableRefunds` changes it to `Refunding`, and the VRF callback fixes a result state (`Raffle.sol:L197-L205`, `L421-L430`, `L240-L260`, `L276-L300`, `L509-L523`). There is no transition back to `Active` in these paths, so purchase writes occur only in the sales phase (`Raffle.sol:L215`).
- **Shared state — ranges and ownership:** `totalEntries`, `ticketCount`, and `_ticketRanges` are created here (`Raffle.sol:L226-L233`); draw/refund/result/settlement paths consume the sold count or ranges (`Raffle.sol:L243`, `L280-L287`, `L362-L369`, `L518-L521`, `L538`, `L579-L584`). ERC-721 transfers may change the current bearer, and refund/redemption later burn the current owner's ticket while historical ranges remain stored (`ERC721.sol:L114-L136`, `L303-L307`; `Raffle.sol:L138-L139`, `L320-L325`, `L357-L365`).
- **Shared state — quote-token accounting:** `unsettledPot` is increased here, moved wholesale to refund liability by `enableRefunds`, or split into terminal liabilities by `_settleWinningTicket`; payout functions reduce those derived buckets (`Raffle.sol:L233`, `L296-L299`, `L539-L555`, `L339-L342`, `L367-L390`). `accountedQuoteBalance` sums every current bucket and `grossSales` derives lifetime purchases from `totalEntries` (`Raffle.sol:L468-L475`).
- **Invariant coupling:** Given the configured token's exact fee-free transfer semantics, every successful call increases custody and `unsettledPot` by the same `entryCount * ENTRY_PRICE` (`Raffle.sol:L223-L233`; `IRaffle.sol:L12-L15`). Given the positive-count and overflow gates, successive stored ranges are nonempty, contiguous, disjoint, and cover entry numbers `1..totalEntries` (`Raffle.sol:L218-L232`). The terminal draw/refund paths rely on those two couplings (`Raffle.sol:L296-L299`, `L518-L521`, `L539-L555`, `L579-L584`).

---

**Open Questions:**
- unclear; need to inspect the deployed quote-token implementation and deployment evidence to confirm that the configured address is canonical USDC and that every accepted `transferFrom` changes raffle custody by exactly `grossAmount`. The target contains the interface/trust requirement and factory code/decimal checks, but not the token implementation or deployment record (`IRaffle.sol:L12-L15`; `IRaffleFactory.sol:L7-L9`; `RaffleFactory.sol:L66-L78`; `SafeERC20.sol:L212-L244`).
