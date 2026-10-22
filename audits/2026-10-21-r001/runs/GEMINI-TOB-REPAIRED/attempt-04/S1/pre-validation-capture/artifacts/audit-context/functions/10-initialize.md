## `initialize` in packages/contracts/src/Raffle.sol (L176-L206)

**Purpose:** Performs the one-time configuration of a freshly deployed ERC-1167 `Raffle` clone on behalf of the canonical `RaffleFactory`, screening `sponsor`, `protocolTreasury`, and `sponsorRecipient` against the zero address and same-factory protocol destinations, persisting the raffle's immutable-per-clone configuration into clone storage, and placing the clone into `Status.AwaitingPrize` (`L176-L206`) so `onERC721Received` (`L416-L431`) can verify and accept the prize deposit. Without `initialize`, a clone has zeroed configuration storage (`sponsor == address(0)`, `prizeToken == IERC721(address(0))`, `endTime == 0`) and cannot accept its prize via `onERC721Received` (`L421-L425`) or transition to `Status.Active` (`L428`).

---

**Inputs & Assumptions:**
- `params` (`IRaffle.RaffleInitParams calldata`, defined at `packages/contracts/src/interfaces/IRaffle.sol:L45-L54`):
  - `params.sponsor` (`address`): prospective prize depositor and pre-`endTime` empty-raffle refund authority (`L282`, `L423`). Trust: **trusted caller frame (`RaffleFactory`), untrusted underlying actor** — `RaffleFactory.createRaffle` populates this with `msg.sender` (`packages/contracts/src/RaffleFactory.sol:L112`).
  - `params.sponsorRecipient` (`address`): recipient of sponsor USDC proceeds (`L379-L380`) and returned prize NFT (`L402-L404`). Trust: **untrusted** — supplied directly by the caller of `createRaffle` (`packages/contracts/src/RaffleFactory.sol:L113`).
  - `params.protocolTreasury` (`address`): recipient of protocol fees (`L389-L390`). Trust: **semi-trusted** — passed by `RaffleFactory.createRaffle` from its immutable `protocolTreasury` (`packages/contracts/src/RaffleFactory.sol:L114`).
  - `params.prizeToken` (`address`): ERC-721 contract for the escrowed prize (`L200`). Trust: **untrusted** — supplied directly by the caller of `createRaffle` (`packages/contracts/src/RaffleFactory.sol:L115`).
  - `params.prizeTokenId` (`uint256`): ERC-721 token ID to be escrowed (`L201`). Trust: **untrusted** — supplied directly by the caller of `createRaffle` (`packages/contracts/src/RaffleFactory.sol:L116`).
  - `params.raffleId` (`uint256`): one-based factory identifier for this clone (`L202`). Trust: **trusted** — computed as `++raffleCount` in `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L105`, `L117`).
  - `params.reserveEntries` (`uint128`): global entry threshold for `Status.NftWon` vs. `Status.CashWon` (`L203`, `L521`). Trust: **untrusted** — supplied by the caller of `createRaffle` (`packages/contracts/src/RaffleFactory.sol:L118`).
  - `params.endTime` (`uint64`): exclusive Unix timestamp when entry sales end (`L204`, `L216`, `L242`). Trust: **untrusted** — supplied by the caller of `createRaffle` (`packages/contracts/src/RaffleFactory.sol:L119`).
