## REQ-28 — Aggregate fee flooring and lossless remainder

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The fee must be calculated once from the aggregate distributable
quote-token pot, using floor division. No raw unit omitted by that division may become unaccounted dust: after
settlement, the defined payout buckets must sum exactly to the full aggregate pot. The immediately preceding
outcome definitions are:

> "Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. Refund outcome pays 100% per entry and returns prize."
> — DESIGN.md:L2, sentences 5–7

Writing the aggregate recorded gross as G, the required accounting identities are therefore:

- NFT result: protocol fee F = floor(G × 500 / 10,000), sponsor = G − F, so F + sponsor = G.
- Cash result: protocol fee F = floor(G × 500 / 10,000), with winner and sponsor allocations together with F
  consuming G. Any indivisible raw units must land in a defined payout rather than a fourth, unclaimable bucket.
- Refund result: the entire unsettled pot must become refund liability; no protocol-fee rounding is applied.

---

**Where enforcement lives:**

The pot is built from every purchase before settlement. The entry-count guard bounds the lifetime aggregate,
each purchase computes its complete gross amount, and that amount is added to the single unsettled pot:

~~~solidity
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
~~~

The rates are immutable compile-time constants, including a 5% protocol rate, an 80% cash-winner rate, and the
10,000 basis-point denominator (target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21):

~~~solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21
uint256 internal constant BPS = 10_000;
uint256 internal constant PROTOCOL_FEE_BPS = 500;
uint256 internal constant CASH_WINNER_BPS = 8000;
uint256 internal constant ENTRY_PRICE = 1_000_000;
~~~

The called three-argument Math.mulDiv implementation explicitly specifies floor and, for the bounded raffle
inputs, executes ordinary integer division (target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L200-L215):

