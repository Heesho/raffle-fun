## `buyEntries` in target/packages/contracts/src/Raffle.sol (L209-L237)

**Purpose:** Converts a payer's quote-token payment into one transferable ERC-721 ticket representing a contiguous, inclusive interval of raffle entries, and adds its price to the unsettled pot. The resulting range is the basis for winner proofs and refunds (Raffle.sol L223-L236, L362-L368, L579-L584).

Source references below use `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, and `libraries/RaffleConstants.sol` under `target/packages/contracts/src/`. Dependency references use paths under `target/packages/contracts/node_modules/@openzeppelin/contracts/`: `ERC721.sol` = `token/ERC721/ERC721.sol`; `ERC721Utils.sol` = `token/ERC721/utils/ERC721Utils.sol`; `SafeERC20.sol` = `token/ERC20/utils/SafeERC20.sol`; `IERC20.sol` = `token/ERC20/IERC20.sol`; and `ReentrancyGuard.sol`, `StorageSlot.sol`, `Context.sol` = their files under `utils/`.

---

**Inputs & Assumptions:**

- `recipient` (`address`) is untrusted caller input. It must be nonzero (Raffle.sol L217), must pass the protocol-destination screen reached through minting (L235, L497-L502, L593-L604), and, if it has code when receiver acceptance runs, must accept the callback (ERC721.sol L287-L290; ERC721Utils.sol L32-L47). There is no requirement that recipient equal payer (Raffle.sol L209, L224, L235).
- `entryCount` (`uint128`) is untrusted caller input, constrained to be positive and at most the remaining uint128 capacity (Raffle.sol L218-L221). The fixed price is 1,000,000 raw quote units per entry (Raffle.sol L44; RaffleConstants.sol L20-L24).
- `msg.sender` is the payer passed to `quoteToken.transferFrom`, whereas `recipient` receives the ticket; the ERC-721 receiver sees the payer as `operator` because `_msgSender()` returns `msg.sender` (Raffle.sol L224-L235; ERC721.sol L289; Context.sol L17-L19). Balance and allowance authorization are delegated to the quote token, whose available interface declares `transferFrom` but does not implement it (IERC20.sol L69-L78).
- Implicit state includes `status`, `endTime`, `totalEntries`, `ticketCount`, `unsettledPot`, `_ticketRanges`, immutable quote/factory addresses, configured prize/wrapper addresses, and ERC-721 ownership/balances (Raffle.sol L55-L91, L139, L215-L235, L593-L604; ERC721.sol L28-L34, L216-L244).
- Active status and a timestamp strictly before `endTime` are established at entry by `_requireStatus` and the explicit time check (Raffle.sol L215-L216, L573-L575). The Active transition occurs after the exact configured prize callback is accepted (L421-L430); canonical creation additionally checks reported prize ownership and Active status after transfer (RaffleFactory.sol L127-L134). `buyEntries` itself does not re-query prize ownership (Raffle.sol L209-L237).
- Exact quote receipt is an explicit environmental assumption: the documented token model is canonical, non-rebasing, fee-free USDC (IRaffle.sol L12-L15). Nothing in this function or SafeERC20 proves a balance increase of `grossAmount`; only call/return acceptance is checked (Raffle.sol L223-L224; SafeERC20.sol L43-L47, L212-L244). Factory construction checks code and six decimals, while its documentation assigns token-identity verification to deployment tooling (RaffleFactory.sol L58-L78, L183-L185; IRaffleFactory.sol L7-L9). Established by onchain logic: **nothing found** for exact transfer semantics or canonical identity.
- The mint ID and counts rely on the normal cumulative state history: every completed purchase adds at least one entry and exactly one ticket, with neither counter decremented by refund or redemption (Raffle.sol L218, L226-L233, L309-L346, L349-L372). Thus `ticketCount <= totalEntries` is inductive from zero-valued fresh storage; the explicit remaining-entry check also leaves room for the ticket increment (L219-L231). Checked arithmetic supplies an additional revert path rather than permitting wraparound (pragma L2; L226-L233).

---

**Outputs & Effects:**

- Returns `ticketId = old(ticketCount) + 1`; stores `[old(totalEntries)+1, old(totalEntries)+entryCount]`, increments lifetime ticket and entry counts, and increases `unsettledPot` by `entryCount * ENTRY_PRICE` (Raffle.sol L213, L223, L226-L233).
- The ERC-721 mint writes ownership and recipient balance and emits `Transfer(0, recipient, ticketId)` before checking receiver acceptance (ERC721.sol L216-L244, L259-L267, L287-L290). `TicketPurchased` is emitted after the receiver call and contains the payer, original recipient, ticket ID, entry bounds/count and gross amount (Raffle.sol L235-L236; IRaffle.sol L64-L80).
- External boundaries are quote-token `transferFrom`, factory getters used by the destination screen, and a conditional receiver callback (Raffle.sol L224, L235, L598-L604; SafeERC20.sol L227; ERC721Utils.sol L32-L33). The quote call transfers no native value (SafeERC20.sol L227); the receiver arguments are payer/operator, zero/from, ticket ID, and empty bytes (ERC721.sol L279-L290).
- Before receiver execution, payment-call acceptance, range storage, counts, pot accounting, and initial ticket ownership have all been established (Raffle.sol L224-L235; ERC721.sol L287-L289). Ownership at final return need not equal `recipient`: the receiver may use unguarded inherited transfers after minting, subject to their normal authorization and destination checks (ERC721.sol L115-L136; Raffle.sol L497-L502). The purchase event records the mint recipient, not a separately checked end-of-call owner (Raffle.sol L236).
- On a revert from payment, screening, minting or callback, EVM transaction rollback applies to the preceding writes and external token movement; there is no caught failure in `buyEntries` that continues to issue a ticket (Raffle.sol L215-L237; SafeERC20.sol L43-L47, L230-L239; ERC721.sol L259-L267; ERC721Utils.sol L34-L45).

---

**Block-by-Block:**

```solidity
// Raffle.sol L209-L221 (signature abbreviated)
function buyEntries(address recipient, uint128 entryCount)
    external override nonReentrant returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
    if (entryCount == 0) revert ZeroEntryCount();
    if (entryCount > type(uint128).max - totalEntries) {
        revert TotalEntriesOverflow(totalEntries, entryCount);
    }
