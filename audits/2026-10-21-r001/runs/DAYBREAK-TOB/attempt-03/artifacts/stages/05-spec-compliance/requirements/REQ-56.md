## REQ-56 — frontend decisions reread current chain state

> "Frontend discovery is advisory; transaction decisions must reread current chain state."
> — DESIGN.md:L2, sentence 17

---

**Verdict:** absent · confidence: high

---

**What this demands of an implementation:** Before deciding whether and how to submit any transaction, the frontend must fetch every value material to that decision from current on-chain state. Discovery records such as emitted events, an index, or any locally cached snapshot may locate a raffle, but may not be treated as authoritative for mutable lifecycle, timing, ownership, accounting, request-price, or registry facts. This requires an off-chain frontend transaction-decision path whose fresh reads can be inspected; merely exposing view functions, or revalidating state after a transaction reaches a contract, does not establish that the frontend performed the required reread.

---

**Where enforcement lives:**

No frontend enforcement exists anywhere in the scoped implementation. The target contains Solidity contracts and Solidity dependencies only. It does contain the following adjacent mechanisms, but none executes a frontend reread before the frontend makes a transaction decision.

The factory persists canonical discovery mappings and then emits its discovery event:

```solidity
// packages/contracts/src/RaffleFactory.sol:L123-L147
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;

IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}

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

The interface exposes live registry reads, so a frontend could reread rather than trust the event, but no caller doing so is present:

```solidity
// packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149
/// @notice Returns the lifetime number of successfully created raffles.
function raffleCount() external view returns (uint256 count);

/// @notice Returns whether an address is a raffle registered by this factory.
function isRaffle(address raffle) external view returns (bool registered);

/// @notice Returns the canonical raffle address for an identifier.
function raffleById(uint256 raffleId) external view returns (address raffle);

/// @notice Returns the canonical identifier assigned to a raffle address.
function idByRaffle(address raffle) external view returns (uint256 raffleId);
```

Contract execution independently rereads mutable state. For example, `requestDraw` reads the current status, block time, entry count, deadline, and wrapper quote in the transaction:

```solidity
// packages/contracts/src/Raffle.sol:L240-L260
function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
    _requireStatus(Status.Active);
    if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
    if (totalEntries == 0) revert NoEntriesSold();
    uint256 requestDeadline = drawRequestDeadline();
    if (block.timestamp >= requestDeadline) {
        revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
    }

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

The inherited callee even obtains the wrapper price again immediately before the external request:

```solidity
// packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88
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

Those execution-time guards make stale frontend data less dangerous, but they do not show a frontend performing the pre-decision reread required by the quoted sentence.

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `_validateCreateParams` → `Clones.clone` → `Raffle.initialize` → registry writes → prize `safeTransferFrom` / `onERC721Received` → current `ownerOf` and `status` checks → `RaffleCreated`: the contract validates current creation inputs and custody before emitting the discovery snapshot (`packages/contracts/src/RaffleFactory.sol:L97-L147`, `L154-L179`; `packages/contracts/src/Raffle.sol:L176-L205`, `L416-L430`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L31-L65`). No frontend event consumer or pre-transaction reread is present. ✗
- `Raffle.buyEntries` → `SafeERC20.safeTransferFrom` → `_safeMint` → receiver check: the transaction reads current `status`, `block.timestamp`, and `totalEntries`, then the token and ERC-721 paths enforce current transfer/mint conditions (`packages/contracts/src/Raffle.sol:L209-L236`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L42-L50`, `L212-L246`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L292`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). This is contract-side validation, not a frontend reread. ✗
- `Raffle.requestDraw` → `getVrfRequestPrice` → `requestRandomnessPayInNative`: the transaction reads current lifecycle, time, entries, and price, and the inherited callee recalculates the price before requesting (`packages/contracts/src/Raffle.sol:L240-L273`, `L435-L443`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`). The interface itself warns that the view quote may change before inclusion (`packages/contracts/src/interfaces/IRaffle.sol:L359-L366`). No frontend code refreshes it. ✗
- `Raffle.enableRefunds`, across its empty-`Active`, sold-`Active`, `Drawing`, and invalid-status branches, reads current `status`, entry count, sponsor identity, deadlines, timestamp, and liability (`packages/contracts/src/Raffle.sol:L276-L300`). No frontend decision path is present. ✗
- `settleWinningTicket` / `_settleWinningTicket` / `_requireWinningTicket` and the settle-first versus already-settled branches of `redeemWinningTicket` read current result, settlement flag, stored winning entry/range, current ticket owner, and current proceeds before mutation or delivery (`packages/contracts/src/Raffle.sol:L304-L345`, `L533-L558`, `L579-L585`). They reject a stale or wrong ticket on chain; they do not establish a frontend reread. ✗
- `refundTickets` walks every supplied ticket, rereads current ownership and stored range, and consumes the current refund liability (`packages/contracts/src/Raffle.sol:L349-L371`). `releaseSponsorProceeds`, `releaseProtocolFees`, and both allowed result branches of `releaseSponsorPrize` read current buckets, result, and claim flag (`packages/contracts/src/Raffle.sol:L374-L406`). No frontend implementation exists for any of these transaction choices. ✗
- `rawFulfillRandomWords` authenticates the current wrapper, then `fulfillRandomWords` checks in-flight state, lifecycle, request ID, word count, and the current callback deadline (`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `packages/contracts/src/Raffle.sol:L504-L523`). This callback path is not frontend logic. ✗
- Inherited `approve`, `setApprovalForAll`, `transferFrom`, and both `safeTransferFrom` routes use the current ERC-721 owner and approvals (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L135`, `L216-L244`). The Raffle override also screens the current factory registry before an ownership update (`packages/contracts/src/Raffle.sol:L491-L502`, `L587-L604`). These guards do not implement pre-decision frontend reads. ✗
- Constructors, clone initialization, the `nonReentrant` modifier, constants, type bounds, and all remaining dependency branches were inspected. The constructors and initializer establish contract configuration (`packages/contracts/src/RaffleFactory.sol:L58-L92`; `packages/contracts/src/Raffle.sol:L149-L205`), while `nonReentrant` only serializes protected execution (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`). None can run or constrain an off-chain frontend cache/read policy. ✗

