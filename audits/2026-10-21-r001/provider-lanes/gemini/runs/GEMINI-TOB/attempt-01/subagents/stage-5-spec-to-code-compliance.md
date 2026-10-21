# Stage 5 — Spec-to-Code Compliance Report (`spec-to-code-compliance`)

## 1. Executive Summary & Compliance Matrix

We extracted 15 atomic requirements (`REQ-01` through `REQ-15`) covering every normative statement in `DESIGN.md` and the NatSpec specifications in `IRaffle.sol` and `IRaffleFactory.sol`, and traced every requirement across `Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`, and their inherited OpenZeppelin / Chainlink base contracts (`ERC721.sol`, `Clones.sol`, `ReentrancyGuard.sol`, `SafeERC20.sol`, `Math.sol`, `VRFV2PlusWrapperConsumerBase.sol`).

| ID | Atomic Requirement Summary | Spec Source | Implementation Location | Skill Verdict | Alignment Class | Rubric Severity |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **REQ-01** | Immutable factory deploying ERC-1167 minimal-proxy clones pointing to a locked, immutable `Raffle` implementation | `DESIGN.md:L1`, `IRaffleFactory.sol:L6-L7`, `Raffle.sol:L37-L38` | `RaffleFactory.sol:L42, L89-L91, L112`, `Raffle.sol:L155-L166` | `implemented` | `FULL MATCH` | — |
| **REQ-02** | No administrator, owner, pause, rescue, mutable configuration, or upgrade path in factory or clones | `DESIGN.md:L2`, `IRaffle.sol:L119-L120`, `IRaffleFactory.sol:L7` | `RaffleFactory.sol:L22-L35, L65-L92`, `Raffle.sol:L41-L166` | `implemented` | `FULL MATCH` | — |
| **REQ-03** | Quote token is canonical 6-decimal USDC; one entry costs exactly `1,000,000` raw units | `DESIGN.md:L1`, `IRaffle.sol:L7-L8, L395-L396`, `IRaffleFactory.sol:L7-L9` | `RaffleConstants.sol:L21-L24`, `RaffleFactory.sol:L69-L78`, `Raffle.sol:L44, L223-L224` | `implemented` | `FULL MATCH` | — |
| **REQ-04** | Each purchase (`buyEntries`) mints one sequential, transferable ERC-721 ticket representing a contiguous inclusive `[firstEntry, lastEntry]` `uint128` range | `DESIGN.md:L1`, `IRaffle.sol:L5-L7, L310-L314, L368-L373` | `Raffle.sol:L36-L39, L139, L209-L237, L450-L455, L497-L502` | `implemented` | `FULL MATCH` | — |
| **REQ-05** | Exactly one ERC-721 prize is escrowed atomically at creation, activating the clone | `DESIGN.md:L1-L2`, `IRaffle.sol:L23-L25, L58-L62`, `IRaffleFactory.sol:L128-L131` | `RaffleFactory.sol:L97-L148`, `Raffle.sol:L176-L206, L416-L431` | `implemented` | `FULL MATCH` | — |
| **REQ-06** | Exclusive sale end (`endTime > block.timestamp`, duration `<= 30 days`); entry purchases rejected at or after `endTime` | `DESIGN.md:L2`, `IRaffle.sol:L44, L204-L207`, `IRaffleFactory.sol:L78-L87` | `RaffleFactory.sol:L99-L104`, `RaffleConstants.sol:L30`, `Raffle.sol:L216` | `stronger-than-spec` (vs `DESIGN.md`) / `implemented` (vs `IRaffleFactory.sol`) | `FULL MATCH` (with `UNDOCUMENTED BEHAVIOR` in `DESIGN.md`) | Low |
| **REQ-07** | Draw request window is `[endTime, endTime + 2 days)` when `totalEntries > 0`; pays native VRF fee and refunds excess native value atomically | `DESIGN.md:L2-L3`, `IRaffle.sol:L83-L96, L316-L320, L375-L377` | `Raffle.sol:L240-L273, L457-L459`, `RaffleConstants.sol:L33` | `implemented` | `FULL MATCH` | — |
| **REQ-08** | VRF callback accepted strictly before `drawRequestedAt + 2 days`; records result only (`winningEntry`, `resolvedAt`, `status`); ignores invalid/late callbacks without reverting | `DESIGN.md:L3`, `IRaffle.sol:L98-L108, L379-L381` | `Raffle.sol:L462-L464, L509-L524`, `RaffleConstants.sol:L36` | `implemented` | `FULL MATCH` | — |
| **REQ-09** | Economics & rounding: Reserve met (`totalEntries >= reserveEntries`) awards NFT + 95% sponsor / 5% treasury; Reserve missed (`CashWon`) awards 80% winner / 15% sponsor / 5% treasury (plus prize return); floor rounding on fee/winner bps with remainder to sponsor without loss | `DESIGN.md:L2`, `IRaffle.sol:L29-L32, L326-L330, L354` | `Raffle.sol:L395-L407, L521, L533-L558`, `RaffleConstants.sol:L11-L19` | `implemented` (code) / `partial` (`DESIGN.md` omits `CashWon` prize return) | `PARTIAL MATCH` (Spec omission in `DESIGN.md`; `FULL MATCH` vs `IRaffle.sol`) | Low |
| **REQ-10** | Permissionless, storage-only settlement (`settleWinningTicket`): validates winning ticket range and allocates liabilities without reading ownership or transferring assets | `DESIGN.md:L3`, `IRaffle.sol:L115-L130, L326-L330` | `Raffle.sol:L304-L306, L533-L558, L577-L585` | `implemented` | `FULL MATCH` | — |
| **REQ-11** | Winner redemption (`redeemWinningTicket`) requires current ticket owner (`msg.sender == ownerOf`), settles if needed, burns ticket atomically, delivers NFT or cash prize, and reverts all effects on delivery failure | `DESIGN.md:L3`, `IRaffle.sol:L131-L145, L333-L338` | `Raffle.sol:L309-L346` | `implemented` | `FULL MATCH` | — |
| **REQ-12** | Sponsor and treasury can claim proceeds independently after settlement (`releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) | `DESIGN.md:L3`, `IRaffle.sol:L161-L180, L346-L355` | `Raffle.sol:L375-L407` | `partial` (broken when `sponsorRecipient` is a precomputed future clone) | `PARTIAL MATCH` | High |
| **REQ-13** | Refunds open at deadline (`enableRefunds`), with early/at-end empty-raffle close; `refundTickets` burns 1..100 caller-owned tickets and pays 100% per entry and `releaseSponsorPrize` returns prize | `DESIGN.md:L2-L3`, `IRaffle.sol:L242-L245, L322-L324, L340-L344` | `Raffle.sol:L276-L301, L348-L372`, `RaffleConstants.sol:L27` | `stronger-than-spec` (vs `DESIGN.md`) / `partial` (NatSpec wording "after" vs `>=`) | `PARTIAL MATCH` (minor NatSpec drift + `UNDOCUMENTED BEHAVIOR` in `DESIGN.md`) | Low |
| **REQ-14** | **Never move assets between raffle clones**; reject known protocol plumbing (`_isProtocolDestination`) so clones/plumbing cannot own tickets, receive payouts, or strand claims | `DESIGN.md:L2`, `IRaffle.sol:L225-L227, L266-L268`, `IRaffleFactory.sol:L89-L91`, `Raffle.sol:L491-L492, L587-L605` | `Raffle.sol:L187-L195, L395-L407, L497-L502, L564-L567, L593-L605`, `RaffleFactory.sol:L154-L170` | **`partial`** | **`PARTIAL MATCH` / `MISMATCH`** | **High** |
| **REQ-15** | Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted; transaction decisions reread current chain state | `DESIGN.md:L3-L4`, `IRaffle.sol:L7-L8`, `IRaffleFactory.sol:L7-L9` | `RaffleFactory.sol:L65-L92, L133-L148, L171-L177`, `Raffle.sol:L209-L431` | `partial` (doc tension on `prizeToken` honesty + pre-`RaffleCreated` callback window) | `PARTIAL MATCH` | Low |

---

## 2. Special Focus Evaluation: Precomputed Future `Raffle` Clone Addresses (`CREATE` Nonce Prediction) vs. `_isProtocolDestination` and *"Never move assets between raffle clones"*

### 2.1 Architectural Mechanism of the Bypass

`DESIGN.md:L2` establishes the mandatory invariant:
> *"Never move assets between raffle clones."*

To enforce this invariant and prevent claims from becoming unreachable inside protocol contracts, `Raffle.sol` and `RaffleFactory.sol` screen addresses using `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L154-L170`) and `Raffle._isProtocolDestination` (`Raffle.sol:L593-L605`):

```solidity
// Raffle.sol:L593-L605
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```

However, `RaffleFactory.createRaffle` deploys clones using `Clones.clone(raffleImplementation)` (`RaffleFactory.sol:L112`), which executes the standard `CREATE` opcode (`Clones.sol:L58`: `instance := create(value, 0x09, 0x37)`).
- Because `CREATE` derives the deployed contract address solely from `keccak256(rlp([factoryAddress, factoryNonce]))[12:]`, where `factoryNonce = 1 + raffleCount` (nonce `1` deployed `raffleImplementation` in `RaffleFactory.sol:L89`), the address of **every future `Raffle` clone** (`R_future`) is deterministic and trivially computable before it is deployed.
- Prior to `R_future`'s deployment via `createRaffle`:
  1. `R_future.code.length == 0`
  2. `canonicalFactory.isRaffle(R_future) == false`
- Consequently, **both `RaffleFactory._validateCreateParams` and `Raffle._isProtocolDestination` return `false` for `R_future`**.
- Furthermore, `Raffle.releaseSponsorPrize()` (`Raffle.sol:L395-L407`) **never calls `_isProtocolDestination` at all** and transfers the prize NFT via raw `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (which does not trigger `IERC721Receiver.onERC721Received`).

### 2.2 Four Concrete Violation & Stranding Paths

#### Path 1 — Direct Inter-Clone ERC-721 Prize Transfer (Violates *"Never move assets between raffle clones"* and Permanently Locks the Prize NFT)
1. **Setup**: Sponsor creates Raffle 1 (`R_1`) via `RaffleFactory.createRaffle`, supplying `params.sponsorRecipient = R_future` (e.g., the address `RaffleFactory` will deploy at its next `CREATE` nonce). Both `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L164-L170`) and `R_1.initialize` (`Raffle.sol:L193-L195`) accept `R_future` because `isRaffle[R_future] == false` and `R_future.code.length == 0`.
2. **Future clone deployment**: Raffle 2 is created at `R_future` via `RaffleFactory.createRaffle` (either by the same actor or by any subsequent user). Now `R_future` is a live `Raffle` clone with `isRaffle[R_future] == true`.
3. **Inter-clone asset transfer**: `R_1` enters `Status.Refunding` (e.g., via `enableRefunds()`) or resolves to `Status.CashWon`. Anyone calls `R_1.releaseSponsorPrize()` (`Raffle.sol:L395-L407`).
4. **Consequence**: Because `releaseSponsorPrize()` omits `_isProtocolDestination` and calls `prizeToken.transferFrom(address(R_1), R_future, prizeTokenId)` rather than `safeTransferFrom`, **`R_1` transfers its escrowed ERC-721 prize directly into Raffle clone `R_future`**. This directly violates `DESIGN.md:L2` (*"Never move assets between raffle clones"*). Worse, as noted in `Raffle.sol:L410-L411`, unrelated NFTs transferred into a `Raffle` clone via `transferFrom` sit outside protocol accounting and are permanently unrecoverable. (Even if `R_1.releaseSponsorPrize()` is called *before* `R_future` is deployed, once `R_future` is deployed at that address, `R_future` holds `R_1`'s NFT permanently).

#### Path 2 — Permanent Stranding of `sponsorProceeds` (Violates *"Sponsor and treasury can claim independently after settlement"*) or Inter-Clone USDC Transfer
1. **Setup**: `R_1` is initialized with `sponsorRecipient = R_future`. `R_1` sells entries, resolves to `Status.NftWon` or `Status.CashWon`, and is settled via `settleWinningTicket`, recording `sponsorProceeds > 0` (`Raffle.sol:L554`).
2. **Subcase 2A (`R_future` is deployed before `R_1.releaseSponsorProceeds()` is called)**:
   - When anyone calls `R_1.releaseSponsorProceeds()` (`Raffle.sol:L375-L382`), it invokes `_transferQuote(sponsorRecipient, amount)` (`Raffle.sol:L564-L567`), which checks:
     ```solidity
     if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
     ```
   - Because `R_future` now has code (`R_future.code.length == 45`) and `canonicalFactory.isRaffle(R_future) == true`, `_isProtocolDestination` returns `true` and `releaseSponsorProceeds()` **permanently reverts with `InvalidQuoteDestination(R_future)`**.
   - **Consequence**: `R_1.sponsorProceeds` is permanently frozen inside `R_1` (`accountedQuoteBalance()` can never reach zero), violating `DESIGN.md:L3` (*"Sponsor and treasury can claim independently after settlement"*).
3. **Subcase 2B (`R_1.releaseSponsorProceeds()` is called before `R_future` is deployed, and `R_future` is deployed afterward)**:
   - `R_1` transfers USDC to `R_future` while `R_future.code.length == 0`. When `R_future` is subsequently deployed via `createRaffle`, `R_future` holds `R_1`'s USDC proceeds outside of `R_future`'s `accountedQuoteBalance()`, violating *"Never move assets between raffle clones"* and permanently locking the USDC in `R_future`.

#### Path 3 — Ticket Minted or Transferred to `R_future`, Permanently Stranding Winner Redemption or Refund Liability
1. **Setup**: Before `R_future` is deployed, a buyer calls `R_1.buyEntries(R_future, entryCount)` (`Raffle.sol:L209-L237`) or an existing ticket holder calls `R_1.transferFrom(holder, R_future, ticketId)` (`Raffle.sol:L497-L502`).
   - In `_update` (`Raffle.sol:L498`), `_isProtocolDestination(R_future, address(prizeToken))` returns `false` because `R_future.code.length == 0`.
   - In `_safeMint` (`ERC721.sol:L276` → `ERC721Utils.sol:L34`), `checkOnERC721Received` is skipped when `to.code.length == 0`.
2. **Future clone deployment**: `R_future` is subsequently deployed via `RaffleFactory.createRaffle`. Now `R_future` (a canonical `Raffle` clone) is the ERC-721 owner of `ticketId` in `R_1`, directly defeating `Raffle.sol:L491-L492` (*"Known protocol sinks are rejected before their ownership could make a claim unreachable"*).
3. **Consequence**:
   - Because `R_future` has no function to transfer tickets or call `redeemWinningTicket` / `refundTickets`:
   - If `ticketId` contains `winningEntry`, anyone can still call `R_1.settleWinningTicket(ticketId)` (so sponsor and treasury can claim their shares), but `R_1.redeemWinningTicket(ticketId)` (`Raffle.sol:L321`: `if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);`) can **never** be executed. The escrowed prize NFT (in `NftWon`) or `winnerProceeds` (in `CashWon`) is **permanently stranded in `R_1`**.
   - If `R_1` transitions to `Status.Refunding`, `R_1.refundTickets` (`Raffle.sol:L360`) can **never** be called for `ticketId`, permanently stranding its `remainingRefundLiability` in `R_1`.

#### Path 4 — Factory DoS if `protocolTreasury` is Configured to a Future Clone Address `R_future`
1. In `RaffleFactory.constructor` (`RaffleFactory.sol:L65-L92`), `protocolTreasury_` is only checked against `address(0)`, `address(this)`, `quoteToken_`, `vrfWrapper_`, and `implementation`.
2. If `protocolTreasury_` were ever set to the `CREATE` address of the `k`-th clone (`R_future`), raffles `1` through `k-1` would initialize and run, but when `createRaffle` attempts to deploy raffle `k` at `R_future`, `R_future.initialize` (`Raffle.sol:L190-L192`) checks `_isProtocolDestination(params.protocolTreasury, params.prizeToken)`, sees `destination == address(this)`, and reverts with `UnsafeProtocolDestination(protocolTreasury)` — permanently bricking `RaffleFactory.createRaffle` for all subsequent raffles.

---

## 3. Per-Requirement Compliance Analysis (`ANALYSIS_FORMAT.md`)

## REQ-01 — Immutable factory and ERC-1167 clones with immutable implementation

> "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
> — `DESIGN.md:L1`
>
> "Defines atomic ERC-1167 raffle creation for one immutable USDC, treasury, and Chainlink configuration."
> — `IRaffleFactory.sol:L6`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `RaffleFactory` must store its configuration (`quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation`) in `immutable` variables, deploy a single locked `Raffle` implementation during factory construction, and deploy each raffle as a standard ERC-1167 minimal proxy delegating to `raffleImplementation`.

**Where enforcement lives:**

```solidity
// RaffleFactory.sol:L33-L43
address public immutable override quoteToken;
address public immutable override vrfWrapper;
address public immutable override protocolTreasury;
address public immutable override raffleImplementation;

// RaffleFactory.sol:L89-L91
address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;

// RaffleFactory.sol:L112
raffle = Clones.clone(raffleImplementation);
```
```solidity
// Raffle.sol:L55-L58, L161-L165
address public immutable override factory;
IERC20 public immutable override quoteToken;
...
factory = msg.sender;
quoteToken = IERC20(quoteToken_);
initialized = true;
status = Status.Refunding;
```
- `RaffleFactory` sets all four configuration addresses as `immutable` in its constructor (`RaffleFactory.sol:L85-L91`).
- `Raffle.constructor` sets `factory`, `quoteToken`, and `i_vrfV2PlusWrapper` (in `VRFV2PlusWrapperConsumerBase.sol:L54-L61`) as `immutable`, and locks the implementation contract with `initialized = true` and `status = Status.Refunding` (`Raffle.sol:L164-L165`).
- `Clones.clone(raffleImplementation)` (`Clones.sol:L29-L59`) deploys the 45-byte ERC-1167 runtime bytecode delegating all calls to `raffleImplementation`.

**Paths walked:**
- `RaffleFactory.constructor` → `new Raffle(quoteToken_, vrfWrapper_)`: locks implementation (`initialized = true`), preventing direct initialization of the implementation via `Raffle.initialize` (`Raffle.sol:L177`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `IRaffle(raffle).initialize(...)`: deploys fresh ERC-1167 clone with `initialized == false` in clone storage and initializes it once (`Raffle.sol:L176-L179`). ✓

**Searched:**
- `immutable` in `Raffle.sol`, `RaffleFactory.sol`, `VRFV2PlusWrapperConsumerBase.sol` → 8 hits (`factory`, `quoteToken`, `i_linkToken`, `i_vrfV2PlusWrapper` in `Raffle`; `quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation` in `RaffleFactory`).
- `Clones.` in `RaffleFactory.sol` → 1 hit at `L112` (`Clones.clone(raffleImplementation)`).

**How the verdict was reached:** All factory and implementation configuration is stored in Solidity `immutable` variables or constants, the implementation is locked at construction, and every raffle is created via OpenZeppelin's `Clones.clone`.

**Open questions:**
- None.

---

## REQ-02 — No administrator, mutable configuration, or upgrade path

> "No administrator, mutable configuration or upgrade."
> — `DESIGN.md:L2`
>
> "Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue path."
> — `Raffle.sol:L37-L38`
>
> "The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration."
> — `IRaffleFactory.sol:L7`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** Neither `RaffleFactory` nor `Raffle` may expose any privileged role, setter function for protocol/raffle configuration after initialization, pause mechanism, arbitrary token/ETH rescue function, or proxy upgrade mechanism (`SELFDESTRUCT` / `DELEGATECALL` to a mutable target).

**Where enforcement lives:**
- `RaffleFactory.sol:L21-L186`: Contains only `constructor`, `createRaffle`, and generated `view` getters. No owner/admin state variable or setter exists.
- `Raffle.sol:L176-L206`: `initialize` is gated by `if (initialized) revert AlreadyInitialized(); if (msg.sender != factory) revert OnlyFactory(); initialized = true;` (`L177-L179`), and all clone configuration variables (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`) are written only inside `initialize`.

**Paths walked:**
- All state-changing functions in `RaffleFactory.sol` (`createRaffle`) and `Raffle.sol` (`receive`, `initialize`, `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `onERC721Received`, `approve`, `setApprovalForAll`, `transferFrom`, `safeTransferFrom`, `rawFulfillRandomWords`) were inspected. None modify configuration after `initialize` or provide admin/upgrade/rescue capabilities. Note that `sponsor` can call `enableRefunds()` prior to `endTime` only when `totalEntries == 0` (`Raffle.sol:L282`), which is a documented empty-raffle cancellation path (`IRaffle.sol:L45, L323`), not an administrative override over sold entries. ✓

**Searched:**
- `Ownable`, `AccessControl`, `onlyOwner`, `admin`, `pause`, `upgrade`, `rescue`, `delegatecall`, `selfdestruct` across `src/` → 0 functional hits (only NatSpec comments stating their absence).
- Assignments to `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime` in `Raffle.sol` → 1 hit each, all at `Raffle.sol:L197-L204` inside `initialize`.

**How the verdict was reached:** Exhaustive inspection of all state variables and external/public functions in `Raffle.sol` and `RaffleFactory.sol` confirms there are no privileged roles, configuration mutators, rescue paths, or upgrade hooks.

**Open questions:**
- None.

---

## REQ-03 — Canonical six-decimal USDC quote token and 1,000,000 unit entry price

> "One entry costs 1,000,000 units of canonical six-decimal USDC."
> — `DESIGN.md:L1`
>
> "The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code."
> — `RaffleFactory.sol:L58`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `RaffleFactory` must verify at construction that `quoteToken_` has deployed code and reports `decimals() == 6`, and `Raffle` must charge `entryCount * 1_000_000` units of `quoteToken` on every entry purchase.

**Where enforcement lives:**

```solidity
// RaffleConstants.sol:L21-L24
uint256 internal constant ENTRY_PRICE = 1_000_000;
uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;

// RaffleFactory.sol:L66-L78
_requireContract(quoteToken_);
...
try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
    quoteDecimals = decimals_;
} catch {
    revert UnsupportedQuoteToken(quoteToken_);
}
if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
    revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
}

// Raffle.sol:L223-L224
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
```

**Paths walked:**
- `RaffleFactory.constructor`: rejects code-less `quoteToken_` (`NotContract`), non-`IERC20Metadata` `quoteToken_` (`UnsupportedQuoteToken`), and `decimals() != 6` (`InvalidQuoteTokenDecimals`). ✓
- `Raffle.buyEntries`: computes `grossAmount = uint256(entryCount) * ENTRY_PRICE` (`1_000_000`) and transfers `grossAmount` from `msg.sender` to `address(this)` via `SafeERC20.safeTransferFrom`. ✓

**Searched:**
- `ENTRY_PRICE` across `src/` → `RaffleConstants.sol:L21`, `Raffle.sol:L44, L223, L367, L474`, `IRaffle.sol:L398`.
- `QUOTE_TOKEN_DECIMALS` across `src/` → `RaffleConstants.sol:L24`, `RaffleFactory.sol:L76, L77`.

**How the verdict was reached:** Both the 6-decimal check at factory construction and the fixed `1_000_000` per-entry price on every purchase and refund path match the specification.

**Open questions:**
- None.

---

## REQ-04 — Sequential, transferable ERC-721 range tickets per purchase

> "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
> — `DESIGN.md:L1`
>
> "Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable bearer claim until its owner atomically burns it for redemption or refund."
> — `IRaffle.sol:L5-L7`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** Every call to `buyEntries(recipient, entryCount)` must reject `entryCount == 0` and `uint128` overflow of `totalEntries`, assign the next sequential `ticketId = ticketCount + 1`, record the contiguous inclusive 1-based range `[totalEntries + 1, totalEntries + entryCount]`, and mint an ERC-721 token for `ticketId` to `recipient` that can be transferred across lifecycle states until burned.

**Where enforcement lives:**

```solidity
// Raffle.sol:L217-L236
if (recipient == address(0)) revert InvalidRecipient();
if (entryCount == 0) revert ZeroEntryCount();
if (entryCount > type(uint128).max - totalEntries) {
    revert TotalEntriesOverflow(totalEntries, entryCount);
}
...
uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;

_safeMint(recipient, ticketId);
```

**Paths walked:**
- `Raffle.buyEntries`: enforces `entryCount > 0` (`L218`), `entryCount <= type(uint128).max - totalEntries` (`L219`), assigns contiguous `[totalEntries + 1, totalEntries + entryCount]`, increments `ticketCount`, stores `_ticketRanges[ticketId]`, and calls `_safeMint(recipient, ticketId)`. ✓
- `ERC721.transferFrom` / `safeTransferFrom` → `Raffle._update` (`Raffle.sol:L497-L502`): does not restrict transfers by `status`, allowing tickets to be transferred as bearer claims in `Active`, `Drawing`, `NftWon`, `CashWon`, and `Refunding` until burned (`_burn(ticketId)` in `redeemWinningTicket` at `L325` or `refundTickets` at `L364`). ✓
- `Raffle.ticketRange(ticketId)` (`Raffle.sol:L450-L455`): returns `(range.firstEntry, range.lastEntry)` from `_ticketRanges[ticketId]`, which persists after `_burn(ticketId)` (`IRaffle.sol:L369`). ✓

**Searched:**
- `_ticketRanges` in `Raffle.sol` → 3 hits: declaration (`L139`), write in `buyEntries` (`L232`), read in `ticketRange` (`L451`). Never deleted or overwritten.
- `_mint` / `_safeMint` in `Raffle.sol` → 1 hit in `buyEntries` (`L235`).

**How the verdict was reached:** Range assignment is strictly contiguous, 1-based, and overflow-checked in `uint128`; tickets are standard OpenZeppelin `ERC721` tokens with no status-based transfer lock.

**Open questions:**
- None.

---

## REQ-05 — Atomic ERC-721 prize escrow at creation

> "Exactly one ERC721 prize is escrowed atomically at creation."
> — `DESIGN.md:L1-L2`
>
> "Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically."
> — `IRaffleFactory.sol:L128`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `RaffleFactory.createRaffle` must deploy the clone, initialize it in `Status.AwaitingPrize`, transfer the configured ERC-721 `prizeTokenId` from `msg.sender` to the clone via `safeTransferFrom`, transition the clone to `Status.Active` inside `onERC721Received` only when `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory`, and verify post-transfer that `prize.ownerOf(prizeTokenId) == raffle` and `raffle.status() == Status.Active`.

**Where enforcement lives:**

```solidity
// RaffleFactory.sol:L133-L140
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```
```solidity
// Raffle.sol:L416-L431
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
    external
    override
    returns (bytes4 selector)
{
    if (
        status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
            || from != sponsor || operator != factory
    ) {
        revert UnexpectedPrize(msg.sender, tokenId, from, operator);
    }

    status = Status.Active;
    emit PrizeDeposited(msg.sender, tokenId, from);
    selector = IERC721Receiver.onERC721Received.selector;
}
```

**Paths walked:**
- `RaffleFactory.createRaffle` → `Raffle.initialize` (`status = Status.AwaitingPrize`) → `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` → `Raffle.onERC721Received` (`status = Status.Active`) → post-conditions `prize.ownerOf(prizeTokenId) == raffle` and `status == Active`. ✓
- Any subsequent safe ERC-721 transfer to `Raffle` reaches `onERC721Received` with `status != Status.AwaitingPrize` and reverts with `UnexpectedPrize`. ✓

**Searched:**
- `AwaitingPrize` across `src/` → `IRaffle.sol:L23`, `Raffle.sol:L205, L422`.
- `onERC721Received` across `src/` → `Raffle.sol:L416, L430`.

**How the verdict was reached:** Creation, initialization, prize transfer, callback validation, ownership verification, and activation occur atomically in a single `nonReentrant` `createRaffle` transaction.

**Open questions:**
- None.

---

## REQ-06 — Sale window and duration bounds

> "Raised when an entry purchase is submitted at or after the exclusive sale end."
> — `IRaffle.sol:L204`
>
> "Raised when the sale end is not strictly after the creation block timestamp."
> — `IRaffleFactory.sol:L78`
>
> "Raised when the prospective sale duration exceeds the fixed 30-day limit."
> — `IRaffleFactory.sol:L83`

**Verdict:** `stronger-than-spec` (relative to `DESIGN.md`) / `implemented` (relative to `IRaffle.sol` & `IRaffleFactory.sol`) (`FULL MATCH` with `UNDOCUMENTED BEHAVIOR` in `DESIGN.md`) · confidence: high

**What this demands of an implementation:** `createRaffle` must require `params.endTime > block.timestamp` and `params.endTime - block.timestamp <= 30 days` (as well as `params.reserveEntries > 0`), and `buyEntries` must require `status == Status.Active` and `block.timestamp < endTime`.

**Where enforcement lives:**

```solidity
// RaffleFactory.sol:L99-L104, L178
uint256 currentTime = block.timestamp;
if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
uint256 saleDuration = uint256(params.endTime) - currentTime;
if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
    revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
}
...
if (params.reserveEntries == 0) revert ZeroReserveEntries();

// Raffle.sol:L215-L216
_requireStatus(Status.Active);
if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
```

**Paths walked:**
- `RaffleFactory.createRaffle`: checks `params.reserveEntries != 0` (`L178`), `params.endTime > block.timestamp` (`L100`), and `saleDuration <= 30 days` (`L102-L104`). ✓
- `Raffle.buyEntries`: checks `status == Status.Active` (`L215`) and `block.timestamp < endTime` (`L216`). ✓

**Searched:**
- `endTime` across `src/` → checked in `RaffleFactory.sol:L100-L101`, `Raffle.sol:L204, L216, L242, L281, L458`.
- `MAX_SALE_DURATION` across `src/` → `RaffleConstants.sol:L30`, `RaffleFactory.sol:L102-L103`.

**How the verdict was reached:** Matches `IRaffle.sol` and `IRaffleFactory.sol` in full; `MAX_SALE_DURATION = 30 days` and `reserveEntries > 0` are additional constraints beyond `DESIGN.md` (`stronger-than-spec` relative to `DESIGN.md`, Low severity documentation note).

**Open questions:**
- None.

---

## REQ-07 — Draw request window `[endTime, endTime + 2 days)` and native fee handling

> "Request window [sale end, end+2days)"
> — `DESIGN.md:L2`
>
> "Pays the current native Chainlink fee and requests the raffle's one random word. Callable by anyone only in `[endTime,drawRequestDeadline())` after at least one entry is sold. Any native value above the wrapper's actual fee is returned to the caller atomically."
> — `IRaffle.sol:L316-L318`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `requestDraw()` must be permissionless, require `status == Status.Active`, `totalEntries > 0`, and `endTime <= block.timestamp < endTime + 2 days`, pay the Chainlink VRF v2.5 wrapper in native currency for 1 random word, transition `status` to `Status.Drawing`, record `drawRequestedAt = uint64(block.timestamp)` and `vrfRequestId`, and refund `msg.value - paidPrice` to `msg.sender` (reverting if the refund call fails).

**Where enforcement lives:**

```solidity
// Raffle.sol:L240-L273
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }

    uint256 quotedFee = getVrfRequestPrice();
    if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

    status = Status.Drawing;
    drawRequestedAt = uint64(block.timestamp);
    _requestInFlight = true;
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
    uint256 paidPrice;
    (requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
    if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
    vrfRequestId = requestId;
    _requestInFlight = false;

    uint256 excess = msg.value - paidPrice;
    if (excess != 0) {
        bool success;
        address refundRecipient = msg.sender;
        assembly ("memory-safe") {
            success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
        }
        if (!success) revert NativeRefundFailed(msg.sender, excess);
    }

    emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
}
```

**Paths walked:**
- `Raffle.requestDraw`:
  - Rejects `status != Status.Active` (`L241`).
  - Rejects `block.timestamp < endTime` (`L242`) and `block.timestamp >= endTime + 2 days` (`L244-L247`, where `drawRequestDeadline()` returns `uint256(endTime) + 2 days` at `L458`).
  - Rejects `totalEntries == 0` (`L243`).
  - Checks `msg.value >= quotedFee` (`L250`), calls `requestRandomnessPayInNative` (`VRFV2PlusWrapperConsumerBase.sol:L90-L103`), verifies `paidPrice <= msg.value` (`L258`), and returns `excess = msg.value - paidPrice` to `msg.sender` (`L262-L270`). ✓
- Direct native transfers outside `requestDraw` hit `receive()` (`Raffle.sol:L171-L173`) and revert with `DirectNativeTransfer()`. ✓

**Searched:**
- `DRAW_REQUEST_TIMEOUT` across `src/` → `RaffleConstants.sol:L33` (`2 days`), `Raffle.sol:L458`.
- `requestRandomnessPayInNative` across bundle → `Raffle.sol:L257`, `VRFV2PlusWrapperConsumerBase.sol:L90`.

**How the verdict was reached:** Every precondition, window bound (`[endTime, endTime + 2 days)`), state transition, and native excess refund matches `DESIGN.md` and `IRaffle.sol`.

**Open questions:**
- None.

---

## REQ-08 — VRF callback window and storage-only resolution

> "callback accepted strictly before request timestamp+2days. ... Callback records result only."
> — `DESIGN.md:L2-L3`
>
> "Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer occurs. In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness"
> — `Raffle.sol:L504-L506`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `rawFulfillRandomWords` must authenticate `msg.sender == address(i_vrfV2PlusWrapper)`, ignore callbacks when `_requestInFlight`, `status != Status.Drawing`, `requestId != vrfRequestId`, `randomWords.length != 1`, or `block.timestamp >= drawRequestedAt + 2 days` (emitting `VrfCallbackIgnored` rather than reverting), and otherwise record only `winningEntry` in `[1, totalEntries]`, `resolvedAt`, and `status` (`NftWon` or `CashWon`).

**Where enforcement lives:**

```solidity
// VRFV2PlusWrapperConsumerBase.sol:L115-L121
function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
    address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
    if (msg.sender != vrfWrapperAddr) {
        revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
    }
    fulfillRandomWords(_requestId, _randomWords);
}

// Raffle.sol:L509-L524
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

**Paths walked:**
- `rawFulfillRandomWords` → `fulfillRandomWords` (valid callback with `block.timestamp < drawRequestedAt + 2 days`): computes `resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`, writes `winningEntry`, `resolvedAt`, and `status`, and emits `RaffleResolved`. No loops or external calls occur. ✓
- `rawFulfillRandomWords` → `fulfillRandomWords` (in-flight synchronous callback during `requestDraw`, late callback at `block.timestamp >= callbackDeadline()`, duplicate callback after status left `Drawing`, mismatched `requestId`, or `randomWords.length != 1`): emits `VrfCallbackIgnored` and returns cleanly. ✓

**Searched:**
- `DRAW_CALLBACK_TIMEOUT` across `src/` → `RaffleConstants.sol:L36` (`2 days`), `Raffle.sol:L463`.
- `fulfillRandomWords` across bundle → `Raffle.sol:L509`, `VRFV2PlusWrapperConsumerBase.sol:L113, L120`.

**How the verdict was reached:** Wrapper authentication, strict `< drawRequestedAt + 2 days` deadline check, non-reverting ignore path for invalid/late callbacks, and O(1) storage-only resolution all match the specification.

**Open questions:**
- None.

---

## REQ-09 — Reserve-met (`NftWon`) and reserve-missed (`CashWon`) economics and rounding

> "Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. Refund outcome pays 100% per entry and returns prize. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss."
> — `DESIGN.md:L2`
>
> "The cash-winner allocation is rounded down; the sponsor receives the remaining raw units."
> — `IRaffle.sol:L328`
>
> "Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`."
> — `IRaffle.sol:L354`

**Verdict:** `implemented` (in code and `IRaffle.sol`) / `partial` (documentation omission in `DESIGN.md` regarding prize return on `CashWon`) (`PARTIAL MATCH` — Low severity documentation gap in `DESIGN.md`) · confidence: high

**What this demands of an implementation:**
1. When `totalEntries >= reserveEntries` (`Status.NftWon`), protocol fee is `floor(grossPot * 500 / 10_000)` (5%), sponsor receives `grossPot - protocolFee` (95% + any floor remainder), and winner receives the escrowed NFT.
2. When `totalEntries < reserveEntries` (`Status.CashWon`), protocol fee is `floor(grossPot * 500 / 10_000)` (5%), winner receives `floor(grossPot * 8000 / 10_000)` (80%), sponsor receives `grossPot - protocolFee - cashAmount` (15% + any floor remainder), and `sponsorRecipient` can recover the escrowed NFT via `releaseSponsorPrize()`.

**Where enforcement lives:**

```solidity
// RaffleConstants.sol:L11-L19
uint256 internal constant BPS = 10_000;
uint256 internal constant PROTOCOL_FEE_BPS = 500;
uint256 internal constant CASH_WINNER_BPS = 8000;

// Raffle.sol:L539-L556
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
```solidity
// Raffle.sol:L395-L407
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();
    ...
```

**Paths walked:**
- `_settleWinningTicket` (`Status.NftWon`): `protocolFee = floor(grossPot * 500 / 10_000)`, `sponsorAmount = grossPot - protocolFee`. Sum of allocated liabilities equals `grossPot` with zero loss. ✓
- `_settleWinningTicket` (`Status.CashWon`): `protocolFee = floor(grossPot * 500 / 10_000)`, `cashAmount = floor(grossPot * 8000 / 10_000)`, `sponsorAmount = grossPot - protocolFee - cashAmount`. Sum of allocated liabilities (`protocolFee + cashAmount + sponsorAmount`) equals `grossPot` with zero loss. (Note: because `ENTRY_PRICE = 1_000_000` is a multiple of `BPS = 10_000`, both `Math.mulDiv` divisions are exact for all `totalEntries`). ✓
- `releaseSponsorPrize()` (`Status.CashWon`): returns the escrowed NFT to `sponsorRecipient` when `status == Status.CashWon` (even before `settleWinningTicket` is called). `IRaffle.sol:L173, L354` explicitly specifies this behavior, whereas `DESIGN.md:L2` only explicitly mentions *"returns prize"* under *"Refund outcome"*.

**Searched:**
- `PROTOCOL_FEE_BPS`, `CASH_WINNER_BPS`, `BPS` across `src/` → `RaffleConstants.sol:L11-L19`, `Raffle.sol:L540, L546`.
- `releaseSponsorPrize` across `src/` → `IRaffle.sol:L354`, `Raffle.sol:L395`.

**How the verdict was reached:** The arithmetic and conservation of funds (`protocolFees + winnerProceeds + sponsorProceeds == unsettledPot`) are exact. `DESIGN.md:L2` omits stating explicitly that `CashWon` ("Reserve missed") also returns the prize NFT to the sponsor recipient (and allows prize recovery immediately upon `CashWon` resolution prior to settlement), which is documented in `IRaffle.sol:L354`.

**Open questions:**
- None.

---

## REQ-10 — Permissionless, storage-only settlement (`settleWinningTicket`)

> "Settlement is permissionless, storage-only"
> — `DESIGN.md:L3`
>
> "Proves which ticket contains the winning entry and allocates winner, sponsor, and protocol liabilities. Anyone may execute; ownership is not read, the ticket remains transferable, and no external asset transfer occurs."
> — `IRaffle.sol:L326-L328`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `settleWinningTicket(ticketId)` must be callable by any address when `status` is `NftWon` or `CashWon` and `!settlementComplete`, verify `firstEntry <= winningEntry <= lastEntry` for `ticketId`, allocate `winnerProceeds`, `sponsorProceeds`, and `protocolFees` from `unsettledPot`, record `winningTicketId = ticketId` and `settlementComplete = true`, and make no external calls or `ownerOf(ticketId)` reads.

**Where enforcement lives:**

```solidity
// Raffle.sol:L304-L306, L533-L558, L577-L585
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}
...
function _requireWinningTicket(uint256 ticketId) private view {
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    uint128 selectedEntry = winningEntry;
    if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
        revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
    }
}
```

**Paths walked:**
- `settleWinningTicket(ticketId)` → `_settleWinningTicket(ticketId)`:
  - Reverts with `SettlementAlreadyComplete` if `settlementComplete == true` (`L534`).
  - Reverts with `InvalidStatus(result)` if `status` is not `NftWon` or `CashWon` (`L536`).
  - Calls `_requireWinningTicket(ticketId)` (`L538`), which checks `selectedEntry >= firstEntry && selectedEntry <= lastEntry` (`L581`). For unminted `ticketId`s (`firstEntry == 0, lastEntry == 0`), since `winningEntry >= 1`, `selectedEntry > lastEntry` holds and reverts with `TicketDoesNotContainWinningEntry`.
  - Updates only storage variables and emits `WinningTicketSettled`. Zero external calls or ownership reads occur. ✓

**Searched:**
- `_settleWinningTicket` in `Raffle.sol` → called at `L305` (`settleWinningTicket`) and `L315` (`redeemWinningTicket`).

**How the verdict was reached:** `_settleWinningTicket` performs only storage reads/writes and arithmetic, has no caller check, does not read `_owners[ticketId]`, and leaves the ticket transferable until `redeemWinningTicket`.

**Open questions:**
- None.

---

## REQ-11 — Atomic winner redemption (`redeemWinningTicket`)

> "redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — `DESIGN.md:L3`
>
> "Lets the current winning-ticket owner atomically burn the ticket and receive the NFT or cash prize. If necessary, this first settles the supplied winning ticket so the owner can complete both steps in one transaction. Any failed delivery reverts the burn and every redemption state change."
> — `IRaffle.sol:L333-L335`

**Verdict:** `implemented` (`FULL MATCH`) · confidence: high

**What this demands of an implementation:** `redeemWinningTicket(ticketId)` must settle `ticketId` if `!settlementComplete` (or verify `ticketId == winningTicketId` if already settled), require `msg.sender == ownerOf(ticketId)`, burn `ticketId`, transfer the prize NFT (in `NftWon`, verifying `prizeToken.ownerOf(prizeTokenId) == winner`) or `winnerProceeds` (in `CashWon` via `SafeERC20.safeTransfer`), and revert the entire transaction if delivery fails.

**Where enforcement lives:**

```solidity
// Raffle.sol:L309-L346
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    if (!settlementComplete) {
        _settleWinningTicket(ticketId);
    } else if (ticketId != winningTicketId) {
        revert WinningTicketMismatch(ticketId, winningTicketId);
    }

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

    emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
}
```

**Paths walked:**
- `redeemWinningTicket` when `!settlementComplete`: calls `_settleWinningTicket(ticketId)`, checks `msg.sender == ownerOf(ticketId)`, burns `ticketId`, delivers NFT or USDC. ✓
- `redeemWinningTicket` when `settlementComplete`: checks `ticketId == winningTicketId`, checks `msg.sender == ownerOf(ticketId)`, burns `ticketId`, delivers NFT or USDC. ✓
- Delivery failure in `NftWon` (`prizeToken.transferFrom` reverts or `prizeToken.ownerOf(deliveredPrizeTokenId) != winner`) or `CashWon` (`_transferQuote` reverts via `SafeERC20.safeTransfer` or `InvalidQuoteDestination`): reverts the entire `redeemWinningTicket` call, rolling back `_burn(ticketId)`, `winnerRedeemed`, `winnerRecipient`, and (if unsettled before the call) `_settleWinningTicket`. ✓

**Searched:**
- `winnerRedeemed` across `src/` → `Raffle.sol:L130, L310, L324`, `IRaffle.sol:L512`.
- `WinningTicketAlreadyRedeemed`, `WinningTicketMismatch`, `PrizeDeliveryVerificationFailed` across `src/` → `Raffle.sol:L310, L317, L336, L405`.

**How the verdict was reached:** All ownership, settlement, atomic burn, and delivery-verification requirements are enforced in `redeemWinningTicket` with full transaction rollback on any failure. (See `REQ-14` for the case where the winning ticket was minted/transferred to a precomputed future `Raffle` clone address before that clone was deployed).

**Open questions:**
- None.

---

## REQ-12 — Independent sponsor and treasury claims after settlement

> "Sponsor and treasury can claim independently after settlement."
> — `DESIGN.md:L3`
>
> "Releases the complete current sponsor-proceeds balance to the immutable sponsor recipient."
> — `IRaffle.sol:L346`
>
> "Releases the complete current protocol-fee balance to the immutable treasury."
> — `IRaffle.sol:L350`

**Verdict:** `partial` (`PARTIAL MATCH`) · confidence: high

**What this demands of an implementation:** Once `_settleWinningTicket` has allocated `sponsorProceeds` and `protocolFees`, `releaseSponsorProceeds()` and `releaseProtocolFees()` must each be independently executable without waiting for the other or for `redeemWinningTicket`.

**Where enforcement lives:**

```solidity
// Raffle.sol:L375-L392
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

