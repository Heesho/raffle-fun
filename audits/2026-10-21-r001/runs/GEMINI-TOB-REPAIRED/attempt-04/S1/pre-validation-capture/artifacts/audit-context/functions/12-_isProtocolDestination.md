## `_isProtocolDestination` in packages/contracts/src/Raffle.sol (L593-L605)

**Purpose:** Screens a candidate `destination` address against the current `Raffle` clone, its canonical `RaffleFactory`, the canonical `quoteToken`, the Chainlink VRF v2.5 wrapper (`i_vrfV2PlusWrapper`), the raffle's `prizeToken_`, the factory's `raffleImplementation`, and all clones registered in the factory's `isRaffle` mapping so that role configuration (`initialize`), ERC-721 ticket ownership (`_update`), and USDC payouts (`_transferQuote`) reject known same-factory protocol contracts that cannot redeem tickets or rescue transferred assets.

---

**Inputs & Assumptions:**
- `destination` (`address`): Candidate address being screened. Trust varies by call site:
  - **untrusted** when passed `params.sponsor` (`Raffle.sol:L187`, originating from `msg.sender` in `RaffleFactory.createRaffle` at `RaffleFactory.sol:L112`), `params.sponsorRecipient` (`Raffle.sol:L193`, originating from `CreateRaffleParams.sponsorRecipient` at `RaffleFactory.sol:L113`), `to` in `_update` (`Raffle.sol:L498`, originating from `buyEntries` `recipient` at `Raffle.sol:L209, L235` or `ERC721.transferFrom`/`safeTransferFrom` `to` at `ERC721.sol:L115, L128, L133`), `winner` in `redeemWinningTicket` (`Raffle.sol:L320, L342`), `msg.sender` in `refundTickets` (`Raffle.sol:L369`), or `sponsorRecipient` in `releaseSponsorProceeds` (`Raffle.sol:L379-L380`).
  - **semi-trusted** when passed `params.protocolTreasury` in `initialize` (`Raffle.sol:L190`, originating from immutable `RaffleFactory.protocolTreasury` at `RaffleFactory.sol:L39, L114`) or `protocolTreasury` in `releaseProtocolFees` (`Raffle.sol:L389-L390`).
- `prizeToken_` (`address`): The prize ERC-721 contract address to reject as a destination. Trust: **untrusted** contract address supplied as `params.prizeToken` during `initialize` (`Raffle.sol:L187, L190, L193`, before `prizeToken` storage is written at `Raffle.sol:L200`) or read from clone storage `address(prizeToken)` in `_update` (`Raffle.sol:L498`) and `_transferQuote` (`Raffle.sol:L565`).
- Implicit inputs:
  - `address(this)` (`Raffle.sol:L599`): Executing contract address (the ERC-1167 clone address when called via proxy `delegatecall` from a clone deployed at `RaffleFactory.sol:L106` and `Clones.sol:L54-L57`, or `raffleImplementation` if called directly on the implementation).
  - `factory` (`Raffle.sol:L55, L161, L598-L599`): Immutable `address` set to `msg.sender` in `Raffle.constructor` (`Raffle.sol:L161`).
  - `quoteToken` (`Raffle.sol:L58, L162, L599`): Immutable `IERC20` set in `Raffle.constructor` (`Raffle.sol:L162`).
  - `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L35, L46`, read at `Raffle.sol:L600`): Immutable `IVRFV2PlusWrapper` set in `VRFV2PlusWrapperConsumerBase.constructor`.
  - `destination.code.length` (`Raffle.sol:L602`): Current `EXTCODESIZE` of `destination`.
  - External state in `RaffleFactory` read via `STATICCALL`: `canonicalFactory.raffleImplementation()` (`RaffleFactory.sol:L43`, read at `Raffle.sol:L601`) and `canonicalFactory.isRaffle(destination)` (`RaffleFactory.sol:L54`, read at `Raffle.sol:L603`).
