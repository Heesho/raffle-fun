## REQ-23 — Reserve-missed treasury allocation is 5% of aggregate gross

> "Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury."
> — DESIGN.md:L2, sentence 6

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** This record checks only the treasury limb identified by the supplied
checkable: every reserve-missed result must allocate
`floor(aggregate gross proceeds * 500 / 10_000)` to the configured treasury. The base must be the full aggregate
sales pot, the floor must occur on that aggregate rather than per purchase, and every way to settle a
reserve-missed result must reach the same calculation (DESIGN.md:L2, sentences 6 and 8).

---

**Where enforcement lives:**

The accepted callback classifies a result as `CashWon` exactly when sold entries are below the stored reserve:

```solidity
// target/packages/contracts/src/Raffle.sol:L518-L523
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

emit RaffleResolved(requestId, resolvedEntry, status);
```

`reserveEntries` is written during the factory-only, one-time initialization
(`target/packages/contracts/src/Raffle.sol:L176-L205`). The factory rejects a zero reserve and passes the
sponsor-supplied `uint128` value to the clone (`target/packages/contracts/src/RaffleFactory.sol:L97-L120`,
`L154-L179`). No later writer exists in the scoped production or dependency closure.

Each successful purchase prices the whole requested range once and adds that amount to `unsettledPot`:

```solidity
// target/packages/contracts/src/Raffle.sol:L219-L224
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}

uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

```solidity
// target/packages/contracts/src/Raffle.sol:L230-L233
totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;
```

The public gross-sales view independently uses the same sold-entry base
(`target/packages/contracts/src/Raffle.sol:L472-L475`). `ENTRY_PRICE` is the fixed 1,000,000-unit constant
(`target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21`). The only paths that clear
`unsettledPot` are refund activation, which moves the raffle to `Refunding`
(`target/packages/contracts/src/Raffle.sol:L276-L300`), and terminal settlement itself
(`target/packages/contracts/src/Raffle.sol:L539-L555`). Settlement accepts only `NftWon` or `CashWon`
(`target/packages/contracts/src/Raffle.sol:L534-L536`), so a successful `CashWon` settlement reads the full,
not-yet-allocated aggregate sales pot.

The rate is compile-time fixed at 500/10,000:

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18
/// @notice Denominator used for every global protocol basis-point rate.
uint256 internal constant BPS = 10_000;

/// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
uint256 internal constant PROTOCOL_FEE_BPS = 500;

/// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
uint256 internal constant CASH_WINNER_BPS = 8000;
```

The single settlement helper computes the protocol allocation before branching on the terminal result, uses the
aggregate `grossPot`, and stores the result in the sole protocol-fee bucket:

```solidity
// target/packages/contracts/src/Raffle.sol:L539-L555
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

The invoked three-argument `Math.mulDiv` is explicitly a floor operation and, on a non-overflowing product,
returns ordinary integer division:

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215
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

The purchase bound limits aggregate entries to `uint128` (`target/packages/contracts/src/Raffle.sol:L219-L230`),
so with the 1,000,000-unit entry price and 500 numerator, the concrete product used for the fee fits in
`uint256`. Thus this call returns `floor(grossPot * 500 / 10_000)`. Moreover, every reachable `grossPot` is a
multiple of 1,000,000, so its 5% share is integral; the selected floor rule is still the rule implemented.

The treasury cannot be supplied by the settler. The factory constructor stores one immutable treasury and one
fixed raffle implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`); `createRaffle` passes
that treasury into the clone (`target/packages/contracts/src/RaffleFactory.sol:L106-L120`); and one-time
factory-only initialization stores it (`target/packages/contracts/src/Raffle.sol:L176-L205`). Release consumes
the complete stored fee bucket and sends it only to that stored address:

```solidity
// target/packages/contracts/src/Raffle.sol:L385-L391
function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
    amount = protocolFees;
    if (amount == 0) revert NoProtocolFees();
    protocolFees = 0;
    address treasury = protocolTreasury;
    _transferQuote(treasury, amount);
    emit ProtocolFeesReleased(msg.sender, treasury, amount);
}
```

