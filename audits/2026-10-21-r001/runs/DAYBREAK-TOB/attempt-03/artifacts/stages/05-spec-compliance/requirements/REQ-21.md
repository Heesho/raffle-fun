## REQ-21 — Reserve-missed 80/15/5 allocation

> "Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury."
> — DESIGN.md:L2, sentence 6

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For every terminal reserve-missed outcome, let `G` be aggregate gross entry proceeds. The implementation must allocate `80% * G` to the winning ticket, `5% * G` to the protocol treasury, and the remaining `15% * G` to the sponsor. The document separately fixes the applicable dust rule:

> "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — DESIGN.md:L2, sentence 8

Thus the protocol fee must be calculated on the aggregate pot and rounded down, and all of `G` must remain represented by the winner, sponsor, and treasury liabilities. In the reachable implementation, gross proceeds are integral multiples of the fixed entry price, so the 80% and 5% calculations must in fact be exact and the lossless remainder must be exactly 15% (`target/packages/contracts/src/Raffle.sol:L223-L233`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`).

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L21
uint256 internal constant BPS = 10_000;

/// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
uint256 internal constant PROTOCOL_FEE_BPS = 500;

/// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
uint256 internal constant CASH_WINNER_BPS = 8000;

/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;
```

- The denominator, treasury rate, cash-winner rate, and entry price are compile-time constants (`target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`). There is no storage-backed rate or setter on this path.
- Each successful purchase computes `grossAmount = entryCount * ENTRY_PRICE`, transfers that amount into the raffle, and adds the same amount to `unsettledPot` (`target/packages/contracts/src/Raffle.sol:L215-L233`). The prospective `uint128` total-entry sum is checked before either update (`target/packages/contracts/src/Raffle.sol:L218-L230`).
- `unsettledPot` is therefore a multiple of `1_000_000`, while `BPS` is `10_000`; every reachable settled pot is divisible by the basis-point denominator (`target/packages/contracts/src/Raffle.sol:L223-L233`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L21`).

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L524
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

- An accepted callback selects `CashWon` exactly when `totalEntries < reserveEntries`; equality and excess select the disjoint `NftWon` branch (`target/packages/contracts/src/Raffle.sol:L518-L523`). The inherited callback gateway admits only the configured wrapper before calling this override (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).

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

- Both percentages use the same aggregate `grossPot`, not per-ticket calculations (`target/packages/contracts/src/Raffle.sol:L539-L547`). In `CashWon`, winner proceeds receive `8000 / 10000`, protocol fees receive `500 / 10000`, and sponsor proceeds receive the entire subtraction remainder (`target/packages/contracts/src/Raffle.sol:L540-L555`). The three stored liabilities sum to `grossPot` by construction.
- The three-argument `Math.mulDiv` is expressly floor division and returns `low / denominator` when the 256-bit product does not overflow (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215`). Its `mul512` callee constructs the exact product limbs (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L32-L46`). Here `grossPot <= type(uint128).max * 1_000_000`, so multiplying by either `8000` or `500` remains below `2^256` and takes that ordinary floor-division branch (`target/packages/contracts/src/Raffle.sol:L85-L91`, `L218-L233`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L21`).
- `settlementComplete` prevents a second allocation, and the helper replaces the unallocated pot with all three liabilities before returning (`target/packages/contracts/src/Raffle.sol:L533-L555`).

```solidity
// target/packages/contracts/src/Raffle.sol:L320-L343
address winner = ownerOf(ticketId);
if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

winnerRecipient = winner;
winnerRedeemed = true;
_burn(ticketId);

address deliveredPrizeToken = address(0);
uint256 deliveredPrizeTokenId = 0;
if (result == Status.NftWon) {
    if (prizeClaimed) revert PrizeAlreadyClaimed();
    prizeClaimed = true;
    deliveredPrizeToken = address(prizeToken);
    deliveredPrizeTokenId = prizeTokenId;
    prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
    if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
        revert PrizeDeliveryVerificationFailed(winner);
    }
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}
```

```solidity
// target/packages/contracts/src/Raffle.sol:L374-L392
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
```

- Redemption reads the current ERC-721 owner, requires that owner as caller, clears the complete winner liability, and transfers exactly that amount (`target/packages/contracts/src/Raffle.sol:L309-L345`). The inherited `ownerOf` resolves a live owner or reverts, and `_burn` removes that ticket after the explicit owner check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63`, `L303-L307`, `L420-L432`).
- Sponsor and protocol releases likewise read and clear their complete stored liabilities, but transfer only to the initialized `sponsorRecipient` and `protocolTreasury` (`target/packages/contracts/src/Raffle.sol:L374-L391`). Those destinations are stored during the factory-only, one-time initialization (`target/packages/contracts/src/Raffle.sol:L176-L205`), and the factory passes its immutable treasury plus the sponsor-selected recipient (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`, `L97-L120`).
- `_transferQuote` rejects protocol sinks and invokes `safeTransfer` for the exact amount (`target/packages/contracts/src/Raffle.sol:L560-L567`). `SafeERC20.safeTransfer` reverts if its underlying call does not satisfy the accepted success convention (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37`, `L167-L200`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → immutable implementation: the factory fixes the quote token, wrapper, treasury, and implementation once (`target/packages/contracts/src/RaffleFactory.sol:L58-L92`). `Clones.clone` builds a minimal proxy pointing at that supplied implementation (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L9-L18`, `L32-L62`), so canonical clones do not select an alternate settlement implementation. ✓
- `RaffleFactory.createRaffle` → `_validateCreateParams` → `Raffle.initialize`: the factory rejects a zero reserve, passes `reserveEntries` and its fixed treasury, and the clone stores the reserve and payout destinations during its one permitted initialization (`target/packages/contracts/src/RaffleFactory.sol:L97-L120`, `L152-L179`; `target/packages/contracts/src/Raffle.sol:L175-L205`). ✓
- `buyEntries` → `SafeERC20.safeTransferFrom` → `unsettledPot`: only an `Active` raffle before sale end accepts a positive `uint128` entry count; the total-entry bound is checked, the nominal gross is transferred, and that same gross is accumulated (`target/packages/contracts/src/Raffle.sol:L209-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47`, `L202-L244`). Because `ENTRY_PRICE = 1_000_000`, every reachable pot is a denominator-divisible aggregate rather than a dust-bearing arbitrary integer (`target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`). ✓
- `requestDraw` → `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: draw initiation requires at least one entry and changes status from `Active` to `Drawing` before the request (`target/packages/contracts/src/Raffle.sol:L239-L260`). The authenticated, current, timely callback makes reserve miss exactly the `CashWon` branch (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- `settleWinningTicket` → `_settleWinningTicket`: the permissionless direct settlement entrypoint has no alternate calculation; it calls the private helper once under `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L303-L306`, `L533-L558`). ✓
- `redeemWinningTicket` → `_settleWinningTicket`: if not already settled, redemption calls the same helper; otherwise it requires the previously recorded winning ticket. It then pays the current owner from the stored winner bucket (`target/packages/contracts/src/Raffle.sol:L308-L345`). ✓
- `_settleWinningTicket`, `CashWon` branch: the helper validates the selected ticket range, computes the 5% and 80% allocations from one `grossPot`, derives the sponsor remainder, and stores all three before any payout (`target/packages/contracts/src/Raffle.sol:L533-L557`, `L577-L585`). ✓
- `releaseSponsorProceeds` and `releaseProtocolFees` → `_transferQuote` → `SafeERC20.safeTransfer`: both complete buckets go to their fixed destinations, and a failed token call reverts the release (`target/packages/contracts/src/Raffle.sol:L374-L391`, `L560-L567`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37`, `L167-L200`). ✓
- `redeemWinningTicket` → `_transferQuote` → `SafeERC20.safeTransfer`: the current owner receives the complete 80% bucket; state is cleared before the external token call, and the whole transaction reverts if that call fails (`target/packages/contracts/src/Raffle.sol:L320-L345`, `L560-L567`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37`, `L167-L200`). ✓
- Modifier/base-contract path: both settlement entrypoints and all three quote-payout entrypoints use `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L303-L309`, `L374-L390`); the modifier rejects nested guarded calls for the duration of the body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73`, `L88-L106`). The one-time `settlementComplete` gate independently prevents repeat allocation (`target/packages/contracts/src/Raffle.sol:L533-L555`). ✓
- Non-cash branches: `NftWon` is selected only when the reserve is met and uses the separate sponsor-minus-protocol allocation (`target/packages/contracts/src/Raffle.sol:L521-L522`, `L543-L549`). `enableRefunds` instead moves the full pot to refund liability and sets `Refunding`; settlement rejects that status (`target/packages/contracts/src/Raffle.sol:L275-L300`, `L533-L537`). Neither branch is a reserve-missed cash allocation path. ✓
- Ignored callback branch: an in-flight, wrong-state, wrong-ID, wrong-shape, or late callback returns without changing the result, so it creates no partially allocated `CashWon` state (`target/packages/contracts/src/Raffle.sol:L509-L516`). ✓