```

- **What:** Locks the guarded entrypoints, enforces the lifecycle/time window, and rejects empty recipients/counts and entry-capacity overflow (Raffle.sol L212-L221; ReentrancyGuard.sol L69-L73, L88-L105).
- **Why here:** These checks run before the payment interaction or new ticket/accounting writes (Raffle.sol L215-L233).
- **Assumes:** The guard slot belongs to this instance and follows its entered-value convention. The implementation returns a constant namespaced slot, accesses it via `StorageSlot.getUint256Slot`, and rejects exactly value 2 (ReentrancyGuard.sol L35-L37, L50-L51, L112-L118; StorageSlot.sol L93-L97). A fresh clone's zero slot is accepted because the guard tests equality to 2, not equality to the initialized value 1 (ReentrancyGuard.sol L88-L99, L112-L114).
- **Establishes:** `entryCount >= 1`, `old(totalEntries) <= uint128.max-1`, and the two subsequent entry additions fit in uint128; the guard stays entered throughout both external interactions and resets after the body (Raffle.sol L218-L227; ReentrancyGuard.sol L69-L73, L94-L105).
- **Depended on by:** Range allocation, cumulative accounting and rejection of nested calls to guarded raffle operations (Raffle.sol L226-L235; guarded signatures L240, L276, L304, L309, L349, L375, L385, L395).

```solidity
// Raffle.sol L223-L224
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

- **What:** Computes the raw price with uint256 multiplication, then asks the immutable quote token to debit the payer and credit this raffle (Raffle.sol L58, L223-L224).
- **Why here:** Payment acceptance precedes minting and pot/count mutation; during the token call, those fields still have their previous values while the guard is entered (Raffle.sol L224-L235; ReentrancyGuard.sol L94-L99).
- **Assumes:** Successful call/return acceptance denotes an exact, authorized transfer of the requested amount; this is the documented token assumption, not a balance-delta check (IRaffle.sol L12-L15; SafeERC20.sol L43-L47, L227-L239).
- **Establishes:** SafeERC20's low-level call succeeded and its acceptance predicate passed. It bubbles a token revert; otherwise it accepts the first output word equal to 1, or empty returndata from an address with code, and returns false for the remaining paths, causing the outer wrapper to revert (SafeERC20.sol L43-L47, L219-L243). No stronger token-ledger claim is established by the wrapper.
- **Depended on by:** The later `unsettledPot += grossAmount` and eventual quote-denominated claims (Raffle.sol L233, L296-L299, L367-L369, L539-L555). Since `entryCount <= 2^128-1` and price is 10^6, this multiplication fits uint256; this is a derived bound from Raffle.sol L209/L223 and RaffleConstants.sol L21.

