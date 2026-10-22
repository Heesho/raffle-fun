## REQ-02 — immutable factory and fixed-target ERC-1167 clones

> "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
> — `DESIGN.md:L2, sentence 1`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The supplied checkable property is that an already deployed
`RaffleFactory` must have no reachable mechanism by which a caller can replace its code or redirect its execution
to mutable logic. The architecture named in the quoted requirement also requires every successfully created raffle
clone to capture a fixed implementation target rather than load a replaceable target from storage.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L21-L42
contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
    // ...
    address public immutable override quoteToken;
    address public immutable override vrfWrapper;
    address public immutable override protocolTreasury;
    address public immutable override raffleImplementation;
```

- `RaffleFactory` is the concrete contract and its only contract base is `ReentrancyGuard`; it does not inherit a
  proxy, beacon, UUPS, ownership, or access-control base (`RaffleFactory.sol:L21-L42`). The implementation reference
  used for raffle creation is a Solidity `immutable` (`RaffleFactory.sol:L41-L42`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L85-L92
quoteToken = quoteToken_;
vrfWrapper = vrfWrapper_;
protocolTreasury = protocolTreasury_;

address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

- On the successful constructor path, the factory directly deploys one `Raffle` and assigns its address to the
  immutable `raffleImplementation`; the same constructor fixes the remaining factory configuration
  (`RaffleFactory.sol:L65-L92`). There is no constructor branch that selects a proxy or a caller-supplied factory
  logic address: validation branches revert, while the sole continuing branch performs `new Raffle(...)`
  (`RaffleFactory.sol:L65-L90`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L110
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
    // ... time validation and raffle ID allocation ...
    raffle = Clones.clone(raffleImplementation);
    // The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
    IRaffle(raffle)
        .initialize(
```