**Paths walked:**
- Standard path: After `settleWinningTicket` (where `totalEntries >= 1` guarantees `sponsorProceeds >= 150_000` and `protocolFees >= 50_000`), `releaseSponsorProceeds()` and `releaseProtocolFees()` have independent storage variables (`sponsorProceeds`, `protocolFees`) and transfer directly to `sponsorRecipient` and `protocolTreasury`. ✓
- Precomputed future clone path: If `sponsorRecipient` (or `protocolTreasury`) was set to a precomputed future `Raffle` clone address `R_future` before `R_future` was deployed, and `R_future` has since been deployed via `createRaffle`, `_transferQuote` (`Raffle.sol:L565`) sees `_isProtocolDestination(R_future, address(prizeToken)) == true` and **permanently reverts** with `InvalidQuoteDestination(R_future)`. ✗ — the gap (see Section 2, Path 2).

**Searched:**
- `sponsorProceeds`, `protocolFees` across `src/` → written in `_settleWinningTicket` (`Raffle.sol:L554-L555`), zeroed and transferred in `releaseSponsorProceeds` (`L376-L380`) and `releaseProtocolFees` (`L386-L390`), summed in `accountedQuoteBalance` (`L468`).

**How the verdict was reached:** The two claim functions are decoupled from each other and from winner redemption, satisfying the requirement on standard paths, but `releaseSponsorProceeds` (or `releaseProtocolFees`) is permanently blocked if `sponsorRecipient` (or `protocolTreasury`) was initialized to a precomputed future `Raffle` clone address that is deployed before the claim is executed.

