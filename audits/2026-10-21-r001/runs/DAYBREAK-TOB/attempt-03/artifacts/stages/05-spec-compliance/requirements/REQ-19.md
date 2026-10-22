## REQ-19 — Reserve-met proceeds split 95% / 5%

> "Reserve met awards NFT and 95% sponsor / 5% treasury."
> — DESIGN.md:L2, sentence 5

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Under the supplied checkable formulation, this record judges the proceeds allocation on a reserve-met resolution, not the separately checkable NFT-delivery mechanics. If `G` is the aggregate quote-token sale pot, the treasury allocation must be `T = floor(G × 5 / 100)` and the sponsor allocation must be the lossless remainder `S = G - T`. Thus `S + T = G`; the sponsor receives 95% subject to the document's stated rule that the aggregate protocol fee is rounded down. The document additionally states, verbatim, "Refunds open at deadline." (`DESIGN.md:L2`); that sentence distinguishes deadline refunds from a successfully resolved reserve-met outcome.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L15
/// @notice Denominator used for every global protocol basis-point rate.
uint256 internal constant BPS = 10_000;

/// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
uint256 internal constant PROTOCOL_FEE_BPS = 500;
```

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21
/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;
```

- The fixed fee fraction is `500 / 10_000 = 5%`; the sponsor share is deliberately implemented as its complement rather than as a second independently rounded percentage (`RaffleConstants.sol:L11-L15`; `Raffle.sol:L540-L547`).
- Each successful purchase computes `grossAmount = entryCount × ENTRY_PRICE`, transfers that amount in, advances the bounded `uint128` entry total, and adds the same amount to `unsettledPot` (`Raffle.sol:L209-L235`). Consequently, before terminal allocation the tracked pot is the aggregate proceeds of successful whole-entry purchases (`Raffle.sol:L223-L233`).

```solidity
// target/packages/contracts/src/Raffle.sol:L518-L523
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

emit RaffleResolved(requestId, resolvedEntry, status);
```

- The reserve comparison has no intermediate truncation: both `totalEntries` and `reserveEntries` are `uint128`, and meeting or exceeding the configured threshold selects `NftWon` (`Raffle.sol:L78-L85`, `L518-L523`). The reserve is copied once during factory-only, one-time initialization (`Raffle.sol:L176-L205`), and the factory rejects a zero reserve (`RaffleFactory.sol:L152-L179`).

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

- On the only relevant branch, `NftWon`, the helper computes the fee once from the aggregate `grossPot`, assigns every other raw unit to `sponsorAmount`, clears the unallocated pot, and records exactly those two claim buckets (`Raffle.sol:L539-L557`). There is no cash-winner allocation on that branch (`Raffle.sol:L541-L549`).
- The conservation identity is direct: after the branch, `sponsorProceeds + protocolFees = (grossPot - protocolFee) + protocolFee = grossPot` (`Raffle.sol:L543-L555`). Solidity 0.8 checked subtraction would revert rather than record a wrapped amount, and `protocolFee` cannot exceed `grossPot` because the constants are `500` and `10_000` (`Raffle.sol:L2`, `RaffleConstants.sol:L11-L15`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215
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
```

- This is actual enforcement, not a promising function name: the selected three-argument overload specifies floor division and, on the reachable bounds here, executes integer division (`Math.sol:L199-L215`). `totalEntries` cannot exceed `uint128.max` (`Raffle.sol:L84-L85`, `L219-L230`), so `grossPot × 500 < 2^128 × 1,000,000 × 500 < 2^256`; therefore the shown `high == 0` branch is sufficient for every reachable protocol-fee calculation (`RaffleConstants.sol:L14-L21`; `Raffle.sol:L223-L233`).
- More strongly, every reachable `grossPot` is `n × 1,000,000` for an integer entry count `n` (`Raffle.sol:L223-L233`, `L472-L475`). Thus `protocolFee = n × 50,000` and `sponsorAmount = n × 950,000`: the reachable split is exactly 5% / 95%, while the subtraction still implements the required lossless remainder rule.

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

/// @inheritdoc IRaffle
function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
    amount = protocolFees;
    if (amount == 0) revert NoProtocolFees();
    protocolFees = 0;
    address treasury = protocolTreasury;
    _transferQuote(treasury, amount);
    emit ProtocolFeesReleased(msg.sender, treasury, amount);
}
```

```solidity
// target/packages/contracts/src/Raffle.sol:L564-L566
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

- The release functions each consume and transfer the complete recorded bucket, independently, to the stored sponsor recipient and treasury (`Raffle.sol:L375-L391`). Those destinations are populated during the one-time initialization (`Raffle.sol:L176-L205`); the factory treasury is constructor-fixed and passed to each clone (`RaffleFactory.sol:L65-L91`, `L109-L120`).
- `_transferQuote` forwards the exact bucket amount to `SafeERC20.safeTransfer` (`Raffle.sol:L564-L566`), whose wrapper reverts when its underlying transfer helper reports failure (`SafeERC20.sol:L30-L37`). Exact recipient balance movement relies on the explicitly documented dependency boundary: "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`). The interface makes that assumption concrete as canonical, non-rebasing, fee-free USDC (`IRaffle.sol:L12-L15`).