- Preconditions:
  - `factory` is a deployed contract implementing `IRaffleFactory.raffleImplementation()` and `IRaffleFactory.isRaffle(address)`. Established by `RaffleFactory.constructor` deploying `new Raffle(quoteToken_, vrfWrapper_)` (`RaffleFactory.sol:L89`) so `factory = msg.sender` (`Raffle.sol:L161`) is the `RaffleFactory` instance, and `Raffle.constructor` not calling `_isProtocolDestination` while `RaffleFactory` construction is still in progress (`Raffle.sol:L155-L166`).
  - `prizeToken_` is the non-zero configured prize token for the raffle. Established in `initialize` by `if (... || params.prizeToken == address(0)) revert ZeroAddress()` (`Raffle.sol:L183-L185`) prior to `L187-L195`, and in `_update` (`Raffle.sol:L498`) and `_transferQuote` (`Raffle.sol:L565`) by passing storage `address(prizeToken)` which was written at `Raffle.sol:L200` during `initialize`.
  - Every `Raffle` clone registered in `canonicalFactory.isRaffle` has `code.length != 0`. Established by `RaffleFactory.createRaffle` deploying the 45-byte ERC-1167 runtime payload via `Clones.clone(raffleImplementation)` (`RaffleFactory.sol:L106`, `Clones.sol:L54-L57`) before setting `isRaffle[raffle] = true` (`RaffleFactory.sol:L125`), with no `selfdestruct` in `Clones.sol` or `Raffle.sol`.
  - Caller assumption: `_isProtocolDestination(destination, prizeToken_)` returning `false` at validation time (`initialize` at `Raffle.sol:L187-L195` or `_update` at `Raffle.sol:L498`) remains invariant across the raffle's lifecycle. **Established by: nothing found** for addresses matching a future `CREATE` address of `RaffleFactory.createRaffle` (`RaffleFactory.sol:L106`, `Clones.sol:L57`): before that nonce is reached by `RaffleFactory`, the future clone address has `code.length == 0` and `isRaffle[destination] == false` so `_isProtocolDestination` returns `false`, whereas after `RaffleFactory.createRaffle` deploys a clone at that address and sets `isRaffle[raffle] = true` (`RaffleFactory.sol:L125`), `_isProtocolDestination` returns `true` for the same address.

---