**Open questions:**
- None.

---

## REQ-13 — Refund activation (`enableRefunds`) and batch ticket refunds (`refundTickets`)

> "Refund outcome pays 100% per entry and returns prize. ... Refunds open at deadline."
> — `DESIGN.md:L2-L3`
>
> "Enables full refunds after the sold-raffle request deadline or an accepted request's callback deadline. Also closes an empty raffle immediately for the sponsor and after sale end for anyone."
> — `IRaffle.sol:L322-L323`
>
> "Burns an owner-selected batch of tickets and returns their full entry purchase value. Accepts one to 100 tickets. Duplicate, nonexistent, or foreign-owned IDs revert the entire batch."
> — `IRaffle.sol:L340-L341`

**Verdict:** `stronger-than-spec` (relative to `DESIGN.md`) / `partial` (minor NatSpec wording drift in `IRaffle.sol:L322` saying "after" instead of "at or after") (`PARTIAL MATCH` — Low severity) · confidence: high

**What this demands of an implementation:**
1. `enableRefunds()` must transition `status` to `Status.Refunding` and move `unsettledPot` to `remainingRefundLiability`:
   - In `Status.Active` with `totalEntries > 0`: when `block.timestamp >= drawRequestDeadline()` (`endTime + 2 days`).
   - In `Status.Drawing`: when `block.timestamp >= callbackDeadline()` (`drawRequestedAt + 2 days`).
   - In `Status.Active` with `totalEntries == 0`: immediately for `msg.sender == sponsor`, or when `block.timestamp >= endTime` for anyone.
