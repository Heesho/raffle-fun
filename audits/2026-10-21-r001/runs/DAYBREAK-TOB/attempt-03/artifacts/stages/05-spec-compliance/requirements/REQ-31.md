## REQ-31 — Fixed logic and no upgrade authority

> "No administrator, mutable configuration or upgrade."
> — DESIGN.md:L2, sentence 9

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The factory must not have an administrator or callable mechanism that can replace its own logic or the logic used by raffle clones. Every clone must permanently delegate to the one implementation selected during factory construction. Clone-specific configuration may be established during creation, but it must not remain reconfigurable afterward.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L32-L43
address public immutable override quoteToken;
address public immutable override vrfWrapper;
address public immutable override protocolTreasury;
address public immutable override raffleImplementation;
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

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L110
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
// The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
// slither-disable-next-line reentrancy-no-eth
IRaffle(raffle)
    .initialize(
```

- All four factory-wide dependencies, including the clone implementation, are Solidity `immutable` values (`target/packages/contracts/src/RaffleFactory.sol:L30-L43`). The successful constructor path deploys exactly one `Raffle`, rejects a treasury collision, and assigns that address to `raffleImplementation`; there is no alternate successful constructor branch selecting another target (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`).
- The sole raffle-creation entrypoint always passes that immutable value to `Clones.clone`; none of its validation or escrow branches can select another implementation (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L33
function clone(address implementation) internal returns (address instance) {
    return clone(implementation, 0);
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L61
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
```

- The selected overload forwards the target unchanged and deploys bytecode containing that address (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). The target is in the clone runtime code, not an implementation storage slot; the only post-`create` branch is failure and revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L61`).

```solidity
// target/packages/contracts/src/Raffle.sol:L155-L179
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

function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;
```

```solidity
// target/packages/contracts/src/Raffle.sol:L197-L205
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

- The directly deployed implementation is locked by setting `initialized = true` in its constructor (`target/packages/contracts/src/Raffle.sol:L151-L166`). A clone starts with isolated zeroed storage, but its only configuration routine first rejects a second initialization, then rejects any caller other than the immutable factory, and sets the lock before writing configuration (`target/packages/contracts/src/Raffle.sol:L176-L205`).
- The factory calls `initialize` immediately after `create` in the same `createRaffle` transaction; no external transaction boundary exists between deployment and the factory-only initialization call (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`).
- `factory` and `quoteToken` are immutable in the shared implementation code (`target/packages/contracts/src/Raffle.sol:L52-L59`), and the inherited VRF wrapper reference is likewise immutable and assigned only by its constructor (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → `Raffle.constructor`: every returning path fixes `quoteToken`, `vrfWrapper`, `protocolTreasury`, and `raffleImplementation`; validation and the implementation/treasury collision branch only revert (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`; `target/packages/contracts/src/Raffle.sol:L155-L166`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `clone(implementation, 0)` → `create`: every successful creation embeds the same constructor-fixed target; deployment failure reverts rather than choosing a fallback target (`target/packages/contracts/src/RaffleFactory.sol:L97-L110`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- Fresh clone → `initialize`: only the canonical factory can pass the caller check, and the one-time flag prevents every later call. The direct implementation is already locked by its constructor (`target/packages/contracts/src/Raffle.sol:L155-L179`). The only clone-specific configuration writes are the initial writes at `Raffle.sol:L197-L205`. ✓
- Factory callable surface: the concrete factory declares `createRaffle` as its only explicit external state-changing function and otherwise has private helpers plus generated getters (`target/packages/contracts/src/RaffleFactory.sol:L94-L185`); inherited `ReentrancyGuard` exposes only modifiers and private/internal routines (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L119`). ✓
- Raffle callable and inherited surface: the raffle's state-changing entrypoints are lifecycle, claim, initialization, and prize-receiver operations (`target/packages/contracts/src/Raffle.sol:L168-L431`). Inherited ERC-721 public mutators only approve or transfer ticket ownership (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L136`), and the inherited VRF callback authenticates the fixed wrapper before invoking the fixed internal hook (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). None accepts or writes a logic target. ✓
- The sponsor-specific branch only permits the configured sponsor to close an empty active raffle before `endTime`; it changes lifecycle/accounting state, not code or configuration (`target/packages/contracts/src/Raffle.sol:L276-L300`). Ticket owners and operators are asset authorities under ERC-721, not protocol administrators (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L136,L164-L187`). ✓
- Unknown calldata has no fallback route. The only `receive` function unconditionally reverts (`target/packages/contracts/src/Raffle.sol:L170-L173`). ✓

---

**Searched:**

- Scope enumeration over `target/packages/contracts/src` and the manifest-pinned `target/packages/contracts/node_modules` → 36 Solidity files: all five production files and all 31 entries in `target/dependency-hashes.json:L2-L32`. SHA-256 verification against that manifest → 31 checked, 0 mismatches.
- `upgrade|upgradable|upgradeable|UUPS|ERC1967|beacon|diamond|facet` across those 36 files → 6 hits: three first-party NatSpec assertions (`target/packages/contracts/src/Raffle.sol:L24-L25`; `target/packages/contracts/src/RaffleFactory.sol:L18-L19`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`), two `StorageSlot` documentation/example lines (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L10-L29`), and one `ReentrancyGuard` explanatory comment (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L39-L43`); 0 executable upgrade functions.
- `admin|administrator|governor|governance|authority|onlyOwner|AccessControl|Ownable|role` → 5 hits, all NatSpec/comment uses: the no-administrator assertion, ticket-operator authority, and the sponsor's empty-raffle authority (`target/packages/contracts/src/Raffle.sol:L24-L25,L491-L501`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30-L34`; `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L44,L406-L412`). No owner, role registry, access-control base, or admin mutator was found.
- `upgradeTo|upgradeToAndCall|changeAdmin|proxiableUUID|setImplementation|replaceImplementation|changeImplementation|setFactory|setTreasury|setWrapper|setQuote|transferOwnership|renounceOwnership` → 1 hit, `_setImplementation` inside a non-executable `StorageSlot` usage example (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L15-L29`); the public/external selector search for those names returned 0 hits.
- Exact factory assignment search for `raffleImplementation =` → 1 hit, the constructor assignment at `target/packages/contracts/src/RaffleFactory.sol:L91`. Exact first-party `Clones.<function>(...)` call search → 1 hit, `Clones.clone(raffleImplementation)` at `RaffleFactory.sol:L106`. Alternate clone variants (`cloneDeterministic`, `cloneWithImmutableArgs`, `cloneDeterministicWithImmutableArgs`) → 0 first-party call sites; their 19 occurrences are confined to internal library definitions and documentation in `Clones.sol:L64-L293`.
- `delegatecall|callcode|selfdestruct|suicide` → 6 textual hits, all in the two generic internal `LowLevelCall` delegatecall helpers (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:L73-L93`). Searches for their identifiers found only the two definitions and 0 callers; the only `LowLevelCall` uses are `returnDataSize` and `bubbleRevert` in `Create2` failure handling (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol:L45-L53`). A narrower `selfdestruct|suicide|callcode` search returned 0 hits. The clone's necessary delegate behavior is instead the fixed-target ERC-1167 bytecode constructed at `Clones.sol:L51-L57`.
- `getAddressSlot|_IMPLEMENTATION_SLOT` → 4 hits: three lines in the `StorageSlot` ERC-1967 documentation example and the generic internal `getAddressSlot` definition (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L15-L29,L63-L70`); 0 call sites. The actual inherited consumer of `StorageSlot` uses only a fixed `Uint256Slot` for reentrancy state (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L33-L37,L94-L117`).
- Exact assignment sweep for factory-wide configuration → only `RaffleFactory.sol:L85-L91`; for clone configuration → only constructor writes at `Raffle.sol:L161-L162` and guarded initialization writes at `Raffle.sol:L197-L204`; for inherited wrapper/link references → only constructor writes at `VRFV2PlusWrapperConsumerBase.sol:L40-L47`.
- Fallback/receive definitions across the 36-file scope → 0 `fallback` functions and 1 `receive` function, the unconditional revert at `target/packages/contracts/src/Raffle.sol:L170-L173`.

---

**How the verdict was reached:** This is `implemented`, not an absence inferred from names. The positive enforcement is structural: the factory's implementation reference can be assigned only during construction, the sole production clone call supplies that immutable reference, and the selected ERC-1167 routine embeds the reference into deployed runtime bytecode (`target/packages/contracts/src/RaffleFactory.sol:L42,L65-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). Clone configuration is factory-only and one-time, while the implementation itself is constructor-locked (`target/packages/contracts/src/Raffle.sol:L151-L205`). It is not `partial` because the constructor, sole creation path, initialization/reinitialization branches, inherited public surface, fallback surface, generic delegatecall helpers, and implementation-slot vocabulary were all walked. It is not `stronger-than-spec` because fixed implementation and lack of an administrator-controlled replacement path are exactly what the quoted invariant requires.

---

**Open questions:**

- None for this requirement within the five production files and 31 pinned dependencies.