- Implicit inputs:
  - `msg.sender`: checked against the immutable `factory` (`L178`).
  - `address(this)`: address of the executing clone (or implementation), read inside `_isProtocolDestination` (`L599`).
  - Storage variable `initialized` (`L136`, read at `L177`).
  - Immutable `factory` (`L55`, set in `Raffle.constructor` at `L161`, read at `L178` and `L598-L599`).
  - Immutable `quoteToken` (`L58`, set in `Raffle.constructor` at `L162`, read in `_isProtocolDestination` at `L599`).
  - Immutable `i_vrfV2PlusWrapper` (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L35`, set at `L46`, read in `_isProtocolDestination` at `L600`).
  - External state in `RaffleFactory`: `canonicalFactory.raffleImplementation()` (`L601` -> `packages/contracts/src/RaffleFactory.sol:L42`) and `canonicalFactory.isRaffle(destination)` (`L603` -> `packages/contracts/src/RaffleFactory.sol:L54`), plus `destination.code.length` (`L602`).
- Preconditions:
  - `initialized == false` (`L177`). Established for a fresh ERC-1167 clone by zero-initialized proxy storage in `Clones.clone(raffleImplementation)` (`packages/contracts/src/RaffleFactory.sol:L106`, `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`); explicitly falsified on the shared implementation contract by `Raffle.constructor` setting `initialized = true` (`L164`).
  - `msg.sender == factory` (`L178`). Established when invoked by `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L109-L121`), because `RaffleFactory.constructor` deploys the `Raffle` implementation at `packages/contracts/src/RaffleFactory.sol:L89` so `factory == address(RaffleFactory)` (`L161`).
  - `params.sponsor`, `params.sponsorRecipient`, `params.protocolTreasury`, and `params.prizeToken` are all non-zero (`L181-L186`) and none of `params.sponsor`, `params.protocolTreasury`, or `params.sponsorRecipient` satisfies `_isProtocolDestination(..., params.prizeToken)` (`L187-L195`). Enforced directly inside `initialize` (`L181-L195`).
  - `params.prizeToken` has deployed bytecode (`params.prizeToken.code.length != 0`), is not itself a protocol destination (`factory`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, or an already-registered raffle `isRaffle[params.prizeToken]`), and reports ERC-165 support for `IERC721`. **Not checked in `initialize`** (`L183` only checks `params.prizeToken == address(0)`); established by caller `RaffleFactory.createRaffle` calling `_validateCreateParams` (`packages/contracts/src/RaffleFactory.sol:L98`, `L154-L177`, `L183-L185`). That `params.prizeToken != address(this)` is established indirectly because `_requireContract(params.prizeToken)` (`packages/contracts/src/RaffleFactory.sol:L155`, `L184`) runs at `L98` before `Clones.clone` deploys `address(this)` at `L106` (if code already existed at the `CREATE` target address, `Clones.clone` would revert with `FailedDeployment` at `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L59-L61`).
  - `params.prizeToken` is a standards-compliant, non-malicious ERC-721 contract whose `transferFrom` and `ownerOf` behave according to EIP-721 at future redemption or release time (`L334-L337`, `L404-L405`). Established by: **nothing found** (ERC-165 `supportsInterface` at `packages/contracts/src/RaffleFactory.sol:L172` is self-reported by `params.prizeToken`, and post-initialization escrow checks at `packages/contracts/src/RaffleFactory.sol:L128-L134` only verify the initial deposit into the clone).
  - `params.reserveEntries > 0`. **Not checked in `initialize`** (`L203` writes `params.reserveEntries` unchecked); established by caller `RaffleFactory._validateCreateParams` (`packages/contracts/src/RaffleFactory.sol:L98`, `L178`).
  - `params.endTime > block.timestamp` and `uint256(params.endTime) - block.timestamp <= RaffleConstants.MAX_SALE_DURATION` (30 days). **Not checked in `initialize`** (`L204` writes `params.endTime` unchecked); established by caller `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L99-L104`).
  - `params.raffleId` is a unique one-based sequential identifier matching `RaffleFactory.raffleById` and `RaffleFactory.idByRaffle`. **Not checked in `initialize`** (`L202` writes `params.raffleId` unchecked); established by caller `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L105`, `L117`, `L123-L124`).
  - Every other clone storage variable (`totalEntries`, `ticketCount`, `unsettledPot`, `remainingRefundLiability`, `winnerRecipient`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `vrfRequestId`, `drawRequestedAt`, `resolvedAt`, `winningEntry`, `winningTicketId`, `settlementComplete`, `winnerRedeemed`, `prizeClaimed`, `_requestInFlight`) is zero/false on entry. Established by fresh clone creation in `Clones.clone` (`packages/contracts/src/RaffleFactory.sol:L106`) coupled with the one-time `initialized` guard (`L177-L179`).
  - Neither `params.sponsorRecipient` nor `params.protocolTreasury` is an un-deployed address (`code.length == 0`) that will later be deployed as a `Raffle` clone by `RaffleFactory` before `releaseSponsorProceeds` (`L375-L382`) or `releaseProtocolFees` (`L385-L392`) is called. Established by: **nothing found** (`_isProtocolDestination` at `L602-L604` only checks `canonicalFactory.isRaffle(destination)` when `destination.code.length != 0` at the time of the check; if `sponsorRecipient` or `protocolTreasury` is a precomputed future `CREATE` clone address of `RaffleFactory`, it passes `initialize` at `L190-L195`, and once that future clone is created and registered in `isRaffle`, `_transferQuote` at `L565` reverts with `InvalidQuoteDestination`).

---

**Outputs & Effects:**
- Returns: none.
- Storage writes (all in `packages/contracts/src/Raffle.sol`):
  - `initialized = true` (`L179`)
  - `sponsor = params.sponsor` (`L197`)
  - `sponsorRecipient = params.sponsorRecipient` (`L198`)
  - `protocolTreasury = params.protocolTreasury` (`L199`)
  - `prizeToken = IERC721(params.prizeToken)` (`L200`)
  - `prizeTokenId = params.prizeTokenId` (`L201`)
  - `raffleId = params.raffleId` (`L202`)
  - `reserveEntries = params.reserveEntries` (`L203`)
  - `endTime = params.endTime` (`L204`)
  - `status = Status.AwaitingPrize` (`L205`)
- Events emitted: none (`RaffleCreated` is emitted by the caller `RaffleFactory.createRaffle` at `packages/contracts/src/RaffleFactory.sol:L136-L147`, and `PrizeDeposited` is emitted later by `Raffle.onERC721Received` at `L429`).
- External interactions: up to three pairs of `STATICCALL`s to `IRaffleFactory(factory).raffleImplementation()` (`L601`) and `IRaffleFactory(factory).isRaffle(destination)` (`L603`) via `_isProtocolDestination` (`L187`, `L190`, `L193`). No state-changing external calls.
- Postconditions on success:
  - `initialized == true` (`L179`), permanently preventing any second execution of `initialize` (`L177`).
  - `sponsor`, `sponsorRecipient`, `protocolTreasury`, and `address(prizeToken)` are all non-zero (`L181-L186`, `L197-L200`).
  - `sponsor`, `protocolTreasury`, and `sponsorRecipient` are each distinct from `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `address(prizeToken)`, `IRaffleFactory(factory).raffleImplementation()`, and any contract address where `IRaffleFactory(factory).isRaffle(addr)` was `true` at initialization time (`L187-L195`, `L598-L604`).
  - `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime` equal the values supplied by `factory` in `params` (`L201-L204`), and no function in `Raffle.sol` ever mutates `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, or `endTime` after `initialize`.
  - `status == Status.AwaitingPrize` (`L205`), enabling `onERC721Received` (`L421-L428`) and blocking all other status-gated entrypoints (`buyEntries` at `L215`, `requestDraw` at `L241`, `enableRefunds` at `L279-L294`, `settleWinningTicket` at `L335-L336`, `redeemWinningTicket` at `L311-L312`, `refundTickets` at `L350`, `releaseSponsorPrize` at `L396-L399`).

---

**Block-by-Block:**

```solidity
// L177-L179
if (initialized) revert AlreadyInitialized();
if (msg.sender != factory) revert OnlyFactory();
initialized = true;
```
- **What:** Enforces single initialization and restricts caller authority to the immutable `factory`, then marks `initialized = true`.
- **Why here:** Placed at the very entry of `initialize` before any validation or external view call, locking the clone immediately (`L179`) and rejecting any direct call on `raffleImplementation` (where `initialized` was set to `true` in `Raffle.constructor` at `L164`) or any unauthorized call on a clone.
- **Assumes:** `factory` (`L55`) is the canonical `RaffleFactory` address (established in `Raffle.constructor` at `L161` when deployed by `RaffleFactory.constructor` at `packages/contracts/src/RaffleFactory.sol:L89`), and `initialized` (`L136`) is `false` on a newly cloned instance (`packages/contracts/src/RaffleFactory.sol:L106`).
- **Establishes:** `initialized == true` (`L179`) and `msg.sender == factory` (`L178`) for the remainder of execution and permanently for the clone's lifetime.
- **Depended on by:** Every state-reading and state-changing function in `Raffle.sol`, which relies on clone configuration variables (`L197-L204`) being immutable after this one-time write.

```solidity
// L181-L186
if (
    params.sponsor == address(0) || params.sponsorRecipient == address(0)
        || params.protocolTreasury == address(0) || params.prizeToken == address(0)
) {
    revert ZeroAddress();
}
```
- **What:** Reverts with `ZeroAddress` if any of the four address fields in `params` (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`) is `address(0)`.
- **Why here:** Rejects zero addresses before running `_isProtocolDestination` (`L187-L195`) or writing configuration storage (`L197-L200`).
- **Assumes:** Nothing.
- **Establishes:** `params.sponsor != address(0)`, `params.sponsorRecipient != address(0)`, `params.protocolTreasury != address(0)`, and `params.prizeToken != address(0)` (`L181-L186`).
- **Depended on by:** `onERC721Received` (`L422-L423`, which compares `msg.sender` against `address(prizeToken)` and `from` against `sponsor`), `enableRefunds` (`L282`, which compares `msg.sender` against `sponsor`), `releaseSponsorProceeds` (`L379-L380`), `releaseProtocolFees` (`L389-L390`), and `releaseSponsorPrize` (`L402-L405`).

