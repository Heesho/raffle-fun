## REQ-30 — No administrator, mutable configuration, or upgrade

> "No administrator, mutable configuration or upgrade."
> — `DESIGN.md:L2`, sentence 9

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The quoted invariant, "No administrator, mutable configuration or upgrade.", requires the factory-wide dependencies, economic/timing parameters, and each raffle's sponsor/prize/reserve/timing choices to become fixed no later than that factory or raffle's creation. No later entrypoint may rewrite those values; no general administrator may control the protocol; and an ERC-1167 clone must not have a mutable implementation target. Runtime ledger and lifecycle state—ticket ownership, approvals, pots, draw state, settlement, and claims—is not behavioral configuration.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L32-L42
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

- The four factory-wide values are Solidity immutables (`RaffleFactory.sol:L32-L42`) and their only left-hand-side writes are the successful constructor assignments at `RaffleFactory.sol:L85-L91`. All validation branches precede those assignments; any reverting constructor branch leaves no deployed factory (`RaffleFactory.sol:L65-L91`).

```solidity
// target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L42
uint256 internal constant BPS = 10_000;
uint256 internal constant PROTOCOL_FEE_BPS = 500;
uint256 internal constant CASH_WINNER_BPS = 8000;
uint256 internal constant ENTRY_PRICE = 1_000_000;
uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;
uint256 internal constant MAX_REFUND_TICKET_BATCH_SIZE = 100;
uint256 internal constant MAX_SALE_DURATION = 30 days;
uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;
uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;
uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 300_000;
uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 30;
```

