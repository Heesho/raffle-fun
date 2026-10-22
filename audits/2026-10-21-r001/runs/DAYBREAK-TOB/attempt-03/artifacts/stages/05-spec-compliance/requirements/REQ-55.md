## REQ-55 — Live chain state controls transaction outcomes

> "Frontend discovery is advisory; transaction decisions must reread current chain state."
> — DESIGN.md:L2, sentence 17

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The quoted requirement makes event streams, indexers, cached view results, and other discovery material non-authoritative. They may tell a caller which operation to try and which identifiers to supply, but execution must determine transaction-critical facts from the state that exists when the transaction runs. For this target, those facts are the raffle lifecycle, time window, sold-entry count, current ticket owner and approvals, winning-entry containment, request continuity, current liabilities, claim flags, and canonical-factory registry state. A stale discovery result may lead to a rejected or ignored call; it must not substitute for an execution-time check.

---

**Where enforcement lives:**

The first-party state-changing ABI accepts caller intent—creation fields, a ticket recipient and entry count, ticket IDs, or a funded draw request—but does not accept a caller-supplied lifecycle status, recorded owner, winning entry, request deadline, settlement flag, or liability balance as authoritative input (packages/contracts/src/interfaces/IRaffle.sol:L305-L355; packages/contracts/src/interfaces/IRaffleFactory.sol:L99-L104). Each operation instead obtains the existing facts it needs during execution.

Entry purchase rechecks the current lifecycle, block time, and accumulated entry count before collecting funds and updating the on-chain range ledger:

~~~solidity
// packages/contracts/src/Raffle.sol:L215-L224
        _requireStatus(Status.Active);
        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
        if (recipient == address(0)) revert InvalidRecipient();
        if (entryCount == 0) revert ZeroEntryCount();
        if (entryCount > type(uint128).max - totalEntries) {
            revert TotalEntriesOverflow(totalEntries, entryCount);
        }

        uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
~~~

Draw initiation does not rely on a previously displayed availability or fee. It rereads status, current block time, current sold entries, the derived deadline, and the wrapper's current price; the inherited request helper obtains the wrapper price again for the actual request (packages/contracts/src/Raffle.sol:L240-L260; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88):

~~~solidity
// packages/contracts/src/Raffle.sol:L241-L260
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
~~~

The interface also warns that a displayed wrapper quote may change before inclusion (packages/contracts/src/interfaces/IRaffle.sol:L357-L366), while the implementation above makes the execution-time wrapper response decisive.

Winner redemption rereads terminal status and settlement state, then calls inherited ownerOf against the current ERC-721 ledger before accepting the caller:

~~~solidity
// packages/contracts/src/Raffle.sol:L309-L325
    function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
        if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        if (!settlementComplete) {
            _settleWinningTicket(ticketId);
        } else if (ticketId != winningTicketId) {
            revert WinningTicketMismatch(ticketId, winningTicketId);
        }

        address winner = ownerOf(ticketId);
        if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

        winnerRecipient = winner;
        winnerRedeemed = true;
        _burn(ticketId);
~~~

Inherited ownerOf reaches the live ownership mapping and rejects a nonexistent or burned ticket (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L421-L432). Inherited transfers likewise obtain the current owner, check the current owner/operator approvals, update the ledger, and compare the caller-supplied from address with the owner that was actually found (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L187; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245).

The wrapper callback has two execution-time layers: the base contract requires the current caller to equal the configured wrapper, and Raffle then checks the in-flight flag, current status, stored request ID, word count, and current callback deadline before recording any result:

~~~solidity
// packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106
  function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
    address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
    if (msg.sender != vrfWrapperAddr) {
      revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
    }
    fulfillRandomWords(_requestId, _randomWords);
~~~

~~~solidity
// packages/contracts/src/Raffle.sol:L509-L523
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
~~~

Factory discovery data is also backed by live registry and escrow postconditions. Creation validates the current timestamp, writes the canonical mappings, performs the prize transfer, and then rereads both the prize contract's owner and the clone's status before emitting RaffleCreated (packages/contracts/src/RaffleFactory.sol:L97-L147). Runtime destination screening queries the canonical factory's current implementation and isRaffle mapping rather than accepting a frontend classification (packages/contracts/src/Raffle.sol:L587-L604).

---

**Paths walked:**

