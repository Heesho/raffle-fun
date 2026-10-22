## REQ-49 — Quote-token dependency is fixed for every canonical raffle

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — DESIGN.md:L2, sentence 16

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For this record's supplied checkable property, one quote-token contract must be selected for the canonical factory deployment, every quote-token receipt and payout must target that same contract, and neither raffle sponsors nor any later caller may substitute a different token. The word “trusted” does not require the contracts to prove official-USDC identity or transfer semantics on chain; it makes correct deployment selection part of the trust boundary. The implementation must nevertheless pin the selected address so that the dependency cannot be replaced after construction.

---

**Where enforcement lives:**

The factory stores both the quote-token address and the implementation address as immutables:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L32-L42
address public immutable override quoteToken;

/// @inheritdoc IRaffleFactory
address public immutable override vrfWrapper;

/// @inheritdoc IRaffleFactory
address public immutable override protocolTreasury;

/// @inheritdoc IRaffleFactory
address public immutable override raffleImplementation;
```

Construction checks that the selected token has code and reports six decimals, assigns it once, passes that exact constructor argument to the sole `Raffle` implementation, and fixes that implementation address:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L78
constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    _requireContract(quoteToken_);
    _requireContract(vrfWrapper_);
    if (protocolTreasury_ == address(0)) revert ZeroAddress();

    uint8 quoteDecimals = 0;
    try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
        quoteDecimals = decimals_;
    } catch {
        revert UnsupportedQuoteToken(quoteToken_);
    }
    if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
        revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
    }
```

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L85-L91
quoteToken = quoteToken_;
vrfWrapper = vrfWrapper_;
protocolTreasury = protocolTreasury_;

address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

`Raffle` independently declares its quote-token reference immutable and assigns it only in the implementation constructor:

```solidity
// target/packages/contracts/src/Raffle.sol:L54-L59
/// @inheritdoc IRaffle
address public immutable override factory;

/// @inheritdoc IRaffle
IERC20 public immutable override quoteToken;
```

```solidity
// target/packages/contracts/src/Raffle.sol:L155-L166
constructor(address quoteToken_, address vrfWrapper_)
    ERC721("", "")
    VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
{
    if (msg.sender == address(0) || quoteToken_ == address(0)) revert ZeroAddress();

    factory = msg.sender;
    quoteToken = IERC20(quoteToken_);

    initialized = true;
    status = Status.Refunding;
}
```

Canonical creation always clones that one immutable implementation. The clone-initialization call supplies raffle-specific sponsor, recipient, prize, identifier, reserve, and timing data, but no quote-token address:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L121
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
// The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
// slither-disable-next-line reentrancy-no-eth
IRaffle(raffle)
    .initialize(
        IRaffle.RaffleInitParams({
        sponsor: msg.sender,
        sponsorRecipient: params.sponsorRecipient,
        protocolTreasury: protocolTreasury,
        prizeToken: params.prizeToken,
        prizeTokenId: params.prizeTokenId,
        raffleId: raffleId,
        reserveEntries: params.reserveEntries,
        endTime: params.endTime
    })
    );
```

```solidity
// target/packages/contracts/src/interfaces/IRaffle.sol:L45-L54
struct RaffleInitParams {
    address sponsor;
    address sponsorRecipient;
    address protocolTreasury;
    address prizeToken;
    uint256 prizeTokenId;
    uint256 raffleId;
    uint128 reserveEntries;
    uint64 endTime;
}
```

The used `Clones.clone(address)` path embeds the supplied implementation address directly into the deployed ERC-1167 runtime and provides no implementation storage slot or retargeting function:

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62
function clone(address implementation, uint256 value) internal returns (address instance) {
    if (address(this).balance < value) {
        revert Errors.InsufficientBalance(address(this).balance, value);
    }
    assembly ("memory-safe") {
        // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
        // of the `implementation` address with the bytecode before the address.
        mstore(0x00, or(shr(232, shl(96, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
        // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
        mstore(0x20, or(shl(120, implementation), 0x5af43d82803e903d91602b57fd5bf3))
        instance := create(value, 0x09, 0x37)
    }
    if (instance == address(0)) {
        revert Errors.FailedDeployment();
    }
}
```

The only direct production calls that move quote tokens both use the immutable `quoteToken`. Purchases use it for inbound `transferFrom`:

