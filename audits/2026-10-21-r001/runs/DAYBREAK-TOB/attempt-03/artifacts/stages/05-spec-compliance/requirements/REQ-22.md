## REQ-22 — Reserve-missed sponsor allocation

> "Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury."
> — DESIGN.md:L2, sentence 6

The applicable rounding rule is also stated verbatim:

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For every reachable reserve-missed outcome, the quote-token liabilities must allocate exactly 15% of the gross sale pot to the sponsor, while applying the quoted aggregate-fee floor and conserving the entire pot. In the implementation, a reserve miss is the `CashWon` side of the comparison between `totalEntries` and `reserveEntries` (`target/packages/contracts/src/Raffle.sol:L518-L523`). The sponsor's economic destination is the immutable-per-raffle `sponsorRecipient`: the factory supplies the creator as `sponsor` and the creator-selected address as `sponsorRecipient`, and initialization stores both (`target/packages/contracts/src/RaffleFactory.sol:L109-L120`; `target/packages/contracts/src/Raffle.sol:L176-L205`).

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18
uint256 internal constant BPS = 10_000;
uint256 internal constant PROTOCOL_FEE_BPS = 500;
uint256 internal constant CASH_WINNER_BPS = 8000;
```

- The fixed rates are 5% for the treasury and 80% for the cash winner; their complement is 15% (`target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`). These are compile-time library constants, not storage values (`target/packages/contracts/src/libraries/RaffleConstants.sol:L10-L18`).

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21
uint256 internal constant ENTRY_PRICE = 1_000_000;

// target/packages/contracts/src/Raffle.sol:L215-L224, L230-L233
_requireStatus(Status.Active);
if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
if (recipient == address(0)) revert InvalidRecipient();
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}

uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
// ...
totalEntries = lastEntry;
// ...
unsettledPot += grossAmount;
```

