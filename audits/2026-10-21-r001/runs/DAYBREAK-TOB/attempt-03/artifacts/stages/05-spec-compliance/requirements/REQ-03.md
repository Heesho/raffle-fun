## REQ-03 — Fixed-target ERC-1167 raffle clones

> "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
> — DESIGN.md:L2, sentence 1

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For the checkable claim in this record, every raffle address returned by the factory's creation entrypoint must have ERC-1167 minimal-proxy runtime behavior: it must forward calls with `DELEGATECALL` to one implementation address embedded in the proxy runtime. The factory must supply a fixed implementation rather than a caller-controlled or later-mutable target, and no successful factory branch may deploy a different raffle form.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L42
address public immutable override raffleImplementation;

// target/packages/contracts/src/RaffleFactory.sol:L89-L91
address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

- The factory deploys one concrete `Raffle` implementation during construction and assigns its address to an `immutable` (`RaffleFactory.sol:L42,L89-L91`). The implementation target is therefore not supplied through `CreateRaffleParams` and has no storage setter.

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L106
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
    uint256 currentTime = block.timestamp;
    if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
    uint256 saleDuration = uint256(params.endTime) - currentTime;
    if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
        revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
    }
    uint256 raffleId = ++raffleCount;
    raffle = Clones.clone(raffleImplementation);
```

- The only implemented creation entrypoint passes that immutable address to the ordinary `Clones.clone` overload (`RaffleFactory.sol:L97-L106`). Sponsor-controlled creation parameters cannot select the target.

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62
function clone(address implementation) internal returns (address instance) {
    return clone(implementation, 0);
}

function clone(address implementation, uint256 value) internal returns (address instance) {
    if (address(this).balance < value) {
        revert Errors.InsufficientBalance(address(this).balance, value);
    }
    assembly ("memory-safe") {
        mstore(0x00, or(shr(232, shl(96, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
        mstore(0x20, or(shl(120, implementation), 0x5af43d82803e903d91602b57fd5bf3))
        instance := create(value, 0x09, 0x37)
    }
    if (instance == address(0)) {
        revert Errors.FailedDeployment();
    }
}
```

- The evidence is the emitted bytecode, not the library's name. The two stores construct init code `3d602d80600a3d3981f3` followed by runtime `363d3d373d3d3d363d73<20-byte implementation>5af43d82803e903d91602b57fd5bf3`; `create(value, 0x09, 0x37)` deploys it (`Clones.sol:L47-L58`). In that runtime, `0x73` pushes the embedded 20-byte target, `0x5a 0xf4` executes `GAS; DELEGATECALL`, and the tail copies return data and either reverts or returns it. There is no implementation storage slot or target-changing branch in the deployed 45-byte runtime (`Clones.sol:L51-L57`).
- The address is an `address`-typed argument, and the assembly explicitly clears its upper 96 bits before embedding exactly 20 bytes (`Clones.sol:L47,L52-L56`). A zero deployment result reverts instead of returning a non-proxy address (`Clones.sol:L59-L61`).

```solidity
// target/packages/contracts/src/Raffle.sol:L155-L166
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

// target/packages/contracts/src/Raffle.sol:L176-L180
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;
```

- `new Raffle` executes the constructor on the shared implementation, binding its immutable factory and quote-token values and locking the implementation's own storage (`Raffle.sol:L155-L166`). The clone creation code does not execute that constructor; calls through the delegate runtime instead use each clone's storage, where the factory performs the guarded one-time initialization (`Raffle.sol:L176-L205`). This is consistent with fixed implementation code plus isolated per-clone state.

---

**Paths walked:**

