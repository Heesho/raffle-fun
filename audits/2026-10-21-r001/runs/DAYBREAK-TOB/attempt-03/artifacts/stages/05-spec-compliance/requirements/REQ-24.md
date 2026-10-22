## REQ-24 — full entry refunds and prize return

> "Refund outcome pays 100% per entry and returns prize."
> — DESIGN.md:L2, sentence 7

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A raffle that reaches its refund outcome must preserve every sold entry's complete purchase value and let the current ticket owner receive exactly 1,000,000 raw quote-token units for each represented entry, with no protocol, sponsor, rounding, or other deduction. The escrowed prize must also have a return path. The relevant trust boundary is explicit in the specification: "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`.)

---

**Where enforcement lives:**

```solidity
// packages/contracts/src/libraries/RaffleConstants.sol:L20-L21
/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;

// packages/contracts/src/Raffle.sol:L43-L44
/// @inheritdoc IRaffle
uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;
```

- The purchase and refund sides use the same immutable constant, so the nominal amount paid for one entry and the amount returned for one entry cannot diverge through configuration (`RaffleConstants.sol:L20-L21`; `Raffle.sol:L43-L44`).

```solidity
// packages/contracts/src/Raffle.sol:L223-L233
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```

- Every successful purchase records an inclusive range of exactly `entryCount` entries and adds `entryCount * ENTRY_PRICE` to the sole unsettled pot (`Raffle.sol:L223-L233`). Zero-entry purchases and any purchase that would make the `uint128` global entry count overflow revert before this accounting (`Raffle.sol:L215-L220`).

```solidity
// packages/contracts/src/Raffle.sol:L296-L300
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;
emit RefundsEnabled(msg.sender, liability);
```

- Every successful `enableRefunds` branch converges on moving the entire unsettled pot into refund liability; there is no percentage calculation or allocation to another bucket in this transition (`Raffle.sol:L276-L300`). Fee allocation exists only in `_settleWinningTicket`, which first rejects every status other than `NftWon` and `CashWon`, so it cannot deduct from a `Refunding` raffle (`Raffle.sol:L533-L555`).

```solidity
// packages/contracts/src/Raffle.sol:L349-L371
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
    _requireStatus(Status.Refunding);
    uint256 ticketQuantity = ticketIds.length;
    if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
        revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
    }

    uint256 aggregateEntries = 0;
    for (uint256 index; index < ticketQuantity; ++index) {
        uint256 ticketId = ticketIds[index];
        address owner = ownerOf(ticketId);
        if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
        _burn(ticketId);
    }

    amount = aggregateEntries * ENTRY_PRICE;
    remainingRefundLiability -= amount;
    _transferQuote(msg.sender, amount);
    uint256 liabilityAfter = remainingRefundLiability;
    emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
}
```

- There is one successful-refund formula on every accepted batch: inclusive range lengths are summed, then multiplied directly by `ENTRY_PRICE`; no fee, division, or rounding operation intervenes (`Raffle.sol:L349-L371`). The public interface independently describes the same return value as represented entries times `ENTRY_PRICE` (`interfaces/IRaffle.sol:L340-L344`).
- A nonexistent or already-burned ticket fails inherited `ownerOf`, a foreign-owned ticket fails the explicit owner comparison, and each accepted ticket is burned before payment (`Raffle.sol:L357-L369`; `ERC721.sol:L61-L63`, `L303-L307`, `L426-L431`). Raffle's `_update` override permits the zero-address burn and delegates it to the base ledger (`Raffle.sol:L497-L502`). Thus duplicate IDs cannot produce a second successful refund.