- Every sale adds `entryCount * 1_000_000` to `unsettledPot`, so every reachable gross pot is a multiple of both 1,000,000 and the 10,000-basis-point denominator (`target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`; `target/packages/contracts/src/Raffle.sol:L215-L224`, `L226-L233`). The `uint128` entry-count types and the explicit cumulative bound prevent `totalEntries` from overflowing (`target/packages/contracts/src/Raffle.sol:L79-L85`, `L209-L220`). Consequently, the largest reachable accounted gross pot is below `2^128 * 1_000_000`, hence below `2^148` and safely within `uint256` for the percentage calculations (`target/packages/contracts/src/Raffle.sol:L79-L91`, `L209-L233`).

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L523
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }

    uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
    winningEntry = resolvedEntry;
    resolvedAt = uint64(block.timestamp);
    status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

    emit RaffleResolved(requestId, resolvedEntry, status);
}
```

- An accepted callback selects `CashWon` exactly when `totalEntries < reserveEntries`; the other side is the reserve-met `NftWon` outcome (`target/packages/contracts/src/Raffle.sol:L509-L523`). The inherited callback gateway admits only the configured wrapper before calling this override (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).

```solidity
// target/packages/contracts/src/Raffle.sol:L533-L555
function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
    if (settlementComplete) revert SettlementAlreadyComplete();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    _requireWinningTicket(ticketId);
    uint256 grossPot = unsettledPot;
    uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
    uint256 sponsorAmount;

    if (result == Status.NftWon) {
        sponsorAmount = grossPot - protocolFee;
    } else {
        cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
        sponsorAmount = grossPot - protocolFee - cashAmount;
        winnerProceeds = cashAmount;
    }

    settlementComplete = true;
    winningTicketId = ticketId;
    unsettledPot = 0;
    sponsorProceeds = sponsorAmount;
    protocolFees = protocolFee;
}
```

- On the `CashWon` branch, the helper computes `protocolFee = floor(grossPot * 500 / 10_000)` and `cashAmount = floor(grossPot * 8000 / 10_000)`, then assigns every unit left to `sponsorAmount` (`target/packages/contracts/src/Raffle.sol:L533-L555`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`). It stores the three liabilities and clears the unallocated pot in the same call (`target/packages/contracts/src/Raffle.sol:L548-L555`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L200-L215
/**
 * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
 * denominator == 0.
 */
function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
    unchecked {
        (uint256 high, uint256 low) = mul512(x, y);
        if (high == 0) {
            return low / denominator;
        }
```

- The three-argument `Math.mulDiv` used by settlement is the floor variant (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L200-L215`). Its full-precision path likewise produces the exact quotient after subtracting the remainder (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L218-L277`); for the reachable bound above, multiplication by 8,000 remains below `2^256`, so the direct division path at `L210-L215` is sufficient.

```solidity
// target/packages/contracts/src/Raffle.sol:L375-L381
function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
    amount = sponsorProceeds;
    if (amount == 0) revert NoSponsorProceeds();
    sponsorProceeds = 0;
    address recipient = sponsorRecipient;
    _transferQuote(recipient, amount);
    emit SponsorProceedsReleased(msg.sender, recipient, amount);
}

// target/packages/contracts/src/Raffle.sol:L564-L567
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

- The release path passes the complete stored sponsor bucket to the configured sponsor recipient; it does not recompute, split, or redirect the amount (`target/packages/contracts/src/Raffle.sol:L375-L381`, `L564-L567`). `SafeERC20.safeTransfer` rejects a false-returning or failed token call, and its callee accepts only a true return or an empty return from an address with code (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37`, `L176-L200`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle`: the factory fixes the quote token, wrapper, treasury, and implementation once (`target/packages/contracts/src/RaffleFactory.sol:L58-L92`); `Raffle` fixes the factory and quote token in its constructor and locks the implementation instance (`target/packages/contracts/src/Raffle.sol:L151-L166`).
- `RaffleFactory.createRaffle` → `Clones.clone` → `Raffle.initialize`: creation delegates each clone to the fixed `raffleImplementation`, supplies the sponsor, sponsor recipient, treasury, reserve, and end time, and then initializes once (`target/packages/contracts/src/RaffleFactory.sol:L97-L125`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`; `target/packages/contracts/src/Raffle.sol:L175-L205`). The factory rejects a zero reserve (`target/packages/contracts/src/RaffleFactory.sol:L171-L179`).
- `Raffle.buyEntries`: every successful Active-state purchase transfers and records `entryCount * ENTRY_PRICE`, then increases `unsettledPot` by that same nominal gross amount (`target/packages/contracts/src/Raffle.sol:L209-L236`). The supplied interface expressly defines the configured quote token as standard, non-rebasing, and fee-free (`target/packages/contracts/src/interfaces/IRaffle.sol:L8-L15`); the factory enforces code presence and six decimals while assigning canonical identity to deployment configuration (`target/packages/contracts/src/RaffleFactory.sol:L58-L78`).
- `Raffle.requestDraw` → inherited wrapper request → `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: requesting changes `Active` to `Drawing` (`target/packages/contracts/src/Raffle.sol:L240-L260`); the authenticated accepted callback changes `Drawing` to `CashWon` only for `totalEntries < reserveEntries` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`). Purchases cannot occur in `Drawing` or `CashWon` because `buyEntries` requires `Active` (`target/packages/contracts/src/Raffle.sol:L209-L216`).
- `Raffle.enableRefunds`: the only branches are `Active` and `Drawing`, and success changes the status to `Refunding`; it cannot drain `unsettledPot` after the raffle is already `CashWon` (`target/packages/contracts/src/Raffle.sol:L276-L300`). Thus the separate refund outcome does not bypass the reserve-missed settlement formula.
- `Raffle.settleWinningTicket` → `_settleWinningTicket`: the direct permissionless settlement entrypoint calls the helper once (`target/packages/contracts/src/Raffle.sol:L303-L306`, `L533-L558`).
- `Raffle.redeemWinningTicket` → `_settleWinningTicket`: redemption calls the same helper when settlement has not yet happened; after settlement it instead requires the already-recorded winning ticket (`target/packages/contracts/src/Raffle.sol:L309-L318`). These are the only two callers of the private helper in the five production files (`target/packages/contracts/src/Raffle.sol:L304-L315`, `L533-L558`).
- `_settleWinningTicket`, `NftWon` branch: the reserve-met branch gives the sponsor the 95% remainder after the 5% fee (`target/packages/contracts/src/Raffle.sol:L543-L545`). It is not a reserve-missed path.
- `_settleWinningTicket`, `CashWon` branch: the reserve-missed branch computes the 80% winner bucket and gives the sponsor the remainder after the 5% fee (`target/packages/contracts/src/Raffle.sol:L545-L555`). A wrong ticket reverts before any liability write (`target/packages/contracts/src/Raffle.sol:L538-L540`, `L577-L585`), and a second settlement reverts before recomputation (`target/packages/contracts/src/Raffle.sol:L533-L536`).
- Settlement and release modifiers: both external settlement routes and `releaseSponsorProceeds` are `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L303-L309`, `L375-L381`). The inherited modifier sets the shared guard before the body and restores it afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`); it contains no branch that changes the allocation arithmetic.
- `Raffle.releaseSponsorProceeds` → `_transferQuote` → `SafeERC20.safeTransfer`: the full stored amount is cleared and delivered to the fixed sponsor recipient (`target/packages/contracts/src/Raffle.sol:L375-L381`, `L560-L567`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37`, `L176-L200`).

---

**Searched:**

- Full corpus coverage → read all five production Solidity files and all 31 dependency files named by `target/dependency-hashes.json:L2-L32`; independent SHA-256 verification returned `OK` for all 31 declared dependencies.
- `sponsor|beneficiary|promoter|host` across the five production files → 86 matching lines. The allocation and release are concentrated at `Raffle.sol:L375-L381` and `L533-L557`; the alternate vocabulary produced no separate beneficiary/promoter/host payout path.
- `reserve|threshold|minimum|miss(ed)?|CashWon|NftWon` across the five production files → 44 matching lines. The operative result branch is `Raffle.sol:L509-L523`; creation and initialization carry the reserve at `RaffleFactory.sol:L109-L120` and `Raffle.sol:L197-L205`.
- `gross|proceeds|pot|sales|collected|revenue` across the five production files → 55 matching lines. The relevant gross origin/write/read sites are `Raffle.sol:L223-L233`, `L473-L475`, and `L539-L555`.
- `BPS|basis|percent|rate|fee|treasury|protocol` across the five production files → 113 matching lines. A focused `CASH_WINNER_BPS|PROTOCOL_FEE_BPS|\bBPS\b|Math\.mulDiv` search → exactly 6 matching lines: `RaffleConstants.sol:L7`, `L12`, `L15`, `L18` and `Raffle.sol:L540`, `L546`.
- `1500|1_500|15%` across the five production files → 0 matching lines. The 15% share is enforced indirectly as `10_000 - 500 - 8_000 = 1_500` basis points through the remainder expression at `Raffle.sol:L547`.
- `_settleWinningTicket` across the five production files → exactly 3 hits: callers at `Raffle.sol:L305` and `L315`, and the private definition at `L533`. No third settlement route exists in scope.
- `sponsorProceeds\s*=|sponsorAmount\s*=` across the five production files → exactly 4 hits: release clears `sponsorProceeds` at `Raffle.sol:L378`; the two result formulas are at `L544` and `L547`; settlement stores the selected formula at `L554`.
- `unsettledPot\s*(\+=|=)|grossAmount|grossPot|grossSales` across the five production files → 15 matching lines. The only `unsettledPot` value writes found are purchase accumulation at `Raffle.sol:L233`, refund transition clearing at `L297`, and settlement clearing at `L553`; the settlement reads it as `grossPot` at `L539`.
- `function mulDiv|Calculates floor` in the pinned `Math.sol` dependency → 4 matching lines: the floor contract at `Math.sol:L200`, the used three-argument definition at `L206`, the unused explicit-rounding overload at `L282`, and an unrelated `mulShr` comment at `L287`. The settlement call selects the three-argument floor definition (`Raffle.sol:L540`, `L546`; `Math.sol:L200-L277`).
- `releaseSponsorProceeds|_transferQuote\(` across the five production files → 7 matching lines: the sponsor release declaration/call is at `Raffle.sol:L375-L380`, while the other `_transferQuote` calls are winner and refund/protocol paths at `L342`, `L369`, and `L390`; the single helper definition is at `L564`.
- Economic mutator vocabulary `function (set[A-Z]|upgrade|admin)|setSponsorRecipient|setSponsorProceeds|setProtocolFee|setCashWinner` across the five production files → 0 hits. The only sponsor-destination storage writes are initialization at `Raffle.sol:L197-L198`; the factory validates that selected destination at `RaffleFactory.sol:L154-L169`.

---

**How the verdict was reached:** Let `G` be the `grossPot` read from `unsettledPot` at settlement (`target/packages/contracts/src/Raffle.sol:L539`). Every reachable `G` is `n * 1_000_000` for an integer number of sold entries (`target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21`; `target/packages/contracts/src/Raffle.sol:L218-L233`). Because 10,000 divides 1,000,000, both percentage products divide without a fractional raw unit on every reachable path:

- `protocolFee = G * 500 / 10_000 = 0.05G` (`target/packages/contracts/src/Raffle.sol:L540`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L15`);
- `cashAmount = G * 8_000 / 10_000 = 0.80G` (`target/packages/contracts/src/Raffle.sol:L546`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`);
- `sponsorAmount = G - protocolFee - cashAmount = 0.15G` (`target/packages/contracts/src/Raffle.sol:L547`).

The aggregate protocol fee nevertheless uses the required floor operation because the selected three-argument `Math.mulDiv` is explicitly floor division (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L200-L215`). The code also invokes floor `mulDiv` for the winner, but this is neither a contradiction nor a stronger reachable constraint: the recorded gross-pot divisibility makes that floor exact for every possible sale pot (`target/packages/contracts/src/Raffle.sol:L223-L233`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`). The remainder assignment makes the three stored buckets sum identically to `G`, so no raw unit is lost (`target/packages/contracts/src/Raffle.sol:L546-L555`).

This is `implemented`, not `partial`, because both successful settlement entrypoints converge on the same private helper, the helper's complete `CashWon` branch uses the formula above, and the only alternative result branch is expressly `NftWon` (`target/packages/contracts/src/Raffle.sol:L303-L318`, `L533-L558`). It is not merely nominal accounting: the independent release function forwards the entire stored sponsor bucket to the sponsor-selected immutable recipient (`target/packages/contracts/src/RaffleFactory.sol:L109-L120`; `target/packages/contracts/src/Raffle.sol:L197-L205`, `L375-L381`).

---

**Open questions:**

- None for the allocation formula. Exact token balance movement rests on the source-declared standard, non-rebasing, fee-free quote-token assumption (`target/packages/contracts/src/interfaces/IRaffle.sol:L8-L15`). That is within the document's stated trust boundary: "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`).