```solidity
// L187-L195
if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsor);
}
if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.protocolTreasury);
}
if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```
- **What:** Screens `params.sponsor`, `params.protocolTreasury`, and `params.sponsorRecipient` against `_isProtocolDestination(..., params.prizeToken)` (`L593-L605`), reverting with `UnsafeProtocolDestination` if any matches a disallowed protocol address.
- **Why here:** Runs before persisting configuration (`L197-L205`), and passes `params.prizeToken` explicitly because `prizeToken` storage (`L70`) has not been populated yet (`L200`). Crucially, because `Clones.clone` (`packages/contracts/src/RaffleFactory.sol:L106`) has already deployed `address(this)` when `initialize` runs (`L109`), `_isProtocolDestination` checks `destination == address(this)` (`L599`) — catching the case where `sponsor`, `protocolTreasury`, or `sponsorRecipient` equals the newly deployed clone's own address even though `isRaffle[address(this)]` is not set to `true` in `RaffleFactory` until `packages/contracts/src/RaffleFactory.sol:L125`. Furthermore, `RaffleFactory._validateCreateParams` (`packages/contracts/src/RaffleFactory.sol:L154-L179`) does not screen `msg.sender` (`params.sponsor`) or `protocolTreasury` against `params.prizeToken` or `isRaffle`, making `L187-L192` the sole check for those pairs.
- **Assumes:** `factory` implements `IRaffleFactory.raffleImplementation()` and `IRaffleFactory.isRaffle(address)` accurately (`L598-L604`, established by `RaffleFactory.sol:L42, L54`), and `params.prizeToken` itself has already been screened against protocol destinations by `RaffleFactory._validateCreateParams` (`packages/contracts/src/RaffleFactory.sol:L157-L161`).
- **Establishes:** None of `params.sponsor`, `params.protocolTreasury`, or `params.sponsorRecipient` equals `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `params.prizeToken`, `canonicalFactory.raffleImplementation()`, or any contract address currently registered in `canonicalFactory.isRaffle` (`L187-L195`, `L599-L604`).
- **Depended on by:** `releaseSponsorProceeds` (`L380` -> `_transferQuote` at `L565`), `releaseProtocolFees` (`L390` -> `_transferQuote` at `L565`), and `releaseSponsorPrize` (`L402-L405`), which require `sponsorRecipient` and `protocolTreasury` not to be protocol sink addresses.

```solidity
// L197-L205
sponsor = params.sponsor;
sponsorRecipient = params.sponsorRecipient;
protocolTreasury = params.protocolTreasury;
prizeToken = IERC721(params.prizeToken);
prizeTokenId = params.prizeTokenId;
raffleId = params.raffleId;
reserveEntries = params.reserveEntries;
endTime = params.endTime;
status = Status.AwaitingPrize;
```
- **What:** Writes the eight raffle configuration parameters into clone storage and sets `status` to `Status.AwaitingPrize`.
- **Why here:** After all authorization (`L177-L178`) and address validation checks (`L181-L195`) have succeeded. Note that `status` (`L124`) shares a storage slot with `initialized` (`L136`), so writing `status = Status.AwaitingPrize` (`0`) touches an already-warm slot and leaves the clone ready for the factory's subsequent `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` call (`packages/contracts/src/RaffleFactory.sol:L128`).
- **Assumes:** `params.prizeTokenId`, `params.raffleId`, `params.reserveEntries`, and `params.endTime` were validated by `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L98-L105`, `L128-L134`, `L178`).
- **Establishes:** Persistent clone configuration (`sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`) and `status == Status.AwaitingPrize` (`L197-L205`).
- **Depended on by:** `onERC721Received` (`L421-L428`, which checks `status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory`), and all subsequent lifecycle functions (`buyEntries`, `requestDraw`, `enableRefunds`, `fulfillRandomWords`, `_settleWinningTicket`, `redeemWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `drawRequestDeadline`).