`_transferQuote` performs the quote-token call through `SafeERC20`
(`target/packages/contracts/src/Raffle.sol:L560-L566`), whose `safeTransfer` reverts when its checked call result
is unsuccessful (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L37`,
`L167-L200`). The implementation expressly treats exact, fee-free canonical-USDC transfer behavior as a trusted
dependency (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`); the allocation itself is fixed in
storage before that release path.

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → `raffleImplementation`: the factory stores the nonzero treasury and
  fixed implementation at `target/packages/contracts/src/RaffleFactory.sol:L65-L91`. `createRaffle` →
  `Clones.clone` → `Raffle.initialize` passes that same treasury at
  `target/packages/contracts/src/RaffleFactory.sol:L97-L120`; the selected clone routine embeds one fixed delegate
  target at `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62`. ✓
- `buyEntries` → `SafeERC20.safeTransferFrom` → `unsettledPot += grossAmount`: the entry-count bound, price,
  collection call, and accounting write are at `target/packages/contracts/src/Raffle.sol:L209-L235`;
  `SafeERC20.safeTransferFrom` rejects a checked failure at
  `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47`,
  `L202-L244`. ✓
- `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: the base contract admits only
  the configured wrapper at
  `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`;
  the override filters non-current callbacks and selects `CashWon` on `totalEntries < reserveEntries` at
  `target/packages/contracts/src/Raffle.sol:L509-L523`. ✓
- `settleWinningTicket` → `_settleWinningTicket`: the direct permissionless entrypoint has no branch around the
  helper (`target/packages/contracts/src/Raffle.sol:L303-L306`); the `CashWon` helper path computes and stores the
  5% fee at `target/packages/contracts/src/Raffle.sol:L533-L557`. ✓
- `redeemWinningTicket` → `_settleWinningTicket`: when settlement is incomplete, redemption calls the identical
  helper at `target/packages/contracts/src/Raffle.sol:L309-L318`. When it is already complete, the branch only
  checks the recorded ticket and does not recompute or replace `protocolFees`
  (`target/packages/contracts/src/Raffle.sol:L314-L318`). ✓
- Repeated settlement: `_settleWinningTicket` reverts when `settlementComplete` is already true and sets that flag
  before returning (`target/packages/contracts/src/Raffle.sol:L533-L557`). Both public settlement routes and the
  release route carry `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L303-L315`, `L384-L391`); the
  inherited modifier executes its before/after guard around the body at
  `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73`, `L88-L106`. ✓
- `releaseProtocolFees` → `_transferQuote` → `SafeERC20.safeTransfer`: the caller chooses neither amount nor
  recipient; the whole bucket goes to `protocolTreasury` at `target/packages/contracts/src/Raffle.sol:L385-L391`,
  `L560-L566`. ✓
- Refund branch: `enableRefunds` moves the whole pot to refund liability and sets `Refunding` at
  `target/packages/contracts/src/Raffle.sol:L276-L300`; `_settleWinningTicket` rejects that status at `L534-L536`.
  It therefore is not an alternate reserve-missed settlement path. ✓

---

**Searched:**

- Scope enumeration → exactly five production files under `target/packages/contracts/src` and 31 dependency paths
  in `target/dependency-hashes.json`; all 31 dependency SHA-256 values matched the manifest, and every scoped file
  was read in full.
- `PROTOCOL_FEE_BPS` → 2 hits in 2 files: definition at
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L15` and use at
  `target/packages/contracts/src/Raffle.sol:L540`.
- `\bBPS\b` → 3 hits in 2 files: denominator definition at
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L12` and the two terminal-allocation calculations at
  `target/packages/contracts/src/Raffle.sol:L540`, `L546`.
- `Math\.mulDiv` → 3 hits in 2 files: the rounding note at
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L7` and the protocol/winner calculations at
  `target/packages/contracts/src/Raffle.sol:L540`, `L546`. `\bmulDiv\b` → 6 hits in 3 files, adding the two
  overload definitions and one overload call in `Math.sol:L206-L283`.
