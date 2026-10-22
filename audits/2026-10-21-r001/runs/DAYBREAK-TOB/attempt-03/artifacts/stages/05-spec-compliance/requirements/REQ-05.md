## REQ-05 — fixed one-USDC entry price

> "One entry costs 1,000,000 units of canonical six-decimal USDC."
> — DESIGN.md:L2, sentence 2

**Verdict:** implemented · confidence: medium

---

**What this demands of an implementation:** For every successful purchase of `n` entries, the amount charged must be exactly `n * 1,000,000` raw units of the raffle's fixed six-decimal quote token. The unit price must not vary by caller, recipient, branch, or mutable configuration. The document also fixes the trust boundary verbatim: "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`).

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L24
/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;

/// @notice Decimal precision required from the immutable quote token.
uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;
```

- The price and required precision are compile-time constants, `1_000_000` and `6` (`target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L24`). `Raffle.ENTRY_PRICE` aliases the library constant and is itself public and constant (`target/packages/contracts/src/Raffle.sol:L41-L45`).

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L224
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

- `entryCount` is a `uint128`, is required to be positive, and is widened to `uint256` before multiplication (`target/packages/contracts/src/Raffle.sol:L209-L223`). Thus its greatest possible product with `1_000_000` is below `2^148`, so this checked `uint256` multiplication has no overflowing input (`target/packages/contracts/src/Raffle.sol:L2,L209-L223`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L21`).
- There is no pricing branch: every call that passes the preconditions computes `grossAmount` as the exact product and supplies that amount to the immutable `quoteToken` before range state is written and the ticket is minted (`target/packages/contracts/src/Raffle.sol:L215-L236`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L70-L78
uint8 quoteDecimals = 0;
try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
    quoteDecimals = decimals_;
} catch {
    revert UnsupportedQuoteToken(quoteToken_);
}
if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
    revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
}

// target/packages/contracts/src/RaffleFactory.sol:L85-L91
quoteToken = quoteToken_;
vrfWrapper = vrfWrapper_;
protocolTreasury = protocolTreasury_;

address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