- Fees, entry price, token precision, sale/refund bounds, timeouts, and VRF parameters are compile-time constants rather than storage configuration (`RaffleConstants.sol:L10-L42`). `Raffle` and `RaffleFactory` expose the relevant entry price and VRF values as constants (`Raffle.sol:L41-L50`; `RaffleFactory.sol:L22-L28`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L121
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
```

```solidity
// target/packages/contracts/src/Raffle.sol:L176-L179
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

- The factory creates the clone and calls `initialize` immediately in the same `nonReentrant` creation transaction (`RaffleFactory.sol:L97-L121`). The implementation is locked by setting `initialized = true` in its constructor (`Raffle.sol:L155-L166`). A fresh clone can pass the initialization path only when called by the immutable factory, and `initialized` is set before validation makes any external factory-registry reads (`Raffle.sol:L176-L205`, with those reads at `Raffle.sol:L187-L194` and `L593-L604`). Every repeat path therefore reverts at `Raffle.sol:L177`; a non-factory first call reverts at `Raffle.sol:L178`.

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L57
assembly ("memory-safe") {
    mstore(0x00, or(shr(232, shl(96, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
    mstore(0x20, or(shl(120, implementation), 0x5af43d82803e903d91602b57fd5bf3))
    instance := create(value, 0x09, 0x37)
}
```

- `createRaffle` passes the immutable `raffleImplementation` to `Clones.clone` (`RaffleFactory.sol:L41-L42`, `L89-L91`, `L105-L106`). The selected `clone` overload embeds that address into the created runtime bytecode, rather than storing it in a writable implementation slot (`Clones.sol:L32-L62`).

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L46
LinkTokenInterface internal immutable i_linkToken;
IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

constructor(
  address _vrfV2PlusWrapper
) {
  IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);

  i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
  i_vrfV2PlusWrapper = vrfV2PlusWrapper;
}
```

- The inherited VRF wrapper and derived LINK-token address are also immutable and written only by the base constructor (`VRFV2PlusWrapperConsumerBase.sol:L31-L47`). `Raffle`'s own `factory` and `quoteToken` are immutable (`Raffle.sol:L52-L59`) and have only the constructor writes at `Raffle.sol:L161-L162`.

---

**Paths walked:**

- `RaffleFactory.constructor` validation failure → revert before successful deployment; success → assign the four immutable global values and deploy/record one `Raffle` implementation (`RaffleFactory.sol:L65-L91`). ✓
- `RaffleFactory.createRaffle` → validate → `Clones.clone(raffleImplementation)` → `IRaffle.initialize`: initialization happens before registry writes and before the sponsor-selected prize transfer can invoke external token code (`RaffleFactory.sol:L97-L128`). A later failure reverts the transaction atomically; there is no partially created registered raffle on a successful-return path (`RaffleFactory.sol:L97-L148`). ✓
- Direct call to the implementation's `initialize` → `initialized` was set in its constructor, so it reverts `AlreadyInitialized` (`Raffle.sol:L155-L177`). ✓
- First call to a fresh clone's `initialize` by an address other than the immutable factory → reverts `OnlyFactory` before any configuration write (`Raffle.sol:L176-L179`). ✓
- First factory call to a fresh clone's `initialize` → sets `initialized` before validation/external registry reads, validates all destinations, then performs the only eight per-raffle configuration writes (`Raffle.sol:L176-L205`, `L593-L604`). ✓
- Reentrant or later `initialize` call → `initialized` is already true and the first branch reverts (`Raffle.sol:L176-L179`). ✓
- All later concrete `Raffle` entrypoints (`buyEntries` through `onERC721Received`) mutate only lifecycle, accounting, claim, range, or ownership state; none appears in the exhaustive left-hand-side search for the eight configuration fields (`Raffle.sol:L208-L430`). The one sponsor-only branch can close an empty raffle before its end time, but it only moves `unsettledPot`, `remainingRefundLiability`, and `status`; it does not rewrite configuration (`Raffle.sol:L276-L300`). ✓
- Inherited ERC-721 `approve`, `setApprovalForAll`, `transferFrom`, and both `safeTransferFrom` paths write ticket approval/ownership state (`ERC721.sol:L92-L135`, `L216-L245`, `L383-L417`). `Raffle._update` adds a destination screen and then calls that ledger update without touching raffle configuration (`Raffle.sol:L491-L502`). These token-owner/operator permissions are not a protocol administrator. ✓
- Inherited VRF callback path `rawFulfillRandomWords` authenticates the immutable wrapper and dispatches to `fulfillRandomWords`; it has no configuration write (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `Raffle.sol:L504-L523`). ✓
- ERC-1167 deployment path → `Clones.clone(address,uint256)` → fixed target encoded in clone bytecode; no storage implementation slot or target-changing branch exists on that path (`RaffleFactory.sol:L105-L106`; `Clones.sol:L32-L62`). ✓
- `StorageSlot` base-library path → only the reentrancy guard consumes it, at one fixed guard slot, and writes only `NOT_ENTERED`/`ENTERED` (`ReentrancyGuard.sol:L35-L37`, `L58-L60`, `L94-L117`). The ERC-1967 implementation-slot text in `StorageSlot.sol:L15-L29` is an example comment, not a compiled contract or caller. ✓

---

**Searched:**

- Complete permitted closure → read all five production files and all 31 paths listed by `target/dependency-hashes.json:L2-L32`; SHA-256 verification returned `OK` for 31/31 dependency files.
- `^\s*(sponsor|sponsorRecipient|protocolTreasury|prizeToken|prizeTokenId|raffleId|reserveEntries|endTime)\s*=` in `Raffle.sol` → exactly 8 hits, all contiguous inside `initialize` at `Raffle.sol:L197-L204`; 0 later hits.
- `^\s*(factory|quoteToken)\s*=` in `Raffle.sol` → exactly 2 hits, both constructor writes at `Raffle.sol:L161-L162`.
- `^\s*(quoteToken|vrfWrapper|protocolTreasury|raffleImplementation)\s*=` in `RaffleFactory.sol` → exactly 4 hits, all constructor writes at `RaffleFactory.sol:L85-L91`.
- `^\s*(i_linkToken|i_vrfV2PlusWrapper)\s*=` in `VRFV2PlusWrapperConsumerBase.sol` → exactly 2 hits, both constructor writes at `VRFV2PlusWrapperConsumerBase.sol:L45-L46`.
- Constant declarations in `RaffleConstants.sol` → exactly 11 hits at `RaffleConstants.sol:L12-L42`; there is no storage-backed parameter registry.
- Setter/configuration vocabulary (`set*`, `update*`, `change*`, `configure*`, `upgrade*`, `pause`, `unpause`, `rescue*`, `migrate*`, ownership transfer) across the 36-file closure → 4 textual function hits: the comment-only `_setImplementation` example at `StorageSlot.sol:L25`, and `setApprovalForAll` in the ERC-721 interface, public implementation, and internal helper (`IERC721.sol:L118`; `ERC721.sol:L105`, `L409`). The ERC-721 implementation writes only `_operatorApprovals` at `ERC721.sol:L409-L417`.
- Administrator/ownership frameworks (`Ownable`, `AccessControl`, `onlyOwner`, `onlyRole`, `DEFAULT_ADMIN_ROLE`) across the closure → 0 hits. Exact administrator getter/role mutation names (`owner`, `admin`, `getRoleAdmin`, `grantRole`, `revokeRole`, `renounceRole`, `transferOwnership`, `acceptOwnership`) → 0 function hits.
- Caller gates and modifiers → the production/base search found only the reentrancy modifier (`ReentrancyGuard.sol:L69-L86`) and narrow operational identity checks: immutable factory for initialization (`Raffle.sol:L176-L179`), sponsor for the pre-end empty-raffle transition (`Raffle.sol:L279-L288`), current ticket owners for redemption/refunds (`Raffle.sol:L320-L321`, `L359-L360`), configured prize token/factory tuple for deposit (`Raffle.sol:L416-L430`), and immutable VRF wrapper for callbacks (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`). None guards a configuration writer after initialization.
- Upgrade/destruction vocabulary (`selfdestruct`, `suicide`, `upgradeTo`, `upgradeAndCall`, `proxiable`, `ProxyAdmin`, `UpgradeableBeacon`) across the closure → 0 hits.
- `delegatecall` → 6 textual hits, all declarations/comments/assembly inside unused generic helpers `LowLevelCall.delegatecallNoReturn` and `delegatecallReturn64Bytes` at `LowLevelCall.sol:L73-L90`; symbol search found no call site outside those declarations. The reached factory path calls only `Clones.clone` (`RaffleFactory.sol:L105-L106`), whose selected overload fixes the target in code (`Clones.sol:L32-L62`).
- ERC-1967/implementation-slot vocabulary → 5 hits, all in the non-executable example comment at `StorageSlot.sol:L15-L29`; actual `StorageSlot` call sites outside its own declarations are only the fixed reentrancy-guard slot operations (`ReentrancyGuard.sol:L58-L60`, `L94-L117`).
- Concrete external/public mutation surface → enumerated `RaffleFactory`, `Raffle`, inherited `ERC721`, and `VRFV2PlusWrapperConsumerBase` declarations (`RaffleFactory.sol:L94-L148`; `Raffle.sol:L168-L430`; `ERC721.sol:L92-L135`; `VRFV2PlusWrapperConsumerBase.sol:L101-L107`). Only `initialize` reaches any per-raffle configuration assignment, and all of its success and rejection branches are covered above.

---

**How the verdict was reached:** This is `implemented`, not merely a promising naming match: the complete write search places global configuration only in immutable constructors/constants and per-raffle configuration only in the one-shot initializer. The caller chain shows the initializer is invoked atomically by the immutable factory immediately after fixed-target clone creation, and its rejection branches prevent direct-implementation, non-factory, repeated, and reentrant initialization. The base-contract and inherited-entrypoint pass found only ticket authorization/ownership mutation, runtime lifecycle/accounting mutation, callback authentication, and the reentrancy lock—not a configuration setter or administrator. The proxy branch embeds an immutable implementation address, while exhaustive upgrade/destruction searches found no target-changing mechanism. It is not `partial` because no later or inherited path bypasses those controls, and it is not `stronger-than-spec` because these constraints implement exactly "No administrator, mutable configuration or upgrade."

---

**Open questions:**

- The concrete deployed quote-token, VRF-wrapper, and sponsor-selected prize implementations are outside the supplied target (only their interfaces are present), so their own governance or upgrade mechanisms cannot be assessed here. No supplied first-party or dependency path can change the addresses to which the factory and raffle are bound (`RaffleFactory.sol:L32-L42`; `Raffle.sol:L52-L59`; `VRFV2PlusWrapperConsumerBase.sol:L34-L46`).