---

**Cross-Function Dependencies:**
- **Callee `_isProtocolDestination(address destination, address prizeToken_)` (`internal` / `private view`, `packages/contracts/src/Raffle.sol:L593-L605`):**
  - Read in full. Evaluates:
    1. Short-circuit boolean disjunction (`L599-L601`): `destination == address(this) || destination == factory || destination == address(quoteToken) || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_ || destination == canonicalFactory.raffleImplementation()`.
    2. Conditional registry lookup (`L602-L604`): if `!unsafeDestination && destination.code.length != 0`, sets `unsafeDestination = canonicalFactory.isRaffle(destination)`.
  - Two path-specific properties of `_isProtocolDestination` matter for `initialize`:
    1. When `destination.code.length == 0` (`L602`), `canonicalFactory.isRaffle(destination)` is not queried and `unsafeDestination` returns `false` (provided none of the 6 direct equality checks matched). Because `RaffleFactory` deploys clones via `CREATE` (`Clones.clone` at `packages/contracts/src/RaffleFactory.sol:L106`, `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L57`), future clone addresses of `RaffleFactory` have `code.length == 0` and `isRaffle == false` when an earlier clone's `initialize` runs. If `sponsorRecipient` or `protocolTreasury` is set to such a future clone address, `_isProtocolDestination` returns `false` during `initialize` (`L190-L195`), and returns `true` later during `_transferQuote` (`L565`) after that future clone is created.
    2. For the current clone being initialized (`address(this)`), `RaffleFactory.createRaffle` calls `initialize` (`packages/contracts/src/RaffleFactory.sol:L109`) *before* setting `isRaffle[raffle] = true` (`packages/contracts/src/RaffleFactory.sol:L125`). However, `_isProtocolDestination` still rejects `destination == address(this)` on the first disjunct (`L599`) without needing `isRaffle(address(this))` to be `true`.
