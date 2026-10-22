## REQ-26 — Aggregate protocol-fee flooring and lossless remainder

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Let `G` be the complete applicable sale pot. The protocol fee must be computed once as `floor(G × protocol rate / denominator)`, rather than by calculating and summing separately rounded fees for purchases, entries, or tickets. The allocation made from `G` must then conserve every raw quote-token unit: after the protocol and any winner share are assigned, the arithmetic remainder must be assigned to another liability rather than left as unallocated dust.

---

**Where enforcement lives:**

Purchases add their full gross amount to one pot; no fee is taken during a purchase:

```solidity
// packages/contracts/src/Raffle.sol:L218-L224
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}

uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

```solidity
// packages/contracts/src/Raffle.sol:L230-L233
totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```

- `buyEntries` accepts a `uint128 entryCount` (`packages/contracts/src/Raffle.sol:L209-L213`), rejects a sum above `type(uint128).max` (`packages/contracts/src/Raffle.sol:L218-L220`), multiplies the accepted count by the fixed `1_000_000` raw-unit entry price (`packages/contracts/src/Raffle.sol:L223-L224`; `packages/contracts/src/libraries/RaffleConstants.sol:L20-L21`), and accumulates that whole gross amount in `unsettledPot` (`packages/contracts/src/Raffle.sol:L230-L233`). Thus the tracked aggregate is built before any percentage calculation. The maximum tracked sale amount is at most `type(uint128).max × 1_000_000`, which fits in `uint256`; neither the multiplication nor the corresponding aggregate addition can wrap on a returning purchase (`packages/contracts/src/Raffle.sol:L218-L233`).

The only terminal allocation helper reads that aggregate once, computes the protocol fee once, and assigns the subtraction remainder in both result branches:

```solidity
// packages/contracts/src/Raffle.sol:L533-L555
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
```

- The fixed denominator and rates are `BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, and `CASH_WINNER_BPS = 8000` (`packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`). Therefore `protocolFee = floor(G × 500 / 10_000)` at `packages/contracts/src/Raffle.sol:L539-L540`.
- In `NftWon`, the recorded liabilities are `protocolFee` and `G - protocolFee`, whose sum is exactly `G` (`packages/contracts/src/Raffle.sol:L543-L545`, `L553-L555`).
- In `CashWon`, if `C = floor(G × 8000 / 10_000)`, the recorded liabilities are `C`, `protocolFee`, and `G - protocolFee - C`; their sum is exactly `G` (`packages/contracts/src/Raffle.sol:L545-L555`). Since the fixed rates total 8,500 basis points, both checked subtractions are defined for every `G`, and the sponsor bucket receives all integer-division remainder (`packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`; `packages/contracts/src/Raffle.sol:L546-L555`).

The arithmetic callee is the three-argument, floor-rounding overload. Its complete implementation was read through the return at L277: it uses direct integer division when the product fits, otherwise subtracts the modular remainder to make the 512-bit division exact, and never adds a rounding increment (`packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L277`). The distinct four-argument overload is the one that can add one for an upward rounding mode, and it is not called here (`packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L279-L283`; `packages/contracts/src/Raffle.sol:L540`, `L546`).

```solidity
// packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215
/**
 * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
 * denominator == 0.
 */
function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
    unchecked {
        (uint256 high, uint256 low) = mul512(x, y);

        // Handle non-overflow cases, 256 by 256 division.
        if (high == 0) {
            return low / denominator;
```

The accounting view includes every possible current sale-pot successor bucket, so the settlement writes remain fully represented after `unsettledPot` is cleared:

```solidity
// packages/contracts/src/Raffle.sol:L468-L470
function accountedQuoteBalance() public view override returns (uint256 amount) {
    amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
}
```

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` fixes one implementation address in immutable `raffleImplementation`; `createRaffle` → `Clones.clone(raffleImplementation)` then initializes the fresh clone (`packages/contracts/src/RaffleFactory.sol:L65-L92`, `L97-L121`). The implementation constructor fixes the factory and quote token and locks its own storage, while clone initialization supplies no fee or rate parameter (`packages/contracts/src/Raffle.sol:L151-L166`, `L176-L205`). The fee denominator and rates are compile-time library constants (`packages/contracts/src/libraries/RaffleConstants.sol:L10-L21`).
- `buyEntries` → `unsettledPot`: every returning purchase passes the status, time, nonzero-count, and `uint128` aggregate bound, transfers `entryCount × ENTRY_PRICE`, and adds that full amount to the shared pot (`packages/contracts/src/Raffle.sol:L209-L236`). There is no purchase, entry, or ticket fee calculation on this path.
- `settleWinningTicket` → `_settleWinningTicket`: the public route is `nonReentrant` and delegates directly to the private helper (`packages/contracts/src/Raffle.sol:L303-L306`). The helper rejects a second allocation before reading the pot and marks settlement complete in the same call (`packages/contracts/src/Raffle.sol:L533-L555`).
- `redeemWinningTicket` → `_settleWinningTicket`: the combined redemption route invokes the same helper when unsettled; after settlement it accepts only the recorded winning ticket and does not recompute a fee (`packages/contracts/src/Raffle.sol:L309-L318`). Thus direct settlement and settlement-during-redemption cannot diverge.
- `_settleWinningTicket`, `NftWon` branch: the aggregate fee is floored once and the sponsor receives `G - fee` (`packages/contracts/src/Raffle.sol:L539-L545`, `L551-L555`). ✓
- `_settleWinningTicket`, `CashWon` branch: the same aggregate fee is used; the cash share is floored once and the sponsor receives `G - fee - cash` (`packages/contracts/src/Raffle.sol:L539-L555`). ✓
- `enableRefunds` branch: no protocol fee is applicable or computed. It atomically moves the entire `unsettledPot` into `remainingRefundLiability` (`packages/contracts/src/Raffle.sol:L276-L300`); each refund aggregates the submitted tickets' entries, pays `aggregateEntries × ENTRY_PRICE`, and subtracts exactly that amount from the liability (`packages/contracts/src/Raffle.sol:L349-L371`). ✓
- Liability release paths: winner redemption clears and transfers the whole `winnerProceeds` bucket (`packages/contracts/src/Raffle.sol:L338-L343`); sponsor and protocol release independently clear and transfer their whole respective buckets (`packages/contracts/src/Raffle.sol:L374-L391`); `_transferQuote` forwards the exact supplied amount through `SafeERC20` (`packages/contracts/src/Raffle.sol:L560-L567`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L47`, `L176-L199`). No allocation bucket is partially released.
- Modifier/base-contract path: both external settlement routes carry `nonReentrant` (`packages/contracts/src/Raffle.sol:L303-L315`). The inherited modifier enters before and exits after the body and rejects the entered state (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). `_settleWinningTicket` is private and performs only local range reads before completing all allocation writes (`packages/contracts/src/Raffle.sol:L533-L555`, `L577-L585`); the dependency sweep found no base-contract fee accounting.

