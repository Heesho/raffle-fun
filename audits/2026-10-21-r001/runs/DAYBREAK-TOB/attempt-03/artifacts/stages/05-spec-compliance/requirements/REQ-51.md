## REQ-51 — Canonical Chainlink wrapper pinning

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — `DESIGN.md:L2, sentence 16`

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** The supplied checkability criterion is: “Randomness requests and callbacks use a pinned canonical Chainlink wrapper dependency that cannot be replaced.” For the wrapper portion of the quoted trust boundary, one address must therefore be established as the canonical Chainlink wrapper, used for both requests and callback authentication, and unavailable for substitution by raffle users or a later configuration authority. This record does not infer canonical identity from a parameter name or NatSpec label.

---

**Where enforcement lives:**

The factory makes its selected wrapper and raffle implementation immutable, and passes that selected wrapper into the sole implementation it deploys:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L32-L42
address public immutable override quoteToken;

/// @inheritdoc IRaffleFactory
address public immutable override vrfWrapper;

/// @inheritdoc IRaffleFactory
address public immutable override protocolTreasury;

/// @inheritdoc IRaffleFactory
address public immutable override raffleImplementation;
```

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L67
constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    _requireContract(quoteToken_);
    _requireContract(vrfWrapper_);
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

The factory's explicit wrapper validation establishes only that the supplied address currently has code:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L181-L185
/// @dev Reverts unless an address contains deployed code.
/// @param account Address required to be a contract.
function _requireContract(address account) private view {
    if (account.code.length == 0) revert NotContract(account);
}
```

`Raffle` passes the same constructor argument through a helper which only rejects zero, while the inherited Chainlink consumer stores it in an immutable after calling its `link()` interface method (`Raffle.sol:L155-L158`, `L607-L613`; `VRFV2PlusWrapperConsumerBase.sol:L34-L47`). These checks require a nonzero contract capable of answering that constructor-time interface call; they do not compare its address or code identity with a known canonical deployment:

```solidity
// target/packages/contracts/src/Raffle.sol:L155-L158
constructor(address quoteToken_, address vrfWrapper_)
    ERC721("", "")
    VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
{
```

```solidity
// target/packages/contracts/src/Raffle.sol:L607-L613
/// @dev Validates the wrapper before passing it to the inherited constructor initializer.
/// @param wrapper Prospective Chainlink wrapper address.
/// @return validatedWrapper The same nonzero wrapper address.
function _validatedVrfWrapper(address wrapper) private pure returns (address validatedWrapper) {
    if (wrapper == address(0)) revert ZeroAddress();
    validatedWrapper = wrapper;
}
```

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47
LinkTokenInterface internal immutable i_linkToken;
IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

/**
 * @param _vrfV2PlusWrapper is the address of the VRFV2Wrapper contract
 */
constructor(
  address _vrfV2PlusWrapper
) {
  IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);

  i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
  i_vrfV2PlusWrapper = vrfV2PlusWrapper;
}
```

Every factory-created raffle is an ERC-1167 clone of that one immutable implementation (`RaffleFactory.sol:L89-L91`, `L105-L106`). The `Clones.clone` implementation embeds the supplied implementation address into the proxy bytecode and deploys it without a mutable implementation slot (`Clones.sol:L47-L62`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L106
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
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

The request path uses that inherited immutable. `Raffle.requestDraw` has one randomness-request call (`Raffle.sol:L240-L260`), and the inherited callee prices and sends the request to `i_vrfV2PlusWrapper` on every returning path (`VRFV2PlusWrapperConsumerBase.sol:L76-L88`):

```solidity
// target/packages/contracts/src/Raffle.sol:L249-L260
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

