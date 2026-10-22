## REQ-50 — Trusted Chainlink callback authority

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — `DESIGN.md:L2, sentence 16`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The supplied checkable criterion operationalizes the quoted trust boundary in three source-level properties: one deployment-fixed Chainlink wrapper must occupy the trusted side; every externally supplied randomness callback must authenticate that wrapper before entering application logic; and sponsor-selected prize contracts or ticket recipients must not receive an equivalent route into that logic.

---

**Where enforcement lives:**

The factory stores its wrapper as an immutable, checks that the constructor input contains code, and uses that same input when it deploys the single raffle implementation (`target/packages/contracts/src/RaffleFactory.sol:L32-L42`, `L65-L67`, `L85-L91`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L67
constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    _requireContract(quoteToken_);
    _requireContract(vrfWrapper_);

// target/packages/contracts/src/RaffleFactory.sol:L85-L91
quoteToken = quoteToken_;
vrfWrapper = vrfWrapper_;
protocolTreasury = protocolTreasury_;

address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

`Raffle` passes only that constructor value through its nonzero validator to the Chainlink base (`target/packages/contracts/src/Raffle.sol:L151-L166`, `L607-L613`). The base records it in an immutable (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L47`):

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L46
abstract contract VRFV2PlusWrapperConsumerBase {
  error OnlyVRFWrapperCanFulfill(address have, address want);

  LinkTokenInterface internal immutable i_linkToken;
  IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

  constructor(
    address _vrfV2PlusWrapper
  ) {
    IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);

    i_linkToken = LinkTokenInterface(vrfV2PlusWrapper.link());
    i_vrfV2PlusWrapper = vrfV2PlusWrapper;
```

The inherited external callback gateway compares `msg.sender` with that immutable address and reverts before internal dispatch on the only failing branch (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107`):

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107
function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal virtual;

function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
  address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
  if (msg.sender != vrfWrapperAddr) {
    revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
  }
  fulfillRandomWords(_requestId, _randomWords);
}
```

After caller authentication, the raffle accepts state-changing callback authority only for a persisted, current, one-word, timely request. Every other authenticated-wrapper branch emits an ignored-callback event and returns without changing the result (`target/packages/contracts/src/Raffle.sol:L504-L523`):

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L523
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }

    uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
    winningEntry = resolvedEntry;
    resolvedAt = uint64(block.timestamp);
    status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

    emit RaffleResolved(requestId, resolvedEntry, status);
}
```

Attacker-selected configuration is kept distinct from the wrapper. `CreateRaffleParams` contains recipient, prize, reserve, and time fields but no wrapper field (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`). Factory validation rejects either the selected prize or sponsor recipient when it equals the wrapper (`target/packages/contracts/src/RaffleFactory.sol:L152-L177`). Runtime ticket mint and transfer destinations pass through `_update`, which rejects the wrapper as a protocol destination (`target/packages/contracts/src/Raffle.sol:L491-L502`, `L587-L604`).

---

**Paths walked:**