- Deployment and clone base: the factory constructor checks current code presence and current token decimals, fixes the dependencies, and deploys the implementation (packages/contracts/src/RaffleFactory.sol:L58-L92). The implementation constructor fixes factory, quote token, and wrapper immutables and locks its own storage (packages/contracts/src/Raffle.sol:L151-L166). The clone callee creates a fixed-target ERC-1167 proxy or reverts on failed deployment (packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62). ✓
- Factory createRaffle: validation rereads code presence and current registry membership for the selected prize and recipient (packages/contracts/src/RaffleFactory.sol:L97-L104; packages/contracts/src/RaffleFactory.sol:L152-L179). After clone initialization and registry writes, successful creation additionally requires current prize ownerOf to equal the clone and current clone status to be Active (packages/contracts/src/RaffleFactory.sol:L105-L147). ✓
- Factory → initialize: initialize checks current initialized and msg.sender values, validates destinations against the current canonical-factory registry, and only then stores configuration (packages/contracts/src/Raffle.sol:L176-L205; packages/contracts/src/Raffle.sol:L593-L604). The only in-scope caller is createRaffle at packages/contracts/src/RaffleFactory.sol:L109-L121. ✓
- Prize deposit callback: onERC721Received accepts only while current status is AwaitingPrize and only when current caller, token ID, from, and operator match the configured deposit tuple (packages/contracts/src/Raffle.sol:L409-L430). The factory then performs the independent owner/status postchecks described above (packages/contracts/src/RaffleFactory.sol:L127-L134). ✓
- buyEntries → SafeERC20 → safe mint: the purchase reads current status, block time, totalEntries, and token transfer result before updating liabilities (packages/contracts/src/Raffle.sol:L209-L235; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L47; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L202-L244). The mint callee checks current token nonexistence, updates current ownership, and invokes receiver acceptance when the recipient currently has code (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L290; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L18-L49). ✓
- Inherited approvals and transfers: approve obtains the current owner and current all-token approval before changing a token approval, while setApprovalForAll records authority for the current msg.sender (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L112; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L365-L418). transferFrom and both safeTransferFrom overloads pass through current owner/authorization checks, and Raffle's _update override additionally rereads the factory registry for the destination (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245; packages/contracts/src/Raffle.sol:L491-L502; packages/contracts/src/Raffle.sol:L593-L604). ✓
- requestDraw → wrapper request: both the common path and every revert branch use current lifecycle, time, sold count, current wrapper price, actual paid price, and returned request ID (packages/contracts/src/Raffle.sol:L240-L273; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88). A synchronous callback encounters the current _requestInFlight flag and is ignored (packages/contracts/src/Raffle.sol:L252-L260; packages/contracts/src/Raffle.sol:L509-L516). ✓
- rawFulfillRandomWords → fulfillRandomWords: a non-wrapper caller reverts in the base gateway; an authenticated callback that is in-flight, stale, duplicate, wrong-ID, wrong-shape, or late is ignored based on state read during that callback (packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L91-L107; packages/contracts/src/Raffle.sol:L504-L523). Only the remaining branch records a result. ✓
- enableRefunds, Active/empty branch: it reads current totalEntries, current caller, and current block time; the sponsor may act early, while anyone else must wait until endTime (packages/contracts/src/Raffle.sol:L276-L285). ✓
- enableRefunds, Active/sold branch: it derives the request deadline from current stored endTime and requires the current block time to reach it (packages/contracts/src/Raffle.sol:L285-L288; packages/contracts/src/Raffle.sol:L457-L460). ✓
- enableRefunds, Drawing branch and all other statuses: Drawing derives the callback deadline from current drawRequestedAt and current block time; every other lifecycle value reverts (packages/contracts/src/Raffle.sol:L289-L300; packages/contracts/src/Raffle.sol:L462-L465). ✓
- settleWinningTicket → _settleWinningTicket → _requireWinningTicket: both the direct external caller and redemption wrapper reach the same private settlement (packages/contracts/src/Raffle.sol:L303-L316; packages/contracts/src/Raffle.sol:L533-L558). It reads current settlementComplete, status, stored ticket range, winningEntry, and unsettledPot; a discovery-supplied ticket ID cannot allocate liabilities unless its on-chain range contains the selected entry (packages/contracts/src/Raffle.sol:L533-L555; packages/contracts/src/Raffle.sol:L577-L584). ✓
- redeemWinningTicket, unsettled and already-settled branches: the first branch runs the full settlement validation; the second requires exact equality with current winningTicketId. Both then read current ownerOf and require the caller to be that owner before burning and consuming the live prize or winner-proceeds claim (packages/contracts/src/Raffle.sol:L309-L345). ✓
- refundTickets, every loop iteration: the function requires current Refunding status, reads ownerOf for each supplied ticket at execution, requires current caller ownership, obtains the stored range, burns, decrements the current aggregate liability, and transfers the computed amount (packages/contracts/src/Raffle.sol:L348-L371). A stale owner or already-burned ticket reverts through ownerOf (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L421-L432). ✓
- Independent release paths: sponsor and protocol quote releases read the current liability bucket and fixed stored recipient before clearing and transferring; sponsor-prize release reads current status and prizeClaimed before delivery (packages/contracts/src/Raffle.sol:L374-L406). Every quote release also rereads destination classification through _isProtocolDestination before calling the quote token (packages/contracts/src/Raffle.sol:L560-L566; packages/contracts/src/Raffle.sol:L593-L604). ✓
- Direct native transfers: the only path has no discovery-derived decision and unconditionally reverts (packages/contracts/src/Raffle.sol:L168-L173). ✓
- Modifier path and reentrant branches: createRaffle and the economic Raffle entrypoints use nonReentrant (packages/contracts/src/RaffleFactory.sol:L97; packages/contracts/src/Raffle.sol:L209-L213; packages/contracts/src/Raffle.sol:L240; packages/contracts/src/Raffle.sol:L276; packages/contracts/src/Raffle.sol:L304-L309; packages/contracts/src/Raffle.sol:L349; packages/contracts/src/Raffle.sol:L375-L395). The modifier reads the current guard slot, sets it before the body, and restores it only after the body (packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L105). The unguarded ERC-721 and callback surfaces have the explicit current owner/approval, deposit-tuple, or wrapper/request checks described above. ✓

