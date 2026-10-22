## REQ-07 — Fixed one-USDC entry price

> "One entry costs 1,000,000 units of canonical six-decimal USDC."
> — `DESIGN.md:L2, sentence 2`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A successful primary entry purchase must charge exactly 1,000,000 raw quote-token units for each entry, and the configured quote token must use six decimal places so that 1,000,000 raw units are one whole token. The same specification states the relevant trust boundary verbatim: "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`). Within that boundary, the implementation must fix the raw-unit price, admit only a quote token reporting six decimals, preserve that token and price across every raffle clone, and expose no discounted or alternate purchase path.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L24
/// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
uint256 internal constant ENTRY_PRICE = 1_000_000;

/// @notice Decimal precision required from the immutable quote token.
uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;
```

- `Raffle` exposes the library value as a public constant, so the value used by purchases is not storage-backed or mutable (`target/packages/contracts/src/Raffle.sol:L41-L45`).

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

- `_requireContract` rejects an address with no deployed code (`target/packages/contracts/src/RaffleFactory.sol:L181-L185`), `IERC20Metadata.decimals()` is the metadata call being made (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol:L11-L25`), a failed call takes the `UnsupportedQuoteToken` branch, and any returned value other than six takes the `InvalidQuoteTokenDecimals` branch (`target/packages/contracts/src/RaffleFactory.sol:L65-L78`).
- After that gate, the factory stores the quote-token address in an immutable and passes the same address to a newly deployed `Raffle` implementation (`target/packages/contracts/src/RaffleFactory.sol:L32-L42`, `L85-L91`). The implementation stores it in its own immutable (`target/packages/contracts/src/Raffle.sol:L54-L59`, `L155-L165`). `createRaffle` clones only that stored implementation (`target/packages/contracts/src/RaffleFactory.sol:L97-L106`), and the used `Clones.clone` overload embeds the fixed implementation address into the proxy bytecode before `create` (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`).

```solidity
// target/packages/contracts/src/Raffle.sol:L218-L224
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}

uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

```solidity
// target/packages/contracts/src/Raffle.sol:L226-L236
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;

_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```

