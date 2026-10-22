## REQ-20 — Reserve-met NFT result and 95% sponsor / 5% treasury proceeds

> "Reserve met awards NFT and 95% sponsor / 5% treasury."
> — DESIGN.md:L2, sentence 5

**Verdict:** implemented · confidence: high

**What this demands of an implementation:** For the supplied checkable interpretation, a resolved raffle whose sold-entry count meets or exceeds its reserve must use the NFT-result branch, calculate the treasury share from the aggregate gross proceeds as 5%, and allocate the other 95% to the sponsor side. The specification also states, verbatim:

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

Concretely, if `G` is the reserve-met raffle's aggregate unsettled pot, the required stored liabilities are `treasury = floor(G * 500 / 10_000)` and `sponsor = G - treasury`. Thus `sponsor + treasury = G`; no raw quote-token unit can be lost to rounding. The `NftWon` result must leave the escrowed NFT claim for the winning ticket rather than create a cash-winner allocation.

---

**Where enforcement lives:**

The reserve threshold selects the NFT result only after an authenticated callback passes every application-level acceptance condition:

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

The basis-point numerator and denominator are compile-time constants, so there is no setter or administrator-controlled rate:

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L18
/// @notice Denominator used for every global protocol basis-point rate.
uint256 internal constant BPS = 10_000;

/// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
uint256 internal constant PROTOCOL_FEE_BPS = 500;

/// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
uint256 internal constant CASH_WINNER_BPS = 8000;
```

Every successful purchase contributes its complete gross amount to the one aggregate unsettled pot:

```solidity
// target/packages/contracts/src/Raffle.sol:L223-L235
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
```

`ENTRY_PRICE` is exactly `1_000_000` raw units (`RaffleConstants.sol:L20-L21`), and the purchase rejects a sum of entries above `uint128` (`Raffle.sol:L209-L220`). Consequently, the reachable `unsettledPot` is a multiple of `1_000_000`, stays well within `uint256`, and is the aggregate—not a per-ticket amount—read at settlement (`Raffle.sol:L223-L233`, `L539`).

The single private settlement body calculates the aggregate protocol fee, takes the NFT-result branch, assigns the entire remainder to the sponsor side, and replaces the unsettled pot with the two liabilities:

```solidity
// target/packages/contracts/src/Raffle.sol:L533-L558
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

The called three-argument `Math.mulDiv` overload specifies floor division and, on its direct 256-bit path, returns integer division; its remaining branch first removes the division remainder before completing the full-precision quotient (`Math.sol:L199-L276`):

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

Substitution gives `protocolFee = floor(G * 500 / 10_000) = floor(G / 20)`. Because reachable `G` is a multiple of `1_000_000`, this is exactly `G / 20` (5%), and `G - protocolFee` is exactly `19G / 20` (95%). Even without that divisibility, the code implements the stated floor-and-remainder rule: the subtraction at `Raffle.sol:L543-L545` makes the two NFT-result buckets sum exactly to `G`, and the writes at `L551-L555` preserve that allocation without a rounding residue.

The stored liabilities are released independently to their configured destinations:

```solidity
// target/packages/contracts/src/Raffle.sol:L374-L391
/// @inheritdoc IRaffle
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

Clone initialization writes `sponsorRecipient` and `protocolTreasury` after its one-time and factory-only gates (`Raffle.sol:L176-L205`). The factory supplies its constructor-fixed `protocolTreasury` to every clone (`RaffleFactory.sol:L65-L91`, `L97-L120`). Searches found no later nonzero assignment to either clone destination; payout uses the stored sponsor recipient and treasury at `Raffle.sol:L375-L391`. `_transferQuote` screens the destination and calls `SafeERC20.safeTransfer` (`Raffle.sol:L560-L567`), whose implementation reverts when the ERC-20 call fails or explicitly returns false (`SafeERC20.sol:L30-L37`, `L167-L200`).

The NFT side of the same result is a claim exercised by the winning ticket owner: after settlement and ownership checks, the `NftWon` branch transfers the configured prize and verifies the reported owner (`Raffle.sol:L309-L337`). This matches the specification's separate instruction that callback resolution and settlement do not themselves deliver assets: "Callback records result only. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure." (`DESIGN.md:L2`, sentences 12-13).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` fixes the quote token, wrapper, treasury, and implementation; `createRaffle` → `Raffle.initialize` passes the reserve and fixed treasury into a fresh clone (`RaffleFactory.sol:L65-L91`, `L97-L120`; `Raffle.sol:L155-L166`, `L176-L205`). The factory rejects a zero reserve (`RaffleFactory.sol:L171-L179`). ✓
- `buyEntries` → `SafeERC20.safeTransferFrom` → `unsettledPot += grossAmount`: every successful sale uses `entryCount * ENTRY_PRICE`; the `uint128` aggregate-entry bound is checked before the pot update (`Raffle.sol:L209-L235`; `SafeERC20.sol:L39-L47`, `L202-L244`). ✓
- `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: the base contract admits only the configured wrapper (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`); the override ignores in-flight, wrong-state, wrong-ID, wrong-word-count, or late callbacks and assigns `NftWon` exactly when `totalEntries >= reserveEntries` (`Raffle.sol:L509-L523`). ✓
- `settleWinningTicket` → `_settleWinningTicket`: the external entrypoint has no alternative body and reaches the shared private allocator (`Raffle.sol:L303-L306`, `L533-L558`). On `NftWon`, it allocates `floor(G * 500 / 10_000)` to `protocolFees` and `G - protocolFee` to `sponsorProceeds`. ✓
- `redeemWinningTicket` → `_settleWinningTicket` when settlement has not occurred: the second allocation-capable entrypoint reaches the same helper; after prior settlement it instead requires the recorded ticket and cannot allocate again (`Raffle.sol:L309-L318`, `L533-L555`). ✓
- Invalid result, wrong winning range, and duplicate-settlement paths revert before bucket writes (`Raffle.sol:L534-L538`, `L577-L585`). Thus no rejecting path commits a different split. ✓
- `releaseSponsorProceeds` → `_transferQuote(sponsorRecipient, amount)` and `releaseProtocolFees` → `_transferQuote(protocolTreasury, amount)` consume the complete corresponding bucket (`Raffle.sol:L374-L391`, `L560-L567`). Both are guarded by the inherited `nonReentrant` modifier, whose before/after hooks reject nested guarded calls and restore the guard only after the body returns (`ReentrancyGuard.sol:L69-L73`, `L88-L105`). ✓
- `enableRefunds` is not a bypass after a reserve-met terminal result: it accepts only `Active` or `Drawing` and rejects `NftWon` (`Raffle.sol:L275-L300`). A pre-resolution deadline instead follows the specification's distinct rule, "Refunds open at deadline." (`DESIGN.md:L2`, sentence 11). ✓