---

**Searched:**

- Production scope enumeration under `target/packages/contracts/src` → exactly five files: `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, and `libraries/RaffleConstants.sol`; each was read in full.
- `jq 'length' target/dependency-hashes.json` → `31`; SHA-256 verification against all entries at `target/dependency-hashes.json:L2-L32` → all 31 files `OK`.
- `CASH_WINNER_BPS|PROTOCOL_FEE_BPS` across the five production files and all 31 pinned dependencies → 4 matching lines: the two declarations at `RaffleConstants.sol:L15,L18` and the two uses at `Raffle.sol:L540,L546`; 0 dependency hits.
- `15%|1_500|1500|SPONSOR_BPS` across the same 36 files → 0 hits. The sponsor share is not separately named; the implementing expression is the remainder subtraction at `Raffle.sol:L547`.
- `_settleWinningTicket` under production source → 3 hits, all in `Raffle.sol`: direct-settlement call at L305, redemption call at L315, and private definition at L533. No wrapper or third caller exists in production scope.
- Assignment search for `unsettledPot|winnerProceeds|sponsorProceeds|protocolFees` under production source → 9 matching write lines, all in `Raffle.sol`: L233, L297, L341, L378, L388, L548, and L553-L555. The only positive `unsettledPot` write is purchase accumulation at L233; the only allocation writes are L548 and L554-L555.
- `grossPot|grossSales|grossAmount` under production source → 13 matching lines: 10 in `Raffle.sol` and 3 in `IRaffle.sol`; the operative collection and settlement lines are `Raffle.sol:L223-L236` and `L539-L557`.
- `CashWon|reserveEntries` across all 36 files → 25 matching production lines (6 in `Raffle.sol`, 3 in `RaffleFactory.sol`, 12 in `IRaffle.sol`, 4 in `IRaffleFactory.sol`) and 0 dependency hits.
- `winner|sponsor|treasury|gross|proceeds` across all 31 pinned dependencies → 0 hits. `basis.?points|bps|80%|15%|5%` across those dependencies → 0 hits. No dependency defines an alternate raffle rate or liability bucket.
- `reserve|missed|cash.?won` across all 31 dependencies → 5 irrelevant substring hits only: `preserve` twice in `Bytes.sol`, `reserved` twice in `Strings.sol`, and `preserve` once in `ERC721.sol`; no reserve-result logic.
- `mulDiv` across all 36 files → 6 matching lines: 2 application calls in `Raffle.sol`, 1 explanatory reference in `RaffleConstants.sol`, and 3 lines in `Math.sol`. The invoked three-argument definition and its `mul512` callee were read at `Math.sol:L32-L46` and `L199-L277`; the four-argument rounding overload at L279-L284 is not called.
- `unchecked|assembly|delegatecall|callcode|selfdestruct|upgrade|set[A-Z].*(Fee|Rate|Bps|BPS)` across all five production files → no economic `unchecked` block, no delegate/callcode/selfdestruct, and no rate setter. The sole production assembly hit is the native-fee refund call at `Raffle.sol:L266-L268`; it does not read or write quote-token liabilities. The fixed-rate declarations are `RaffleConstants.sol:L15,L18`.
- Imports and inherited paths were followed through `Clones.clone`, `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords`, `ReentrancyGuard.nonReentrant`, `ERC721.ownerOf/_burn/_update`, `Math.mulDiv/mul512`, `SafeERC20.safeTransfer/safeTransferFrom`, and their directly used storage/error/interface callees. The remaining hash-pinned files had no economic-symbol hits and are not on the reserve-result allocation or quote-transfer call chains.

---

**How the verdict was reached:** Let `N` be the lifetime sold-entry count on a raffle that reaches `CashWon`. Purchases and the `uint128` aggregate bound make `G = N * 1_000_000` the recorded `unsettledPot` (`target/packages/contracts/src/Raffle.sol:L209-L233`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21`). Sales stop before `Drawing`, and an accepted callback changes `Drawing` to `CashWon` only when `N < reserveEntries` (`target/packages/contracts/src/Raffle.sol:L239-L260`, `L509-L523`), so that pot is frozen on the relevant path.