- Every successful `buyEntries` execution calculates `grossAmount` as `entryCount * ENTRY_PRICE`, submits that exact value to the configured quote token, adds the same value to the pot, and mints the range containing exactly `entryCount` entries (`target/packages/contracts/src/Raffle.sol:L209-L236`). For `entryCount == 1`, the expression is exactly `1 * 1_000_000` raw units (`target/packages/contracts/src/libraries/RaffleConstants.sol:L20-L21`; `target/packages/contracts/src/Raffle.sol:L223-L224`).
- The SafeERC20 wrapper forwards the supplied `value` to its private `transferFrom` implementation and reverts when the token call/return convention signals failure (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47`, `L212-L243`). It does not establish a balance delta; the source instead expressly treats standard, non-rebasing, fee-free canonical USDC behavior as trusted (`target/packages/contracts/src/interfaces/IRaffle.sol:L8-L15`; `target/packages/contracts/src/Raffle.sol:L560-L566`).
- The same constant prices full refunds and the `grossSales` view, so downstream raw-unit accounting does not introduce a second entry valuation (`target/packages/contracts/src/Raffle.sol:L356-L371`, `L472-L475`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract(quoteToken_)` → `IERC20Metadata.decimals()`: no-code tokens revert at `_requireContract`; a reverting metadata call becomes `UnsupportedQuoteToken`; a value other than six becomes `InvalidQuoteTokenDecimals`; only a token reporting six reaches immutable assignment and implementation deployment (`target/packages/contracts/src/RaffleFactory.sol:L65-L89`, `L181-L185`). ✓
- `RaffleFactory.constructor` → `new Raffle(quoteToken_, vrfWrapper_)` → `Raffle.constructor`: the already-screened address becomes the implementation's immutable `quoteToken`; the constructor exposes no entry-price input (`target/packages/contracts/src/RaffleFactory.sol:L85-L91`; `target/packages/contracts/src/Raffle.sol:L151-L165`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `Raffle.initialize`: creation supplies sponsor, prize, identifier, reserve, and time fields, but neither a quote token nor a price; the clone executes the fixed implementation selected by the factory (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`; `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- External `buyEntries(recipient, entryCount)` failure branches: wrong status, ended sale, zero recipient, zero count, or a `uint128` range overflow all revert before a ticket is minted (`target/packages/contracts/src/Raffle.sol:L209-L220`). These branches create no differently priced entry. ✓
- External `buyEntries(recipient, entryCount)` success branch → `grossAmount` → `SafeERC20.safeTransferFrom` → range/accounting writes → `_safeMint`: there is no branch around the multiplication or transfer on a successful purchase (`target/packages/contracts/src/Raffle.sol:L223-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L39-L47`, `L212-L243`). ✓
- `nonReentrant` on `buyEntries` enters the shared guard before the body and restores it afterward (`target/packages/contracts/src/Raffle.sol:L209-L213`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73`, `L88-L106`). The token call and later receiver callback therefore cannot re-enter another guarded purchase path. ✓
- `_safeMint` → `_mint` → virtual `_update`: the inherited base performs the mint and receiver check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290`), while `Raffle._update` adds only its destination screen before calling the base update (`target/packages/contracts/src/Raffle.sol:L491-L502`). The only production `_safeMint` call is the paid path at `Raffle.sol:L235`. ✓
- `refundTickets` and `grossSales` both multiply represented or sold entries by the identical constant (`target/packages/contracts/src/Raffle.sol:L356-L371`, `L472-L475`). ✓

---

**Searched:**

- Scope coverage → all five first-party production files and every one of the 31 paths in `target/dependency-hashes.json:L2-L32` were read in full; SHA-256 verification returned `OK` for 31/31 dependency files.
- `ENTRY_PRICE|entry[_ ]?price|1_000_000|1000000` → 12 hits: the fixed declaration, public exposure, purchase multiplication, refund multiplication, gross-sales multiplication, and interface/NatSpec descriptions; no alternate numeric entry price.
- `QUOTE_TOKEN_DECIMALS|decimals\(|six-decimal|six decimal` → 45 hits: the relevant executable hits are the constant `6`, the factory metadata call, and the equality gate (`target/packages/contracts/src/libraries/RaffleConstants.sol:L23-L24`; `target/packages/contracts/src/RaffleFactory.sol:L70-L78`); the remaining hits are interface declarations, dependency declarations, or documentation.
- `buyEntries` → 2 hits in the entire scoped set: the external interface declaration and its implementation (`target/packages/contracts/src/interfaces/IRaffle.sol:L310-L314`; `target/packages/contracts/src/Raffle.sol:L209-L237`). There is no in-scope wrapper or caller; it is the purchase entrypoint.
- `_safeMint\(|_mint\(` → 6 hits: one production call at `Raffle.sol:L235` and five inherited ERC-721 definitions/calls at `ERC721.sol:L259-L288`; no second production mint path.
- `purchaseEntries|mintEntries|enterRaffle|buyTicket|purchaseTicket|entryFee|ticketPrice` → 0 hits.
- `setEntryPrice|updateEntryPrice|setPrice|updatePrice|changePrice|setCost|updateCost` → 0 hits.
- `setQuoteToken|updateQuoteToken|changeQuoteToken` → 0 hits.
- `quoteToken\s*=|quoteToken_|new Raffle\(|Clones\.clone\(` → 13 hits, all in the constructor-to-implementation wiring described above; the only assignments are the factory and implementation immutable assignments (`target/packages/contracts/src/RaffleFactory.sol:L85-L91`; `target/packages/contracts/src/Raffle.sol:L155-L165`).
- `chainid|chain\.id|official.*address|USDC.*address|address.*USDC|token identity|identity.*token` → 4 hits, all documentation comments. They state that deployment tooling must verify the official USDC address and that on-chain construction checks code presence and six-decimal metadata (`target/packages/contracts/src/RaffleFactory.sol:L58-L62`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`, `L108-L110`).
- `balanceOf\(|balance.?delta|fee.?on.?transfer|rebasing|non-rebasing|fee-free` → 7 hits: ERC-20/ERC-721 interface or base declarations plus the two explicit canonical-token trust statements; no quote-token balance-delta enforcement appears in production (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/src/Raffle.sol:L560-L566`).

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every successful in-scope entry-creation path uses the same compile-time `1_000_000` price, the canonical factory rejects any configured token that does not report six decimals, and factory-created clones share the screened immutable token and fixed implementation. No branch, caller, modifier, base-contract mint, constructor parameter, or mutable setter supplies a different entry price. The absence of an on-chain official-address proof does not create a failing purchase path under this specification: the document itself says, verbatim, "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`), and the implementation explicitly assigns official-address verification to deployment tooling (`target/packages/contracts/src/RaffleFactory.sol:L58-L62`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). It is not `stronger-than-spec` because the six-decimal gate and fixed raw price are the constraints the quoted requirement states, and it is not `undecidable` because both quantities are concrete and directly traceable.

---

**Open questions:**

- The supplied target contains no deployment record or live-chain configuration proving that a particular factory instance received the target chain's official USDC address. The source explicitly leaves that identity check to deployment tooling (`target/packages/contracts/src/RaffleFactory.sol:L58-L62`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). This is an external confirmation of the specification's stated trusted dependency, not an unresolved code path in the fixed-price calculation.
