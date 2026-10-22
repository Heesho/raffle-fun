## `RaffleFactory.createRaffle` in target/packages/contracts/src/RaffleFactory.sol (L97-L148)

**Purpose:** Creates the next one-based raffle, deploys a fixed-target ERC-1167 clone, configures it, registers it in both factory lookup directions, escrows the caller's selected ERC-721 prize, verifies the token-reported ownership and clone lifecycle state, and publishes the completed raffle (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`). The interface exposes this as an unrestricted external entrypoint and describes successful completion as an atomic create/initialize/register/fund operation (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L104`).

**Inputs & Assumptions:**

- `params.sponsorRecipient` (`address`): the future sponsor-proceeds and returned-prize recipient (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25`). Trust: **untrusted**, because any external caller can supply it through the unrestricted interface (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L104`). It must be nonzero and must not equal the factory, quote token, VRF wrapper, prospective prize token, raffle implementation, or an already registered raffle (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`). `Raffle.initialize` screens it again against clone-local protocol destinations (`target/packages/contracts/src/Raffle.sol:L181-L195`).
- `params.prizeToken` (`address`): sponsor-selected code that is expected to implement ERC-721 (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25`). Trust: **untrusted**. It must currently contain code, avoid the factory's listed protocol destinations, and return `true` from `supportsInterface(type(IERC721).interfaceId)` (`target/packages/contracts/src/RaffleFactory.sol:L154-L177`). The implementation of that address is not present in scope; the self-report does not establish the behavior of `safeTransferFrom` or `ownerOf`.
- `params.prizeTokenId` (`uint256`): the token identifier passed without transformation to clone initialization, escrow transfer, ownership verification, and the creation event (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`, `target/packages/contracts/src/RaffleFactory.sol:L127-L146`). Trust: **untrusted**. Existence, caller ownership, and factory approval are not pre-queried; for a conforming token, the subsequent `safeTransferFrom` call enforces ownership/approval and reverts if they do not hold (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`). For the selected black-box implementation, nothing in visible source establishes that behavior.
- `params.reserveEntries` (`uint128`): the entry threshold copied into clone storage (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`; `target/packages/contracts/src/Raffle.sol:L197-L205`). Trust: **untrusted**. The factory rejects zero and otherwise accepts the full type range (`target/packages/contracts/src/RaffleFactory.sol:L171-L178`). It later controls the result branch when randomness resolves (`target/packages/contracts/src/Raffle.sol:L518-L523`).
- `params.endTime` (`uint64`): exclusive sale-end timestamp copied into clone storage (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`; `target/packages/contracts/src/Raffle.sol:L197-L205`). Trust: **untrusted**. On entry it must be strictly greater than the current `block.timestamp`, and the difference must not exceed 30 days (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L30`).
- `msg.sender`: becomes the immutable-per-raffle sponsor, the `from` argument of prize escrow, and the indexed sponsor in `RaffleCreated` (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`, `target/packages/contracts/src/RaffleFactory.sol:L127-L146`). Trust: **untrusted**. The factory helper does not screen it, but `Raffle.initialize` rejects it when it is zero or a clone-local protocol destination (`target/packages/contracts/src/Raffle.sol:L181-L195`; `target/packages/contracts/src/Raffle.sol:L593-L604`).
- Implicit environment: `block.timestamp` is sampled once before duration validation (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`); the factory's reentrancy-guard slot is entered before the body and reset after a normal return (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L106`).
- Implicit factory configuration: `quoteToken`, `vrfWrapper`, `protocolTreasury`, and `raffleImplementation` are immutable values fixed by the constructor (`target/packages/contracts/src/RaffleFactory.sol:L30-L43`, `target/packages/contracts/src/RaffleFactory.sol:L65-L91`). The constructor creates the implementation from `Raffle`, making the factory its embedded immutable `factory` and sharing the configured quote token and wrapper with clones (`target/packages/contracts/src/RaffleFactory.sol:L89-L91`; `target/packages/contracts/src/Raffle.sol:L151-L165`).
- Implicit persistent factory state: `raffleCount`, `raffleById`, `idByRaffle`, and `isRaffle` (`target/packages/contracts/src/RaffleFactory.sol:L44-L54`). The function assumes their pre-call entries are internally consistent; `createRaffle` is the only visible writer of all four (`target/packages/contracts/src/RaffleFactory.sol:L105-L125`).

