## `createRaffle` in packages/contracts/src/RaffleFactory.sol (L97-L148)

**Purpose:** Atomically validates sponsor-supplied raffle parameters, deploys and initializes a fresh ERC-1167 `Raffle` clone, registers the clone in the factory's canonical bidirectional mappings, escrows the configured ERC-721 prize into the clone via `safeTransferFrom`, and verifies that the clone holds the prize and is in `Status.Active` before emitting `RaffleCreated`. Without this function, no canonical `Raffle` clone can be deployed, initialized (`Raffle.sol:L178`), or registered in `isRaffle` (`RaffleFactory.sol:L125`).

**Inputs & Assumptions:**
- `params` (`IRaffleFactory.CreateRaffleParams calldata`, defined at `IRaffleFactory.sol:L20-L26`):
  - `params.sponsorRecipient` (`address`): recipient of sponsor quote proceeds (`Raffle.sol:L379-L380`) and returned prize NFT on `CashWon` or `Refunding` (`Raffle.sol:L402-L404`). Trust: **untrusted**.
  - `params.prizeToken` (`address`): prospective ERC-721 prize contract. Trust: **untrusted**.
  - `params.prizeTokenId` (`uint256`): token ID to escrow from `msg.sender` into the new clone. Trust: **untrusted**.
  - `params.reserveEntries` (`uint128`): minimum `totalEntries` threshold required to resolve to `Status.NftWon` (`Raffle.sol:L521`). Trust: **untrusted**.
  - `params.endTime` (`uint64`): exclusive Unix timestamp at which entry sales close (`Raffle.sol:L216, L242`). Trust: **untrusted**.
- Implicit inputs:
  - `msg.sender` (`address`): prospective raffle sponsor (`RaffleFactory.sol:L112, L128, L139`). Trust: **untrusted**.
  - `block.timestamp` (`uint256`): current block timestamp used to bound `params.endTime` (`RaffleFactory.sol:L99-L104`). Trust: **trusted** (execution environment).
  - `quoteToken` (`address` immutable, `RaffleFactory.sol:L33`): canonical 6-decimal USDC address configured at factory deployment (`RaffleFactory.sol:L85`). Trust: **trusted**.
  - `vrfWrapper` (`address` immutable, `RaffleFactory.sol:L36`): Chainlink VRF v2.5 wrapper address configured at factory deployment (`RaffleFactory.sol:L86`). Trust: **trusted**.
  - `protocolTreasury` (`address` immutable, `RaffleFactory.sol:L39`): fee recipient configured at factory deployment (`RaffleFactory.sol:L87`). Trust: **semi-trusted**.
  - `raffleImplementation` (`address` immutable, `RaffleFactory.sol:L42`): shared `Raffle` implementation deployed in the factory constructor (`RaffleFactory.sol:L89-L91`). Trust: **trusted**.
  - `raffleCount` (`uint256`, `RaffleFactory.sol:L45`) and `isRaffle` (`mapping(address => bool)`, `RaffleFactory.sol:L54`): factory storage read and mutated during creation.
  - `REENTRANCY_GUARD_STORAGE` (`ReentrancyGuard.sol:L36-L37`): storage slot read and mutated by `nonReentrant` (`RaffleFactory.sol:L97`).