---

**Searched:**

- Scope inventory → read all five first-party production files named in the dossier and all 31 paths in dependency-hashes.json:L2-L32; SHA-256 verification returned dependencies_checked=31 mismatches=0. No test path was opened.
- frontend|front-end across the 36-file production/dependency scope → 0 hits.
- indexer|indexed data|indexing → 1 hit, the comment that historical ticket ranges remain available for indexers and callers (packages/contracts/src/Raffle.sol:L138-L139); the transaction paths validate current lifecycle and ownership separately.
- discover|discovery → 0 hits.
- cache|cached → 0 hits.
- snapshot|stale → 0 hits.
- off[- ]?chain → 0 hits.
- advisory|non-authoritative|authoritative → 1 hit, Status being identified as the single authoritative lifecycle/result (packages/contracts/src/interfaces/IRaffle.sol:L20-L34).
- Concrete first-party state-changing surface → 13 implementations after deduplicating interface declarations: factory createRaffle; Raffle receive, initialize, buyEntries, requestDraw, enableRefunds, settleWinningTicket, redeemWinningTicket, refundTickets, three release functions, and onERC721Received (packages/contracts/src/RaffleFactory.sol:L94-L148; packages/contracts/src/Raffle.sol:L168-L431).
- Inherited/base state-changing surface → 6 externally callable paths: ERC-721 approve, setApprovalForAll, transferFrom, two safeTransferFrom overloads, and Chainlink rawFulfillRandomWords (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L135; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107). Also followed Raffle's _update override and ReentrancyGuard's modifier body.
- First-party callers → .initialize( had 1 call site at RaffleFactory.sol:L110; _settleWinningTicket( had 2 call sites plus its definition at Raffle.sol:L305, L315, and L533; no in-scope call sites for the other public economic entrypoints, so those were treated as direct transaction boundaries.
- Helper callers → _isProtocolDestination had 5 call sites plus its definition (packages/contracts/src/Raffle.sol:L187, L190, L193, L498, L565, L593); _transferQuote had 4 call sites plus its definition (packages/contracts/src/Raffle.sol:L342, L369, L380, L390, L564).
- Current-state vocabulary across first-party files plus the ERC-721 and VRF bases → _requireStatus|status: 32 hits; block.timestamp|Deadline|endTime: 61; ownership/authorization variants: 26; settlement/redemption/prize flags: 15; liability buckets: 36; request/in-flight/random-word variants: 17; registry/implementation/code-length variants: 15; current wrapper price/request variants: 3. Each semantic call chain represented by those hits was opened rather than accepted by name.
- Event emissions → 13 implementation sites: 12 in Raffle and RaffleCreated in the factory (packages/contracts/src/Raffle.sol:L236, L272, L300, L345, L371, L381, L391, L406, L429, L514, L523, L557; packages/contracts/src/RaffleFactory.sol:L136-L147). The corresponding transaction paths above make their decisions before or independently of these discovery outputs.

---

**How the verdict was reached:** This is implemented because every reachable state-changing path in the supplied contract system either (a) decides from current storage, current block context, current caller, and current dependency responses, or (b) is an unconditional rejection such as direct native receipt. Caller-supplied IDs and addresses select what to examine; they do not replace the current status, ownership, authorization, winning range, request, registry, or liability reads. The two especially stale-prone frontend values are handled directly: a VRF fee is fetched again inside requestDraw, and ticket ownership is fetched again inside redemption/refund and inherited transfers.

This is not partial: the Active-empty, Active-sold, Drawing, terminal-result, unsettled/already-settled, NFT/cash, every refund-loop iteration, synchronous/stale callback, inherited transfer/approval, and release branches were walked, and none uses an indexed assertion in place of the live check. It is not stronger-than-spec: rejecting or ignoring a transaction whose discovery snapshot is no longer true is the mechanism the quoted requirement calls for, not an additional constraint.

The target contains no separate frontend implementation, so this verdict does not claim that a particular user interface always performs a pre-submission refresh. It establishes the checkable trust-boundary property supplied with REQ-55: frontend or indexed information alone cannot make these authoritative contracts take a transaction-critical state transition without the current-chain checks above.

---

**Open questions:**

- None within the supplied five-file production implementation and its 31 pinned dependencies.