```solidity
// packages/contracts/src/Raffle.sol:L560-L566
/// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

- The refund's computed `amount` is forwarded unchanged to the quote token (`Raffle.sol:L367-L369`, `L564-L566`). `SafeERC20.safeTransfer` either accepts a successful `transfer(to, value)` call or reverts; it does not substitute a lower value (`SafeERC20.sol:L30-L37`, `L176-L199`). This settles the local enforcement under the specification's canonical, fee-free quote-token trust boundary.

```solidity
// packages/contracts/src/Raffle.sol:L395-L406
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();

    address recipient = sponsorRecipient;
    prizeClaimed = true;
    prizeToken.transferFrom(address(this), recipient, prizeTokenId);
    if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
    emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
}
```

- `Refunding` expressly enables the permissionless, one-time path that transfers the configured prize to the fixed sponsor recipient and requires the prize contract to report that recipient as owner before the call can complete (`Raffle.sol:L395-L406`). The factory initially escrows that exact configured token and verifies both clone ownership and `Active` status (`RaffleFactory.sol:L127-L134`).

---

**Paths walked:**

- Construction and cloning: the factory fixes the quote token, deploys one `Raffle` implementation, and clones that fixed target; neither constructor nor initializer accepts an entry-price parameter (`RaffleFactory.sol:L65-L91`, `L97-L120`; `Raffle.sol:L43-L58`, `L155-L165`; `Clones.sol:L32-L62`). ✓
- Purchase path: `buyEntries` rejects zero or overflowing entry counts, collects `entryCount * ENTRY_PRICE`, creates `[oldTotal + 1, oldTotal + entryCount]`, and adds the same gross amount to `unsettledPot` (`Raffle.sol:L209-L235`). ✓
- Empty `Active` refund activation: only the sponsor may activate before sale end; because `totalEntries == 0`, there are no entry claims, and the common transition moves the zero unsettled pot without creating a deduction (`Raffle.sol:L279-L284`, `L296-L300`). ✓ (vacuous for per-entry payment)
- Sold `Active` refund activation: after the draw-request deadline, the branch reaches the common transition that moves all of `unsettledPot` into `remainingRefundLiability` (`Raffle.sol:L285-L300`). ✓
- Expired `Drawing` refund activation: at or after the callback deadline, the branch reaches that same full-pot transition (`Raffle.sol:L289-L300`). ✓
- Fee-settlement branch: `_settleWinningTicket` is reachable only for `NftWon` or `CashWon`, not `Refunding`; its 5% and 80% calculations therefore cannot touch refund liability (`Raffle.sol:L533-L555`). ✓
- One-ticket and multi-ticket claims: every successful loop iteration proves current ownership, sums the complete inclusive range, and burns the ticket; the single post-loop calculation pays the aggregate at exactly `ENTRY_PRICE` (`Raffle.sol:L349-L371`). ✓
- Duplicate, nonexistent, burned, or foreign-owned ticket: inherited existence checks or the explicit ownership check revert rather than paying a reduced amount (`Raffle.sol:L357-L364`; `ERC721.sol:L61-L63`, `L303-L307`, `L426-L431`). ✓
- Quote-token delivery: `_transferQuote` receives the already-computed amount unchanged and invokes `safeTransfer`; a rejected token call reverts rather than converting the claim into a smaller payment (`Raffle.sol:L367-L369`, `L564-L566`; `SafeERC20.sol:L30-L37`, `L176-L199`). ✓ under the quoted canonical-token trust boundary.
- Prize return: after either refund activation path sets `Refunding`, `releaseSponsorPrize` transfers the configured NFT to `sponsorRecipient`, verifies reported ownership, and permits no second completed release (`Raffle.sol:L296-L300`, `L395-L406`). ✓
- Modifiers and base contract: `enableRefunds`, `refundTickets`, and `releaseSponsorPrize` all use `nonReentrant` (`Raffle.sol:L276`, `L349`, `L395`); the inherited modifier enters before the body and exits only after it (`ReentrancyGuard.sol:L69-L72`, `L94-L105`). No reentrant guarded branch bypasses the refund formula or prize-release gate. ✓

---

**Searched:**

- Scope enumeration and full-file review → all five production files and all 31 paths in `dependency-hashes.json`; SHA-256 check of the 31 dependency files returned `checked=31 mismatches=0`.
- `refund` across the 36 scoped files → 61 hits in 5 files; implementation hits resolve to the `enableRefunds` transition and `refundTickets` claim path in `Raffle.sol`. Vocabulary variants `reimburse`, `rebate`, and `repay` → 0 hits each.
- `ENTRY_PRICE` → 10 hits in 3 files; `grossAmount` → 6 hits in 2 files. The behavior-bearing hits are the constant (`RaffleConstants.sol:L20-L21`), purchase multiplication (`Raffle.sol:L223-L224`), and refund multiplication (`Raffle.sol:L367`).
- `remainingRefundLiability` → 10 hits in 2 files; `unsettledPot` → 8 hits in 2 files. Production writes are purchase accumulation (`Raffle.sol:L233`), full-pot refund transition (`L296-L298`), refund decrement (`L368`), and terminal settlement consumption (`L539-L555`).
- `refundTickets\s*\(` → exactly 2 hits: the interface declaration (`IRaffle.sol:L344`) and the external implementation (`Raffle.sol:L349`); no in-scope wrapper or alternate refund entrypoint.
- `enableRefunds\s*\(` → exactly 2 hits: the interface declaration (`IRaffle.sol:L324`) and the external implementation (`Raffle.sol:L276`). `status\s*=\s*Status\.Refunding` → 2 hits: the locked implementation constructor (`Raffle.sol:L165`) and the runtime refund transition (`L299`).
- `_transferQuote\s*\(` → 5 hits: four calls and the private helper. The refund call is `Raffle.sol:L369`; the helper is `L564-L566`.
- `PROTOCOL_FEE_BPS|CASH_WINNER_BPS|mulDiv\s*\(` → 7 hits. The only raffle percentage calculations are in `_settleWinningTicket` (`Raffle.sol:L540`, `L546`), whose status gate excludes `Refunding` (`L535-L536`).
- Deduction vocabulary: `deduct` → 1 hit, only generic ERC-20 allowance documentation (`IERC20.sol:L69-L72`); `haircut`, `penalt`, `withhold`, and `discount` → 0 hits. `fee` → 69 hits in 7 files, with refund-relevant fee arithmetic confined to the excluded settlement path above.
- `_burn\s*\(` → 3 hits: winner redemption, refunding, and the inherited base implementation (`Raffle.sol:L325`, `L364`; `ERC721.sol:L303`). `ticketRange\s*\(` → 4 hits: interface, refund use, accessor, and winner-proof use (`IRaffle.sol:L373`; `Raffle.sol:L362`, `L451`, `L580`).
- `releaseSponsorPrize\s*\(` → exactly 2 hits: interface and implementation (`IRaffle.sol:L355`; `Raffle.sol:L395`). `prizeClaimed` → 6 hits in 2 files; all behavior-bearing writes/checks are the winner-delivery and sponsor-return one-time gates (`Raffle.sol:L330-L331`, `L400-L403`).
- Callers, modifiers, base contracts, constructors, type bounds, and all branches → read through `Raffle.sol`, `RaffleFactory.sol`, both interfaces, `RaffleConstants.sol`, `ERC721.sol`, `SafeERC20.sol`, `ReentrancyGuard.sol`, `Clones.sol`, and the remaining manifest dependencies; no second implementation of refund value or prize return was found.

---

**How the verdict was reached:** The code implements the exact economic equality required by "Refund outcome pays 100% per entry and returns prize.": each successfully refunded entry contributes one full `ENTRY_PRICE`, and `ENTRY_PRICE` is exactly 1,000,000 raw units (`Raffle.sol:L362-L369`; `RaffleConstants.sol:L20-L21`). This is not `partial` because the sold-`Active` and expired-`Drawing` activation branches both converge on the same full-pot liability, and every successful single- or multi-ticket claim uses the same multiplication (`Raffle.sol:L285-L300`, `L349-L371`). It is not `contradicted` because percentage fees are confined to terminal winner settlement and are status-incompatible with refunding (`Raffle.sol:L533-L555`). It is not merely `absent` or name-based evidence: the amount-producing arithmetic, liability writers, transfer helper, inherited burn behavior, guard modifier, constructors, and external entrypoints were read. The prize half also has a concrete `Refunding`-gated transfer-and-verification path (`Raffle.sol:L395-L406`). The implementation pays exactly the specified value, rather than a stricter value, so `stronger-than-spec` does not apply.

---

**Open questions:**

- None within the supplied specification and source scope. The concrete deployed quote-token implementation is not present, but the specification expressly makes the canonical quote token trusted; locally, the full amount is passed unchanged and any rejected transfer reverts (`DESIGN.md:L2`; `Raffle.sol:L564-L566`; `SafeERC20.sol:L176-L199`).