~~~solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L200-L215
/**
 * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
 * denominator == 0.
 *
 * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
 * Uniswap Labs also under MIT license.
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
~~~

The bound totalEntries ≤ type(uint128).max and ENTRY_PRICE = 1,000,000 make both percentage products smaller
than 2^161, so the quoted high == 0 branch covers every reachable fee and winner calculation
(Raffle.sol:L219-L233; RaffleConstants.sol:L11-L21). The result is therefore the floor of the aggregate product,
not a sum of per-ticket rounded fees.

The private settlement helper reads the aggregate unsettledPot once. Both result branches derive the sponsor
bucket by subtraction from that same gross pot, then replace the unsettled pot with the terminal buckets:

~~~solidity
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
~~~

This makes the branch identities exact:

- NftWon: protocolFees + sponsorProceeds = F + (G − F) = G (Raffle.sol:L539-L555).
- CashWon: winnerProceeds + sponsorProceeds + protocolFees =
  W + (G − F − W) + F = G (Raffle.sol:L539-L555).

The public accounting view includes every mutually exclusive current quote liability, so the post-settlement
bucket sum remains visible rather than being silently dropped:

~~~solidity
// target/packages/contracts/src/Raffle.sol:L468-L470
function accountedQuoteBalance() public view override returns (uint256 amount) {
    amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
}
~~~

The refund branch likewise moves the complete pot into refund liability, and ticket refunds consume exact
range length times the fixed entry price (target/packages/contracts/src/Raffle.sol:L296-L300, L356-L371):

~~~solidity
uint256 liability = unsettledPot;
unsettledPot = 0;
remainingRefundLiability = liability;
status = Status.Refunding;

// ...
aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
_burn(ticketId);
// ...
amount = aggregateEntries * ENTRY_PRICE;
remainingRefundLiability -= amount;
_transferQuote(msg.sender, amount);
~~~

Finally, the allocated winner, sponsor, and protocol buckets are each consumed in full before the corresponding
quote transfer (Raffle.sol:L339-L342, L375-L390). The shared helper calls SafeERC20
(Raffle.sol:L560-L566), whose safeTransfer wrapper reverts if its low-level operation is not accepted
(target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L37).
Thus a failed release reverts rather than clearing a bucket without payment.

---

**Paths walked:**

- buyEntries → grossAmount → unsettledPot: every successful positive purchase adds entryCount × ENTRY_PRICE to
  the one aggregate pot; the total-entry bound prevents an arithmetic domain larger than uint128 entries
  (Raffle.sol:L209-L235). ✓
- authenticated resolution → NftWon → settleWinningTicket → _settleWinningTicket: the external entrypoint is
  nonReentrant and has no alternative allocator; the helper assigns floor(5% of aggregate G) to protocolFees
  and every other raw unit to sponsorProceeds (Raffle.sol:L304-L305, L533-L555). ✓
- authenticated resolution → NftWon → redeemWinningTicket before separate settlement: redemption calls the same
  private helper when settlementComplete is false, so it reaches the identical allocation
  (Raffle.sol:L309-L318, L533-L555). ✓
- authenticated resolution → CashWon → either settlement entrypoint: the helper assigns floor(80% of G) to the
  winner, floor(5% of G) to protocol, and the exact subtraction remainder to sponsor
  (Raffle.sol:L304-L315, L533-L555). ✓
- redemption after prior settlement: the recorded winning ticket is checked and no allocation runs again
  (Raffle.sol:L314-L318); settlementComplete also rejects any second direct settlement
  (Raffle.sol:L533-L535, L551-L555). ✓
- winner cash claim: the complete winnerProceeds bucket is zeroed and transferred
  (Raffle.sol:L339-L342). Sponsor and treasury independently consume their complete buckets
  (Raffle.sol:L375-L391). ✓
- Active/Drawing → Refunding: enableRefunds copies the entire unsettledPot to remainingRefundLiability without a
  fee (Raffle.sol:L276-L300). Each owned ticket then consumes its exact represented-entry value, and ERC721._burn
  rejects a second consumption of a burned ticket (Raffle.sol:L349-L371;
  target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307). ✓
- modifier/base path: settlement, redemption, refunds, and both quote release entrypoints are nonReentrant
  (Raffle.sol:L304-L309, L349-L390). The inherited modifier executes its before/after guard around the body and
  rejects a nested guarded call
  (target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73, L88-L105). ✓
- lifecycle exclusion: callback resolution requires Drawing and selects only NftWon or CashWon
  (Raffle.sol:L509-L523); enableRefunds changes Active/Drawing to Refunding
  (Raffle.sol:L276-L300), and settlement rejects every nonterminal/refund status
  (Raffle.sol:L533-L536). No refund and terminal-allocation branch can both consume the same pot. ✓

---

**Searched:**

- All five files under target/packages/contracts/src were read in full; dependency-hashes.json named 31
  dependencies, all 31 were read in full, and recomputed SHA-256 values produced 0 diff lines against the pinned
  hashes.
- round|floor|remainder over the five production files → 6 hits: Raffle.sol:L529-L530,
  IRaffle.sol:L120-L121 and L328, and RaffleConstants.sol:L7.
- dust|residu|leftover|without loss over the five production files → 0 hits.
- protocolFee|protocolFees|PROTOCOL_FEE_BPS|\bBPS\b over the five production files → 15 hits. The actual
  arithmetic is Raffle.sol:L540 and L544-L547; the state write is L555; the rate constants are
  RaffleConstants.sol:L11-L15. The remaining hits are declaration, view, event, and release surfaces.
- unsettledPot|grossPot|grossAmount|grossSales|accountedQuoteBalance over the five production files → 21 hits.
  The only positive unsettled-pot writer is Raffle.sol:L233; its other writes are the full resets at L297 and
  L553.
- _settleWinningTicket|settleWinningTicket over the five production files → 5 hits: the external caller at
  Raffle.sol:L304-L305, the redemption caller at L315, the private definition at L533, and the interface
  declaration at IRaffle.sol:L331. No third implementation caller exists.
- (unsettledPot|remainingRefundLiability|winnerProceeds|sponsorProceeds|protocolFees)\s*(\+?=|-=) in Raffle.sol
  → 11 hits: L233, L297-L298, L341, L368, L378, L388, L548, and L553-L555. These are the complete accounting
  writers; none creates a dust/remainder bucket.
- protocolFees|sponsorProceeds|winnerProceeds|unsettledPot|grossPot|PROTOCOL_FEE_BPS|CASH_WINNER_BPS across the
  31 pinned dependencies → 0 hits.
- function mulDiv|Calculates floor|return low / denominator|remainder := mulmod across the 31 pinned
  dependencies → 5 hits, all in OpenZeppelin Math.sol:L200-L231; the overload with an explicit rounding argument
  is at L282-L284 and is not called by Raffle.

---

**How the verdict was reached:** This is implemented, not partial, because every reachable disposition of the
recorded aggregate pot was walked. Both terminal-result branches allocate exactly G by construction; the refund
branch moves and pays the full G without applying a fee; the only two callers of the private terminal allocator
reach the same formulas; and the complete writer search found no alternative fee path or unallocated state bucket.
It is not contradicted because the fee is taken once from grossPot, not separately from tickets, and the called
Math implementation floors. It is not stronger-than-spec because the code neither withholds an extra amount nor
imposes a higher fee: it implements the stated floor and assigns the subtraction remainder to the sponsor payout.

With the current fixed ENTRY_PRICE of 1,000,000 raw units, every reachable G is a multiple of 1,000,000, so both
5% and 80% are in fact integral for the present input domain
(Raffle.sol:L219-L233; RaffleConstants.sol:L11-L21). Even so, the implementation does not rely on that
divisibility for conservation: sponsorAmount is computed as the residual after the floored allocations
(Raffle.sol:L539-L555). Confidence is high because the aggregate source, all accounting writers, both settlement
callers, every result/refund branch, the claim paths, the inherited guard, and the concrete Math and SafeERC20
callees were read.

---

**Open questions:**

- None for this requirement. Exact token custody follows the target's explicit assumption of canonical,
  standard, non-rebasing, fee-free USDC (target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15;
  Raffle.sol:L560-L566); that trust boundary does not make the source-level allocation identity ambiguous.