2. `refundTickets(ticketIds)` must require `status == Status.Refunding`, `1 <= ticketIds.length <= 100`, verify `msg.sender == ownerOf(ticketId)` for each ticket, burn each ticket, and transfer `aggregateEntries * ENTRY_PRICE` (100% of purchase price) to `msg.sender`.
3. `releaseSponsorPrize()` must return the escrowed prize NFT to `sponsorRecipient` in `Status.Refunding`.

**Where enforcement lives:**

```solidity
// Raffle.sol:L276-L301
function enableRefunds() external override nonReentrant {
    uint256 deadline;

    if (status == Status.Active) {
        if (totalEntries == 0) {
            deadline = endTime;
            if (msg.sender != sponsor && block.timestamp < deadline) {
                revert RefundsNotAvailable(deadline, block.timestamp);
            }
        } else {
            deadline = drawRequestDeadline();
            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
        }
    } else if (status == Status.Drawing) {
        deadline = callbackDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    } else {
        revert InvalidStatus(status);
    }

    uint256 liability = unsettledPot;
    unsettledPot = 0;
    remainingRefundLiability = liability;
    status = Status.Refunding;
    emit RefundsEnabled(msg.sender, liability);
}
```
```solidity
// Raffle.sol:L348-L372
function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
    _requireStatus(Status.Refunding);
    uint256 ticketQuantity = ticketIds.length;
    if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
        revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
    }

    uint256 aggregateEntries = 0;
    for (uint256 index; index < ticketQuantity; ++index) {
        uint256 ticketId = ticketIds[index];
        address owner = ownerOf(ticketId);
        if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
        _burn(ticketId);
    }

    amount = aggregateEntries * ENTRY_PRICE;
    remainingRefundLiability -= amount;
    _transferQuote(msg.sender, amount);
    uint256 liabilityAfter = remainingRefundLiability;
    emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
}
```

