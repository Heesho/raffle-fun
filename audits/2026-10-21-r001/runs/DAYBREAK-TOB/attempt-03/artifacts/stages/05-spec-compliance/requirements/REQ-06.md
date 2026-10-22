## REQ-06 — Canonical USDC identity

> "One entry costs 1,000,000 units of canonical six-decimal USDC."
> — `DESIGN.md:L2, sentence 2`

---

**Verdict:** absent · confidence: high

---

**What this demands of an implementation:** The quote-token trust boundary must bind every entry purchase to the target chain's canonical USDC contract, rather than merely to an arbitrary contract that presents compatible ERC-20 metadata. The accepted token must also use six decimals, and one entry must debit exactly 1,000,000 raw units of that bound token. The supplied checkability criterion makes canonical contract identity—not a token name—the decisive property.

---

**Where enforcement lives:**

No canonical-USDC identity enforcement was found. The implementation does enforce the adjacent numeric properties:

```solidity
// packages/contracts/src/libraries/RaffleConstants.sol:L20-L24
/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;

/// @notice Decimal precision required from the immutable quote token.
uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;
```

The factory constructor accepts a caller-supplied address, checks only that it has code and reports six decimals, then stores that same address and passes it into the shared implementation:

```solidity
// packages/contracts/src/RaffleFactory.sol:L58-L62
/// @notice Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.
/// @dev The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code.
///      Deployment tooling must supply and verify the target chain's official USDC address because the constructor
///      cannot prove token identity from metadata.
/// @param quoteToken_ Target chain's official six-decimal USDC contract trusted by every raffle.

// packages/contracts/src/RaffleFactory.sol:L65-L78
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

// packages/contracts/src/RaffleFactory.sol:L85-L89
    quoteToken = quoteToken_;
    vrfWrapper = vrfWrapper_;
    protocolTreasury = protocolTreasury_;

    address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
```

The `_requireContract` callee is only a code-length predicate; it does not attest an address, runtime-code hash, chain-specific allowlist entry, or deployment provenance:

```solidity
// packages/contracts/src/RaffleFactory.sol:L181-L185
/// @dev Reverts unless an address contains deployed code.
/// @param account Address required to be a contract.
function _requireContract(address account) private view {
    if (account.code.length == 0) revert NotContract(account);
}
```

The `Raffle` constructor adds only nonzero checks and persists exactly the factory-supplied token. Its own NatSpec states that clones share these immutables:

```solidity
// packages/contracts/src/Raffle.sol:L151-L163
/// @notice Deploys and locks the implementation shared by one factory's minimal-proxy raffles.
/// @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
/// @param quoteToken_ Canonical six-decimal USDC contract fixed for the implementation and every clone.
/// @param vrfWrapper_ Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.
constructor(address quoteToken_, address vrfWrapper_)
    ERC721("", "")
    VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
{
    if (msg.sender == address(0) || quoteToken_ == address(0)) revert ZeroAddress();

    factory = msg.sender;
    quoteToken = IERC20(quoteToken_);
```

Every successful purchase computes the specified raw amount but invokes `transferFrom` on whichever address survived that constructor path:

```solidity
// packages/contracts/src/Raffle.sol:L209-L224
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
    if (entryCount == 0) revert ZeroEntryCount();
    if (entryCount > type(uint128).max - totalEntries) {
        revert TotalEntriesOverflow(totalEntries, entryCount);
    }

    uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
    quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

The called `SafeERC20` wrapper checks call/return behavior, not token identity: `safeTransferFrom` delegates the supplied `token` address (`SafeERC20.sol:L43-L46`), and `_safeTransferFrom` calls that address and accepts either boolean `true` or a successful empty return from an address with code (`SafeERC20.sol:L212-L240`).

---

**Paths walked:**

- `RaffleFactory.constructor(canonical USDC, wrapper, treasury)` → `_requireContract` → `decimals() == 6` → immutable assignment → `new Raffle`: this configuration can use canonical USDC, but only because the deployer supplied it; no executed comparison establishes that identity (`RaffleFactory.sol:L65-L89`, `L181-L185`).
- `RaffleFactory.constructor(substitute six-decimal contract, wrapper, treasury)` follows the same code path. A substitute with nonzero code whose `decimals()` call returns `6` reaches `quoteToken = quoteToken_` and `new Raffle(quoteToken_, ...)` without a distinct branch or rejection (`RaffleFactory.sol:L65-L89`, `RaffleConstants.sol:L23-L24`). This is the unenforced path.
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)`: clone creation supplies no replacement quote token, so it preserves rather than repairs the constructor selection (`RaffleFactory.sol:L89-L91`, `L97-L106`; `Raffle.sol:L151-L163`).
- `Raffle.buyEntries` → `SafeERC20.safeTransferFrom` → `_safeTransferFrom`: every purchase charges `entryCount * 1_000_000`, but the external call target is the stored, caller-selected constructor address (`Raffle.sol:L209-L224`; `SafeERC20.sol:L43-L46`, `L212-L240`).
- Refund, cash-winner, sponsor, and treasury release branches all return or distribute the same selected token through `_transferQuote`: refund calls it at `Raffle.sol:L367-L369`, cash redemption at `L339-L342`, sponsor release at `L375-L380`, protocol release at `L385-L390`, and the helper calls `quoteToken.safeTransfer` at `L560-L566`. None introduces an identity check.
- The purchase modifier is only `nonReentrant` (`Raffle.sol:L209-L213`). Its base implementation brackets the function body with reentrancy-state updates and contains no quote-token predicate (`ReentrancyGuard.sol:L69-L73`, `L88-L105`). The factory constructor has no modifier (`RaffleFactory.sol:L65-L92`), and `quoteToken_` is an unconstrained `address` parameter at `L65`.