The settlement arithmetic is therefore:

- winner: `floor(G * 8000 / 10000) = N * 800_000 = 80% * G`;
- treasury: `floor(G * 500 / 10000) = N * 50_000 = 5% * G`;
- sponsor: `G - winner - treasury = N * 150_000 = 15% * G`.

The rate constants are at `target/packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`; the floor operations and remainder assignment are at `target/packages/contracts/src/Raffle.sol:L539-L555`; and the library's floor semantics are at `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L215`. The arithmetic both matches the three percentages and conserves every raw unit. Because `1_000_000` is divisible by `10_000`, no reachable gross pot produces winner or protocol dust; the sponsor remainder is exactly 15%, not merely at least 15%.

This is `implemented`, not `partial`: the only two callers of the allocation helper converge on the same cash branch, and the refund, reserve-met, and ignored-callback branches cannot produce an alternative `CashWon` allocation (`target/packages/contracts/src/Raffle.sol:L303-L315`, `L509-L557`). It is not `contradicted`: the apparent absence of a `15%` constant is explained by the required lossless remainder, which is exactly 15% for every reachable gross pot (`target/packages/contracts/src/Raffle.sol:L546-L555`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L21`). It is not `stronger-than-spec`: the enforced allocation is the documented 80/15/5 split rather than an additional restriction.

Confidence is high because all first-party production files were read, the full 31-file pinned dependency set was hash-verified and vocabulary-swept, and every relevant constructor, clone, callback, modifier, arithmetic callee, ownership base function, caller, branch, and payout helper was followed.

---

**Open questions:**

- None affecting the allocation verdict within the document's stated trust boundary. The document says, verbatim, "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`, sentence 16). The concrete deployed quote-token implementation is not among the 31 pinned source dependencies (`target/dependency-hashes.json:L2-L32`); locally, `IRaffle` records the fee-free/non-rebasing assumption (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`) and `SafeERC20` establishes call/return success rather than recipient balance deltas (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L167-L200`). Verifying deployed-token identity or runtime balance-delta semantics would require deployment evidence outside this frozen target, but the specification expressly places that dependency inside the trusted boundary and REQ-21's checkable property is the allocation.