**Paths walked:**
- `enableRefunds()` in `Status.Active` (`totalEntries == 0`): allows `msg.sender == sponsor` at any `block.timestamp`, and any caller at `block.timestamp >= endTime`. (Matches `IRaffle.sol:L323`, undocumented in `DESIGN.md`). ✓
- `enableRefunds()` in `Status.Active` (`totalEntries > 0`): allows any caller at `block.timestamp >= endTime + 2 days`. ✓
- `enableRefunds()` in `Status.Drawing`: allows any caller at `block.timestamp >= drawRequestedAt + 2 days`. ✓
- `refundTickets(ticketIds)`: enforces `1 <= ticketIds.length <= 100` (`RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE`), reverts via `ownerOf(ticketId)` (`ERC721NonexistentToken`) if a `ticketId` is nonexistent or duplicated in `ticketIds` (since the first occurrence calls `_burn(ticketId)`), reverts with `NotTicketOwner` if `msg.sender != owner`, and refunds `aggregateEntries * ENTRY_PRICE`. ✓

**Searched:**
- `MAX_REFUND_TICKET_BATCH_SIZE` across `src/` → `RaffleConstants.sol:L27`, `Raffle.sol:L352-L353`.
- `remainingRefundLiability` across `src/` → `Raffle.sol:L95, L298, L368, L370, L468`.