- `\bprotocolFees\b` → 6 hits in 2 files: interface getter at
  `target/packages/contracts/src/interfaces/IRaffle.sol:L480`; declaration/getter at
  `target/packages/contracts/src/Raffle.sol:L106`; release read/clear at `L386`, `L388`; aggregate-accounting read at
  `L469`; settlement write at `L555`.
- `\bunsettledPot\b` → 8 hits in 2 files: interface getter at
  `target/packages/contracts/src/interfaces/IRaffle.sol:L460`; declaration at
  `target/packages/contracts/src/Raffle.sol:L91`; purchase write at `L233`; refund read/clear at `L296-L297`;
  accounting read at `L469`; settlement read/clear at `L539`, `L553`.
- `\bgrossPot\b` → 5 hits, all in `target/packages/contracts/src/Raffle.sol:L539-L547`; `\bgrossSales\b` → 2 hits
  in 2 files, the interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L390` and
  implementation at `target/packages/contracts/src/Raffle.sol:L473`.
- `_settleWinningTicket` → 3 hits in 1 file: direct caller at
  `target/packages/contracts/src/Raffle.sol:L305`, redemption caller at `L315`, and private implementation at `L533`.
- `Status\.CashWon` → 4 hits in 1 file: terminal-status admission at
  `target/packages/contracts/src/Raffle.sol:L312`, sponsor-prize admission at `L397`, reserve classification at
  `L521`, and settlement admission at `L536`.
- `releaseProtocolFees` → 2 hits in 2 files: interface at
  `target/packages/contracts/src/interfaces/IRaffle.sol:L352` and implementation at
  `target/packages/contracts/src/Raffle.sol:L385`.
- State-writer search for `protocolFees`, `protocolTreasury`, `reserveEntries`, `totalEntries`, and `unsettledPot` →
  9 assignment hits: factory treasury initialization at `RaffleFactory.sol:L87`; clone treasury/reserve initialization
  at `Raffle.sol:L199`, `L203`; entry/pot writes at `L230`, `L233`; refund pot clear at `L297`; fee clear at `L388`;
  settlement pot/fee writes at `L553`, `L555`.
- Alternate fee/configuration vocabulary: `commission|commissioned` → 0 hits;
  `\bcut\b|revenueShare|revenue.share` → 0 hits; `basis.point|basis_point|bps` → 3 hits, all the rate comments in
  `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L17`.
- Mutable-rate/destination symbols `setProtocol|setTreasury|setFee|updateTreasury|updateFee|upgradeTo|upgradeToAndCall`
  → 0 hits across the 36 scoped files.

---

**How the verdict was reached:** A reserve miss is the `CashWon` side of the sole result-classification expression
(`target/packages/contracts/src/Raffle.sol:L518-L523`). Both settlement entrypoints converge on one private helper
(`L303-L315`, `L533-L557`). In that helper, `grossPot` is the aggregate, unallocated sales pot; the protocol bucket
is `floor(grossPot * 500 / 10_000)`; and 500/10,000 is exactly 5%
(`target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18`;
`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215`). The helper stores
that value in `protocolFees`, and the only release uses the fixed `protocolTreasury`
(`target/packages/contracts/src/Raffle.sol:L539-L555`, `L385-L391`). The one-shot guard, status gate, immutable-rate
constants, factory-only treasury initialization, and exhaustive caller/writer searches leave no `CashWon` path
that applies a different base, rate, or rounding rule. The verdict is therefore `implemented`, not `partial` or
`contradicted`; it is not `stronger-than-spec` because the enforced rate and floor rule are exactly the quoted
requirements.

---

**Open questions:**

- None for the stated allocation property. Exact live-token balance-delta behavior is an explicit trusted-dependency
  premise rather than locally implemented token logic (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`),
  but REQ-23's supplied checkable concerns the amount allocated to the treasury, which is fully determined before
  release at `target/packages/contracts/src/Raffle.sol:L539-L555`.