---

**Searched:**

- Scope inventory → read all five first-party production files and every one of the 31 paths in `target/dependency-hashes.json` in full; recomputed SHA-256 for all 31 dependency files produced 0 mismatches.
- `95%` → 0 line hits in production source. The implementation expresses the percentage arithmetically rather than by that string.
- `5%`, `500`, `10_000`, `remainder`, `protocolFee`, `sponsorAmount` → respectively 1, 2, 1, 2, 18, and 7 case-insensitive production line hits. The enforcing hits are the fixed constants at `RaffleConstants.sol:L11-L18`, the aggregate calculation at `Raffle.sol:L539-L547`, and the bucket writes at `L551-L555`; the remaining hits are declarations, events, interface documentation, and release reads.
- `PROTOCOL_FEE_BPS|CASH_WINNER_BPS|\bBPS\b|mulDiv` → 6 production line hits across `Raffle.sol` and `RaffleConstants.sol`: two calculations, three constant declarations, and the constants library's rounding note. No alternate fee formula was found.
- `reserveEntries|NftWon|CashWon` → 30 production line hits across `Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, and `IRaffleFactory.sol`. The only executable assignment of either terminal result is `Raffle.sol:L521`; other executable hits configure/read the reserve or branch on the already-recorded result.
- `unsettledPot|sponsorProceeds|protocolFees|winnerProceeds` → 23 production line hits across `Raffle.sol` and `IRaffle.sol`. Assignment-specific search found nine writes: pot increase at `Raffle.sol:L233`; pot zeroing for refund or settlement at `L297`, `L553`; winner zero/set at `L341`, `L548`; sponsor zero/set at `L378`, `L554`; protocol zero/set at `L388`, `L555`. No other writer can alter the reserve-met buckets.
- `_settleWinningTicket(` across all five production files and all 31 dependencies → 3 hits: calls at `Raffle.sol:L305` and `L315`, and the private definition at `L533`. Both allocation-capable callers were walked.
- `^[[:space:]]*(sponsorRecipient|protocolTreasury)[[:space:]]*=[^=]` → 3 production hits: clone initialization at `Raffle.sol:L198-L199` and factory-constructor initialization at `RaffleFactory.sol:L87`. No destination setter or alternate clone assignment was found.
- `mulDiv(` across the bounded production/dependency scope → 5 hits: the protocol and cash calculations at `Raffle.sol:L540`, `L546`; the floor overload at `Math.sol:L206`; the explicit-rounding overload and its delegation at `Math.sol:L282-L283`. The protocol call has three arguments and therefore uses the floor overload.
- Settlement/release modifiers and inherited implementation → the four relevant external entrypoints are `nonReentrant` at `Raffle.sol:L304`, `L309`, `L375`, and `L385`; the modifier and its complete before/after path were read at `ReentrancyGuard.sol:L69-L105`.

---

**How the verdict was reached:** `implemented`, rather than `partial`, because both externally reachable ways to allocate a terminal result converge on the same private helper, and every `NftWon` execution of that helper uses the same 500/10,000 aggregate fee and sponsor-remainder branch (`Raffle.sol:L303-L318`, `L533-L555`). Rejecting paths revert before allocation, and a completed settlement cannot be repeated (`Raffle.sol:L534-L538`). It is not `contradicted`: the called math routine floors, the calculation is over the aggregate `unsettledPot`, and the sponsor subtraction assigns every unit left after the fee (`Math.sol:L199-L276`; `Raffle.sol:L539-L555`). It is not `stronger-than-spec`: assigning the rounding remainder to the sponsor is exactly what the quoted rounding sentence requires. Because the reachable pot is denominated in one-million-unit entries, the state allocation is also numerically exact 95% / 5%, not merely an approximation subject to truncation (`RaffleConstants.sol:L20-L21`; `Raffle.sol:L223-L233`).

---

**Open questions:**

- None for the recorded allocation property. Actual quote-token transfer semantics remain an external dependency, but the specification expressly states, "Quote token and Chainlink wrapper are trusted canonical dependencies" (`DESIGN.md:L2`, sentence 16), and the interface records the assumed standard, non-rebasing, fee-free token behavior (`IRaffle.sol:L12-L15`). That documented trust premise does not make the source-visible aggregate liability split undecidable.