- **Callee `IRaffleFactory.raffleImplementation()` (`external-source-available`, `packages/contracts/src/RaffleFactory.sol:L42`):**
  - Public getter for `address public immutable override raffleImplementation` (`packages/contracts/src/RaffleFactory.sol:L42`), initialized in `RaffleFactory.constructor` at `L91`. Always returns the non-zero `Raffle` implementation address without reverting.
- **Callee `IRaffleFactory.isRaffle(address)` (`external-source-available`, `packages/contracts/src/RaffleFactory.sol:L54`):**
  - Public getter for `mapping(address raffle => bool registered) public override isRaffle` (`packages/contracts/src/RaffleFactory.sol:L54`), written only in `RaffleFactory.createRaffle` at `L125`. Always returns `true` for clones that have completed `initialize` and reached `L125` in `createRaffle`, and `false` otherwise.
- **Callers:**
  - `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L109-L121`): the sole valid caller (`L178`). Calls `initialize` immediately after `Clones.clone(raffleImplementation)` (`L106`) and before writing registry mappings (`L123-L125`) and transferring the prize NFT (`L128`). `createRaffle` relies on `initialize` to set `status = Status.AwaitingPrize`, record `sponsor = msg.sender`, `prizeToken = params.prizeToken`, and `prizeTokenId = params.prizeTokenId` so that `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`L128`) triggers `Raffle.onERC721Received` (`L416-L431`) and transitions `status` to `Status.Active` (`L428`, verified at `RaffleFactory.sol:L132`).
- **Shared state:**
  - `initialized` (`L136`): written in `Raffle.constructor` (`L164`) and `Raffle.initialize` (`L179`); read in `Raffle.initialize` (`L177`).
  - `sponsor` (`L61`): written in `Raffle.initialize` (`L197`); read in `enableRefunds` (`L282`) and `onERC721Received` (`L423`).
  - `sponsorRecipient` (`L64`): written in `Raffle.initialize` (`L198`); read in `releaseSponsorProceeds` (`L379`) and `releaseSponsorPrize` (`L402`).
  - `protocolTreasury` (`L67`): written in `Raffle.initialize` (`L199`); read in `releaseProtocolFees` (`L389`).
  - `prizeToken` (`L70`): written in `Raffle.initialize` (`L200`); read in `redeemWinningTicket` (`L332`, `L334-L335`), `releaseSponsorPrize` (`L404-L406`), `onERC721Received` (`L422`), `_update` (`L498`), and `_transferQuote` (`L565`).
  - `prizeTokenId` (`L73`): written in `Raffle.initialize` (`L201`); read in `redeemWinningTicket` (`L333`), `releaseSponsorPrize` (`L404-L406`), and `onERC721Received` (`L422`).
  - `raffleId` (`L76`): written in `Raffle.initialize` (`L202`); exposed via public getter (`L76`).
  - `reserveEntries` (`L79`): written in `Raffle.initialize` (`L203`); read in `fulfillRandomWords` (`L521`).
  - `endTime` (`L82`): written in `Raffle.initialize` (`L204`); read in `buyEntries` (`L216`), `requestDraw` (`L242`), `enableRefunds` (`L281`), and `drawRequestDeadline` (`L459`).
  - `status` (`L124`): written in `Raffle.constructor` (`L165`), `Raffle.initialize` (`L205`), `onERC721Received` (`L428`), `requestDraw` (`L252`), `enableRefunds` (`L299`), and `fulfillRandomWords` (`L521`); read in `buyEntries` (`L215`), `requestDraw` (`L241`), `enableRefunds` (`L279`, `L289`, `L293`), `redeemWinningTicket` (`L311`), `refundTickets` (`L350`), `releaseSponsorPrize` (`L396`), `onERC721Received` (`L422`), `fulfillRandomWords` (`L511`), `_settleWinningTicket` (`L535`), and `_requireStatus` (`L574`).
- **Invariant couplings:**
  - Because `Raffle.initialize` does not validate `params.reserveEntries > 0`, `params.endTime > block.timestamp`, `params.endTime - block.timestamp <= MAX_SALE_DURATION`, or `params.prizeToken` contract/interface/destination properties (`L181-L205`), the clone's configuration invariants depend on `msg.sender == factory` (`L178`) coupling `initialize` exclusively to `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L97-L121`).
  - `_transferQuote` (`L565`) re-evaluates `_isProtocolDestination(to, address(prizeToken))` at claim release time (`releaseSponsorProceeds` at `L380`, `releaseProtocolFees` at `L390`). Because `_isProtocolDestination` reads dynamic state (`destination.code.length` and `canonicalFactory.isRaffle(destination)` at `L602-L604`), the predicate `!_isProtocolDestination(addr, address(prizeToken))` established at `initialize` (`L190-L195`) is only guaranteed to remain `true` at payout time if `addr` is not subsequently registered in `canonicalFactory.isRaffle`.

---

**Open Questions:**
- None; all callers, callees, and state dependencies of `initialize` are in scope and inspected.