---

**Searched:**

- Scope completeness → read all five first-party production files and all 31 files named by `target/dependency-hashes.json`; all 31 dependency SHA-256 values matched the manifest (`declared=31 mismatches=0`).
- `canonical|official|USDC` across those 36 source files → 33 hits: 30 are comments/NatSpec; the other three are the unrelated local name `canonicalFactory` in destination screening at `Raffle.sol:L598-L603`. No executable canonical quote-token comparison was found.
- `quoteToken_|quoteToken|quote-token|quote token` across the same scope → 68 hits. The executable selection chain resolves to the constructor checks/assignment at `RaffleFactory.sol:L65-L89`, the implementation assignment at `Raffle.sol:L155-L163`, and the two token member calls at `Raffle.sol:L224` and `L566`.
- `decimals|QUOTE_TOKEN_DECIMALS|six-decimal|six decimal` across the same scope → 50 hits. The relevant executable gate is only `IERC20Metadata(quoteToken_).decimals()` compared with `6` at `RaffleFactory.sol:L70-L78` and `RaffleConstants.sol:L23-L24`.
- `codehash|extcodehash|chainid|chainId|block.chainid|USDC_ADDRESS|TOKEN_ADDRESS` across the same scope → 6 hits, all generic `bytecodeHash` text/code in the unused-for-this-purpose `Create2` dependency (`Create2.sol:L57-L89`); the five first-party production files produced 0 hits.
- `0x[0-9a-f]{40}|block.chainid|chainid|extcodehash|codehash|USDC_ADDRESS|TOKEN_ADDRESS` in the five first-party files → 0 hits. There is no source-visible hard-coded address, chain-address map, or runtime-code attestation to inspect.
- `name()` and `symbol()` across the 36 files → 5 hits each, all interface declarations, inherited ERC-721/ticket display functions, or the Chainlink LINK interface; neither is called on `quoteToken_`. Metadata names would not establish identity in any event.
- `new RaffleFactory` across the 36 files → 0 hits; no in-scope deployment wrapper validates the constructor argument. `buyEntries(` → 2 hits, the interface declaration and the external implementation only, so there is no in-scope caller-side identity precheck.
- Modifiers and bases on the relevant route → `buyEntries` has `nonReentrant` only (`Raffle.sol:L209-L213`); `RaffleFactory`'s constructor has no modifier (`RaffleFactory.sol:L65-L92`); the inherited guard only controls nested execution (`ReentrancyGuard.sol:L69-L105`).

---

**How the verdict was reached:** The exact 1,000,000-unit price and the six-decimal metadata constraint are implemented, but they are lookalike properties that a substitute token can satisfy. The checkable trust-boundary requirement is canonical contract identity, and no address equality, per-chain allowlist, code-hash attestation, or in-scope deployment validation enforces it before the supplied address becomes the immutable payment token. This is **absent**, not `implemented`.

It is not `partial`: the canonical-address constructor case succeeds because of the deployer's external choice, not because one implementation branch enforces identity while another omits it. It is not best classified as `contradicted`: the source does not force a different token and can be configured with canonical USDC; it permits both and explicitly assigns identity verification to deployment tooling (`RaffleFactory.sol:L58-L62`; `IRaffleFactory.sol:L6-L9`). The missing source-level trust-boundary enforcement is therefore the operative gap.

---

**Open questions:**

- The actual `quoteToken` address and provenance of any deployed factory are outside the frozen source scope. Deployment records could establish that a particular instance was configured with official USDC, as the code expects tooling to verify (`RaffleFactory.sol:L58-L62`; `IRaffleFactory.sol:L6-L9`), but they would not add canonical-identity enforcement to this implementation.
- No ambiguity or contradiction was found in the requirement itself.