```solidity
// Raffle.sol L226-L233
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;
totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```

- **What:** Appends one nonempty inclusive interval, assigns the next ticket ID, and stores the entire payment as unsettled liability (Raffle.sol L226-L233).
- **Why here:** The writes occur after payment-call acceptance and before receiver-controlled execution; the receiver therefore observes its complete range and matching entry/pot accounting (Raffle.sol L224-L235; ERC721.sol L287-L290).
- **Assumes:** No intervening guarded purchase changes `totalEntries`/`ticketCount`; the shared guard enforces this throughout the earlier quote-token interaction (Raffle.sol L212, L224; ReentrancyGuard.sol L88-L105). `ticketCount <= totalEntries` follows the positive-count induction described above, rather than a separate comparison in this block (Raffle.sol L218-L231).
- **Establishes:** `lastEntry-firstEntry+1 == entryCount`; the new first entry is exactly one above the previous final entry; each successful call advances ticket IDs by one. Inductively the historical ranges partition `[1,totalEntries]` without gaps or overlap (Raffle.sol L226-L233). Burning later leaves these historical ranges and lifetime counters untouched (L325, L362-L364, L451-L455).
- **Depended on by:** Constant-size winner containment checks, full entry-value refunds, and `grossSales()` computed from lifetime entries (Raffle.sol L362-L368, L473-L475, L579-L584). While sales remain Active, accumulated `unsettledPot` equals `totalEntries * ENTRY_PRICE` from fresh state; pot-clearing transitions leave Active and cannot accompany a successful guarded purchase (L215, L233, L296-L299, L534-L555).

```solidity
// Raffle.sol L235-L236
_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```

- **What:** Mints the ticket, applies destination screening, conditionally invokes receiver acceptance, then emits the purchase record (Raffle.sol L235-L236, L497-L502; ERC721.sol L259-L290).
- **Why here:** Accounting precedes the untrusted callback; event emission follows acceptance and any nested ticket transfers (Raffle.sol L230-L236; ERC721.sol L287-L289, L115-L136).
- **Assumes:** Callback success only establishes the expected selector when code exists; it does not establish continuing recipient ownership or recipient ability to redeem later (ERC721Utils.sol L32-L47; ERC721.sol L115-L136). Code-less recipients skip the callback entirely (ERC721Utils.sol L32-L48).
- **Establishes:** `_mint` rejects zero recipient and previously existing token IDs, with the latter check performed after `_update` but reverting the transaction if the previous owner was nonzero (ERC721.sol L259-L267). Raffle's override rejects itself, its factory, quote token, wrapper, prize token, implementation, and code-bearing registered sibling raffles (Raffle.sol L497-L502, L598-L604). If a receiver callback runs, only the expected selector allows continuation; wrong selectors and empty/nonempty reverts all fail the purchase (ERC721Utils.sol L32-L47).
- **Depended on by:** The returned ticket ID and emitted purchase attest to completed issuance. Subsequent bearer claims use the then-current owner, independently of the payer/original mint recipient (Raffle.sol L236, L320-L325, L359-L364).

---

**Cross-Function Dependencies:**

