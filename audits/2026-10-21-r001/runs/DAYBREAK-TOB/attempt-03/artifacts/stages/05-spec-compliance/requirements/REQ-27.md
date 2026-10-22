## REQ-27 — Aggregate protocol-fee floor and lossless remainder

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — `DESIGN.md:L2, sentence 8`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** “Rounding is floor on aggregate protocol fee; remainder must be allocated without loss.” Concretely, the protocol fee must be calculated once from the aggregate gross quote-token pot, any fractional quotient must be rounded toward the lower whole raw-token unit, and the post-rounding residual must remain in an allocated liability rather than disappear from accounting.

---

**Where enforcement lives:**

Each purchase contributes its entire gross amount to one accumulated pot; the `uint128` entry-total guard is applied before that amount is recorded:

```solidity
// target/packages/contracts/src/Raffle.sol:L219-L233
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
```

The rate and denominator are compile-time constants, and the entry price is stated in raw six-decimal quote-token units:

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21
/// @notice Denominator used for every global protocol basis-point rate.
uint256 internal constant BPS = 10_000;

/// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
uint256 internal constant PROTOCOL_FEE_BPS = 500;

/// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
uint256 internal constant CASH_WINNER_BPS = 8000;

/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;
```

The private settlement routine reads the accumulated pot once, computes the protocol fee before branching, and makes the sponsor allocation the exact subtraction remainder in both terminal result branches:

```solidity
// target/packages/contracts/src/Raffle.sol:L533-L557
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

    emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
}
```

The called three-argument OpenZeppelin routine is not merely suggestively named: its implementation specifies floor division, forms the full 512-bit product, and in the non-overflow branch returns integer division directly. In the 512-bit branch it subtracts `mulmod`'s remainder before completing the exact division (`Math.sol:L227-L275`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L216
/**
 * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
 * denominator == 0.
 */
function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
    unchecked {
        (uint256 high, uint256 low) = mul512(x, y);

        // Handle non-overflow cases, 256 by 256 division.
        if (high == 0) {
            // Solidity will revert if denominator == 0, unlike the div opcode on its own.
            // The surrounding unchecked block does not change this fact.
            // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
            return low / denominator;
        }
```

After settlement, the accounting view includes every allocated quote-token bucket, and the protocol and sponsor release paths consume and transfer the complete respective bucket:

```solidity
// target/packages/contracts/src/Raffle.sol:L375-L391
function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
    amount = sponsorProceeds;
    if (amount == 0) revert NoSponsorProceeds();
    sponsorProceeds = 0;
    address recipient = sponsorRecipient;
    _transferQuote(recipient, amount);
    emit SponsorProceedsReleased(msg.sender, recipient, amount);
}

function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
    amount = protocolFees;
    if (amount == 0) revert NoProtocolFees();
    protocolFees = 0;
    address treasury = protocolTreasury;
    _transferQuote(treasury, amount);
    emit ProtocolFeesReleased(msg.sender, treasury, amount);
}

// target/packages/contracts/src/Raffle.sol:L468-L470
function accountedQuoteBalance() public view override returns (uint256 amount) {
    amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
}
```

- For `NftWon`, `sponsorAmount + protocolFee = (grossPot - protocolFee) + protocolFee = grossPot` (`Raffle.sol:L539-L555`).
- For `CashWon`, `cashAmount + sponsorAmount + protocolFee = cashAmount + (grossPot - protocolFee - cashAmount) + protocolFee = grossPot` (`Raffle.sol:L539-L555`).
- The fixed rates total at most 8,500 of 10,000 basis points, so the cash branch's checked subtractions cannot underflow from the configured shares (`RaffleConstants.sol:L11-L18`; `Raffle.sol:L546-L547`).
- Under the current fixed entry price and 5% rate, every reachable gross pot is a multiple of 1,000,000 raw units and its protocol fee is a multiple of 50,000 raw units (`Raffle.sol:L223-L233`; `RaffleConstants.sol:L14-L21`). Fractional protocol fees are therefore unreachable with the present constants, but the selected `Math.mulDiv` overload still enforces floor semantics for any non-integral quotient (`Math.sol:L199-L216`, `L227-L275`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` records a single implementation in immutable `raffleImplementation` (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`); `createRaffle` → `Clones.clone(raffleImplementation)` → `initialize` makes each canonical raffle delegate to that fixed implementation (`RaffleFactory.sol:L97-L121`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`). Neither constructor nor initializer accepts a fee numerator, denominator, or rounding mode (`Raffle.sol:L155-L205`; `RaffleConstants.sol:L11-L18`). ✓
- Direct implementation path: the `Raffle` constructor locks the implementation as initialized and `Refunding` (`Raffle.sol:L155-L166`), while settlement accepts only `NftWon` or `CashWon` (`Raffle.sol:L533-L536`). It cannot expose an alternate live fee calculation. ✓
- Every successful `buyEntries` call → `grossAmount = entryCount * ENTRY_PRICE` → `unsettledPot += grossAmount`; there is no per-ticket or per-purchase protocol-fee rounding (`Raffle.sol:L209-L235`). ✓
- Accepted callback → `NftWon` when the reserve is met or `CashWon` otherwise (`Raffle.sol:L509-L523`). Those are the only two statuses accepted by `_settleWinningTicket`, and the shared aggregate fee calculation at `L539-L540` executes before their branch at `L543` (`Raffle.sol:L533-L547`). ✓
- `settleWinningTicket` → `_settleWinningTicket`: the public permissionless settlement entrypoint has no alternate arithmetic (`Raffle.sol:L303-L306`). ✓
- `redeemWinningTicket` with incomplete settlement → `_settleWinningTicket`; with completed settlement it checks the recorded ticket and does not recompute fees (`Raffle.sol:L308-L318`). ✓
- `NftWon` branch → sponsor receives `grossPot - protocolFee`; the entire aggregate pot is assigned between sponsor and protocol buckets (`Raffle.sol:L539-L555`). ✓
- `CashWon` branch → winner receives floored 80%, sponsor receives `grossPot - protocolFee - cashAmount`; the entire aggregate pot is assigned among winner, sponsor, and protocol buckets (`Raffle.sol:L539-L555`). ✓
- `Refunding` branch does not assess a protocol fee: `enableRefunds` moves the complete `unsettledPot` into `remainingRefundLiability` and zeroes the former (`Raffle.sol:L275-L300`). It therefore introduces no fee-rounding remainder. ✓
- Repeated settlement is rejected before calculation, and both external callers are protected by the inherited `nonReentrant` modifier (`Raffle.sol:L303-L315`, `L533-L534`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L63-L73`, `L88-L105`). No reentrant or repeat branch performs a second fee calculation. ✓
- Settlement → `protocolFees` / `sponsorProceeds` / optional `winnerProceeds` → independent release functions; releases read the full stored bucket rather than calculating a new percentage (`Raffle.sol:L339-L342`, `L375-L391`, `L548-L555`). ✓