- Preconditions:
  - Reentrancy lock is `NOT_ENTERED` (`1`). Established by `ReentrancyGuard._nonReentrantBefore` (`ReentrancyGuard.sol:L88-L100`).
  - `raffleImplementation` contains deployed `Raffle` runtime code with `factory == address(this)` (`Raffle.sol:L161`). Established by `RaffleFactory.constructor` (`RaffleFactory.sol:L89-L91`).
  - `protocolTreasury` is non-zero and not equal to `address(this)`, `quoteToken`, `vrfWrapper`, or `raffleImplementation`. Established by `RaffleFactory.constructor` (`RaffleFactory.sol:L68, L80-L83, L90`).
  - `protocolTreasury` is not equal to the newly deployed `raffle` clone or any previously registered raffle in `isRaffle`. Enforced at clone initialization by `Raffle.initialize` -> `Raffle._isProtocolDestination` (`Raffle.sol:L190-L192, L599-L604`).
  - `msg.sender` (the `sponsor`) is non-zero and not equal to `address(this)`, `quoteToken`, `vrfWrapper`, `params.prizeToken`, `raffleImplementation`, the new `raffle` clone, or any registered raffle in `isRaffle`. Not checked in `RaffleFactory`; enforced by `Raffle.initialize` -> `Raffle._isProtocolDestination` (`Raffle.sol:L182, L187-L189, L599-L604`).
  - `params.sponsorRecipient` is not equal to the newly deployed `raffle` clone. Not checked in `_validateCreateParams` (which runs before `raffle` is deployed and registered at `RaffleFactory.sol:L106, L125`); enforced by `Raffle.initialize` -> `Raffle._isProtocolDestination` via `destination == address(this)` (`Raffle.sol:L193-L195, L599`).
  - `params.prizeToken` is a genuinely standards-compliant ERC-721 contract whose `safeTransferFrom` and `ownerOf` enforce exclusive token custody by `raffle` until `raffle` calls `transferFrom`. `_validateCreateParams` checks code presence and ERC-165 `IERC721` interface support (`RaffleFactory.sol:L155, L171-L177`), and `createRaffle` verifies `onERC721Received` activation (`RaffleFactory.sol:L132-L134`) and immediate post-transfer `ownerOf(params.prizeTokenId) == raffle` (`RaffleFactory.sol:L129-L131`). Honesty of `params.prizeToken` beyond those checks is established by **nothing found**.
  - `params.sponsorRecipient` can receive `quoteToken` via `SafeERC20.safeTransfer` (`Raffle.sol:L380, L566`) and `params.prizeToken` via `IERC721.transferFrom` (`Raffle.sol:L404`) without reverting. Non-zero and protocol-sink screening are established at `RaffleFactory.sol:L156, L163-L169` and `Raffle.sol:L182, L193-L195`; absence of token-level blacklisting or transfer restrictions on `params.sponsorRecipient` is established by **nothing found**.

**Outputs & Effects:**
- Return value: `raffle` (`address`), the newly deployed, initialized, registered, and active ERC-1167 `Raffle` clone (`RaffleFactory.sol:L97, L106`).
- Factory state writes:
  - `raffleCount`: incremented by 1 (`++raffleCount` at `RaffleFactory.sol:L105`).
  - `raffleById[raffleId] = raffle` (`RaffleFactory.sol:L123`).
  - `idByRaffle[raffle] = raffleId` (`RaffleFactory.sol:L124`).
  - `isRaffle[raffle] = true` (`RaffleFactory.sol:L125`).
- Clone deployment and state writes (via `Clones.clone`, `Raffle.initialize`, and `Raffle.onERC721Received`):
  - Deploys a 45-byte ERC-1167 minimal proxy via `CREATE` (`Clones.sol:L54-L58`).
  - Sets `initialized = true`, `sponsor = msg.sender`, `sponsorRecipient = params.sponsorRecipient`, `protocolTreasury = protocolTreasury`, `prizeToken = IERC721(params.prizeToken)`, `prizeTokenId = params.prizeTokenId`, `raffleId = raffleId`, `reserveEntries = params.reserveEntries`, `endTime = params.endTime`, and `status = Status.AwaitingPrize` (`Raffle.sol:L179, L197-L205`).
  - Sets `status = Status.Active` inside `Raffle.onERC721Received` (`Raffle.sol:L428`).