- **`nonReentrant` and its helper chain (internal):** `_nonReentrantBefore` calls `_nonReentrantBeforeView`, which reads `_reentrancyGuardEntered`; slot lookup uses `_reentrancyGuardStorageSlot` and `StorageSlot.getUint256Slot`. Value 2 rejects entry, otherwise it is written before the body and reset to 1 after it (ReentrancyGuard.sol L69-L73, L88-L118; StorageSlot.sol L93-L97). This excludes nested guarded purchases/lifecycle/claim calls, not inherited ERC-721 approvals and transfers (Raffle.sol L212, L240, L276, L304, L309, L349, L375, L385, L395; ERC721.sol L93-L107, L115-L136).
- **`_requireStatus` (internal):** All mismatched statuses revert; matching Active returns without writes (Raffle.sol L573-L575).
- **`SafeERC20.safeTransferFrom -> _safeTransferFrom` (internal) and `quoteToken.transferFrom` (external black box):** The internal implementation is available and inspected, including its revert and optional-return paths. The actual token implementation is not supplied by its interface, so exact debit/credit, allowance enforcement and the absence of unexpected token behavior remain external assumptions. The raw external call forwards gas and zero native value with `(payer, raffle, grossAmount)` before raffle accounting writes; arbitrary re-entry is a possible external action, with guarded re-entry rejected (SafeERC20.sol L43-L47, L212-L244; IERC20.sol L69-L78; Raffle.sol L212, L224-L233).
- **`ERC721._safeMint -> _mint -> Raffle._update -> ERC721._update` (internal):** `_safeMint` supplies empty callback data; `_mint` checks nonzero destination and previous nonexistence; Raffle screens nonzero destinations; base update reads `_ownerOf`, optionally checks authorization only for nonzero `auth`, conditionally clears prior approval/decrements an old balance, increments the recipient balance, records ownership and emits Transfer (ERC721.sol L146-L148, L216-L244, L259-L290; Raffle.sol L497-L502). Mint passes zero `auth`, so authorization checking is skipped by design. The old-owner branch reaches `_approve(0,tokenId,0,false)`, which writes approval directly without owner/authorization queries; that branch is followed by `_mint` reverting because the ID existed (ERC721.sol L225-L231, L263-L265, L383-L399). Balance updates are unchecked but cumulative minted tickets are uint128-bounded, and successful fresh mint takes no decrement branch (ERC721.sol L225-L237; Raffle.sol L218-L231).
- **`_isProtocolDestination` (internal) and factory getters (external source available):** Explicit-address matches short-circuit the remaining disjunction. Otherwise the immutable implementation getter is called, and `isRaffle(destination)` is queried only if no earlier match and the recipient has code (Raffle.sol L598-L604). The factory exposes its immutable implementation and registration mapping, with registration stored before prize escrow (RaffleFactory.sol L42, L54, L89-L91, L123-L128). No receiver behavior is inferred from a negative registry answer; it only clears this screen (Raffle.sol L602-L604; ERC721Utils.sol L32-L47).
- **`Context._msgSender` and `ERC721Utils.checkOnERC721Received` (internal), recipient callback (external black box):** `_msgSender` returns the payer; the utility skips code-less destinations and calls code-bearing recipients with `(payer,0,ticketId,"")`, accepting only the selector and bubbling nonempty revert data (Context.sol L17-L19; ERC721.sol L279-L290; ERC721Utils.sol L25-L48). The receiver implementation depends on untrusted caller-selected `recipient`; no generic implementation is available. It may reject, consume gas, re-enter or transfer the ticket; all guarded accounting mutations remain excluded during the callback (same guard sources above; ERC721.sol L115-L136).
- **Callers:** This is an external permissionless entrypoint with no caller allowlist in its body. A caller funds another recipient by authorizing its own quote-token transfer; receiving the ticket and paying are separate roles (Raffle.sol L209-L224, L235).
- **Shared state/couplings:** `totalEntries` determines draw eligibility, selected-entry modulus, reserve result and gross sales (Raffle.sol L243, L518-L521, L473-L475). `_ticketRanges` feeds refunds and winning proofs (L362-L363, L451-L455, L579-L584). `unsettledPot` feeds refund activation or terminal allocation (L296-L299, L539-L555). ERC-721 ownership supplies the current authorized claimant, while ranges remain historical after burns (L320-L325, L359-L364, L451-L455).

---

**Open Questions:**

- unclear; need to inspect the actual selected quote-token implementation and deployment identity evidence to verify exact transfer/balance/allowance semantics. The available interface and factory metadata checks do not establish those properties (IERC20.sol L69-L78; RaffleFactory.sol L58-L78; SafeERC20.sol L227-L239).
- unclear; need to inspect any concrete recipient contract to characterize its callback execution, willingness to accept the ticket, and subsequent ability to exercise bearer claims. The generic callback check establishes only code-dependent selector acceptance (ERC721Utils.sol L32-L47; Raffle.sol L320-L321, L359-L360).
