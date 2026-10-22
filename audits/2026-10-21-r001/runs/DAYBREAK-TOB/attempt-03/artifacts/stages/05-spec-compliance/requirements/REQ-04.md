## REQ-04 — Fixed ERC-1167 clone implementation target

> "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
> — `DESIGN.md:L2, sentence 1`

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Every canonical raffle clone must select its implementation address when the clone is deployed. Later calls must continue to delegate to that same address: the destination must not come from a writable implementation slot, initializer argument, caller choice, administrator setter, or upgrade branch.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L41-L42
/// @inheritdoc IRaffleFactory
address public immutable override raffleImplementation;
```

- The factory's implementation reference is a Solidity `immutable`, not a storage-backed configuration field (`RaffleFactory.sol:L41-L42`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L89-L91
address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

- A successful factory construction directly deploys one concrete `Raffle` and assigns its address to the immutable reference; the intervening branch either reverts construction or reaches that assignment (`RaffleFactory.sol:L89-L91`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L107
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

- The canonical creation entrypoint does not accept an implementation parameter; after its validation branches, it passes the immutable factory value to `Clones.clone` (`RaffleFactory.sol:L97-L107`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L34
function clone(address implementation) internal returns (address instance) {
    return clone(implementation, 0);
}
```

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62
function clone(address implementation, uint256 value) internal returns (address instance) {
    if (address(this).balance < value) {
        revert Errors.InsufficientBalance(address(this).balance, value);
    }
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
}
```

- The called overload has one successful deployment path. It packs the first 3 and remaining 17 bytes of `implementation` into the ERC-1167 creation payload and deploys it with `create`; the only branches before or after deployment revert (`Clones.sol:L47-L62`). The library describes this runtime as delegating to a “known, fixed address,” and the assembly shows that the destination is a bytecode literal rather than a storage lookup (`Clones.sol:L9-L15`, `L51-L57`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle` → `raffleImplementation = implementation`: the only branch between deployment and assignment reverts the entire factory construction; a successfully constructed factory fixes the directly deployed `Raffle` address (`RaffleFactory.sol:L65-L92`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)`: validation can revert, but no branch substitutes a caller-selected or alternate implementation (`RaffleFactory.sol:L97-L107`). ✓
- `Clones.clone(address)` → `clone(address,uint256)` → `create`: the wrapper supplies value zero, the overload embeds all 20 address bytes, and a failed `create` reverts rather than returning another kind of proxy (`Clones.sol:L32-L34`, `L47-L62`). ✓
- `createRaffle` → `IRaffle(raffle).initialize`: initialization occurs only after deployment (`RaffleFactory.sol:L106-L121`). `initialize` accepts only the clone-specific `RaffleInitParams`, gates the call to the immutable factory, and writes raffle application state; no implementation destination is among the parameter fields (`IRaffle.sol:L36-L54`; `Raffle.sol:L175-L205`). ✓
- Post-deployment callable and inherited paths: `Raffle` inherits ERC-721, the reentrancy guard, the prize receiver, and the VRF consumer (`Raffle.sol:L28-L29`). The complete production/dependency sweep found no reachable setter, implementation-slot write, arbitrary delegatecall, or destruction path that could retarget the already deployed proxy; the exact vocabulary and call-site results are recorded below. ✓

---

**Searched:**

- Full scoped read → all five production files were read in full, together with all 31 files named by `target/dependency-hashes.json:L2-L32`; all 31 file digests matched the manifest.
- `raffleImplementation` in the five production files → 7 hits: declaration (`RaffleFactory.sol:L42`), constructor assignment (`L91`), clone argument (`L106`), two destination screens (`L159`, `L166`), interface getter (`IRaffleFactory.sol:L130`), and a read used only for destination screening (`Raffle.sol:L601`).
- `raffleImplementation\s*=` in production → 1 hit, the constructor assignment at `RaffleFactory.sol:L91`.
- `Clones.(clone|cloneDeterministic|cloneWithImmutableArgs|cloneDeterministicWithImmutableArgs)` in production → 1 hit, `Clones.clone(raffleImplementation)` at `RaffleFactory.sol:L106`; no alternate clone family is invoked.
- Explicit factory callable surface (`constructor|function|receive|fallback`) → 4 declarations: the constructor (`RaffleFactory.sol:L65`), `createRaffle` (`L97`), and private `_validateCreateParams` / `_requireContract` helpers (`L154`, `L183`); no explicit setter or fallback exists. The public implementation getter is compiler-generated from the immutable declaration at `L42`.
- `upgrade|upgrades|upgradeable|upgrader|upgradeTo|upgradeToAndCall|setImplementation|changeImplementation|beacon|uups|erc1967` in production → 3 comment-only hits (`Raffle.sol:L24`, `IRaffleFactory.sol:L7`, `RaffleFactory.sol:L19`); 0 operational hits. The narrower `upgradeTo|upgradeToAndCall|setImplementation|changeImplementation|beacon|uups|erc1967` search returned 0 hits.
- `delegatecall|sstore` in production → 0 hits. In the 31 dependencies, `delegatecall` produced 4 hits, all in the generic, uncalled `LowLevelCall` function definitions/comments (`LowLevelCall.sol:L73-L90`); the combined definition/call-site search returned only the two definitions at `L74` and `L85`, with no invocation.
- `_IMPLEMENTATION_SLOT|getAddressSlot` in production and dependencies → 4 dependency hits: three lines in an illustrative `StorageSlot` documentation example (`StorageSlot.sol:L19-L27`) and the generic `getAddressSlot` declaration (`L66`); no production call or implementation-slot declaration.
- `selfdestruct|suicide` across the five production files and all 31 manifest dependencies → 0 hits.
- `new Raffle|Clones.clone` in production → exactly 2 hits: direct implementation deployment (`RaffleFactory.sol:L89`) and fixed-value clone deployment (`L106`).

---

**How the verdict was reached:** The factory fixes one directly deployed implementation in its constructor, and its only canonical raffle-creation path passes that immutable address into the standard `clone(address)` path. That path constructs runtime code containing the address itself; it does not install or consult a mutable implementation slot (`RaffleFactory.sol:L42`, `L89-L91`, `L97-L107`; `Clones.sol:L32-L34`, `L47-L62`). This is `implemented`, not `partial`, because every non-reverting creation branch reaches the same fixed-target builder and the post-deployment initializer has no target field (`IRaffle.sol:L36-L54`; `Raffle.sol:L175-L205`). It is not `stronger-than-spec`: fixing the factory reference and embedding it in each clone are the mechanisms that satisfy the stated immutable-implementation property, not an additional behavioral restriction.

---

**Open questions:**

- None for this requirement within the supplied frozen source and dependency scope.