- `RaffleFactory.constructor` → input/code/decimal/destination validation → `new Raffle(quoteToken_, vrfWrapper_)` → single assignment to immutable `raffleImplementation` (`RaffleFactory.sol:L65-L92`). Every exceptional branch reverts factory construction; a successfully deployed factory has the constructor-created implementation.
- `Raffle` implementation construction → `ERC721("", "")`, `ReentrancyGuard`, and `VRFV2PlusWrapperConsumerBase` base construction → implementation lock (`Raffle.sol:L155-L166`). The ERC-721 base constructor only assigns its name and symbol (`ERC721.sol:L37-L42`); the VRF base constructor fixes wrapper-related immutables (`VRFV2PlusWrapperConsumerBase.sol:L34-L47`); and the reentrancy base constructor initializes only its guard slot (`ReentrancyGuard.sol:L35-L60`). None selects or mutates the proxy target.
- `RaffleFactory.createRaffle` → `nonReentrant` → `_validateCreateParams` and time checks → `Clones.clone(raffleImplementation)` → `IRaffle(raffle).initialize` → registry writes → prize escrow and final status check (`RaffleFactory.sol:L97-L148`). The modifier only brackets the function body with guard-state transitions (`ReentrancyGuard.sol:L69-L73,L94-L106`). All pre-clone failures revert before deployment, and all post-clone failures propagate rather than returning the address; the sole returning path therefore returns the clone created at `RaffleFactory.sol:L106`.
- `Clones.clone(address)` → `clone(address, 0)` → balance guard → bytecode assembly → `CREATE` → zero-address failure check (`Clones.sol:L32-L62`). With the factory's zero-value call, the balance condition cannot select another behavior. The only success branch returns the proxy whose runtime contains the supplied target; the only deployment-failure branch reverts.
- Clone initialization call → runtime `DELEGATECALL` → `Raffle.initialize`. The initializer rejects an already-initialized storage context and any caller other than the implementation-wide immutable factory before populating clone state (`Raffle.sol:L176-L205`). It does not read or write a proxy implementation slot because the target is in proxy code.
- Caller and alternative-path review: `IRaffleFactory` exposes one state-changing creation function (`IRaffleFactory.sol:L99-L104`), and `RaffleFactory` contains one implementation of it (`RaffleFactory.sol:L97-L148`). No other production function invokes a clone/deployment API.

---

**Searched:**

- Scope inventory → read all five production files in full; enumerated all 31 dependency paths from `target/dependency-hashes.json`; SHA-256 verification returned `OK` for all 31 paths.
- `function createRaffle` in the five production files → 2 hits: interface declaration at `IRaffleFactory.sol:L104` and the sole implementation at `RaffleFactory.sol:L97`.
- `new Raffle|Clones\.clone` in the five production files → 2 executable hits: implementation deployment at `RaffleFactory.sol:L89` and proxy deployment at `RaffleFactory.sol:L106`.
- `raffleImplementation\s*=` in the five production files → 1 hit, the constructor assignment at `RaffleFactory.sol:L91`; the declaration is immutable at `L42`.
- `cloneDeterministic|cloneWithImmutableArgs|cloneDeterministicWithImmutableArgs|create2` in the five production files → 0 hits. Those alternative APIs exist only in the dependency library and are not selected by production code (`Clones.sol:L64-L294`).
- `upgradeTo|upgradeToAndCall|setImplementation|changeImplementation|selfdestruct|delegatecall` in the five production files → 0 hits. `selfdestruct` across all five production files plus all 31 manifest dependencies → 0 hits.
- ERC-1167 init/runtime fragments across the 31 dependencies → 8 hits, all in `Clones.sol:L54,L56,L101,L103,L122,L124,L288,L290`; the factory-selected ordinary `clone` path is `L32-L62`.
- `LowLevelCall|delegatecallNoReturn|delegatecallReturn64Bytes` across all 36 scoped files → 7 hits confined to `Create2.sol` and `LowLevelCall.sol`; no production import or invocation. The selected ordinary clone path performs its delegate operation through the literal `0xf4` runtime byte at `Clones.sol:L56`, not that unrelated utility.

---

**How the verdict was reached:** The requirement is implemented because the sole successful factory creation path calls the ordinary OpenZeppelin clone routine with a constructor-created immutable address, and the routine's inspected assembly emits the 45-byte fixed-target delegate runtime required by ERC-1167. This is not `partial`: validation can prevent creation and later initialization/escrow can revert the transaction, but no successful branch returns a direct `Raffle`, a deterministic/custom-argument clone, or a proxy with a mutable target. It is not merely name-based evidence: the decisive bytes embed one `PUSH20` target and execute `DELEGATECALL`, then propagate return or revert data (`Clones.sol:L51-L57`). The constructor, modifier, base-contract, caller, callee, type-cleaning, and failure branches do not introduce an alternate target. The code meets the stated fixed-clone property rather than imposing a different extra constraint, so `implemented` is the closest verdict.

---

**Open questions:**

- None within the frozen source and this requirement's checkable scope.
