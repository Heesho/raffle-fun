## `_validateCreateParams` in packages/contracts/src/RaffleFactory.sol (L154-L179)

**Purpose:** Screens the untrusted `CreateRaffleParams` struct supplied by a prospective sponsor at the start of `RaffleFactory.createRaffle` (`L98`) before the factory validates sale timing (`L99-L104`), increments `raffleCount` (`L105`), clones `raffleImplementation` (`L106`), initializes the clone (`L109-L121`), registers the clone (`L123-L125`), or calls `safeTransferFrom` on the prize token (`L128`). Without it, `createRaffle` could clone and register raffles configured with a zero-address or contract-less `prizeToken`, a zero-address `sponsorRecipient`, a `prizeToken` or `sponsorRecipient` pointing to core protocol contracts (such as `quoteToken`, `vrfWrapper`, `RaffleFactory`, `raffleImplementation`, or an existing registered `Raffle` clone), a `prizeToken` that does not declare ERC-165 support for `IERC721`, or `reserveEntries == 0` (which would make `totalEntries >= reserveEntries` at `Raffle.sol:L521` vacuously true for every resolved draw since `totalEntries >= 1` is required by `Raffle.requestDraw` at `Raffle.sol:L243`).

---

**Inputs & Assumptions:**
- `params` (`IRaffleFactory.CreateRaffleParams calldata`, declared at `packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L26`):
  - `params.sponsorRecipient` (`address`, `IRaffleFactory.sol:L21`): recipient of sponsor USDC proceeds (`Raffle.sol:L379-L380`) and returned prize NFTs (`Raffle.sol:L402-L404`). Trust: **untrusted** (passed directly from `createRaffle` caller at `RaffleFactory.sol:L97-L98`).
  - `params.prizeToken` (`address`, `IRaffleFactory.sol:L22`): prospective ERC-721 contract to escrow. Trust: **untrusted** (passed directly from `createRaffle` caller at `RaffleFactory.sol:L97-L98`).
  - `params.prizeTokenId` (`uint256`, `IRaffleFactory.sol:L23`): token ID to escrow. Trust: **untrusted** (unread by `_validateCreateParams`; consumed later by `createRaffle` at `L116`, `L128-L130`, `L142`).
  - `params.reserveEntries` (`uint128`, `IRaffleFactory.sol:L24`): entry count threshold selecting `Status.NftWon` over `Status.CashWon` at draw resolution (`Raffle.sol:L521`). Trust: **untrusted** (passed directly from `createRaffle` caller at `RaffleFactory.sol:L97-L98`).
  - `params.endTime` (`uint64`, `IRaffleFactory.sol:L25`): exclusive sale-end timestamp. Trust: **untrusted** (unread by `_validateCreateParams`; validated by `createRaffle` at `L99-L104`).
- Implicit:
  - `address(this)`: the `RaffleFactory` contract address (`L158`, `L164`). Trust: **trusted**.
  - `quoteToken` (`address immutable`, `RaffleFactory.sol:L33`): canonical 6-decimal USDC address initialized in `RaffleFactory.constructor` (`L85`). Trust: **trusted**.
  - `vrfWrapper` (`address immutable`, `RaffleFactory.sol:L36`): Chainlink VRF v2.5 wrapper address initialized in `RaffleFactory.constructor` (`L86`). Trust: **trusted**.
  - `raffleImplementation` (`address immutable`, `RaffleFactory.sol:L42`): shared `Raffle` implementation contract deployed in `RaffleFactory.constructor` (`L89-L91`). Trust: **trusted**.
  - `isRaffle` (`mapping(address raffle => bool registered)`, `RaffleFactory.sol:L54`): storage mapping of clones previously registered by this factory (`L125`), read at `L159` and `L166`. Trust: **trusted**.
  - `params.prizeToken.code.length`: external account bytecode length inspected via `_requireContract` (`L155`, `L184`). Trust: **untrusted**.
  - Return data of external `STATICCALL` to `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` (`L172`). Trust: **untrusted**.