---

**Searched:**

- Scope coverage → read all five production files under `packages/contracts/src` and all 31 files named by `dependency-hashes.json` in full. Recomputed SHA-256 for every declared dependency: `31` checked, `0` mismatches.
- `round|remainder|dust|loss|residu|leftover` in the five production files → `6` hits: `Raffle.sol:L529-L530`, `IRaffle.sol:L120-L121`, `IRaffle.sol:L328`, and `RaffleConstants.sol:L7`; no separate rounding implementation was hidden behind another name.
- `Math.mulDiv(` in production → `2` hits: aggregate protocol fee at `Raffle.sol:L540` and aggregate cash-winner share at `Raffle.sol:L546`.
- `_settleWinningTicket(` in production → `3` hits exactly: direct-settlement call at `Raffle.sol:L305`, redemption call at `Raffle.sol:L315`, and the private definition at `Raffle.sol:L533`.
- `protocolFees\s*(\+=|-=|=)` → `2` hits: claim-time clear at `Raffle.sol:L388` and settlement assignment at `Raffle.sol:L555`. `protocolFees\s*\+=|protocolFee\s*\+=` → `0` hits.
- `(entryCount|ticketId|ENTRY_PRICE)` combined on a line with `(PROTOCOL_FEE_BPS|protocolFee|protocolFees|Math.mulDiv)` in either order → `1` hit, the `WinningTicketSettled` event emission at `Raffle.sol:L557`; it performs no arithmetic. No per-entry or per-ticket fee computation was found.
- Liability-assignment sweep for `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, and `protocolFees` → `11` hits, all in `Raffle.sol`: gross accumulation at L233; refund transition at L297-L298; winner clear at L341; refund decrement at L368; sponsor clear at L378; protocol clear at L388; winner allocation at L548; settlement pot clear at L553; sponsor allocation at L554; protocol allocation at L555.
- `unsettledPot +=`, `uint256 grossPot = unsettledPot`, or `unsettledPot = 0` → `4` hits: `Raffle.sol:L233`, `L297`, `L539`, and `L553`. The only aggregate fee source is the shared pot read at L539.
- `protocol.?fee|sponsorProceeds|winnerProceeds|unsettledPot|PROTOCOL_FEE_BPS` over the 31 declared dependencies → `0` hits. `function mulDiv|enum Rounding|mulmod(x, y, denominator)` → `5` hits, all in `Math.sol:L13`, `L206`, `L231`, `L282-L283`; the complete `mulDiv` callee was read.
- `settlementComplete` in production → `5` hits: state declaration `Raffle.sol:L127`, redemption gate L314, repeat-settlement rejection L534, completion write L551, and interface getter `IRaffle.sol:L508`. No reset path exists in scope.
- Modifiers on the two settlement-capable external routes → `nonReentrant` on both `Raffle.sol:L304` and `L309`; the inherited modifier implementation was read at `ReentrancyGuard.sol:L69-L105`.

---

**How the verdict was reached:** The verdict is `implemented`, not `partial`, because every route that can allocate a protocol fee—standalone settlement and settlement performed during redemption—converges on the same private helper, and its only two economic result branches both use the one fee computed from `grossPot` (`packages/contracts/src/Raffle.sol:L303-L315`, `L533-L555`). The called three-argument `Math.mulDiv` returns the full-precision floor, not a rounded-up result (`packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L277`). The `NftWon` identity is `fee + (G - fee) = G`; the `CashWon` identity is `fee + cash + (G - fee - cash) = G`, with the subtraction remainder recorded as sponsor proceeds (`packages/contracts/src/Raffle.sol:L539-L555`). The refund alternative preserves the whole pot without assessing a fee (`packages/contracts/src/Raffle.sol:L276-L300`, `L349-L371`). Writer and vocabulary sweeps found neither incremental fee accumulation nor a separately rounded entry/ticket path. The reachable `G` is also a multiple of the fixed `1_000_000` entry price, so the 5% fee is integral for reachable sale pots; the aggregate formula nevertheless enforces floor semantics directly (`packages/contracts/src/Raffle.sol:L218-L233`; `packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`). This is the exact documented property, not an additional restriction, so `stronger-than-spec` does not apply.

---

**Open questions:**

- None.