- External interactions:
  - `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` (`STATICCALL` inside `_validateCreateParams` at `RaffleFactory.sol:L172`).
  - `Clones.clone(raffleImplementation)` (`CREATE` opcode at `RaffleFactory.sol:L106`, `Clones.sol:L57`).
  - `IRaffle(raffle).initialize(...)` (`CALL` to fresh clone at `RaffleFactory.sol:L109-L121`, which makes `STATICCALL`s back to `factory.raffleImplementation()` and `factory.isRaffle(...)` at `Raffle.sol:L601-L603`).
  - `IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`CALL` to untrusted `params.prizeToken` at `RaffleFactory.sol:L128`, expected to call `raffle.onERC721Received` at `Raffle.sol:L416`).
  - `IERC721(params.prizeToken).ownerOf(params.prizeTokenId)` (`STATICCALL` to untrusted `params.prizeToken` at `RaffleFactory.sol:L129`).
  - `IRaffle(raffle).status()` (`STATICCALL` to `raffle` clone at `RaffleFactory.sol:L132`).
- Events emitted:
  - `IRaffle.PrizeDeposited(params.prizeToken, params.prizeTokenId, msg.sender)` emitted by `raffle` inside `onERC721Received` (`Raffle.sol:L429`).
  - `IRaffleFactory.RaffleCreated(raffleId, raffle, msg.sender, params.sponsorRecipient, params.prizeToken, params.prizeTokenId, quoteToken, protocolTreasury, params.reserveEntries, params.endTime)` emitted by `RaffleFactory` (`RaffleFactory.sol:L136-L147`).
- Postconditions on success:
  - `raffle` is deployed, initialized (`initialized == true`), registered (`raffleById[raffleId] == raffle`, `idByRaffle[raffle] == raffleId`, `isRaffle[raffle] == true`), and in `Status.Active` (`RaffleFactory.sol:L132-L134`).
  - `IERC721(params.prizeToken).ownerOf(params.prizeTokenId)` returned `raffle` at `RaffleFactory.sol:L129`.
  - `block.timestamp < raffle.endTime() <= block.timestamp + 30 days` (`RaffleFactory.sol:L99-L104`) and `raffle.reserveEntries() >= 1` (`RaffleFactory.sol:L178`).

---

**Block-by-Block:**

```solidity
// L97-L98
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
```
- **What:** Acquires the factory reentrancy lock and validates `params.prizeToken`, `params.sponsorRecipient`, ERC-165 `IERC721` support, and `params.reserveEntries`.
- **Why here:** Rejects invalid addresses, non-contract prize addresses, protocol-sink destinations, non-ERC-721 contracts, and zero reserve thresholds before incrementing `raffleCount` or deploying a clone.
- **Assumes:** `ReentrancyGuard` storage is `NOT_ENTERED` (`ReentrancyGuard.sol:L88-L100`).
- **Establishes:**
  - `REENTRANCY_GUARD_STORAGE == ENTERED` (`ReentrancyGuard.sol:L99`).
  - `params.prizeToken.code.length > 0` (`RaffleFactory.sol:L155, L184`).
  - `params.sponsorRecipient != address(0)` (`RaffleFactory.sol:L156`).
  - Neither `params.prizeToken` nor `params.sponsorRecipient` is `address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, or any existing address in `isRaffle`, and `params.sponsorRecipient != params.prizeToken` (`RaffleFactory.sol:L157-L169`).
  - `IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` returned `true` (`RaffleFactory.sol:L171-L177`).
  - `params.reserveEntries > 0` (`RaffleFactory.sol:L178`).
- **Depended on by:** Clone initialization (`RaffleFactory.sol:L109-L121`), prize escrow (`RaffleFactory.sol:L127-L134`), and downstream raffle resolution (`Raffle.sol:L521`).

```solidity
// L99-L104
uint256 currentTime = block.timestamp;
if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
uint256 saleDuration = uint256(params.endTime) - currentTime;
if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
    revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
}
```
- **What:** Verifies that `params.endTime` is strictly in the future and no more than `MAX_SALE_DURATION` (`30 days`, `RaffleConstants.sol:L30`) after `block.timestamp`.
- **Why here:** Checked before state mutations and clone deployment; L100 guards the checked subtraction at L101 against underflow.
- **Assumes:** Nothing beyond `block.timestamp` availability.
- **Establishes:** `block.timestamp < params.endTime <= block.timestamp + 30 days`. Because `params.endTime` is `uint64`, `uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT` in `Raffle.drawRequestDeadline()` (`Raffle.sol:L458-L460`) cannot overflow `uint256`.
- **Depended on by:** `Raffle.initialize` (`Raffle.sol:L204`, which stores `endTime` without re-validating bounds), `Raffle.buyEntries` (`Raffle.sol:L216`), `Raffle.requestDraw` (`Raffle.sol:L242`), and `Raffle.enableRefunds` (`Raffle.sol:L281`).