- Preconditions:
  - Immutable protocol addresses (`quoteToken`, `vrfWrapper`, `raffleImplementation`) are populated. Established by `RaffleFactory.constructor` (`L85-L91`).
  - Caller `createRaffle` holds the `nonReentrant` lock (`RaffleFactory.sol:L97`), although `_validateCreateParams` itself is `private view` (`L154`) and can only emit `STATICCALL` during external interactions.
  - System assumption that `params.prizeToken` is a standards-compliant, non-malicious ERC-721 implementation (`IRaffle.sol:L14-L15`, `DESIGN.md:L2`): `_validateCreateParams` checks only that `params.prizeToken.code.length > 0` (`L155`, `L184`) and that `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` returns `true` (`L172-L177`). Full ERC-721 compliance of `params.prizeToken` is established by `nothing found`.

---

**Outputs & Effects:**
- Returns: none (`void`).
- State writes: none (`view` function at `L154`).
- Events: none.
- External interactions:
  - `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` (`L172`): high-level Solidity `STATICCALL` (enforced by `view` mutability at `L154`) to untrusted `params.prizeToken` with selector `0x01ffc9a7` (`IERC165.supportsInterface.selector`, `@openzeppelin/contracts/utils/introspection/IERC165.sol:L24`) and argument `0x80ac58cd` (`type(IERC721).interfaceId`, `@openzeppelin/contracts/token/ERC721/IERC721.sol:L11`), without an explicit `{gas: ...}` cap.
- Postconditions (on normal return):
  1. `params.prizeToken.code.length > 0` (`L155`, `L184`), which also guarantees `params.prizeToken != address(0)`.
  2. `params.sponsorRecipient != address(0)` (`L156`).
  3. `params.prizeToken` is not `address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, or any address currently mapped to `true` in `isRaffle` (`L157-L162`).
  4. `params.sponsorRecipient` is not `address(this)`, `quoteToken`, `vrfWrapper`, `params.prizeToken`, `raffleImplementation`, or any address currently mapped to `true` in `isRaffle` (`L163-L169`).
  5. `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` succeeded and returned `true` (`L171-L177`).
  6. `params.reserveEntries > 0` (`L178`).

---

**Block-by-Block:**

```solidity
// L155-L156
_requireContract(params.prizeToken);
if (params.sponsorRecipient == address(0)) revert ZeroAddress();
```
- **What:** Requires `params.prizeToken` to have non-empty deployed code (`L155` -> `L184`) and `params.sponsorRecipient` to be non-zero (`L156`).
- **Why here:** Rejects empty-code addresses (including `address(0)` and EOAs) before the external `supportsInterface` call at `L172`, and rejects a zero `sponsorRecipient` before cloning (`L106`).
- **Assumes:** `params.prizeToken.code.length > 0` at `L184` indicates a deployed contract capable of being called at `L172` and `L128`.
- **Establishes:** `params.prizeToken.code.length > 0` (and therefore `params.prizeToken != address(0)`) and `params.sponsorRecipient != address(0)`.
- **Depended on by:** `IERC165(params.prizeToken).supportsInterface(...)` at `L172`, `IERC721(params.prizeToken).safeTransferFrom(...)` at `L128`, and `Raffle.initialize` (`Raffle.sol:L181-L186`), which also checks `params.sponsorRecipient == address(0)` and `params.prizeToken == address(0)`.

```solidity
// L157-L169
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
- **What:** Reverts with `UnsafeProtocolDestination` if `params.prizeToken` (`L157-L162`) or `params.sponsorRecipient` (`L163-L169`) matches known protocol contract addresses or if `params.sponsorRecipient == params.prizeToken`.
- **Why here:** Prevents a raffle from using another registered raffle ticket contract or core protocol contract as its `prizeToken` (`L158-L159`), and prevents `sponsorRecipient` from being set to a protocol sink (`L164-L166`) before cloning (`L106`) and before external calls to `params.prizeToken` (`L172`, `L128`).
- **Assumes:**
  - `isRaffle` (`L54`, written at `L125`) contains all previously created clones of this factory.
  - Note: At `L98`, the prospective clone `raffle` for the current `createRaffle` call has not yet been deployed (`L106`) or added to `isRaffle` (`L125`). For `params.prizeToken`, equality with the prospective clone is already impossible because `_requireContract(params.prizeToken)` (`L155`) requires existing code prior to `Clones.clone` (`L106`). For `params.sponsorRecipient`, equality with the prospective clone `raffle` is not caught here because `isRaffle[raffle]` is still `false` at `L166`; instead, `Raffle.initialize` catches `params.sponsorRecipient == raffle` via `_isProtocolDestination(params.sponsorRecipient, params.prizeToken)` (`Raffle.sol:L193-L195`, `L599` where `destination == address(this)` is checked).
  - Note: `_validateCreateParams` does not check `params.prizeToken == protocolTreasury`; instead, `Raffle.initialize` rejects `params.protocolTreasury == params.prizeToken` via `_isProtocolDestination(params.protocolTreasury, params.prizeToken)` at `Raffle.sol:L190-L192` and `L600`.