---

**Searched:**

- Scope inventory → exactly five production Solidity files and 31 files listed by `target/dependency-hashes.json`; all 31 dependency SHA-256 values matched the manifest. All 36 scoped files were included in vocabulary searches.
- `protocolFee|protocolFees|PROTOCOL_FEE_BPS` → 21 matched tokens across three files. The only quote-token protocol-fee calculation is `Raffle.sol:L540`; the only `protocolFees` writes are settlement at `L555` and claim clearing at `L388`.
- `grossPot|unsettledPot|grossSales|aggregate` → 21 matched tokens across `Raffle.sol` and `IRaffle.sol`. Writes to `unsettledPot` are exactly purchase accumulation at `Raffle.sol:L233`, refund transition clearing at `L297`, and settlement clearing at `L553`.
- `Math.mulDiv|BPS|basis point|percent` → the production code has two `Math.mulDiv` calls: the common protocol-fee calculation at `Raffle.sol:L540` and the cash-winner calculation at `L546`; the corresponding rates and denominator are only in `RaffleConstants.sol:L11-L18`.
- `_settleWinningTicket(` → three hits, all in `Raffle.sol`: direct caller `L305`, lazy-redemption caller `L315`, and the private implementation `L533`. No wrapper, derived production contract, or alternate settlement implementation was found.
- `releaseProtocolFees(` → two hits: interface declaration `IRaffle.sol:L352` and sole implementation `Raffle.sol:L385-L391`.
- `commission|platform|house|cut` → 0 hits in the five production files.
- `remainder|residual|dust|leftover` → two production hits, both identifying sponsor allocation as the remainder (`IRaffle.sol:L121`; `Raffle.sol:L530`); no separate dust or residual bucket exists.
- `round|rounded|rounding|floor|truncate` → four production hits, all consistent with down-rounding (`RaffleConstants.sol:L7`; `IRaffle.sol:L120`, `L328`; `Raffle.sol:L529`). The dependency implementation was then read at `Math.sol:L199-L275` rather than relying on those names or comments alone.
- Base contracts, modifiers, constructors, clone library, state writers, both callers, both terminal branches, refund branch, and all release paths → no bypass or second protocol-fee formula found.

---

**How the verdict was reached:** `implemented` applies because enforcement is present and was followed through the arithmetic callee. `Math.mulDiv(grossPot, 500, 10_000)` computes the floor of one calculation over the accumulated `unsettledPot` (`Raffle.sol:L539-L540`; `RaffleConstants.sol:L11-L15`; `Math.sol:L199-L275`). It is not `partial`: both fee-bearing outcomes execute that same calculation before branching, both callable settlement routes converge on the same private function, and both outcome branches define sponsor proceeds by exact subtraction from `grossPot` (`Raffle.sol:L303-L318`, `L533-L555`). It is not `contradicted`: no ceiling, per-purchase fee sum, or discarded residual appears in the scoped writers and callers, while each branch's stored liabilities algebraically sum to the original pot (`Raffle.sol:L539-L555`). The separate floor applied to the cash-winner share does not change this verdict; the sponsor subtraction absorbs its residual as well (`Raffle.sol:L546-L548`). This is the exact requested behavior, not an additional restriction, so `stronger-than-spec` does not apply.

---

**Open questions:**

- None for this requirement.