**Outputs & Effects:**

- Returns the address produced by `Clones.clone(raffleImplementation)` (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`). The clone bytecode delegates calls to the fixed implementation address packed into it (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L9-L18`, `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`).
- Increments `raffleCount` and uses the incremented value as the clone's `raffleId` (`target/packages/contracts/src/RaffleFactory.sol:L105-L117`).
- Initializes clone storage with sponsor, recipients, prize, identifier, reserve, end time, and `Status.AwaitingPrize`; initialization also marks the clone initialized (`target/packages/contracts/src/Raffle.sol:L176-L205`).
- Writes a bidirectional registry entry and the registration flag before interacting with the prize token: `raffleById[raffleId]`, `idByRaffle[raffle]`, and `isRaffle[raffle]` (`target/packages/contracts/src/RaffleFactory.sol:L123-L128`).
- Calls the sponsor-selected prize contract to escrow the configured token, then calls it again to read reported ownership (`target/packages/contracts/src/RaffleFactory.sol:L127-L131`). A conforming safe transfer calls the recipient's `onERC721Received` hook (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`); the raffle hook validates token, token ID, sponsor, operator, and lifecycle state, then changes the clone from `AwaitingPrize` to `Active` and emits `PrizeDeposited` (`target/packages/contracts/src/Raffle.sol:L409-L431`).
- Reads the clone's `status` getter and requires `Status.Active` after escrow (`target/packages/contracts/src/RaffleFactory.sol:L129-L134`; `target/packages/contracts/src/Raffle.sol:L123-L124`).
- Emits `RaffleCreated` only after registry writes, the token-reported ownership check, and the active-status check have completed (`target/packages/contracts/src/RaffleFactory.sol:L123-L147`).
- Any explicit validation failure, failed clone deployment, bubbling external-call revert, ownership mismatch, or status mismatch reverts the call at its cited guard (`target/packages/contracts/src/RaffleFactory.sol:L98-L134`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`). Thus none of this function's earlier writes or deployment effects persist on those reverting paths.

---

**Block-by-Block:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
```

- **What:** Opens a permissionless external call under the factory's single reentrancy guard (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L104`).
- **Why here:** The modifier executes before validation and therefore before every call to sponsor-selected code in this function. Its pre-hook rejects an already-entered guard and then writes `ENTERED`; its post-hook restores `NOT_ENTERED` (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L106`).
- **Assumes:** The dedicated guard storage slot is not independently mutated. `StorageSlot.getUint256Slot` maps the fixed key directly to the storage slot (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L35-L37`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L90-L97`), and no factory code exposes a writer to it.
- **Establishes:** A callback cannot enter another `createRaffle` execution until the outer call completes; an attempted nested call observes `ENTERED` and reverts (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L100`).
- **Depended on by:** The ERC-165 query and ERC-721 escrow interaction, both of which execute sponsor-selected code (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`, `target/packages/contracts/src/RaffleFactory.sol:L127-L131`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L98
_validateCreateParams(params);
```

- **What:** Applies code-presence, address-separation, ERC-165-reporting, and nonzero-reserve gates before assigning an ID or deploying a clone (`target/packages/contracts/src/RaffleFactory.sol:L152-L179`).
- **Why here:** All factory and clone writes occur later, beginning with the counter increment at L105 (`target/packages/contracts/src/RaffleFactory.sol:L98-L106`). The only call into sponsor-selected code at this stage is the read-only ERC-165 query (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`).
- **Assumes:** `supportsInterface` truthfully describes the token's behavior. The helper handles both a reverting query and a returned `false`, but the implementation is a black box and nothing in visible source links a returned `true` to correct `safeTransferFrom` or `ownerOf` behavior (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol:L15-L24`).
- **Establishes:** On return, the prize address has nonzero code length; the sponsor recipient is nonzero; neither selected address equals the enumerated factory plumbing or an already registered raffle; the token has returned ERC-721 support; and the reserve is nonzero (`target/packages/contracts/src/RaffleFactory.sol:L154-L179`).
- **Depended on by:** Clone initialization, registry writes keyed by the new clone, and the later calls into the selected prize address (`target/packages/contracts/src/RaffleFactory.sol:L105-L134`).

The helper's paths are complete:

- `_requireContract` reverts exactly when `params.prizeToken.code.length == 0` (`target/packages/contracts/src/RaffleFactory.sol:L155`, `target/packages/contracts/src/RaffleFactory.sol:L181-L185`).
- The prize-token exclusion rejects the factory, quote token, wrapper, implementation, and every address already marked in `isRaffle` (`target/packages/contracts/src/RaffleFactory.sol:L157-L162`).
- The recipient exclusion rejects zero separately, then rejects the factory, quote token, wrapper, selected prize, implementation, and every registered raffle (`target/packages/contracts/src/RaffleFactory.sol:L156-L169`).
- The ERC-165 `try` path records the returned boolean, the `catch` path reverts, and a normal `false` return reverts after the call (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`).
- The final path rejects only a zero reserve (`target/packages/contracts/src/RaffleFactory.sol:L178`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L99-L104
uint256 currentTime = block.timestamp;
if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
uint256 saleDuration = uint256(params.endTime) - currentTime;
if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
    revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
}
```

- **What:** Samples the creation timestamp, requires a future end time, computes the positive duration, and caps it at the fixed 30-day maximum (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L30`).
- **Why here:** The strict ordering guards the subtraction and completes all timing validation before incrementing `raffleCount` (`target/packages/contracts/src/RaffleFactory.sol:L99-L105`).
- **Assumes:** `block.timestamp` is the protocol's time input. No second timestamp sample is used in this transaction (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`).
- **Establishes:** At this execution point, `0 < uint256(params.endTime) - block.timestamp <= 30 days` (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L30`).
- **Depended on by:** `Raffle.initialize` stores `endTime` without additional timing checks, and later sales/draw/refund paths use it (`target/packages/contracts/src/Raffle.sol:L197-L205`, `target/packages/contracts/src/Raffle.sol:L215-L216`, `target/packages/contracts/src/Raffle.sol:L240-L247`, `target/packages/contracts/src/Raffle.sol:L279-L288`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L106
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
```

- **What:** Assigns the next identifier and deploys a new minimal proxy that delegates to the immutable implementation (`target/packages/contracts/src/RaffleFactory.sol:L42-L45`, `target/packages/contracts/src/RaffleFactory.sol:L105-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`).
- **Why here:** Validation completes first; initialization needs both the clone address and assigned identifier (`target/packages/contracts/src/RaffleFactory.sol:L98-L121`).
- **Assumes:** The implementation remains the `Raffle` created by this factory. This is established at factory construction by `new Raffle(quoteToken_, vrfWrapper_)` followed by the immutable assignment (`target/packages/contracts/src/RaffleFactory.sol:L89-L91`). The implementation constructor embeds the creating factory and quote token as immutables (`target/packages/contracts/src/Raffle.sol:L155-L165`).
- **Establishes:** `raffleId` equals the incremented lifetime counter, and a successful `Clones.clone` returns a nonzero new contract address; `create` returning zero causes `FailedDeployment` (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`). The deployed bytecode fixes its delegate target to `raffleImplementation` (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L58`).
- **Depended on by:** Initialization, both registry directions, prize escrow, postconditions, and the creation event (`target/packages/contracts/src/RaffleFactory.sol:L109-L147`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L109-L121
IRaffle(raffle).initialize(
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

- **What:** Calls the freshly deployed proxy, which delegates to the source-visible `Raffle.initialize` implementation with all per-raffle configuration (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`; `target/packages/contracts/src/Raffle.sol:L176-L205`).
- **Why here:** The clone must know the expected prize, sponsor, operator factory, and lifecycle state before it can validate the safe-transfer receiver callback (`target/packages/contracts/src/Raffle.sol:L197-L205`, `target/packages/contracts/src/Raffle.sol:L416-L430`). Registration and escrow follow only after initialization returns (`target/packages/contracts/src/RaffleFactory.sol:L123-L128`).
- **Assumes:** The proxy begins with clone-local `initialized == false`; the implementation constructor's storage writes lock only the implementation, while clones hold isolated storage (`target/packages/contracts/src/Raffle.sol:L151-L165`). `Clones.clone` deploys only the minimal proxy bytecode and passes no initialization call to `create` (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L58`).
- **Establishes:** On the returning path, initialization has confirmed `initialized == false` and `msg.sender == factory`, set `initialized = true`, rejected zero required addresses, screened sponsor/treasury/recipient, copied every supplied field, and set `status = AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`).
- **Depended on by:** The receiver hook compares `status`, `prizeToken`, `prizeTokenId`, `sponsor`, and the immutable factory against callback inputs (`target/packages/contracts/src/Raffle.sol:L416-L430`). Later lifecycle and payout functions consume `endTime`, `reserveEntries`, `sponsorRecipient`, and `protocolTreasury` (`target/packages/contracts/src/Raffle.sol:L215-L216`, `target/packages/contracts/src/Raffle.sol:L379-L390`, `target/packages/contracts/src/Raffle.sol:L402-L405`, `target/packages/contracts/src/Raffle.sol:L518-L523`).

`Raffle.initialize` and its helper were followed on every path:

- It rejects a clone already marked initialized, rejects any caller other than the embedded factory, and writes `initialized = true` before its remaining checks (`target/packages/contracts/src/Raffle.sol:L176-L180`). Reverts in any later branch unwind that write with the external call.
- It rejects zero sponsor, recipient, treasury, or prize addresses (`target/packages/contracts/src/Raffle.sol:L181-L186`).
- It calls `_isProtocolDestination` separately for sponsor, treasury, and sponsor recipient (`target/packages/contracts/src/Raffle.sol:L187-L195`). That helper rejects the clone, factory, quote token, wrapper, prospective prize token, and implementation; when the destination contains code and no direct equality matched, it queries the factory's `isRaffle` registry (`target/packages/contracts/src/Raffle.sol:L593-L604`). The new clone is not registered yet, but its own address is covered by the direct `destination == address(this)` branch (`target/packages/contracts/src/Raffle.sol:L598-L604`; `target/packages/contracts/src/RaffleFactory.sol:L123-L125`).
- Its only external calls are to the immutable canonical factory's generated `raffleImplementation` and conditional `isRaffle` getters (`target/packages/contracts/src/Raffle.sol:L598-L604`; `target/packages/contracts/src/RaffleFactory.sol:L42-L54`).
- Its sole successful exit copies all configuration and leaves the clone awaiting the prize (`target/packages/contracts/src/Raffle.sol:L197-L205`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L123-L125
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;
```

- **What:** Publishes consistent forward, reverse, and membership registry entries (`target/packages/contracts/src/RaffleFactory.sol:L123-L125`).
- **Why here:** The writes occur after initialization succeeds but before the first untrusted state-changing call. Consequently the prize contract and receiver callback can observe the new clone as registered during `safeTransferFrom` (`target/packages/contracts/src/RaffleFactory.sol:L123-L128`).
- **Assumes:** The same clone/ID pair is used for all three writes. This is established locally by the unchanged `raffle` and `raffleId` variables (`target/packages/contracts/src/RaffleFactory.sol:L105-L125`).
- **Establishes:** `raffleById[raffleId] == raffle`, `idByRaffle[raffle] == raffleId`, and `isRaffle[raffle] == true` before prize-code execution (`target/packages/contracts/src/RaffleFactory.sol:L123-L128`).
- **Depended on by:** Factory discovery getters and every raffle's `_isProtocolDestination` registry check (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149`; `target/packages/contracts/src/Raffle.sol:L593-L604`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L127-L128
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
```

- **What:** Invokes sponsor-selected code with the sponsor as `from`, the clone as `to`, and the configured token ID (`target/packages/contracts/src/RaffleFactory.sol:L127-L128`).
- **Why here:** Clone initialization and registration are already visible, so the expected receiver hook can validate its configured values and change the clone from `AwaitingPrize` to `Active` (`target/packages/contracts/src/Raffle.sol:L197-L205`, `target/packages/contracts/src/Raffle.sol:L416-L430`).
- **Assumes:** The external token implements ERC-721 transfer and ownership semantics, calls the receiver hook as specified, and treats a reverting or wrong-selector hook as a failed transfer. Those requirements are declared by the vendored interface (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol:L11-L27`), but no implementation for `params.prizeToken` is visible. Nothing found establishes its behavior.
- **Establishes:** For a conforming token, a normal return means the token accepted the factory's authority, transferred the ID to the clone, and received the expected hook selector. The factory does not rely on normal return alone; it separately checks reported ownership and clone status next (`target/packages/contracts/src/RaffleFactory.sol:L129-L134`).
- **Depended on by:** The two post-call checks and the meaning of both `PrizeDeposited` and `RaffleCreated` (`target/packages/contracts/src/Raffle.sol:L428-L430`; `target/packages/contracts/src/RaffleFactory.sol:L129-L147`).

The source-visible receiver path is:

- `onERC721Received` is externally callable and first requires `status == AwaitingPrize`, caller equal to the configured prize token, token ID equal to the configured ID, `from` equal to the sponsor, and `operator` equal to the immutable factory (`target/packages/contracts/src/Raffle.sol:L416-L426`). Any mismatch reverts.
- Its success path writes `status = Active`, emits `PrizeDeposited`, and returns the receiver selector (`target/packages/contracts/src/Raffle.sol:L428-L430`). It does not query token ownership; the factory performs that as a separate call afterward (`target/packages/contracts/src/RaffleFactory.sol:L129-L134`).
- During the black-box token call, the factory guard is `ENTERED`, so another `createRaffle` call cannot pass the modifier (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L100`). The registry is already populated (`target/packages/contracts/src/RaffleFactory.sol:L123-L128`). After the hook writes `Active` and returns control to the token, other public clone entrypoints are selected by their own status and input checks; the factory later checks only token-reported ownership and `status` (`target/packages/contracts/src/Raffle.sol:L208-L237`; `target/packages/contracts/src/RaffleFactory.sol:L129-L134`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L129-L134
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```

- **What:** Requires the prize contract to report the clone as owner and the source-visible clone getter to report `Active` (`target/packages/contracts/src/RaffleFactory.sol:L129-L134`).
- **Why here:** These are postconditions on the preceding black-box transfer and source-visible callback; the event is emitted only after both hold (`target/packages/contracts/src/RaffleFactory.sol:L127-L147`).
- **Assumes:** `ownerOf` is truthful and stable according to ERC-721 semantics. The visible interface only declares the call and its existence requirement; the selected implementation is absent, so nothing found establishes truthful reporting (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L27-L39`).
- **Establishes:** On the returning path, the selected token's current call result equals the clone address and the clone's current stored lifecycle value equals `Active` (`target/packages/contracts/src/RaffleFactory.sol:L129-L134`; `target/packages/contracts/src/Raffle.sol:L123-L124`).
- **Depended on by:** The semantic content and ordering of `RaffleCreated` (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L28-L52`; `target/packages/contracts/src/RaffleFactory.sol:L136-L147`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L136-L147
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

- **What:** Publishes the canonical identifier, clone address, sponsor, complete selected configuration, and fixed factory configuration (`target/packages/contracts/src/RaffleFactory.sol:L136-L147`).
- **Why here:** It is after initialization, registration, escrow interaction, ownership check, and status check; no external call or state write follows it in the function body (`target/packages/contracts/src/RaffleFactory.sol:L105-L148`).
- **Assumes:** Off-chain consumers correlate the event with the on-chain registry and clone state. The event fields are taken from the same locals, calldata, and immutables used for initialization and registry writes (`target/packages/contracts/src/RaffleFactory.sol:L109-L147`).
- **Establishes:** A successful call has one terminal factory event describing the returned clone (`target/packages/contracts/src/RaffleFactory.sol:L136-L148`). The `nonReentrant` post-hook then restores the factory guard (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L102-L106`).

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` and helpers (internal, source available):** The modifier checks that the fixed guard slot is not `ENTERED`, writes `ENTERED` before the body, and writes `NOT_ENTERED` after a normal return (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L106`). `createRaffle` depends on this across both sponsor-selected external calls (`target/packages/contracts/src/RaffleFactory.sol:L97`, `target/packages/contracts/src/RaffleFactory.sol:L171-L177`, `target/packages/contracts/src/RaffleFactory.sol:L127-L131`).
- **Callee `_validateCreateParams` (internal, `target/packages/contracts/src/RaffleFactory.sol:L154-L179`):** Establishes code presence, direct destination exclusions, a positive reserve, and that the prize contract returned ERC-721 support. It explicitly handles the ERC-165 call's success, `false`, and revert paths (`target/packages/contracts/src/RaffleFactory.sol:L171-L178`). It does not establish actual ERC-721 behavior because the queried implementation is absent.
- **Callee `_requireContract` (internal, `target/packages/contracts/src/RaffleFactory.sol:L183-L185`):** Establishes only nonzero current code length for the prize address. It does not identify the code or constrain future code behavior (`target/packages/contracts/src/RaffleFactory.sol:L183-L185`).
- **Callee `IERC165.supportsInterface` (external black box):** Receives the ERC-721 interface ID and can return `true`, return `false`, or revert; the latter two paths are rejected (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`). A `true` response is relied on as a capability claim, while the later transfer and ownership behavior remains unestablished by visible source (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol:L15-L24`).
- **Callee `Clones.clone` and its value overload (internal, source available):** Packs `raffleImplementation` into minimal-proxy bytecode, deploys it with `create` and zero value, returns the instance, and reverts when `create` returns zero (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L34`, `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`). The factory depends on the fixed delegate target and nonzero returned address.
- **Callee `Raffle.initialize` (external, source available through the clone):** Its returning path enforces one-time factory-only initialization, zero-address and protocol-destination exclusions, copies the exact configuration, and establishes `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`). The factory depends on those fields for the subsequent receiver checks.
- **Callee `Raffle._isProtocolDestination` (internal to `initialize`, source available):** Reads the embedded factory/quote/wrapper, prospective prize, the factory implementation getter, and conditionally the factory registry (`target/packages/contracts/src/Raffle.sol:L593-L604`). It rejects every matching path and returns false only after both direct and conditional registry checks.
- **Callees `RaffleFactory.raffleImplementation` and `RaffleFactory.isRaffle` (external source-available generated getters):** Called back by the clone during `_isProtocolDestination`; their backing immutable and mapping are declared at `target/packages/contracts/src/RaffleFactory.sol:L41-L54`, with the implementation fixed at L89-L91 and registrations written at L123-L125.
- **Callee `IERC721.safeTransferFrom` (external black box):** Receives the sponsor, initialized clone, and selected token ID (`target/packages/contracts/src/RaffleFactory.sol:L127-L128`). The interface specifies owner/approval checks and a receiver call for contract recipients (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`), but the actual selected code can revert, return after arbitrary calls, or depart from those declared semantics. The factory's own state writes land before this call, and a revert unwinds them.
- **Conditional callee `Raffle.onERC721Received` (external source available):** A conforming safe transfer invokes it. It accepts only the configured token/ID/sponsor/factory tuple while awaiting the prize, then writes `Active`, emits `PrizeDeposited`, and returns the selector; all mismatches revert (`target/packages/contracts/src/Raffle.sol:L416-L430`).
- **Callee `IERC721.ownerOf` (external black box):** Its current return must equal the clone or the factory reverts (`target/packages/contracts/src/RaffleFactory.sol:L129-L131`). Visible source does not establish that the returned address reflects persistent token ownership (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L27-L39`).
- **Callee `IRaffle.status` (external source available through the clone):** The generated getter reads the clone's `status` storage declared at `target/packages/contracts/src/Raffle.sol:L123-L124`. The factory requires `Active`, whose expected creation-time source write is the receiver hook at `target/packages/contracts/src/Raffle.sol:L428-L430`.
- **Callers:** No production Solidity function in `target/packages/contracts/src` calls `createRaffle`; the interface makes it directly available to any external actor (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L104`; `target/packages/contracts/src/RaffleFactory.sol:L97`). External integrations are outside the inspected source.
- **Shared factory state:** `raffleCount` is incremented and the three registry mappings are written by this function (`target/packages/contracts/src/RaffleFactory.sol:L44-L54`, `target/packages/contracts/src/RaffleFactory.sol:L105-L125`). `isRaffle` is also read by `_validateCreateParams` and by every clone's `_isProtocolDestination` helper (`target/packages/contracts/src/RaffleFactory.sol:L157-L169`; `target/packages/contracts/src/Raffle.sol:L593-L604`). `quoteToken`, `vrfWrapper`, `protocolTreasury`, and `raffleImplementation` are immutable constructor outputs read here or by clone initialization checks (`target/packages/contracts/src/RaffleFactory.sol:L30-L43`, `target/packages/contracts/src/RaffleFactory.sol:L65-L91`).
- **Shared clone state:** `initialize` writes `initialized`, sponsor, sponsor recipient, treasury, prize token/ID, raffle ID, reserve, end time, and `status` (`target/packages/contracts/src/Raffle.sol:L176-L205`). The receiver reads the sponsor/prize fields and moves status to `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). `endTime` gates sales, draw requests, and refunds (`target/packages/contracts/src/Raffle.sol:L215-L216`, `target/packages/contracts/src/Raffle.sol:L240-L247`, `target/packages/contracts/src/Raffle.sol:L279-L288`); `reserveEntries` selects the resolved result (`target/packages/contracts/src/Raffle.sol:L518-L523`); recipient and treasury feed later release functions (`target/packages/contracts/src/Raffle.sol:L374-L406`).
- **Invariant coupling:** On success the factory counter, forward mapping, reverse mapping, clone-stored `raffleId`, returned address, and event all use the same local pair (`target/packages/contracts/src/RaffleFactory.sol:L105-L125`, `target/packages/contracts/src/RaffleFactory.sol:L136-L147`; `target/packages/contracts/src/Raffle.sol:L197-L205`). The creation lifecycle is coupled across contracts: initialization establishes `AwaitingPrize`, the expected ERC-721 receiver call establishes `Active`, and the factory refuses to emit unless the getter reports `Active` (`target/packages/contracts/src/Raffle.sol:L197-L205`, `target/packages/contracts/src/Raffle.sol:L416-L430`; `target/packages/contracts/src/RaffleFactory.sol:L132-L147`).

---

**Open Questions:**

- unclear; need to inspect the deployed prize-token implementation and any upgrade controls to determine whether its ERC-165 response, safe-transfer behavior, callback ordering, and `ownerOf` result match the interfaces relied on at `target/packages/contracts/src/RaffleFactory.sol:L171-L177` and `target/packages/contracts/src/RaffleFactory.sol:L127-L134`.
- unclear; need to inspect the intended creation-time state contract for whether `RaffleCreated` is expected to imply zero sold entries and otherwise untouched post-initialization state. After the hook sets `Active`, the black-box token regains control before the factory checks only ownership and status (`target/packages/contracts/src/Raffle.sol:L428-L430`; `target/packages/contracts/src/RaffleFactory.sol:L129-L147`), while `buyEntries` is externally reachable in `Active` (`target/packages/contracts/src/Raffle.sol:L208-L237`).
- unclear; need to inspect external integrations to determine whether callers independently verify current on-chain registry, clone state, and token ownership after consuming `RaffleCreated`; no such callers are present under `target/packages/contracts/src` (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L28-L52`, `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L149`).