```solidity
// L105-L121
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
- **What:** Assigns a sequential 1-based `raffleId`, deploys an ERC-1167 minimal proxy pointing to `raffleImplementation`, and initializes its storage with the raffle configuration and `Status.AwaitingPrize`.
- **Why here:** `raffle` must be deployed and initialized into `Status.AwaitingPrize` before `prize.safeTransferFrom` triggers `raffle.onERC721Received` (`Raffle.sol:L421-L425`). Running `initialize` before setting `isRaffle[raffle] = true` (L125) avoids a redundant registry hit during `_isProtocolDestination`, while `destination == address(this)` inside `Raffle._isProtocolDestination` (`Raffle.sol:L599`) still rejects `sponsor == raffle`, `protocolTreasury == raffle`, and `sponsorRecipient == raffle`.
- **Assumes:** `raffleImplementation` has deployed `Raffle` code with `factory == address(this)` (established by `RaffleFactory.constructor` at `RaffleFactory.sol:L89-L91` and `Raffle.constructor` at `Raffle.sol:L161`).
- **Establishes:**
  - `raffleCount` is incremented by 1 and `raffleId >= 1` (L105).
  - `raffle != address(0)` and `raffle` contains ERC-1167 proxy code delegating to `raffleImplementation` (`Clones.sol:L54-L61`).
  - `raffle.initialized() == true` and `raffle.status() == Status.AwaitingPrize` (`Raffle.sol:L179, L205`).
  - `msg.sender` (`sponsor`), `protocolTreasury`, and `params.sponsorRecipient` are all verified to be non-zero and not equal to `raffle`, `address(this)`, `quoteToken`, `vrfWrapper`, `params.prizeToken`, `raffleImplementation`, or any existing registered raffle (`Raffle.sol:L181-L195, L593-L605`).
- **Depended on by:** Registry writes at L123-L125 and `Raffle.onERC721Received` during `safeTransferFrom` at L128.

```solidity
// L123-L125
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;
```
- **What:** Records the bidirectional mapping between `raffleId` and `raffle` and marks `isRaffle[raffle] = true`.
- **Why here:** Executed before the external call `prize.safeTransferFrom` at L128 so that `isRaffle[raffle]` is already `true` if `params.prizeToken` makes external calls to any existing or newly created `Raffle` clone (where `_isProtocolDestination` queries `canonicalFactory.isRaffle(destination)` at `Raffle.sol:L603`).
- **Assumes:** `raffleId` and `raffle` are unique (established by `++raffleCount` at L105 and `CREATE` nonce progression in `Clones.clone` at L106).
- **Establishes:** `raffleById[raffleId] == raffle`, `idByRaffle[raffle] == raffleId`, and `isRaffle[raffle] == true`.
- **Depended on by:** `Raffle._isProtocolDestination` (`Raffle.sol:L603`), `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L159, L166`), and external callers querying factory registries.

```solidity
// L127-L134
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```
- **What:** Calls `safeTransferFrom` on `params.prizeToken` to transfer `params.prizeTokenId` from `msg.sender` to `raffle`, then verifies that `prize.ownerOf(params.prizeTokenId) == raffle` and `IRaffle(raffle).status() == IRaffle.Status.Active`.
- **Why here:** After `raffle` is initialized (`Status.AwaitingPrize`) and registered (`isRaffle[raffle] == true`), so `raffle.onERC721Received` has the stored configuration needed to validate `(msg.sender == address(prizeToken), tokenId == prizeTokenId, from == sponsor, operator == factory)` (`Raffle.sol:L421-L425`) and transition `status` to `Status.Active` (`Raffle.sol:L428`). The post-call checks at L129-L134 ensure that `safeTransferFrom` neither skipped `onERC721Received` nor left `params.prizeTokenId` reported under a different owner or left `raffle` in `Status.Refunding` (for example, if `sponsor` called `raffle.enableRefunds()` during a callback from `prizeToken`).
- **Assumes:** `params.prizeToken` is an honest ERC-721 contract whose `ownerOf(params.prizeTokenId) == raffle` guarantee persists after creation (`establishedBy: "nothing found"`).
- **Establishes:**
  - `prize.ownerOf(params.prizeTokenId)` returned `raffle` at L129.
  - `raffle.onERC721Received` executed with `msg.sender == params.prizeToken`, `tokenId == params.prizeTokenId`, `from == msg.sender`, and `operator == address(this)` (`Raffle.sol:L421-L428`).
  - `IRaffle(raffle).status() == IRaffle.Status.Active` at L132.
- **Depended on by:** Event emission at L136-L147 and the entire downstream lifecycle of `raffle` (`buyEntries`, `requestDraw`, `enableRefunds`, `redeemWinningTicket`, `releaseSponsorPrize`).

```solidity
// L136-L147
emit RaffleCreated(
    raffleId,
    raffle,
    msg.sender,
    params.sponsorRecipient,
    params.prizeToken,
    params.prizeTokenId,
    quoteToken,
    protocolTreasury,
    params.reserveEntries,
    params.endTime
);
```
- **What:** Emits `RaffleCreated` with the immutable and sponsor-supplied configuration of the active raffle clone.
- **Why here:** Emitted last, after all state mutations, external transfers, and post-transfer verification checks have succeeded.
- **Assumes:** All prior steps succeeded.
- **Establishes:** Off-chain indexers observe `RaffleCreated` only for initialized, registered, and active clones. (Note: if `params.prizeToken` invokes `raffle.buyEntries` during `safeTransferFrom` at L128 after `raffle.onERC721Received` sets `status = Status.Active`, `PrizeDeposited` and `TicketPurchased` events from `raffle` will precede `RaffleCreated` in transaction log order.)
- **Depended on by:** Off-chain discovery and indexers (`DESIGN.md:L2`).

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` (`external-source-available`, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73, L88-L106`):**
  - `_nonReentrantBefore` (L94-L100) reverts with `ReentrancyGuardReentrantCall()` if `REENTRANCY_GUARD_STORAGE == ENTERED`, then sets it to `ENTERED`. `_nonReentrantAfter` (L102-L106) resets it to `NOT_ENTERED`.
  - Prevents reentrant calls into `RaffleFactory.createRaffle` while control is in `params.prizeToken` (L128). Does not block view getters on `RaffleFactory` (`raffleCount`, `raffleById`, `idByRaffle`, `isRaffle`, `raffleImplementation`) or external calls to `Raffle` clones.
- **Callee `RaffleFactory._validateCreateParams` (`internal`, `packages/contracts/src/RaffleFactory.sol:L154-L179`) and `RaffleFactory._requireContract` (`internal`, `packages/contracts/src/RaffleFactory.sol:L183-L185`):**
  - Walked all paths:
    1. `_requireContract(params.prizeToken)` (L155 -> L183-L185): reverts with `NotContract(params.prizeToken)` if `params.prizeToken.code.length == 0` (which also rejects `address(0)`).
    2. `params.sponsorRecipient == address(0)` (L156): reverts with `ZeroAddress()`.
    3. `params.prizeToken` sink check (L157-L162): reverts with `UnsafeProtocolDestination(params.prizeToken)` if `params.prizeToken` equals `address(this)`, `quoteToken`, `vrfWrapper`, `raffleImplementation`, or has `isRaffle[params.prizeToken] == true`.
    4. `params.sponsorRecipient` sink check (L163-L169): reverts with `UnsafeProtocolDestination(params.sponsorRecipient)` if `params.sponsorRecipient` equals `address(this)`, `quoteToken`, `vrfWrapper`, `params.prizeToken`, `raffleImplementation`, or has `isRaffle[params.sponsorRecipient] == true`.
    5. `try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)` (L171-L177): executes an unbounded-gas `STATICCALL` to `params.prizeToken`; reverts with `UnsupportedPrizeToken(params.prizeToken)` if the call reverts, returns un-decodable data, or returns `false`.
    6. `params.reserveEntries == 0` (L178): reverts with `ZeroReserveEntries()`.
  - Does **not** validate `msg.sender` (`sponsor`), does **not** check `params.sponsorRecipient` against the not-yet-created `raffle` clone address, and does **not** validate `params.endTime` (which is checked in `createRaffle` at L99-L104).
- **Callee `Clones.clone(address)` (`external-source-available`, `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`):**
  - Calls `clone(implementation, 0)` (L33 -> L47-L62). Since `value == 0`, `address(this).balance < value` (L48) is false. Packs the 55-byte creation code for a 45-byte ERC-1167 runtime proxy targeting `implementation` into scratch memory `0x00..0x3f` and executes `create(0, 0x09, 0x37)` (L54-L57). Reverts with `Errors.FailedDeployment()` if `instance == address(0)` (L59-L61).
  - Does not check `implementation.code.length > 0`; `createRaffle` relies on `RaffleFactory.constructor` (`RaffleFactory.sol:L89-L91`) having deployed `raffleImplementation`.
- **Callee `Raffle.initialize` (`internal`, `packages/contracts/src/Raffle.sol:L176-L206`) and `Raffle._isProtocolDestination` (`internal`, `packages/contracts/src/Raffle.sol:L593-L605`):**
  - Walked all paths:
    1. Reverts with `AlreadyInitialized()` if `initialized == true` (L177) and `OnlyFactory()` if `msg.sender != factory` (L178), then sets `initialized = true` (L179).
    2. Reverts with `ZeroAddress()` if any of `sponsor`, `sponsorRecipient`, `protocolTreasury`, or `prizeToken` is `address(0)` (L181-L186).
    3. Screens `sponsor` (L187-L189), `protocolTreasury` (L190-L192), and `sponsorRecipient` (L193-L195) via `_isProtocolDestination(destination, params.prizeToken)` (L593-L605).
    4. Inside `_isProtocolDestination` (L598-L604): checks `destination == address(this)` (the new `raffle` clone itself), `destination == factory`, `destination == address(quoteToken)`, `destination == address(i_vrfV2PlusWrapper)`, `destination == prizeToken_`, `destination == canonicalFactory.raffleImplementation()`, and (when `destination.code.length != 0`) `canonicalFactory.isRaffle(destination)`. This is the **only** place that rejects `msg.sender` (`sponsor`) being a protocol sink or existing raffle, and the **only** place that rejects `sponsor`, `protocolTreasury`, or `sponsorRecipient` being equal to the newly deployed `raffle` clone (`address(this)`).
    5. Stores `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`, and `status = Status.AwaitingPrize` (L197-L205).
    6. Does **not** validate `reserveEntries > 0` or `endTime` bounds; relies on `RaffleFactory.createRaffle` (L98-L104, L178) for those invariants.
- **Callee `IERC721(params.prizeToken).safeTransferFrom` (`external-black-box`, invoked at `packages/contracts/src/RaffleFactory.sol:L128`):**
  - Untrusted external call with `(from: msg.sender, to: raffle, tokenId: params.prizeTokenId)`.
  - Expected to transfer `params.prizeTokenId` to `raffle` and invoke `IERC721Receiver(raffle).onERC721Received(address(this), msg.sender, params.prizeTokenId, "")`.
  - Because `params.prizeToken` is untrusted and has full execution control during `safeTransferFrom`:
    - It cannot re-enter `RaffleFactory.createRaffle` because `nonReentrant` is active (`RaffleFactory.sol:L97`).
    - It must call `raffle.onERC721Received(address(this), msg.sender, params.prizeTokenId, ...)` exactly once while `raffle.status == Status.AwaitingPrize`, or else `IRaffle(raffle).status() != IRaffle.Status.Active` at `RaffleFactory.sol:L132` will revert.
    - After calling `raffle.onERC721Received` (which sets `raffle.status = Status.Active` at `Raffle.sol:L428`), `params.prizeToken` can call external functions on `raffle` that are valid in `Status.Active` prior to `endTime`:
      - If `params.prizeToken` (or `msg.sender` via callback) calls `raffle.enableRefunds()` (`Raffle.sol:L276`), `raffle.status` transitions to `Status.Refunding` (`Raffle.sol:L299`), causing `createRaffle` to revert at `RaffleFactory.sol:L132-L134`.
      - If `params.prizeToken` (or another caller) calls `raffle.buyEntries(...)` (`Raffle.sol:L209`) during `safeTransferFrom` after `onERC721Received`, `buyEntries` succeeds (`raffle.status` remains `Status.Active`), so `createRaffle` completes with `totalEntries > 0` and `TicketPurchased` emitted before `RaffleCreated`.
- **Callee `Raffle.onERC721Received` (`internal`, `packages/contracts/src/Raffle.sol:L416-L431`):**
  - Reverts with `UnexpectedPrize(msg.sender, tokenId, from, operator)` unless `status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory` (L421-L426).
  - Transitions `status = Status.Active` (L428), emits `PrizeDeposited(msg.sender, tokenId, from)` (L429), and returns `IERC721Receiver.onERC721Received.selector` (L430).
- **Callee `IERC721(params.prizeToken).ownerOf` (`external-black-box`, invoked at `packages/contracts/src/RaffleFactory.sol:L129`):**
  - `STATICCALL` to untrusted `params.prizeToken`. `createRaffle` reverts with `PrizeEscrowVerificationFailed` if the return value is not `raffle` (L129-L131). Does not guarantee that a non-standard/malicious `params.prizeToken` will continue reporting `raffle` as owner or permit transfer when `redeemWinningTicket` (`Raffle.sol:L334-L337`) or `releaseSponsorPrize` (`Raffle.sol:L404-L405`) is later called.
- **Callee `IRaffle(raffle).status` (`internal`, `packages/contracts/src/Raffle.sol:L124`, invoked at `packages/contracts/src/RaffleFactory.sol:L132`):**
  - `STATICCALL` to the newly created `raffle` clone reading storage variable `status`. `createRaffle` reverts with `PrizeEscrowVerificationFailed` if `status != IRaffle.Status.Active` (L132-L134).
- **Callers:**
  - External entrypoint (`RaffleFactory.sol:L97`); no internal callers in the repository.
- **Shared state:**
  - `raffleCount`, `raffleById`, `idByRaffle`: written only by `RaffleFactory.createRaffle` (`RaffleFactory.sol:L105, L123-L124`).
  - `isRaffle`: written only by `RaffleFactory.createRaffle` (`RaffleFactory.sol:L125`); read by `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:L159, L166`) and `Raffle._isProtocolDestination` (`Raffle.sol:L603`) during `Raffle.initialize` (`Raffle.sol:L187-L195`), `Raffle._update` (`Raffle.sol:L498`), and `Raffle._transferQuote` (`Raffle.sol:L565`).
  - Clone storage (`initialized`, `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`, `status`): written via `Raffle.initialize` (`Raffle.sol:L179, L197-L205`) and `Raffle.onERC721Received` (`Raffle.sol:L428`); read across all lifecycle functions in `Raffle.sol`.
- **Invariant couplings:**
  - Every address with `isRaffle[addr] == true` has `addr.code.length == 45` (deployed by `Clones.clone` at `RaffleFactory.sol:L106`, `Clones.sol:L54-L57`). `Raffle._isProtocolDestination` (`Raffle.sol:L602-L604`) relies on `destination.code.length != 0` to skip calling `canonicalFactory.isRaffle(destination)` for code-less addresses while still catching all registered raffles.
  - Every registered raffle has `1 <= reserveEntries <= type(uint128).max` (`RaffleFactory.sol:L178`) and `block.timestamp < endTime <= block.timestamp + 30 days` at creation (`RaffleFactory.sol:L99-L104`), which `Raffle` relies on without re-checking in `Raffle.initialize`.

**Open Questions:**
- None; all production and dependency source files on the `createRaffle` call path are in scope and inspected.