**How the verdict was reached:** Code behavior matches `DESIGN.md` ("Refunds open at deadline") and `IRaffle.sol:L243` ("Unix timestamp, in seconds, at which refunds become available"). Two minor documentation discrepancies exist: (1) `DESIGN.md` does not mention the empty-raffle early/at-end refund rule or the 100-ticket batch cap, and (2) `IRaffle.sol:L322-L323` says "after" the deadline/sale end where the code (and `DESIGN.md`) enforces `block.timestamp >= deadline` ("at or after").

**Open questions:**
- None.

---

## REQ-14 — Never move assets between raffle clones; reject protocol sinks

> "Never move assets between raffle clones."
> — `DESIGN.md:L2`
>
> "Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected before their ownership could make a claim unreachable."
> — `Raffle.sol:L491-L492`
>
> "Identifies same-factory protocol plumbing that cannot safely own a ticket or receive a payout. ... Code-less addresses are not queried in the registry."
> — `Raffle.sol:L587-L589`

**Verdict:** `partial` (`PARTIAL MATCH` / `MISMATCH`) · confidence: high · **Severity: High**

**What this demands of an implementation:** No ERC-721 prize, ERC-20 quote token (`USDC`), or ERC-721 raffle entry ticket may be transferred between `Raffle` clones, and no `Raffle` clone (or other protocol contract) may be configured as a payout recipient or become the owner of a raffle ticket such that a prize, payout, or refund claim is stranded.