status = Status.Drawing;
drawRequestedAt = uint64(block.timestamp);
_requestInFlight = true;
bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
uint256 paidPrice;
(requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
vrfRequestId = requestId;
_requestInFlight = false;
```

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88
function requestRandomnessPayInNative(
  uint32 _callbackGasLimit,
  uint16 _requestConfirmations,
  uint32 _numWords,
  bytes memory extraArgs
) internal returns (uint256 requestId, uint256 requestPrice) {
  requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords);
  return (
    i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(
      _callbackGasLimit, _requestConfirmations, _numWords, extraArgs
    ),
    requestPrice
  );
}
```

The callback gateway authenticates the caller against that same inherited immutable before dispatching to `Raffle.fulfillRandomWords`; the raffle then filters in-flight, wrong-state, wrong-ID, wrong-length, and late callbacks (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `Raffle.sol:L509-L523`):

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107
function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
  address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
  if (msg.sender != vrfWrapperAddr) {
    revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
  }
  fulfillRandomWords(_requestId, _randomWords);
}
```

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L516
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }
```

Thus the selected address is pinned at the factory, implementation, clone, request, and callback layers. The missing enforcement is canonical identity: `RaffleFactory` accepts a constructor-supplied compatible contract, and neither its code-length check nor the inherited `link()` call proves that address is the target chain's official Chainlink wrapper (`RaffleFactory.sol:L65-L67`, `L181-L185`; `VRFV2PlusWrapperConsumerBase.sol:L40-L47`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract(vrfWrapper_)` → `new Raffle(quoteToken_, vrfWrapper_)` → `_validatedVrfWrapper` → `VRFV2PlusWrapperConsumerBase.constructor`: the selected address becomes immutable, but the identity gates are only code presence, nonzero, and a decodable `link()` response (`RaffleFactory.sol:L65-L67`, `L85-L91`, `L181-L185`; `Raffle.sol:L155-L158`, `L607-L613`; `VRFV2PlusWrapperConsumerBase.sol:L40-L47`). ✓ pinning / ✗ canonical-identity enforcement.
- `RaffleFactory.createRaffle` → `Clones.clone(raffleImplementation)` → fixed-target clone: every canonical factory clone delegates to the one implementation constructed with the selected wrapper (`RaffleFactory.sol:L89-L91`, `L105-L110`; `Clones.sol:L47-L62`). ✓ address continuity.
- `Raffle.requestDraw` → `getVrfRequestPrice` → `requestRandomnessPayInNative` → `i_vrfV2PlusWrapper.requestRandomWordsInNative`: both quote and request go to the same immutable wrapper (`Raffle.sol:L240-L260`, `L435-L448`; `VRFV2PlusWrapperConsumerBase.sol:L76-L88`). ✓.
- Wrapper callback → `rawFulfillRandomWords` → caller equality against `i_vrfV2PlusWrapper` → `Raffle.fulfillRandomWords`: no other caller reaches the internal application callback (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `Raffle.sol:L509-L523`). ✓.
- Post-deployment replacement path: the only assignments found are the factory constructor assignment at `RaffleFactory.sol:L86` and the base constructor assignment at `VRFV2PlusWrapperConsumerBase.sol:L46`; the wrapper-facing first-party functions are getters, price queries, and the pure validation helper (`Raffle.sol:L435-L448`, `L607-L613`; `IRaffle.sol:L359-L366`, `L426-L428`; `IRaffleFactory.sol:L112-L114`). ✓ no address setter or runtime replacement branch.
- Deployment with a noncanonical but interface-compatible contract → the same immutable propagation and request/callback paths: the contract is permanently trusted by that factory even though source never binds it to a known Chainlink deployment (`RaffleFactory.sol:L65-L67`, `L85-L91`, `L181-L185`; `VRFV2PlusWrapperConsumerBase.sol:L40-L47`). ✗ — the uncovered path.

---

**Searched:**