- Factory construction requires code at the quote-token address, requires its reported decimals to equal the constant `6`, stores the address immutably, and passes that same address into the one shared `Raffle` implementation (`target/packages/contracts/src/RaffleFactory.sol:L30-L34,L58-L91,L181-L185`). The `Raffle` constructor stores it as an immutable `IERC20` (`target/packages/contracts/src/Raffle.sol:L52-L59,L151-L165`).
- `createRaffle` always clones that stored implementation (`target/packages/contracts/src/RaffleFactory.sol:L97-L110`). The selected `Clones.clone` overload delegates to a fixed implementation address and rejects failed deployment (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`), while clone initialization has no price or quote-token field (`target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46
function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    if (!_safeTransferFrom(token, from, to, value, true)) {
        revert SafeERC20FailedOperation(address(token));
    }
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L219-L240
bytes4 selector = IERC20.transferFrom.selector;

assembly ("memory-safe") {
    let fmp := mload(0x40)
    mstore(0x00, selector)
    mstore(0x04, and(from, shr(96, not(0))))
    mstore(0x24, and(to, shr(96, not(0))))
    mstore(0x44, value)
    success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
    // if call success and return is true, all is good.
    // otherwise (not success or return is not true), we need to perform further checks
    if iszero(and(success, eq(mload(0x00), 1))) {
        // if the call was a failure and bubble is enabled, bubble the error
        if and(iszero(success), bubble) {
            returndatacopy(fmp, 0x00, returndatasize())
            revert(fmp, returndatasize())
        }
        // if the return value is not true, then the call is only successful if:
        // - the token address has code
        // - the returndata is empty
        success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
    }
```

- `SafeERC20.safeTransferFrom` forwards the same `value` into ERC-20 `transferFrom` calldata and rejects a false return or failed call, while allowing the ERC-20 convention of empty successful return data (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47,L202-L243`). It does not independently compare sender or receiver balance deltas (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L202-L243`). The production interface expressly identifies the configured token as trusted canonical six-decimal USDC with fee-free, non-rebasing transfers (`target/packages/contracts/src/interfaces/IRaffle.sol:L8-L15`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract` → `IERC20Metadata.decimals` → immutable `quoteToken` → `new Raffle`: code presence and exactly six decimals are required before the same address is embedded in the shared implementation (`target/packages/contracts/src/RaffleFactory.sol:L30-L34,L58-L91,L181-L185`; `target/packages/contracts/src/Raffle.sol:L52-L59,L151-L165`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `Raffle.initialize`: every factory-created clone delegates to the fixed implementation, while initialization has no quote-token or entry-price field (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`; `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`). ✓
- `buyEntries` rejection paths: wrong status, ended sale, zero recipient, zero `entryCount`, and cumulative `uint128` overflow all revert before the transfer or mint (`target/packages/contracts/src/Raffle.sol:L209-L224`). They do not complete a purchase at another price. ✓
- `buyEntries` success with an EOA recipient: the only path computes `uint256(entryCount) * ENTRY_PRICE`, transfers that `grossAmount`, records the matching range and liability, and then mints; safe-mint performs no receiver call when the recipient has no code (`target/packages/contracts/src/Raffle.sol:L223-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L18-L33`). ✓
- `buyEntries` success with a contract recipient: it reaches the same charge before `_safeMint`; the inherited safe-mint path then performs the receiver callback (`target/packages/contracts/src/Raffle.sol:L223-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L49`). The purchase holds `nonReentrant` across that callback (`target/packages/contracts/src/Raffle.sol:L209-L213`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73,L88-L105`), so the callback cannot enter another protected purchase path. ✓
- `buyEntries` → `SafeERC20.safeTransferFrom` → `_safeTransferFrom` → external token `transferFrom`: the exact computed value is encoded unchanged; false or reverting calls abort the transaction, and true or empty-return successful calls continue (`target/packages/contracts/src/Raffle.sol:L223-L224`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47,L202-L243`). ✓ under the documented trusted-token model at `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`.
- No alternate in-scope caller, wrapper, public mint, or mutable price path was found. The sole production `_safeMint` call is reached from `buyEntries` after the charge (`target/packages/contracts/src/Raffle.sol:L223-L235`); the inherited `_safeMint` functions are internal (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`). ✓

---

**Searched:**

- Bounded scope → 36 Solidity files: all five production files and all 31 paths in `target/dependency-hashes.json`; every dependency was read in full and all 31 SHA-256 values matched the manifest.
- `ENTRY_PRICE` → 10 hits: the only assignments are the alias at `target/packages/contracts/src/Raffle.sol:L44` and literal definition at `target/packages/contracts/src/libraries/RaffleConstants.sol:L21`; the remaining hits are the purchase/refund/gross-sales uses and interface documentation/declaration. No mutable write exists.
- `buyEntries\(` → 2 hits: the implementation at `target/packages/contracts/src/Raffle.sol:L209` and interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L314`; no in-scope caller or wrapper.
- `grossAmount\s*=` → 1 hit, the exact multiplication at `target/packages/contracts/src/Raffle.sol:L223`.
- `_safeMint\(` → 4 hits: one production call at `target/packages/contracts/src/Raffle.sol:L235` and three inherited definition/delegation hits at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L287`; no alternate production mint call.
- `safeTransferFrom\(` → 13 hits: the relevant ERC-20 purchase call is `target/packages/contracts/src/Raffle.sol:L224`, whose implementation chain is `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L43-L46,L212-L243`; the other hits are the prize transfer, ERC-721 overloads, and unused helper variants.
- `quoteToken\s*=` → 2 hits, both immutable construction assignments: `target/packages/contracts/src/RaffleFactory.sol:L85` and `target/packages/contracts/src/Raffle.sol:L162`.
- `decimals\(` → 5 hits: the relevant runtime call is `target/packages/contracts/src/RaffleFactory.sol:L71`, checked at `L76-L78`; the other hits are an error signature and dependency interface declarations.
- `official|canonical` → 27 hits. The identity-relevant hits say deployment tooling must verify the official USDC address because construction cannot prove identity (`target/packages/contracts/src/RaffleFactory.sol:L58-L63`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`); none adds another purchase-price branch.
- `balanceOf\(` → 5 dependency-only hits and zero hits in the five production files. The target performs no local ERC-20 balance-delta measurement; exact balance movement rests on the stated canonical-USDC transfer assumption (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L202-L243`).

---

**How the verdict was reached:** The requirement's checkable price formula is enforced directly rather than inferred from a name: the sole successful purchase path multiplies its `uint128 entryCount` by the immutable literal `1_000_000` in `uint256` and passes that product unchanged to the only quote-token collection call (`target/packages/contracts/src/Raffle.sol:L209-L224`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L24`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47,L202-L243`). Factory construction additionally enforces reported six-decimal precision and fixes the selected token across the implementation and its clones (`target/packages/contracts/src/RaffleFactory.sol:L30-L34,L58-L91,L97-L110`; `target/packages/contracts/src/Raffle.sol:L52-L59,L151-L165`). This is `implemented`, not `partial`, because no successful purchase branch, alternate mint path, caller, or mutable price bypasses the formula. It is not `stronger-than-spec`: sale-state and positive/count bounds determine whether a purchase may occur but do not change the price of an accepted entry (`target/packages/contracts/src/Raffle.sol:L215-L224`). Confidence is medium rather than high because the target proves the amount requested from the configured token but does not contain deployment provenance or the concrete token implementation needed to independently prove official-USDC identity and exact balance effects; the document and interface explicitly place those facts inside the trusted canonical-dependency model (`DESIGN.md:L2`; `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/src/RaffleFactory.sol:L58-L63`).

---

**Open questions:**

- unclear; need the deployment record and concrete deployed quote-token implementation to establish that `quoteToken_` is the target chain's official USDC and that an accepted `transferFrom` changes balances by exactly the requested amount. The supplied source enforces code presence and six reported decimals, explicitly assigns identity verification to deployment tooling, and relies on trusted fee-free, non-rebasing behavior (`target/packages/contracts/src/RaffleFactory.sol:L58-L78`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`; `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L202-L243`).