- Every non-reverting creation path calls `Clones.clone` with the constructor-fixed immutable; neither the caller nor
  any branch supplies another target (`RaffleFactory.sol:L97-L121`). The remainder of the path registers that clone,
  escrows the prize, verifies custody and status, and emits the creation event; it does not assign
  `raffleImplementation` (`RaffleFactory.sol:L123-L148`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L60
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
```

- The selected `clone(address)` overload forwards that address with zero value (`Clones.sol:L32-L34`). The reached
  overload inserts the `implementation` argument into the minimal-proxy creation/runtime bytes and executes `CREATE`;
  its only post-creation branch either returns that instance or reverts (`Clones.sol:L47-L62`). The clone therefore
  contains its target in code rather than consulting an implementation storage slot.

```solidity
// target/packages/contracts/src/Raffle.sol:L155-L180
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

- The directly deployed target locks its own storage in its constructor, while clone initialization is one-time and
  factory-only (`Raffle.sol:L151-L180`). Initialization writes raffle-specific state but exposes no implementation
  pointer (`Raffle.sol:L181-L205`).
- The inherited `ReentrancyGuard` constructor writes only the guard status, and `nonReentrant` only brackets the
  function body with guard-state transitions (`ReentrancyGuard.sol:L58-L73`, `L94-L117`). It contributes no external
  entrypoint and no code-target setter (`ReentrancyGuard.sol:L32-L119`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract(quoteToken_)` / `_requireContract(vrfWrapper_)`: each helper either
  reverts on code length zero or returns without writing an implementation target (`RaffleFactory.sol:L65-L68`,
  `L181-L185`).
- `RaffleFactory.constructor` → quote-token `decimals()` try/catch and decimal comparison: failure branches revert;
  success proceeds to the direct implementation deployment (`RaffleFactory.sol:L70-L89`).
- `RaffleFactory.constructor` → treasury-destination checks → `new Raffle(...)` → immutable assignment: unsafe inputs
  revert; the single successful branch deploys the target and assigns `raffleImplementation`
  (`RaffleFactory.sol:L80-L92`). ✓
- External caller → `RaffleFactory.createRaffle` → `nonReentrant` → `_validateCreateParams`: every validation and time
  branch either reverts or reaches the same `Clones.clone(raffleImplementation)` call
  (`RaffleFactory.sol:L97-L106`, `L152-L179`; `ReentrancyGuard.sol:L69-L73`, `L94-L106`). ✓
- `Clones.clone(raffleImplementation)` → `clone(implementation, 0)` → fixed-address ERC-1167 bytecode → `CREATE`: the
  only outcome branches are a fixed-target instance or a deployment revert (`Clones.sol:L32-L34`, `L47-L62`). ✓
- New clone → `Raffle.initialize`: the call is accepted only once and only from the immutable factory, then writes only
  clone configuration and lifecycle state (`Raffle.sol:L176-L205`). It cannot change the implementation address,
  because that address is in the clone bytecode constructed by `Clones.clone` (`Clones.sol:L52-L57`). ✓
- After clone creation, `createRaffle` has normal external calls for initialization and prize escrow, registry writes,
  custody/status checks, and an event (`RaffleFactory.sol:L109-L147`). Re-entry is rejected by the inherited modifier
  while the call is active (`ReentrancyGuard.sol:L69-L73`, `L88-L105`), and no continuation branch writes the immutable
  implementation (`RaffleFactory.sol:L109-L148`). ✓
- Callable factory surface: the implementation defines only the external `createRaffle` mutator plus two private
  validation helpers (`RaffleFactory.sol:L94-L186`); the interface exposes that mutator and generated read-only getters
  (`IRaffleFactory.sol:L99-L150`). There is no in-scope wrapper or caller around `createRaffle`; the only two
  `createRaffle(` hits are its implementation and interface declarations (`RaffleFactory.sol:L97`,
  `IRaffleFactory.sol:L104`). ✓

---

**Searched:**

- Scope inventory → all five production Solidity files and all 31 paths in `target/dependency-hashes.json` were read in
  full; all 31 dependency SHA-256 values matched the manifest.
- Case-insensitive `upgrade|upgradeTo|proxiable|beacon|transparent|ERC1967|setImplementation|_setImplementation` across
  those 36 files → 7 hits: three project NatSpec statements (`RaffleFactory.sol:L19`, `IRaffleFactory.sol:L7`,
  `Raffle.sol:L24`), one `ReentrancyGuard` comment (`ReentrancyGuard.sol:L42`), and three lines in the `StorageSlot`
  documentation/example (`StorageSlot.sol:L10`, `L17`, `L25`). None is executable upgrade logic.
- `function (upgrade|setImplementation|changeImplementation|setAdmin|transferOwnership)` across the same scope → 0 hits.
- `selfdestruct|suicide` across the same scope → 0 hits.
- `delegatecall` across the same scope → 6 hits, all comments, declarations, or bodies of the two generic helpers in
  `LowLevelCall.sol:L73-L90`. `delegatecallNoReturn|delegatecallReturn64Bytes` has exactly 2 hits—the helper definitions—and
  no call site. `LowLevelCall.` has 4 hits: its own filename comment, one import, and only `returnDataSize` and
  `bubbleRevert` calls from the separate `Create2.deploy` failure path (`Create2.sol:L7`, `L49-L52`); the factory's
  reached `Clones.clone` path uses `CREATE`, not `Create2.deploy` (`Clones.sol:L47-L62`).
- `onlyOwner|Ownable|AccessControl|DEFAULT_ADMIN_ROLE|admin` across the same scope → 1 hit, the word
  “administrator” in `Raffle.sol:L25` NatSpec; 0 executable authority mechanisms.
- `fallback|receive` in `RaffleFactory.sol` → 0 hits. `assembly|sstore|delegatecall|callcode|selfdestruct|create2` in
  `RaffleFactory.sol` → 0 hits.
- `raffleImplementation` across the same scope → 7 hits: immutable declaration (`RaffleFactory.sol:L42`), sole
  assignment (`L91`), clone read (`L106`), two destination comparisons (`L159`, `L166`), interface getter
  (`IRaffleFactory.sol:L130`), and a raffle destination comparison (`Raffle.sol:L601`). No post-construction writer.
- `createRaffle\(` → 2 hits, the implementation and interface declarations; no in-scope caller. `clone\(` → 4 hits,
  comprising the factory call and the three lines in the reached two-overload chain (`RaffleFactory.sol:L106`,
  `Clones.sol:L32-L33`, `L47`). `initialize\(` → 3 hits, the interface declaration, factory call, and implementation
  (`IRaffle.sol:L308`, `RaffleFactory.sol:L110`, `Raffle.sol:L176`).

---

**How the verdict was reached:** `implemented` is supported by both halves of the enforcement trace. The factory is a
direct concrete deployment whose inheritance and complete callable surface contain no proxy dispatch, upgrade setter,
fallback, destruction opcode, or other code-replacement route (`RaffleFactory.sol:L21-L42`, `L94-L186`). Its raffle
target is constructed and assigned once (`RaffleFactory.sol:L85-L92`), and every successful creation path passes that
immutable value into ERC-1167 bytecode that embeds the target (`RaffleFactory.sol:L97-L106`; `Clones.sol:L47-L62`).

This is not `partial`: validation failures revert, and there is no alternative successful constructor or creation
branch with a mutable target (`RaffleFactory.sol:L65-L92`, `L97-L148`). It is not `stronger-than-spec`: a directly
deployed non-upgradeable factory and fixed-target clones are the mechanisms the quoted requirement asks for, rather
than an additional undocumented restriction. The generic `delegatecall` helpers and the `StorageSlot` upgrade example
do not change the result because neither lies on a factory call path, as the exact call-site searches above show.

---

**Open questions:** None within the frozen source and manifest-pinned dependency scope.