**Where enforcement lives:**

```solidity
// RaffleFactory.sol:L157-L170
if (
    params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
        || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
) {
    revert UnsafeProtocolDestination(params.prizeToken);
}
if (
    params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
        || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
        || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```
```solidity
// Raffle.sol:L593-L605
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```
```solidity
// Raffle.sol:L395-L407
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();

    address recipient = sponsorRecipient;
    prizeClaimed = true;
    prizeToken.transferFrom(address(this), recipient, prizeTokenId);
    if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
    emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
}
```

**Paths walked:**
- Already-deployed clone `R_existing` passed as `sponsorRecipient`, `prizeToken`, `buyEntries` `recipient`, or `transferFrom` `to`: `R_existing.code.length == 45 != 0` and `isRaffle[R_existing] == true`, so `_validateCreateParams` and `_isProtocolDestination` reject `R_existing` with `UnsafeProtocolDestination`. ✓
- Precomputed future clone `R_future` (computed from `address(factory)` and a future `CREATE` nonce `1 + raffleCount + k`) passed as `sponsorRecipient` in `createRaffle`:
  - `isRaffle[R_future]` is `false` and `R_future.code.length == 0`, so `_validateCreateParams` (`RaffleFactory.sol:L164-L170`) and `Raffle.initialize` (`Raffle.sol:L193-L195`) **accept** `R_future`.
  - After `R_future` is deployed via `createRaffle`, `R_1.releaseSponsorPrize()` (`Raffle.sol:L395-L407`) does not call `_isProtocolDestination` and executes `prizeToken.transferFrom(address(R_1), R_future, prizeTokenId)`, moving the escrowed ERC-721 prize from clone `R_1` into clone `R_future` (where it is permanently trapped). ✗ — **direct violation of *"Never move assets between raffle clones"***.
  - After `R_future` is deployed via `createRaffle`, `R_1.releaseSponsorProceeds()` (`Raffle.sol:L375-L382`) calls `_transferQuote(R_future, amount)`, which calls `_isProtocolDestination(R_future, address(prizeToken))` and **permanently reverts** with `InvalidQuoteDestination(R_future)`, stranding `sponsorProceeds` in `R_1`. (Or if called before `R_future` is deployed, transfers USDC to `R_future` which then becomes a live `Raffle` clone holding `R_1`'s USDC). ✗ — **strands `sponsorProceeds` or moves USDC to a future clone**.
- Precomputed future clone `R_future` passed as `recipient` in `buyEntries` (`Raffle.sol:L235`) or `to` in `transferFrom` (`Raffle.sol:L498`) before `R_future` is deployed:
  - `R_future.code.length == 0`, so `_isProtocolDestination` returns `false` and `_safeMint` skips `onERC721Received`.
  - Once `R_future` is deployed, `R_future` owns the ticket in `R_1` and cannot call `redeemWinningTicket` or `refundTickets`, permanently stranding the winning NFT, `winnerProceeds`, or `remainingRefundLiability` in `R_1`. ✗ — **strands winner or refund claims**.

**Searched:**
- `_isProtocolDestination` in `Raffle.sol` → 6 hits: `L187, L190, L193` (`initialize`), `L498` (`_update`), `L565` (`_transferQuote`), `L593` (definition). **Absent from `releaseSponsorPrize` (`L395-L407`) and `redeemWinningTicket`'s `NftWon` branch (`L329-L337`).**
- `isRaffle` across `src/` → `RaffleFactory.sol:L54, L131, L159, L166`, `Raffle.sol:L603`.

**How the verdict was reached:** Enforcement holds when the destination clone is already deployed (`destination.code.length != 0`), but fails whenever a future clone's deterministic `CREATE` address (`R_future`) is supplied before that clone is created. Because `releaseSponsorPrize()` omits `_isProtocolDestination` and uses `transferFrom`, an ERC-721 prize can be transferred directly from one active `Raffle` clone into another `Raffle` clone, and USDC/NFT claims can be permanently stranded.

**Open questions:**
- None.

---

## REQ-15 — Trust boundaries and advisory frontend discovery

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted. Frontend discovery is advisory; transaction decisions must reread current chain state."
> — `DESIGN.md:L3-L4`
>
> "The immutable quote token is trusted canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest, standards-compliant ERC-721s."
> — `IRaffle.sol:L7-L8`

**Verdict:** `partial` (`PARTIAL MATCH` — Low severity documentation contradiction + event-ordering quirk for untrusted `prizeToken`) · confidence: high

**What this demands of an implementation:**
1. All interactions with `prizeToken` and ticket recipients must defend against reentrancy, bogus return values, and denial-of-service against other claimants.
2. All contract state transitions must validate current on-chain state rather than trusting caller-supplied assumptions.

**Where enforcement lives:**
- `Raffle.sol:L41` & `RaffleFactory.sol:L21`: Both contracts inherit `ReentrancyGuard` and mark external state-changing entrypoints `nonReentrant` (except `initialize`, `onERC721Received`, `rawFulfillRandomWords`, and ERC-721 transfer/approval functions).
- `Raffle.sol:L304-L392`: Quote-token settlement (`settleWinningTicket`), cash winner payout (`redeemWinningTicket` in `CashWon`), ticket refunds (`refundTickets`), sponsor proceeds (`releaseSponsorProceeds`), and treasury fees (`releaseProtocolFees`) never call `prizeToken`, isolating all USDC claims from a broken or malicious `prizeToken`.
- `RaffleFactory.sol:L134-L140`, `Raffle.sol:L334-L337, L404-L405`: Every `prizeToken` transfer verifies `prizeToken.ownerOf(prizeTokenId) == expectedOwner` after the transfer.

**Paths walked:**
- Untrusted `prizeToken` reverting after escrow: cannot block `settleWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `redeemWinningTicket` (in `CashWon`), or `refundTickets` (in `Refunding`). If `prizeToken` reverts during `redeemWinningTicket` in `NftWon` or `releaseSponsorPrize`, the call reverts as required by `DESIGN.md:L3` (hence `IRaffle.sol:L7-L8` qualifies that *"Supported prizes are honest, standards-compliant ERC-721s"*). ✓
- Untrusted `prizeToken` reentering `raffle.buyEntries` during `RaffleFactory.createRaffle`:
  - In `RaffleFactory.createRaffle` (`RaffleFactory.sol:L129-L148`), `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`L134`) calls `raffle.onERC721Received` (`Raffle.sol:L416-L431`), which sets `raffle.status = Status.Active` (`L428`) and emits `PrizeDeposited`.
  - Before `prize.safeTransferFrom` returns to `RaffleFactory.createRaffle` (and before `RaffleCreated` is emitted at `RaffleFactory.sol:L142`), control returns to `prizeToken`. Because `raffle`'s own `ReentrancyGuard` is not entered during `onERC721Received` and `raffle.status` is now `Status.Active`, an untrusted `prizeToken` can call `raffle.buyEntries(...)` synchronously inside `safeTransferFrom`, causing `TicketPurchased` to be emitted **before** `RaffleCreated`! ✗ (Low severity event-ordering inversion for indexers).

**Searched:**
- `nonReentrant` across `src/` → `RaffleFactory.sol:L97` (`createRaffle`), `Raffle.sol:L212, L240, L276, L304, L309, L349, L375, L385, L395`.
- `prizeToken.` across `src/` → `Raffle.sol:L334, L335, L404, L405`.

**How the verdict was reached:** USDC claims are properly isolated from `prizeToken`, and `nonReentrant` guards protect state transitions, with two Low-severity findings: (1) `DESIGN.md:L3-L4` ("arbitrary prize contracts ... are untrusted") vs `IRaffle.sol:L7-L8` ("Supported prizes are honest, standards-compliant ERC-721s"), and (2) `Raffle.onERC721Received` setting `status = Status.Active` before `prize.safeTransferFrom` finishes in `createRaffle` allows an untrusted `prizeToken` to call `buyEntries` and emit `TicketPurchased` before `RaffleCreated` is emitted.

**Open questions:**
- None.

---

## 4. Reverse-Direction Pass: Undocumented Code Behaviors (`stronger-than-spec` / `UNDOCUMENTED BEHAVIOR`)