- **Establishes:** `params.prizeToken` is not in `{address(this), quoteToken, vrfWrapper, raffleImplementation}` and `isRaffle[params.prizeToken] == false`; `params.sponsorRecipient` is not in `{address(this), quoteToken, vrfWrapper, params.prizeToken, raffleImplementation}` and `isRaffle[params.sponsorRecipient] == false`.
- **Depended on by:** `createRaffle` (`L109-L134`), `Raffle.initialize` (`Raffle.sol:L193-L195`), `Raffle.releaseSponsorProceeds` (`Raffle.sol:L379-L380`, `L565`), and `Raffle.releaseSponsorPrize` (`Raffle.sol:L402-L404`).

```solidity
// L171-L177
bool supports721 = false;
try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
    supports721 = supported;
} catch {
    revert UnsupportedPrizeToken(params.prizeToken);
}
if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```
- **What:** Performs an external `STATICCALL` to `params.prizeToken.supportsInterface(0x80ac58cd)` and reverts with `UnsupportedPrizeToken(params.prizeToken)` if the call reverts (`L174-L176`) or returns `false` (`L177`).
- **Why here:** Placed after `_requireContract(params.prizeToken)` (`L155`) and protocol-address screening (`L157-L162`) so known protocol contracts and code-less addresses are never queried, and before `createRaffle` mutates state (`L105`) or deploys the clone (`L106`).
- **Assumes:**
  - `params.prizeToken` responds to `supportsInterface(type(IERC721).interfaceId)` without consuming excessive gas (no `{gas: ...}` cap is applied at `L172`, unlike the 30,000 gas bound noted in `@openzeppelin/contracts/utils/introspection/IERC165.sol:L22`; only the sponsor's own transaction gas is at risk during `createRaffle`).
  - Returning `true` from `supportsInterface(type(IERC721).interfaceId)` indicates that `params.prizeToken` implements `IERC721`. Nothing on-chain enforces that an arbitrary contract returning `true` at `L172` honestly implements ERC-721 transfer and ownership logic (`nothing found`).
- **Establishes:** `params.prizeToken` returned a valid ABI-encoded `true` for `IERC165.supportsInterface(0x80ac58cd)` during this call.
- **Depended on by:** `createRaffle` (`L127-L131`), `Raffle.redeemWinningTicket` (`Raffle.sol:L334-L337`), and `Raffle.releaseSponsorPrize` (`Raffle.sol:L404-L405`).

```solidity
// L178
if (params.reserveEntries == 0) revert ZeroReserveEntries();
```
- **What:** Rejects a zero `reserveEntries` threshold.
- **Why here:** Completes parameter validation in `_validateCreateParams` before returning to `createRaffle` (`L98`).
- **Assumes:** Any non-zero `uint128` value (`1` through `type(uint128).max`) is a valid `reserveEntries` configuration; no upper bound below `type(uint128).max` is checked (`nothing found`).
- **Establishes:** `params.reserveEntries >= 1`.
- **Depended on by:** `Raffle.fulfillRandomWords` (`Raffle.sol:L521`: `status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;`), ensuring `reserveEntries` is strictly positive.

---

**Cross-Function Dependencies:**
- **Callee `_requireContract(address account)` (`internal`, `packages/contracts/src/RaffleFactory.sol:L183-L185`):**
  - Checks `if (account.code.length == 0) revert NotContract(account);` (`L184`).
  - Two paths: if `account.code.length == 0`, reverts with `NotContract(account)`; if `account.code.length > 0`, returns normally.
  - `_validateCreateParams` depends on `_requireContract(params.prizeToken)` (`L155`) to establish that `params.prizeToken` has deployed bytecode (`params.prizeToken.code.length > 0`) and is non-zero (`params.prizeToken != address(0)`) on all non-reverting paths.
- **Callee `IERC165(params.prizeToken).supportsInterface(bytes4 interfaceId)` (`external-black-box`, interface at `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol:L24`):**
  - Invoked at `L172` with `type(IERC721).interfaceId` (`0x80ac58cd`, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L11`).
  - Executed as a `STATICCALL` because `_validateCreateParams` is `view` (`L154`), preventing state mutations during the call.
  - Four paths:
    1. Call reverts (including out-of-gas inside callee): caught by `catch` (`L174-L176`), reverts with `UnsupportedPrizeToken(params.prizeToken)`.
    2. Call succeeds and returns ABI-encoded `false`: `supports721` is `false` (`L173`), reverts at `L177` with `UnsupportedPrizeToken(params.prizeToken)`.
    3. Call succeeds and returns malformed or short data (`returndatasize < 32` or non-boolean word `> 1`): Solidity's ABI decoder reverts prior to entering the `returns` or `catch` block.
    4. Call succeeds and returns ABI-encoded `true`: `supports721` is `true` (`L173`), passes `L177`.
  - `_validateCreateParams` depends on it to establish that `params.prizeToken` self-reports `IERC721` interface support, though behavioral compliance of `params.prizeToken` with ERC-721 is not established by this call (`nothing found`).
- **Callers:**
  - `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L98`): sole caller. Relies on `_validateCreateParams` to validate `params.prizeToken`, `params.sponsorRecipient`, and `params.reserveEntries`, while `createRaffle` itself validates `params.endTime` (`L99-L104`), `Raffle.initialize` additionally screens `params.sponsor` (`msg.sender`), `params.protocolTreasury`, and `params.sponsorRecipient` against `_isProtocolDestination` (`Raffle.sol:L187-L195`), and `createRaffle` verifies `params.prizeTokenId` escrow via `safeTransferFrom`, `ownerOf`, and `status() == Status.Active` (`RaffleFactory.sol:L128-L134`, `Raffle.sol:L416-L431`).
- **Shared state:**
  - `quoteToken`, `vrfWrapper`, `raffleImplementation` (immutables written once in `RaffleFactory.constructor` at `L85-L91`, read in `_validateCreateParams` at `L158-L159`, `L164-L166` and `createRaffle` at `L106`, `L143`).
  - `isRaffle` (mapping written in `RaffleFactory.createRaffle` at `L125`, read in `_validateCreateParams` at `L159`, `L166` and externally by `Raffle._isProtocolDestination` at `Raffle.sol:L603`).
- **Invariant couplings:**
  - Coupled with `Raffle.initialize` (`Raffle.sol:L181-L195`) and `Raffle._isProtocolDestination` (`Raffle.sol:L593-L605`): `_validateCreateParams` performs early factory-side rejection of protocol destinations for `prizeToken` and `sponsorRecipient`, while `Raffle.initialize` completes the check once the clone's own address (`address(this)` in `Raffle`), `sponsor` (`msg.sender`), and `protocolTreasury` vs `prizeToken` are in scope.
  - Coupled with `Raffle._transferQuote` (`Raffle.sol:L564-L567`) and `Raffle.releaseSponsorProceeds` (`Raffle.sol:L375-L382`): `Raffle._transferQuote` reverts if `_isProtocolDestination(to, address(prizeToken))` is true (`Raffle.sol:L565`). Because `_validateCreateParams` (`L157-L169`) and `Raffle.initialize` (`Raffle.sol:L193-L195`) reject `sponsorRecipient` if it is a protocol destination at creation time, `sponsorRecipient` can only become a protocol destination later if `sponsorRecipient` was an undeployed address at raffle creation that is subsequently deployed as a new `Raffle` clone by `RaffleFactory.createRaffle` (`L106`, `L125`), in which case `isRaffle[sponsorRecipient]` becomes `true` and `sponsorRecipient.code.length != 0` (`Raffle.sol:L602-L603`).

---

**Open Questions:**
- None; all callees, callers, and state interactions of `_validateCreateParams` are fully resolved in the workspace source.
