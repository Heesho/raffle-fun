## REQ-29 — No administrator, mutable configuration, or upgrade

> "No administrator, mutable configuration or upgrade."
> — DESIGN.md:L2, sentence 9

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** No deployer, treasury, sponsor, owner, governance account, or other address may retain a general-purpose administrative control path. Protocol-wide dependencies and the implementation target must be fixed at construction, clone-specific configuration must become final after one bounded initialization step, and no reachable function may retarget a clone, replace its implementation, pause or rescue the protocol, or rewrite configuration. Narrow functional authorization—such as authenticating the one-time initializer, the randomness callback, or the owner of a particular ticket—is not an administrator role unless that authority can cross into general protocol control.

---

**Where enforcement lives:**

The factory inherits only the interface and the reentrancy guard, and every protocol-wide address is an immutable rather than an owner-controlled storage setting:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L21-L45
contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
    // ...
    address public immutable override quoteToken;
    address public immutable override vrfWrapper;
    address public immutable override protocolTreasury;
    address public immutable override raffleImplementation;

    uint256 public override raffleCount;
```

The constructor writes those four immutables and deploys the sole implementation. The factory's creation path then passes only that stored implementation to `Clones.clone`; it accepts no caller-supplied implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`, `L97-L106`).

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
// target/packages/contracts/src/RaffleFactory.sol:L97-L106
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    // ... validation and raffle ID allocation ...
    raffle = Clones.clone(raffleImplementation);
```

The exact `Clones.clone` overload reached by the factory incorporates the implementation address into the deployed ERC-1167 bytecode and deploys that bytecode with `create`; there is no implementation storage slot on this path (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62
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

At the implementation level, the factory and quote token are Solidity immutables; the inherited Chainlink base likewise makes the wrapper and LINK-token reference immutable (`target/packages/contracts/src/Raffle.sol:L52-L58`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L47`). The implementation constructor fixes those values and locks the implementation instance by setting `initialized = true` (`target/packages/contracts/src/Raffle.sol:L151-L166`).

Each clone's storage-backed configuration is logically immutable because all clone-specific configuration assignments occur behind the same one-time, factory-only gate. The flag is set before any parameter validation or external factory getter reached later in initialization, so no returning branch leaves a second initialization opportunity (`target/packages/contracts/src/Raffle.sol:L176-L205`, `L187-L194`, `L593-L604`).

```solidity
// target/packages/contracts/src/Raffle.sol:L176-L205
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;

    // ... validation ...
    sponsor = params.sponsor;
    sponsorRecipient = params.sponsorRecipient;
    protocolTreasury = params.protocolTreasury;
    prizeToken = IERC721(params.prizeToken);
    prizeTokenId = params.prizeTokenId;
    raffleId = params.raffleId;
    reserveEntries = params.reserveEntries;
    endTime = params.endTime;
    status = Status.AwaitingPrize;
}
```

The actor-restricted paths are scoped to protocol functions rather than administration:

- The factory restriction exists only on the already one-time `initialize` path above. The factory itself exposes one state-changing entrypoint, `createRaffle`, with no caller-identity check; the caller becomes sponsor only for the newly created raffle (`target/packages/contracts/src/RaffleFactory.sol:L94-L148`).
- Before a raffle with zero sold entries reaches `endTime`, its fixed sponsor alone may move it to `Refunding`; once the deadline is reached anyone may do so, and a raffle with sold entries never takes this sponsor branch (`target/packages/contracts/src/Raffle.sol:L276-L300`). This cannot alter any configuration or affect a participant-bearing raffle.
- Winner redemption and refunds require the current owner of the particular ticket (`target/packages/contracts/src/Raffle.sol:L309-L345`, `L349-L371`). Inherited ERC-721 operators exist only through owner-issued per-token or per-owner approvals, and transfer authorization resolves to the token owner, such an approval, or that owner's operator (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L135`, `L153-L185`, `L383-L418`).
- `rawFulfillRandomWords` authenticates only the immutable wrapper and then dispatches to a handler that can write the selected entry, resolution time, and terminal result; it has no configuration write (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`).
- Prize receipt accepts only the configured prize-token call carrying the configured sponsor and canonical factory as `operator`; its only state effect is activation (`target/packages/contracts/src/Raffle.sol:L409-L430`).
- Sponsor proceeds, protocol fees, and the returned prize can be released by any caller, while their destinations come from the one-time configuration (`target/packages/contracts/src/Raffle.sol:L374-L406`). No treasury or sponsor address receives an exclusive withdrawal function.

---

**Paths walked:**

- Deployment caller → `RaffleFactory.constructor` → `new Raffle`: the factory constructor validates and stores only the four immutable configuration values and does not persist its own deployer (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`). The new implementation records `factory = msg.sender`, which at that call site is the factory contract, and locks its own initializer (`target/packages/contracts/src/Raffle.sol:L155-L166`). ✓
- Any sponsor → `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → `Raffle.initialize`: creation has no privileged caller gate, the clone target comes from the immutable factory field, and initialization accepts the canonical factory exactly once (`target/packages/contracts/src/RaffleFactory.sol:L97-L125`; `target/packages/contracts/src/Raffle.sol:L176-L205`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- Prize escrow callback → `Raffle.onERC721Received`: token, token ID, previous owner, operator, and lifecycle must all match the just-configured deposit; the path only changes `AwaitingPrize` to `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). ✓
- Buyer/keeper paths → `buyEntries`, `requestDraw`, and `settleWinningTicket`: these are open entrypoints gated by lifecycle, time, payment, or winning-range facts, not by an administrator address (`target/packages/contracts/src/Raffle.sol:L209-L273`, `L303-L306`, `L533-L558`). ✓
- Refund transition → `enableRefunds`: sold raffles require the fixed request/callback deadlines; the only address-specific branch is the sponsor's early cancellation of an empty raffle, and that branch is unreachable after even one entry is sold (`target/packages/contracts/src/Raffle.sol:L276-L300`). ✓
- Claims → `redeemWinningTicket` / `refundTickets`: authority derives from live ownership of the submitted ticket and cannot edit system settings (`target/packages/contracts/src/Raffle.sol:L309-L371`). The inherited transfer and approval routes similarly derive authority from each ticket owner and flow through `Raffle._update`, whose added behavior is only destination screening (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L93-L135`, `L164-L185`; `target/packages/contracts/src/Raffle.sol:L491-L502`). ✓
- Liability release → `releaseSponsorProceeds`, `releaseProtocolFees`, and `releaseSponsorPrize`: all callers reach the same fixed-recipient transfer; caller identity is merely emitted (`target/packages/contracts/src/Raffle.sol:L374-L406`). ✓
- Wrapper callback → `rawFulfillRandomWords` → `fulfillRandomWords`: the immutable wrapper is the only accepted caller, while every accepted branch records a result and no configuration (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`, `L101-L107`; `target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Upgrade candidates in the dependency closure: the factory calls only the plain fixed-target `Clones.clone` overload (`target/packages/contracts/src/RaffleFactory.sol:L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). `LowLevelCall` contains two generic internal dynamic-delegatecall helpers, but no file calls either symbol (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol:L73-L93`). `StorageSlot` mentions an ERC-1967 implementation slot only in its example; its executable `getAddressSlot` helper has no caller, while the inherited reentrancy guard uses only a fixed `uint256` guard slot (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L7-L34`, `L63-L70`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L32-L60`, `L94-L118`). ✓

---

**Searched:**

- Scope → read all five production files and all 31 files named by `target/dependency-hashes.json` in full; all 31 dependency SHA-256 values matched the manifest.
- `\b(admin|administrator|onlyowner|ownable|accesscontrol|grantrole|revokerole|renouncerole|default_admin_role|guardian|governor|governance|privileged)\b` over the 36-file scope → 1 hit, the `administrator` NatSpec statement at `target/packages/contracts/src/Raffle.sol:L25`; 0 executable hits.
- Privileged mutator declarations matching `transferOwnership`, `renounceOwnership`, role grant/revoke, upgrade, admin change, pause/unpause, rescue/sweep, emergency withdrawal, or configuration setters → 0 hits across the 36-file scope.
- Upgrade/destruction vocabulary (`upgrade*`, `UUPS`, `ERC1967`, beacon, diamond, `selfdestruct`, `suicide`, destroy) → 6 hits, all comments: three first-party non-upgrade claims, one ReentrancyGuard compiler comment, and two StorageSlot documentation/example references; `selfdestruct|suicide|callcode` separately returned 0 hits.
- Pause/rescue vocabulary (`pause|paused|unpause|rescue|sweep|emergency|recover|recovery`) → 5 hits: four first-party comments describing the absence of such controls or ordinary prize recovery, plus unrelated `recover` prose in `Strings.sol`; no executable pause, rescue, or sweep function.
- `^\s*(factory|quoteToken|vrfWrapper|protocolTreasury|raffleImplementation|sponsor|sponsorRecipient|prizeToken|prizeTokenId|raffleId|reserveEntries|endTime)\s*=` in production → 14 hits, all at `RaffleFactory.sol:L85-L91` or `Raffle.sol:L161-L162,L197-L204`; none after construction/initialization.
- `msg.sender\s*(==|!=)|operator\s*!=\s*factory|from\s*!=\s*sponsor` in production plus inherited ERC-721/VRF bases → 8 matching lines: constructor nonzero screening, factory-only initialization, the empty-raffle sponsor branch, two ticket-owner claims, the exact prize-deposit tuple, and wrapper callback authentication (`target/packages/contracts/src/Raffle.sol:L159,L178,L282,L321,L360,L422-L423`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L103`). ERC-721's `_msgSender()` authorization path was read separately at `ERC721.sol:L93-L135,L164-L185,L383-L418`.
- `Clones.<symbol>` in first-party production → 2 hits: the import and the single `Clones.clone(raffleImplementation)` call at `target/packages/contracts/src/RaffleFactory.sol:L4,L106`; no deterministic, custom-argument, or caller-selected target call.
- `delegatecallNoReturn|delegatecallReturn64Bytes` → 2 hits, both internal definitions in `LowLevelCall.sol:L74,L85`; no invocation. `_IMPLEMENTATION_SLOT|getAddressSlot(` → 4 hits, three lines in the StorageSlot example and the helper definition at `StorageSlot.sol:L66`; no executable caller.
- External/public state-changing surface → walked `RaffleFactory.createRaffle`; `Raffle.receive`, initialization, purchase, draw, refund transition, settlement, redemption/refund, three releases, and prize receipt; inherited ERC-721 approve/transfer entrypoints; and the inherited VRF callback gateway. No unexamined production modifier, base-contract mutator, fallback, or wrapper path remains (`target/packages/contracts/src/RaffleFactory.sol:L94-L148`; `target/packages/contracts/src/Raffle.sol:L168-L430`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L135`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L98-L107`).

---

**How the verdict was reached:** `implemented` requires more than the absence of an `admin` variable. Here, every address-sensitive branch was followed. The canonical factory has no deployer/owner state and no general execution surface; its sole state-changing entrypoint always deploys a clone of one constructor-fixed implementation. Clone configuration has exactly one factory-authenticated write pass, with the guard consumed before the assignments and no later write site. The ERC-1167 target is embedded in runtime bytecode, not loaded from a mutable implementation slot. The apparent privileged actors are confined to narrow functions: the factory initializes, the immutable wrapper supplies a result, ticket owners act on their own claims, and the sponsor can close only its own still-empty raffle before the public deadline. None can rewrite configuration, switch code, pause participant activity, redirect fixed proceeds, or rescue arbitrary assets. Therefore there is no uncovered branch that would make the verdict `partial`, and no incompatible administrator or upgrade mechanism that would make it `contradicted`.

---

**Open questions:**

- None for REQ-29 within the supplied frozen production and dependency scope.