---

**Searched:**

- Scope inventory → `rg --files packages/contracts/src` returned exactly the five production files `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, and `libraries/RaffleConstants.sol`; `dependency-hashes.json:L2-L32` contains exactly 31 dependency paths, all ending in `.sol`. All 36 files were read in full.
- Dependency integrity → SHA-256 verification against every entry in `dependency-hashes.json` returned `OK` for all 31 dependencies.
- `\b(frontend|front-end|user interface|browser|dapp)\b` over all 36 scoped files → 0 hits.
- `\b(discovery|advisory|cache|cached|stale|refresh|reread|re-read)\b` over all 36 scoped files → 0 hits.
- `\b(readContract|simulateContract|writeContract|sendTransaction|eth_call|callStatic|blockTag|wagmi|viem|ethers)\b` over all 36 scoped files → 0 hits.
- `\b(refetch|refresh|reread|re-read|invalidate|revalidate|queryClient)\b` and `\b(cache|cached|stale|localStorage|sessionStorage|indexedDB)\b` over all 36 scoped files → 0 hits for each search.
- `\b(indexers?|listeners?|subscribe|queryFilter|getLogs|event logs?|eventLog)\b` → 1 hit, solely the comment that historical ticket ranges remain available to “indexers and callers” at `packages/contracts/src/Raffle.sol:L138`; it contains no frontend read or transaction logic.
- `RaffleCreated` → exactly 2 hits: the event declaration at `packages/contracts/src/interfaces/IRaffleFactory.sol:L41` and emission at `packages/contracts/src/RaffleFactory.sol:L136`; there is no in-scope consumer.
- `raffleById|idByRaffle|isRaffle|raffleCount` → 15 hits, all in Solidity declarations, writes, and on-chain registry checks (`packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149`; `packages/contracts/src/RaffleFactory.sol:L44-L54`, `L105`, `L123-L125`, `L159-L166`; `packages/contracts/src/Raffle.sol:L603`).
- `^\s*function\s+` over the five production files → 92 declarations, including interface duplication, getters, entrypoints, helpers, and callbacks. The state-changing implementations, inherited ERC-721 entrypoints, modifiers, constructors, and their relevant callees are accounted for in **Paths walked**.

---

**How the verdict was reached:** The requirement is concrete: it names the actor (the frontend), the timing (before a transaction decision), the authoritative source (current on-chain state), and the prohibited substitute (cached discovery data). It is therefore not `undecidable`. The exhaustive scoped inventory and vocabulary/tooling searches found no frontend artifact or off-chain caller at all, so there is no path on which the required reread is implemented. That makes the verdict `absent`, not `partial`: the live getters and contract-side validation are useful adjacent defenses, but they are not some covered frontend paths among other uncovered frontend paths. It is not `contradicted`, because no frontend path was found that affirmatively uses cached discovery data as authoritative. It is not `stronger-than-spec`, because execution-time contract guards cannot ensure that a frontend refreshed state before deciding what transaction to present or submit.

---

**Open questions:**

- Is the production frontend maintained outside the supplied frozen target? Its exact source and revision would be required to determine whether the wider system, beyond this scoped implementation, performs the mandated pre-decision rereads.
- No ambiguity or contradiction in the requirement itself was found.