---

**Paths walked:**

- Factory construction → implementation deployment → clone creation → `initialize`: the factory fixes `protocolTreasury` and the `Raffle` implementation in immutable variables (`RaffleFactory.sol:L32-L42`, `L65-L91`), `createRaffle` clones that implementation and passes the sponsor-selected recipient, fixed treasury, and reserve (`RaffleFactory.sol:L97-L120`), and `initialize` is factory-only and one-time (`Raffle.sol:L175-L205`). OpenZeppelin's selected `Clones.clone` creates a proxy pointing to the supplied implementation (`Clones.sol:L23-L33`, `L47-L61`). ✓
- `buyEntries` → quote collection → `unsettledPot`: only `Active`, pre-end, positive purchases pass; the function bounds the `uint128` total, charges `entryCount × 1,000,000`, and adds that exact amount to the aggregate pot (`Raffle.sol:L209-L235`; `RaffleConstants.sol:L20-L21`). ✓
- Authenticated callback → `fulfillRandomWords` → reserve comparison: the inherited gateway admits only the configured wrapper (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`); the implementation rejects in-flight, wrong-state, wrong-request, wrong-length, and late callbacks before setting `NftWon` exactly when `totalEntries >= reserveEntries` (`Raffle.sol:L509-L523`). ✓
- `settleWinningTicket` → `_settleWinningTicket`: the permissionless external entrypoint is `nonReentrant` and has no alternate body (`Raffle.sol:L303-L306`); the private helper validates terminal status and the winning range before running the single allocation formula (`Raffle.sol:L533-L557`, `L577-L585`). ✓
- `redeemWinningTicket` before settlement → `_settleWinningTicket`: redemption invokes the same private helper when `settlementComplete` is false (`Raffle.sol:L309-L316`). If settlement is already complete, it only checks the recorded ticket and does not recompute or change either sponsor or protocol allocation (`Raffle.sol:L314-L325`). ✓
- Settlement replay: the helper rejects when `settlementComplete` is already true, and this flag has one writer, in the same transaction as the two liability assignments (`Raffle.sol:L533-L555`). ✓
- Sponsor claim → `_transferQuote`; treasury claim → `_transferQuote`: each entrypoint reads its whole bucket, clears it before the external call, and transfers exactly the read amount (`Raffle.sol:L375-L391`, `L564-L566`). Both carry `nonReentrant`; the inherited modifier executes its before/after guard around the function body (`Raffle.sol:L375-L385`; `ReentrancyGuard.sol:L69-L73`, `L88-L105`). ✓
- Cash-result branch: `totalEntries < reserveEntries` selects `CashWon` and the helper applies the separate cash-winner formula (`Raffle.sol:L521`, `L543-L549`). It is not a reserve-met allocation path. ✓ not applicable.
- Deadline-refund branch: `enableRefunds` moves the whole unallocated pot into refund liability and changes status to `Refunding`, after which settlement rejects that status (`Raffle.sol:L276-L300`, `L533-L537`). This is the distinct behavior authorized by the verbatim specification sentence "Refunds open at deadline." (`DESIGN.md:L2`), not a partial reserve-met settlement path. ✓ not applicable.
- Direct implementation calls: the implementation constructor locks its own storage in `Refunding`, so its settlement path rejects; initialized clones use isolated storage and the fixed implementation's logic (`Raffle.sol:L151-L166`, `L533-L537`; `RaffleFactory.sol:L89-L91`, `L105-L120`). ✓

---

**Searched:**

- Scope coverage → read all five production files (`Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, `RaffleConstants.sol`) and all 31 dependencies enumerated by `target/dependency-hashes.json:L2-L32`; SHA-256 verification returned 31/31 matches.
- `95|9500|5%` (case-sensitive, all 36 scoped files) → 1 hit, the `5%` rate comment at `RaffleConstants.sol:L14`; there is no literal `95` because the sponsor side is the computed remainder at `Raffle.sol:L543-L545`.
- `PROTOCOL_FEE_BPS|protocolFee` (case-insensitive, all 36 scoped files) → 19 hits: 1 in `RaffleConstants.sol`, 6 in `IRaffle.sol`, and 12 in `Raffle.sol`; the operative definition, calculation, storage write, and claim are at `RaffleConstants.sol:L14-L15` and `Raffle.sol:L385-L391`, `L539-L557`.
- `sponsorAmount|sponsorProceeds` (case-insensitive, all 36 scoped files) → 18 hits: 6 in `IRaffle.sol` and 12 in `Raffle.sol`; the operative remainder, storage write, and claim are at `Raffle.sol:L375-L381`, `L541-L557`.
- `_settleWinningTicket|settleWinningTicket` → 5 hits: the interface declaration (`IRaffle.sol:L331`), external definition (`Raffle.sol:L304`), its call (`Raffle.sol:L305`), redemption's call (`Raffle.sol:L315`), and the private definition (`Raffle.sol:L533`). No third caller exists in scope.
- Precise write scan for `sponsorProceeds` or `protocolFees` → 4 hits, all in `Raffle.sol`: clearing on claims at `L378` and `L388`, and allocation at `L554-L555`. No modifier, base contract, factory, interface, or dependency writes either bucket.
- Precise write scan for `unsettledPot` → 3 hits, all in `Raffle.sol`: purchase accumulation at `L233`, refund clearing at `L297`, and settlement clearing at `L553`.
- Precise write scans for result/configuration → 6 `status` writes, with the only terminal result write at `Raffle.sol:L521`; 1 `reserveEntries` write at `Raffle.sol:L203`; 1 `totalEntries` write at `Raffle.sol:L230`; and 3 sponsor-recipient/treasury writes at `RaffleFactory.sol:L87` and `Raffle.sol:L198-L199`.
- `Math.mulDiv(` in first-party source → 2 call sites: protocol fee at `Raffle.sol:L540` and the cash-only winner share at `Raffle.sol:L546`. The called three-argument implementation was read through its floor division, full-precision path, and return (`Math.sol:L199-L277`).
- `_transferQuote(` → 5 hits: four callers and the private definition (`Raffle.sol:L342`, `L369`, `L380`, `L390`, `L564`). The sponsor and treasury are the `L380` and `L390` callers; `quoteToken.safeTransfer` has one outbound call site at `Raffle.sol:L566`.
- `commission|revenueShare|sponsorCut|treasuryCut` (case-insensitive, all 36 scoped files) → 0 hits. The varied vocabulary did not reveal an alternate split mechanism.
- Function-name sweep for `upgrade`, `setFee`, `setProtocol`, `setSponsor`, `withdraw`, or `rescue` across the 36 scoped files → 0 production function declarations. `raffleImplementation` has 7 scoped hits; its only assignment is the immutable factory constructor write at `RaffleFactory.sol:L91`, and clone creation reads it at `L106`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because both possible reserve-result settlement entry paths—the standalone settlement entrypoint and redemption's settle-if-needed branch—converge on the same private helper (`Raffle.sol:L303-L316`, `L533-L557`). In its `NftWon` branch the helper always calculates `floor(G × 500 / 10,000)`, records that as `protocolFees`, and records `G` minus that fee as `sponsorProceeds`; no branch or caller can substitute a different reserve-met formula (`Raffle.sol:L539-L555`; `RaffleConstants.sol:L11-L15`; `Math.sol:L199-L215`). The only later writes to those buckets clear and release the whole claim (`Raffle.sol:L375-L391`). The cash and deadline-refund branches are distinct documented outcomes, not uncovered reserve-met settlement routes (`DESIGN.md:L2`; `Raffle.sol:L276-L300`, `L521`, `L543-L549`). This is not `stronger-than-spec`: floor on the aggregate 5% fee plus sponsor remainder is exactly the document's specified rounding rule. Because reachable pots are whole multiples of the 1,000,000-unit entry price, that rule evaluates to exactly 5% treasury and 95% sponsor for every reachable reserve-met pot (`RaffleConstants.sol:L14-L21`; `Raffle.sol:L223-L233`, `L539-L555`).

---

**Open questions:**

- None for this requirement. Exact external balance movement is intentionally conditioned on the specification's verbatim trust statement for the canonical quote token (`DESIGN.md:L2`) and the matching fee-free, non-rebasing interface assumption (`IRaffle.sol:L12-L15`); it does not make the local allocation formula undecidable.