| # | Location | Undocumented Behavior in Code | Impact / Alignment |
| :--- | :--- | :--- | :--- |
| **UB-01** | `RaffleFactory.sol:L89` → `Raffle.sol:L157` → `VRFV2PlusWrapperConsumerBase.sol:L59` | **Constructor calls `vrfWrapper_.link()`**: `IRaffleFactory.sol:L8-L9` states *"onchain construction checks only code presence and six-decimal metadata"*, and `RaffleFactory.sol:L58` states *"the wrapper and quote token must contain deployed code."* However, `new Raffle(quoteToken_, vrfWrapper_)` invokes `VRFV2PlusWrapperConsumerBase(vrfWrapper_)`, which executes `i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link())`. Any `vrfWrapper_` that does not implement `link() external view returns (address)` causes `RaffleFactory` construction to revert. | `UNDOCUMENTED BEHAVIOR` (`stronger-than-spec`) — Low |
| **UB-02** | `VRFV2PlusWrapperConsumerBase.sol:L54, L124-L132` (inherited by `Raffle.sol:L41`) | **Extra public getters on `Raffle` not declared in `IRaffle.sol`**: Inheriting `VRFV2PlusWrapperConsumerBase` exposes `i_vrfV2PlusWrapper()` (duplicate of `vrfWrapper()`), `getBalance()`, `getLinkToken()`, and `rawFulfillRandomWords(uint256,uint256[])` on every `Raffle` clone, none of which appear in `IRaffle.sol`. | `UNDOCUMENTED BEHAVIOR` — Low |
| **UB-03** | `RaffleFactory.sol:L66-L67, L155, L183-L185` | **`address(0)` reverts with `NotContract(address(0))` instead of `ZeroAddress()`**: For `quoteToken_`, `vrfWrapper_`, and `params.prizeToken`, `_requireContract` (`account.code.length == 0`) runs before any zero-address check, so passing `address(0)` raises `NotContract(address(0))` rather than `ZeroAddress()`. | `UNDOCUMENTED BEHAVIOR` — Low |
| **UB-04** | `RaffleFactory.sol:L101-L104, L178`, `RaffleConstants.sol:L27, L30`, `Raffle.sol:L279-L285, L352-L354` | **Constraints documented in `IRaffle.sol` / `IRaffleFactory.sol` but omitted from `DESIGN.md`**: (1) `MAX_SALE_DURATION = 30 days`, (2) `params.reserveEntries > 0` (`ZeroReserveEntries`), (3) `MAX_REFUND_TICKET_BATCH_SIZE = 100`, and (4) empty-raffle (`totalEntries == 0`) refund activation by `sponsor` before `endTime` and by anyone at `endTime`. | `UNDOCUMENTED BEHAVIOR` (relative to `DESIGN.md`; `FULL MATCH` with `IRaffle.sol` / `IRaffleFactory.sol`) — Low |

---

## 5. Summary of Findings & Recommended Remediations

### Finding 1 (High): Precomputed Future `Raffle` Clone Addresses (`CREATE` Nonce Prediction) Bypass `_isProtocolDestination` and `_validateCreateParams`, Violating *"Never move assets between raffle clones"* and Stranding Claims
- **Requirement**: `REQ-14` (`DESIGN.md:L2`: *"Never move assets between raffle clones"*), `REQ-12` (`DESIGN.md:L3`: *"Sponsor and treasury can claim independently after settlement"*), `Raffle.sol:L491-L492, L587-L605`.
- **Root Cause**:
  1. `RaffleFactory` deploys clones via `Clones.clone(raffleImplementation)` (`CREATE`), making every future clone address `R_future` deterministically predictable from `address(factory)` and `factoryNonce = 1 + raffleCount`.
  2. Before `R_future` is deployed, `R_future.code.length == 0` and `isRaffle[R_future] == false`, so both `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L157-L170`) and `Raffle._isProtocolDestination` (`Raffle.sol:L593-L605`) return `false` for `R_future`.
  3. `Raffle.releaseSponsorPrize()` (`Raffle.sol:L395-L407`) does not check `_isProtocolDestination` and uses raw `prizeToken.transferFrom(address(this), recipient, prizeTokenId)`.
- **Impact**:
  1. **Inter-clone NFT transfer & permanent lock**: Setting `sponsorRecipient = R_future` on `R_1` and then deploying `R_future` allows `R_1.releaseSponsorPrize()` to transfer `R_1`'s ERC-721 prize directly into `R_future`, violating *"Never move assets between raffle clones"* and permanently locking the NFT inside `R_future`.
  2. **Permanent stranding of `sponsorProceeds`**: Once `R_future` is deployed, `R_1.releaseSponsorProceeds()` permanently reverts with `InvalidQuoteDestination(R_future)`.
  3. **Permanent stranding of winner prize/proceeds or refund liability**: Minting (`buyEntries`) or transferring (`transferFrom`) a ticket to `R_future` before `R_future` is deployed makes `R_future` the ticket owner once deployed; `R_future` can never call `redeemWinningTicket` or `refundTickets`, permanently locking the winning NFT, `winnerProceeds`, or `remainingRefundLiability` in `R_1`.
- **Recommended Remediation**:
  1. **Deploy clones deterministically with caller/params-bound `CREATE2` salts that commit to the full configuration and current block/caller**, or include a salt derived from `keccak256(abi.encode(msg.sender, params, block.number, raffleId))` via `Clones.cloneDeterministic(raffleImplementation, salt)`. Because a future raffle's `salt` commits to that future raffle's own `params` (or `raffleId` + unpredictable/self-referential inputs), a future clone `R_2` cannot have its address embedded as `sponsorRecipient` inside `R_1` unless `R_2`'s exact parameters are already known; **even stronger**, if `Clones.cloneDeterministic` uses a salt committing to `blockhash(block.number - 1)` or if `Raffle` checks `_isProtocolDestination` in `releaseSponsorPrize()`, wait: can `CREATE2` address still be precomputed for a known future `params` and `msg.sender` if `blockhash` is not in the salt? Yes! If `salt = keccak256(abi.encode(blockhash(block.number - 1), raffleId, msg.sender, params))`, then **no future transaction in a subsequent block can ever deploy a clone at an address chosen in an earlier block**, and within the same block `raffleId` strictly increases!
  2. Additionally, in `Raffle.releaseSponsorPrize()` (`Raffle.sol:L395-L407`), add the missing `_isProtocolDestination(recipient, address(prizeToken))` check so `releaseSponsorPrize()` cannot transfer an ERC-721 prize into a deployed `Raffle` clone even if a same-block `CREATE2` address were predicted.

### Finding 2 (Low): Untrusted `prizeToken` Can Execute `buyEntries` Inside `createRaffle` Before `RaffleCreated` Event Is Emitted
- **Requirement**: `REQ-05` & `REQ-15` (`DESIGN.md:L3-L4`, `IRaffleFactory.sol:L29`).
- **Root Cause**: In `RaffleFactory.createRaffle` (`RaffleFactory.sol:L134-L148`), `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` invokes `raffle.onERC721Received`, which sets `raffle.status = Status.Active` (`Raffle.sol:L428`) before returning control to `prizeToken`. Because `Raffle.onERC721Received` is not under `Raffle`'s `nonReentrant` guard, an untrusted `prizeToken` can call `raffle.buyEntries(...)` before `safeTransferFrom` returns to `RaffleFactory.createRaffle` and before `RaffleCreated` is emitted.
- **Recommended Remediation**: Emit `RaffleCreated` before `prize.safeTransferFrom` (since `createRaffle` reverts the entire transaction if `safeTransferFrom` or post-escrow verification fails), or guard `onERC721Received` / activation so `buyEntries` cannot execute while `createRaffle` is still in flight.

### Finding 3 (Low): Documentation Gaps Between `DESIGN.md`, `IRaffle.sol`, and `IRaffleFactory.sol`
- **Root Cause**:
  1. `DESIGN.md:L2` omits stating that `Status.CashWon` ("Reserve missed") also returns the escrowed prize NFT to `sponsorRecipient` via `releaseSponsorPrize()` (and that this is available immediately upon `CashWon` resolution prior to `settleWinningTicket`).
  2. `DESIGN.md:L2-L3` omits the `MAX_SALE_DURATION = 30 days` cap, `reserveEntries > 0`, `MAX_REFUND_TICKET_BATCH_SIZE = 100`, and the `totalEntries == 0` early/at-end refund rule.
  3. `DESIGN.md:L3-L4` states *"arbitrary prize contracts ... are untrusted"*, whereas `IRaffle.sol:L7-L8` states *"Supported prizes are honest, standards-compliant ERC-721s."*
  4. `IRaffleFactory.sol:L8-L9` states *"onchain construction checks only code presence and six-decimal metadata"*, omitting that `VRFV2PlusWrapperConsumerBase` calls `vrfWrapper_.link()` during construction.
  5. `IRaffle.sol:L322-L323` says `enableRefunds` is available *"after"* the deadline/sale end, whereas the code enforces `block.timestamp >= deadline` (*"at or after"*, matching `DESIGN.md:L3`).