**Outputs & Effects:**
- Returns `bool unsafeDestination`: `true` if `destination` equals `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `prizeToken_`, `canonicalFactory.raffleImplementation()`, or (when `destination.code.length != 0`) satisfies `canonicalFactory.isRaffle(destination)`; `false` otherwise.
- State writes: None (`view` function, `Raffle.sol:L595`).
- Events: None.
- External interactions:
  - `STATICCALL` to `IRaffleFactory(factory).raffleImplementation()` (`Raffle.sol:L601`) when `destination` does not match any of the first five addresses in the disjunction (`Raffle.sol:L599-L600`).
  - `STATICCALL` to `IRaffleFactory(factory).isRaffle(destination)` (`Raffle.sol:L603`) when `unsafeDestination` is still `false` after `L601` and `destination.code.length != 0` (`Raffle.sol:L602`).
- Postconditions:
  - Returns `false` for `address(0)` because `factory` (`Raffle.sol:L159`), `quoteToken` (`Raffle.sol:L159`), `i_vrfV2PlusWrapper` (`Raffle.sol:L611`), `prizeToken_` (`Raffle.sol:L183, L200`), `address(this)`, and `raffleImplementation` (`RaffleFactory.sol:L89, L91`) are all non-zero and `address(0).code.length == 0`.
  - When `unsafeDestination == false`, `destination` is not currently identified as any of the seven checked same-factory addresses/categories at the current block state.

---

**Block-by-Block:**

```solidity
// L598-L601
IRaffleFactory canonicalFactory = IRaffleFactory(factory);
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
```
- **What:** Casts the immutable `factory` address to `IRaffleFactory` and evaluates a six-way short-circuiting equality check against `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `prizeToken_`, and `canonicalFactory.raffleImplementation()`.
- **Why here:** Performs all local and immutable address comparisons (`address(this)`, `factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `prizeToken_`) before making the external `STATICCALL` to `canonicalFactory.raffleImplementation()`, and precedes the registry lookup at `L602-L604`. Checking `destination == address(this)` first also ensures that during `Raffle.initialize` (`Raffle.sol:L187-L195`), the newly created clone rejects its own address even though `RaffleFactory.createRaffle` does not set `isRaffle[raffle] = true` until `RaffleFactory.sol:L125` (after `initialize` returns at `RaffleFactory.sol:L109-L121`).
- **Assumes:** `factory` holds a valid `IRaffleFactory` contract whose `raffleImplementation()` getter returns the implementation address without reverting (`RaffleFactory.sol:L43, L89-L91`).
- **Establishes:** If `unsafeDestination` is `false` after `L601`, `destination` is distinct from `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `prizeToken_`, and `canonicalFactory.raffleImplementation()`.
- **Depended on by:** `L602` (`if (!unsafeDestination && ...)`), which skips the registry check when `unsafeDestination` is already `true`.

```solidity
// L602-L604
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```
- **What:** When `destination` did not match the six singleton addresses and currently has non-zero runtime bytecode length, queries `canonicalFactory.isRaffle(destination)` and assigns the result to `unsafeDestination`.
- **Why here:** Avoids an external `STATICCALL` to `canonicalFactory.isRaffle(destination)` when `unsafeDestination` is already `true` or when `destination` has no deployed code (`destination.code.length == 0`, such as an EOA).
- **Assumes:** Every address for which `canonicalFactory.isRaffle(destination)` should reject `destination` already has `destination.code.length != 0` and `isRaffle[destination] == true` at the moment `_isProtocolDestination` executes.
- **Establishes:** `unsafeDestination == true` if `destination` is currently registered in `RaffleFactory.isRaffle` (`RaffleFactory.sol:L54, L125`).
- **Depended on by:** Callers `Raffle.initialize` (`Raffle.sol:L187-L195`), `Raffle._update` (`Raffle.sol:L498-L500`), and `Raffle._transferQuote` (`Raffle.sol:L565`).

---

**Cross-Function Dependencies:**

- **Callee `IRaffleFactory.raffleImplementation` (`external-source-available`, `packages/contracts/src/RaffleFactory.sol:L43`):**
  - Compiler-generated `public immutable` getter returning `raffleImplementation`, which is assigned once in `RaffleFactory.constructor` (`RaffleFactory.sol:L89-L91`) to `address(new Raffle(quoteToken_, vrfWrapper_))`.
  - Contains a single non-reverting path once `RaffleFactory` is deployed. `_isProtocolDestination` depends on it to return the shared `Raffle` implementation address (`Raffle.sol:L601`).
- **Callee `IRaffleFactory.isRaffle` (`external-source-available`, `packages/contracts/src/RaffleFactory.sol:L54`):**
  - Compiler-generated `public` mapping getter reading `mapping(address raffle => bool registered) public override isRaffle`.
  - Written only in `RaffleFactory.createRaffle` at `RaffleFactory.sol:L125` (`isRaffle[raffle] = true;`), after `raffle = Clones.clone(raffleImplementation)` (`RaffleFactory.sol:L106`) and `IRaffle(raffle).initialize(...)` (`RaffleFactory.sol:L109-L121`).
  - Contains a single non-reverting path. `_isProtocolDestination` depends on it to report whether `destination` is a clone created by `factory`. Because `isRaffle[raffle] = true` is written only when `createRaffle` executes for that clone (`RaffleFactory.sol:L125`), `isRaffle(destination)` returns `false` for any future clone address (`CREATE` from `RaffleFactory` at `Clones.sol:L57`) before that clone is created, and `true` after.
- **Callers:**
  - `Raffle.initialize` (`Raffle.sol:L187, L190, L193`): Screens `params.sponsor`, `params.protocolTreasury`, and `params.sponsorRecipient` against `params.prizeToken`, reverting with `UnsafeProtocolDestination` (`Raffle.sol:L188, L191, L194`) if `true`. Note that `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L157-L169`) screens `params.prizeToken` and `params.sponsorRecipient` before cloning, whereas `Raffle.initialize` additionally screens `params.sponsor`, `params.protocolTreasury`, and `params.sponsorRecipient` against the new clone's own address (`address(this)`) and `params.prizeToken`.
  - `Raffle._update` (`Raffle.sol:L498`): Screens non-zero `to` against `address(prizeToken)` on every ERC-721 ticket mint (`buyEntries` -> `_safeMint` at `Raffle.sol:L235`) and transfer (`ERC721.transferFrom` / `safeTransferFrom` at `ERC721.sol:L115-L136`), reverting with `UnsafeProtocolDestination(to)` (`Raffle.sol:L499`) if `true`. Burns pass `to == address(0)` (`ERC721.sol:L304`) and bypass `_isProtocolDestination` via `to != address(0)` (`Raffle.sol:L498`).
  - `Raffle._transferQuote` (`Raffle.sol:L565`): Screens `to` against `address(prizeToken)` before `quoteToken.safeTransfer(to, amount)` (`Raffle.sol:L566`), reverting with `InvalidQuoteDestination(to)` (`Raffle.sol:L565`) if `true`. Reached by `redeemWinningTicket` (`Raffle.sol:L342`, `to = winner`), `refundTickets` (`Raffle.sol:L369`, `to = msg.sender`), `releaseSponsorProceeds` (`Raffle.sol:L380`, `to = sponsorRecipient`), and `releaseProtocolFees` (`Raffle.sol:L390`, `to = protocolTreasury`).