- Trusted deployment configuration: `RaffleFactory.constructor` checks that `vrfWrapper_` has code, assigns it once to the immutable `vrfWrapper`, and passes it to `new Raffle` (`target/packages/contracts/src/RaffleFactory.sol:L58-L67`, `L85-L91`). `Raffle.constructor` passes the nonzero value into `VRFV2PlusWrapperConsumerBase` (`target/packages/contracts/src/Raffle.sol:L151-L166`, `L607-L613`), whose constructor makes `i_vrfV2PlusWrapper` immutable (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L47`). ✓
- Untrusted raffle creation: a sponsor can supply only `sponsorRecipient`, `prizeToken`, `prizeTokenId`, `reserveEntries`, and `endTime` (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`). `createRaffle` clones the immutable `raffleImplementation` and initializes per-raffle fields without any wrapper parameter (`target/packages/contracts/src/RaffleFactory.sol:L97-L125`; `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`). The clone library embeds the selected implementation in fixed minimal-proxy bytecode (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`). ✓
- Permissionless request: any funded caller can invoke `requestDraw`, but the function supplies fixed callback parameters to `requestRandomnessPayInNative` and stores the returned request ID; it accepts no callback address (`target/packages/contracts/src/Raffle.sol:L239-L260`). The base sends that request only to `i_vrfV2PlusWrapper` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L75-L89`). ✓
- Non-wrapper callback attempt: `rawFulfillRandomWords` takes the revert branch whenever its caller differs from `address(i_vrfV2PlusWrapper)` and does not call the internal hook (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). There is no second external randomness handler in the scoped files; the base declaration and raffle override are both `internal` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L106`; `target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Wrapper callback attempt: after the sender gate, an in-flight, non-`Drawing`, wrong-ID, wrong-length, or late callback returns without result writes; only the remaining branch writes `winningEntry`, `resolvedAt`, and terminal status (`target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Untrusted prize path: factory validation prevents the selected prize address from being the wrapper (`target/packages/contracts/src/RaffleFactory.sol:L154-L177`). Prize escrow reaches only `onERC721Received`, whose exact-token/operator/from/status checks can change `AwaitingPrize` to `Active`, not enter the randomness hook (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L409-L430`). Any separate call by that prize contract to the randomness gateway still encounters the wrapper-only sender comparison (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). ✓
- Untrusted ticket-recipient path: `buyEntries` is `nonReentrant`, and safe mint invokes recipient code only through the ERC-721 receiver check (`target/packages/contracts/src/Raffle.sol:L209-L235`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L17-L48`). A recipient's direct attempt to use the randomness gateway remains subject to the same wrapper-only sender comparison (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). ✓

---

**Searched:**

- Full frozen code scope → read all five production files and all 31 files named by `target/dependency-hashes.json`; recomputation matched 31/31 declared SHA-256 hashes.
- `function\s+(rawFulfillRandomWords|fulfillRandomWords)\s*\(` across that 36-file scope → 3 declarations: the base's internal virtual hook at `VRFV2PlusWrapperConsumerBase.sol:L99`, its external authenticated gateway at `L101`, and `Raffle`'s internal override at `Raffle.sol:L509`.
- `rawFulfillRandomWords|fulfillRandomWords` → 6 total code/comment/call hits, all confined to `Raffle.sol` and `VRFV2PlusWrapperConsumerBase.sol`; no other dependency or production file supplies a callback entrypoint.
- `OnlyVRFWrapperCanFulfill|i_vrfV2PlusWrapper|vrfWrapper_?|vrfWrapper\(` → 31 hits: constructor configuration, immutable storage, request calls, getters, destination exclusions, and the single sender gate; none grants another address callback dispatch.
- `(^|[^A-Za-z0-9_])(i_vrfV2PlusWrapper|vrfWrapper)\s*=` → 2 writes: `RaffleFactory.sol:L86` and `VRFV2PlusWrapperConsumerBase.sol:L46`, both constructor-time immutable assignments.
- Candidate setter/update/change/replace/upgrade function names containing `vrf` or `wrapper` → 0 hits.
- `fallback\s*\(` → 0 declarations. The sole `receive()` declaration rejects direct native transfers at `Raffle.sol:L170-L173`.
- `LowLevelCall\.(delegatecallNoReturn|delegatecallReturn64Bytes)` → 0 call sites. The dependency defines generic helpers, but scoped production code does not invoke them; raffle cloning instead uses the fixed implementation packed by `Clones.clone` (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62`).
- `(sponsorRecipient|prizeToken|recipient).*vrfWrapper|vrfWrapper.*(sponsorRecipient|prizeToken|recipient)` → 2 hits, both exclusion comparisons in `RaffleFactory.sol:L158` and `L165`.
- `_requestInFlight|vrfRequestId|winningEntry|resolvedAt` → 21 declaration/comment/read/write hits. Request-coordination writes occur in `requestDraw` (`target/packages/contracts/src/Raffle.sol:L252-L260`); result writes occur only after the authenticated handler's rejection branch (`L509-L523`).

---

**How the verdict was reached:** This is `implemented`, not `partial`, because the sole external randomness gateway has no branch around its sender-equality check: a mismatched caller reverts before the internal hook, while a matched caller alone reaches `fulfillRandomWords` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`). It is not merely enforcement by name: the wrapper value is traced from the factory constructor, through the raffle/base constructors, into an immutable, then read in the actual comparison (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`; `target/packages/contracts/src/Raffle.sol:L151-L166`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L47`, `L101-L107`). Sponsor-controlled creation fields do not include a wrapper, explicit checks keep selected prizes and recipients distinct from it, and no setter, fallback, or second external callback route exists in the scoped implementation (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`; `target/packages/contracts/src/RaffleFactory.sol:L154-L177`; `target/packages/contracts/src/Raffle.sol:L491-L502`, `L587-L604`). The additional current-request checks constrain the trusted wrapper's application-level effect but do not create a separate undocumented trust rule, so `stronger-than-spec` is not the better category (`target/packages/contracts/src/Raffle.sol:L509-L523`).

---

**Open questions:**

- None that prevents the source-level verdict. The frozen source cannot prove that a deployed constructor argument is the target chain's official wrapper; it expressly assigns official-address verification to deployment tooling (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`; `target/packages/contracts/src/RaffleFactory.sol:L58-L64`). That deployment-provenance question is distinct from the supplied checkable criterion, which asks whether the configured Chainlink wrapper alone receives callback authority.