- Complete allowed corpus → read all 36 files in full: five first-party production files plus all 31 paths in `target/dependency-hashes.json`; all 31 files matched their recorded SHA-256 hashes.
- `vrfWrapper_|vrfWrapper|i_vrfV2PlusWrapper|requestRandomnessPayInNative|requestRandomWordsInNative|rawFulfillRandomWords` across those 36 files → 33 matching lines. They resolve to constructor propagation, immutable declarations/getters, the single native request callee, the single callback gateway, interface declarations, and destination screening; no second wrapper source was found.
- `requestRandomnessPayInNative|requestRandomWordsInNative|rawFulfillRandomWords|fulfillRandomWords` across those 36 files → 10 matching lines: one first-party request call (`Raffle.sol:L257`), one first-party internal fulfillment override (`Raffle.sol:L509`), the inherited request/callback definitions and calls (`VRFV2PlusWrapperConsumerBase.sol:L53`, `L76`, `L84`, `L92`, `L99`, `L101`, `L106`), and the wrapper interface declaration (`IVRFV2PlusWrapper.sol:L74`).
- `(vrfWrapper|i_vrfV2PlusWrapper)\s*=` across those 36 files → exactly 2 matching lines: `RaffleFactory.sol:L86` and `VRFV2PlusWrapperConsumerBase.sol:L46`, both inside constructors.
- First-party function declarations whose names contain `vrf` or `wrapper` → 9 matching lines: interface or implementation getters/price queries at `IRaffleFactory.sol:L114`, `IRaffle.sol:L361`, `L366`, `L428`, `L484`, and `Raffle.sol:L436`, `L441`, `L446`, plus the pure `_validatedVrfWrapper` helper at `Raffle.sol:L610`; none is a mutator.
- `extcodehash|codehash|allowlist|white[-_ ]?list|chain.id|chainid|expected...(vrf|wrapper)|approved...(vrf|wrapper)|known...(vrf|wrapper)` across all five first-party production files → 0 hits.
- Exact 20-byte address literals (`0x` followed by 40 hexadecimal digits) across all five first-party production files → 0 hits.
- `dependency-hashes.json` entries containing `@chainlink/contracts` → 4 files. Contract/interface declaration search found only `IVRFV2PlusWrapper` (`IVRFV2PlusWrapper.sol:L4`) and the abstract consumer base (`VRFV2PlusWrapperConsumerBase.sol:L31`), not a concrete wrapper implementation whose identity or upgrade behavior could be inspected.

---

**How the verdict was reached:** This is `partial`, not `implemented`, because the implementation fully enforces address-level continuity and non-replacement after construction, yet does not establish the selected address as canonical. A deployment can supply any contract with code that answers the required interface calls; that address is then immutably propagated to every clone and trusted for both requests and callbacks (`RaffleFactory.sol:L65-L91`, `L181-L185`; `VRFV2PlusWrapperConsumerBase.sol:L40-L47`, `L76-L88`, `L101-L107`). NatSpec calling the parameter “Official Chainlink” at `RaffleFactory.sol:L63` is not an identity check.

The verdict is not `contradicted` or `absent`: there is concrete enforcement for a fixed wrapper address, a fixed clone implementation, request routing, and callback caller authentication (`RaffleFactory.sol:L32-L42`, `L85-L91`, `L105-L106`; `Clones.sol:L47-L62`; `VRFV2PlusWrapperConsumerBase.sol:L34-L47`, `L76-L88`, `L101-L107`). It is not `undecidable`: the supplied criterion is concrete enough to trace; what is missing is deployment evidence and a concrete wrapper implementation, not a checkable meaning.

---

**Open questions:**

- Need the canonical factory deployment transaction, chain identifier, constructor arguments, and authoritative Chainlink address list to establish that the immutable `vrfWrapper` selected for the deployed system is actually the intended official wrapper.
- Need the deployed wrapper's concrete source/bytecode and administration state to determine whether logic at the immutable address can itself be upgraded or replaced. The supplied corpus contains only its interface and the consumer base (`target/dependency-hashes.json:L5`, `L25-L27`).