- **Shared state:**
  - `Raffle.factory` (`Raffle.sol:L55`), `Raffle.quoteToken` (`Raffle.sol:L58`), and `VRFV2PlusWrapperConsumerBase.i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L35`): written once in `Raffle.constructor` (`Raffle.sol:L155-L163`) and `VRFV2PlusWrapperConsumerBase.constructor` (`VRFV2PlusWrapperConsumerBase.sol:L40-L47`).
  - `Raffle.prizeToken` (`Raffle.sol:L70`): written once per clone in `Raffle.initialize` (`Raffle.sol:L200`) and passed into `_isProtocolDestination` by `_update` (`Raffle.sol:L498`) and `_transferQuote` (`Raffle.sol:L565`).
  - `RaffleFactory.raffleImplementation` (`RaffleFactory.sol:L43`): written once in `RaffleFactory.constructor` (`RaffleFactory.sol:L91`).
  - `RaffleFactory.isRaffle` (`RaffleFactory.sol:L54`): written in `RaffleFactory.createRaffle` (`RaffleFactory.sol:L125`) and also read directly by `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L159, L166`).
- **Invariant couplings:**
  - Supports the system invariant that protocol plumbing contracts from the same `RaffleFactory` deployment cannot hold active ERC-721 range tickets or receive USDC payouts via `_transferQuote`.
  - Because `RaffleFactory.isRaffle` grows monotonically as new clones are deployed at `RaffleFactory.sol:L106, L125`, `_isProtocolDestination` can transition from `false` to `true` for a precomputed `CREATE` address of `RaffleFactory`:
    1. An address validated at `Raffle.initialize` (`sponsorRecipient` at `Raffle.sol:L193` or `protocolTreasury` at `Raffle.sol:L190`) or at `Raffle._update` (`to` at `Raffle.sol:L498`) before that `CREATE` address is deployed by `RaffleFactory.createRaffle` will later cause `_isProtocolDestination` to return `true` in `_transferQuote` (`Raffle.sol:L565`, blocking `releaseSponsorProceeds`, `releaseProtocolFees`, `redeemWinningTicket` for `CashWon`, or `refundTickets`) and in `Raffle.initialize` for subsequent clones (if `protocolTreasury` was set to that `CREATE` address at `RaffleFactory.sol:L87`).
    2. Conversely, `redeemWinningTicket` for `Status.NftWon` (`Raffle.sol:L329-L337`) and `releaseSponsorPrize` (`Raffle.sol:L395-L407`) transfer the ERC-721 `prizeToken` via `prizeToken.transferFrom(address(this), ...)` (`Raffle.sol:L334, L404`) without re-calling `_isProtocolDestination`, relying entirely on the earlier `_update` (`Raffle.sol:L498`) or `initialize` (`Raffle.sol:L193`) check.
  - Note also that `VRFV2PlusWrapperConsumerBase.i_linkToken` (`VRFV2PlusWrapperConsumerBase.sol:L34, L45`) is not included in `_isProtocolDestination` (`Raffle.sol:L599-L601`).

---

**Open Questions:**
- None; all callees (`IRaffleFactory.raffleImplementation` and `IRaffleFactory.isRaffle`) and all callers in `Raffle.sol` are in scope and inspected in full.