```solidity
// target/packages/contracts/src/Raffle.sol:L223-L225
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

Every outbound quote-token branch reaches the same private helper:

```solidity
// target/packages/contracts/src/Raffle.sol:L338-L343
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}
```

```solidity
// target/packages/contracts/src/Raffle.sol:L367-L390
amount = aggregateEntries * ENTRY_PRICE;
remainingRefundLiability -= amount;
_transferQuote(msg.sender, amount);
uint256 liabilityAfter = remainingRefundLiability;
emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
}

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
```

```solidity
// target/packages/contracts/src/Raffle.sol:L560-L566
/// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
/// @param to Immutable or owner-derived recipient of the claim.
/// @param amount Raw six-decimal USDC units transferred.
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

The `SafeERC20` callees preserve the caller-supplied token as the EVM call target. `safeTransfer` and `safeTransferFrom` pass their `token` argument unchanged (`SafeERC20.sol:L33-L46`), and the low-level calls target that same argument at `SafeERC20.sol:L184` and `L227`:

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L46
function safeTransfer(IERC20 token, address to, uint256 value) internal {
    if (!_safeTransfer(token, to, value, true)) {
        revert SafeERC20FailedOperation(address(token));
    }
}

/**
 * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
 * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
 */
function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    if (!_safeTransferFrom(token, from, to, value, true)) {
        revert SafeERC20FailedOperation(address(token));
    }
}
```

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L184
success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
```

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L227
success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
```

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract(quoteToken_)` → `IERC20Metadata(quoteToken_).decimals()` → immutable `quoteToken` assignment → `new Raffle(quoteToken_, vrfWrapper_)` → immutable `raffleImplementation`: the deploy-time token is passed through once and thereafter neither factory field can change (`RaffleFactory.sol:L65-L91`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `Raffle.initialize`: the ERC-1167 bytecode has a fixed implementation target (`Clones.sol:L47-L62`), and neither `RaffleInitParams` nor the initialization writes at `Raffle.sol:L176-L205` contain a quote-token field. A sponsor can choose `prizeToken`, but cannot choose or replace `quoteToken` (`IRaffle.sol:L45-L54`; `RaffleFactory.sol:L105-L121`). ✓
- `Raffle.buyEntries` → `quoteToken.safeTransferFrom` → `SafeERC20.safeTransferFrom` → `_safeTransferFrom`: the only inbound quote-token movement calls the immutable field, and the callee's EVM target remains its `token` argument (`Raffle.sol:L209-L225`; `SafeERC20.sol:L43-L46`, `L212-L240`). ✓
- `Raffle.redeemWinningTicket`, `NftWon` branch: this branch transfers only the independently configured prize NFT at `Raffle.sol:L329-L337`; it performs no quote-token operation. ✓
- `Raffle.redeemWinningTicket`, `CashWon` branch → `_transferQuote` → `_isProtocolDestination` → `quoteToken.safeTransfer` → `SafeERC20._safeTransfer`: the recipient is screened, but the token target remains the immutable field (`Raffle.sol:L338-L343`, `L560-L566`, `L593-L604`; `SafeERC20.sol:L33-L37`, `L176-L199`). ✓
- `Raffle.refundTickets` → `_transferQuote`: the refund branch uses the same helper and immutable target (`Raffle.sol:L349-L370`, `L560-L566`). ✓
- `Raffle.releaseSponsorProceeds` → `_transferQuote` and `Raffle.releaseProtocolFees` → `_transferQuote`: both independent payout paths use the same helper and immutable target (`Raffle.sol:L374-L391`, `L560-L566`). ✓
- `Raffle.enableRefunds` and `_settleWinningTicket` only move amounts among local accounting buckets (`Raffle.sol:L296-L300`, `L533-L557`); neither introduces another token call target. ✓
- Base contracts and modifiers were followed through the prescribed dependency closure. `ReentrancyGuard` gates the quote-moving external entrypoints but has no token field (`ReentrancyGuard.sol:L32-L37`, `L69-L73`); ERC-721 and VRF bases do not write `Raffle.quoteToken`. No inherited or library branch retargets an ERC-20 call.

---

**Searched:**

- Scope coverage at frozen target `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`: read all five production files in full (`Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, `RaffleConstants.sol`) and all 31 files named at `target/dependency-hashes.json:L2-L32`; recomputing every listed SHA-256 produced 31 `OK` results.
- Case-insensitive `quote.?token|usdc|payment.?token|settlement.?token|currency` in the five production files → 84 hits: `Raffle.sol` 15, `RaffleFactory.sol` 18, `IRaffle.sol` 34, `IRaffleFactory.sol` 13, and `RaffleConstants.sol` 4. Refining to executable `quoteToken.(safeTransferFrom|safeTransfer|transferFrom|transfer|approve|balanceOf)` → exactly 2 hits, `Raffle.sol:L224` and `L566`.
- `_transferQuote` in production → exactly 5 hits: four callers at `Raffle.sol:L342`, `L369`, `L380`, and `L390`, plus the helper at `L564`. All four callers therefore converge on `quoteToken.safeTransfer` at `L566`.
- `setQuote|updateQuote|changeQuote|replaceQuote|configureQuote|reconfigureQuote|quoteToken\s*=` in production → exactly 2 hits, both constructor assignments: `Raffle.sol:L162` and `RaffleFactory.sol:L85`; no setter or post-construction write.
- `quoteToken_` in production → 12 hits, all in constructor NatSpec, constructor parameters, construction-time validation/assignment, or the factory's pass-through to `new Raffle`; no runtime method parameter carries it (`Raffle.sol:L153-L162`; `RaffleFactory.sol:L62-L89`).
- Function-declaration sweep of `Raffle.sol` and `RaffleFactory.sol` → 32 declarations; none is a quote-token setter, general configuration setter, implementation setter, or upgrade function. Executable search for `delegatecall(`, `selfdestruct(`, or an upgrade/implementation-replacement function → 0 hits.
- Dependency-key search for `upgradeable|erc1967|transparent|beacon|uups|proxy.sol` → 0 hits. The only proxy-related manifest entry is `@openzeppelin/contracts/proxy/Clones.sol`; its used `clone(address)` branch embeds a fixed implementation (`Clones.sol:L32-L62`).
- `quote.?token|usdc` across all 31 dependency files → 0 hits. The inherited ERC-721, reentrancy, and VRF bases therefore expose no quote-token field or quote-token retargeting path; the only dependency that receives the ERC-20 target is the generic `SafeERC20` library at the production call sites already enumerated.
- `IERC20|SafeERC20|ERC20` in production → 10 hits, limited to the quote-token import/type/immutable/cast/helper documentation and the factory's metadata check (`Raffle.sol:L7-L8`, `L29`, `L58`, `L162`, `L560`; `IRaffle.sol:L5`, `L424`; `RaffleFactory.sol:L5`, `L71`). Search for production low-level ERC-20 transfer selectors/calls → 0 hits; the only low-level ERC-20 calls are inside the pinned `SafeERC20` dependency and use the passed token argument (`SafeERC20.sol:L176-L240`).
- All production `safeTransferFrom|safeTransfer|transferFrom|transfer|transferAndCall` spellings were reviewed. Executable non-quote hits are prize-NFT operations at `Raffle.sol:L334`, `L404` and `RaffleFactory.sol:L128`; they use `prizeToken`/`prize`, not an alternate ERC-20 quote asset.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every reachable branch that actually moves quote tokens targets `Raffle.quoteToken`, that field is immutable, every canonical clone runs the same fixed implementation carrying that immutable, and clone initialization exposes no replacement token. No caller, modifier, base contract, dependency, administrative path, or upgrade path supplies a second ERC-20 target.

The factory constructor deliberately accepts the trusted address rather than hard-coding a chain-specific USDC address. That is not a divergence from “Quote token and Chainlink wrapper are trusted canonical dependencies”; the implementation itself states that deployment tooling must establish official identity and that on-chain construction checks only code and six-decimal metadata (`RaffleFactory.sol:L58-L78`; `IRaffleFactory.sol:L6-L9`). Once selected, the address is pinned exactly as the supplied checkable criterion requires. This is not `stronger-than-spec`: the contract/code and six-decimal checks operationalize properties already attributed to the canonical dependency, while its deeper behavior remains trusted.

---

**Open questions:**

- The frozen source does not establish which concrete address deployment tooling supplied as `quoteToken_`; official-USDC provenance must come from deployment records. `IRaffleFactory` explicitly assigns that verification to deployment tooling (`IRaffleFactory.sol:L7-L9`), so this does not change the source-level verdict that the selected address cannot be replaced.
