# In-scope source (line-numbered; cite these line numbers)

### DESIGN.md (repository-root clean protocol specification)

```markdown
# Clean design specification
Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation. One entry costs 1,000,000 units of canonical six-decimal USDC. One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range. Exactly one ERC721 prize is escrowed atomically at creation. Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. Refund outcome pays 100% per entry and returns prize. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss. No administrator, mutable configuration or upgrade. Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days. Refunds open at deadline. Callback records result only. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure. Sponsor and treasury can claim independently after settlement. Never move assets between raffle clones. Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted. Frontend discovery is advisory; transaction decisions must reread current chain state.

This specification was composed before scanner results and historical findings. Source, not design prose, determines actual behavior. No tests, audit history, accepted-risk lists or scanner results are provided.

```

### packages/contracts/src/Raffle.sol

```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity 0.8.36;
     3	
     4	import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
     5	import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
     6	import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
     7	import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
     8	import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
     9	import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    10	import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
    11	import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
    12	import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
    13	import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
    14	
    15	import { IRaffle } from "./interfaces/IRaffle.sol";
    16	import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
    17	import { RaffleConstants } from "./libraries/RaffleConstants.sol";
    18	
    19	/// @title raffle.fun Raffle Escrow and Entry Ticket
    20	/// @author heesho
    21	/// @notice Escrows one NFT and sells fixed-price USDC entries through one transferable ERC-721 ticket per purchase.
    22	/// @dev Ticket IDs are sequential and map to one inclusive `[firstEntry,lastEntry]` uint128 range. Purchases, Chainlink
    23	///      callbacks, and winner proofs are O(1) in entry count. Tickets remain transferable bearer claims until their
    24	///      owners burn them for redemption or refund. Each raffle is a fixed, non-upgradeable ERC-1167 clone with no
    25	///      administrator or rescue path. Permissionless settlement only allocates liabilities; the winning-ticket owner
    26	///      atomically burns the ticket while receiving the NFT or cash prize.
    27	/// @custom:version 1.0.0
    28	contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {
    29	    using SafeERC20 for IERC20;
    30	
    31	    // Types
    32	
    33	    /// @notice Inclusive global entry-number range represented by one sequential ERC-721 ticket.
    34	    /// @param firstEntry First represented one-based global entry.
    35	    /// @param lastEntry Last represented one-based global entry.
    36	    struct TicketRange {
    37	        uint128 firstEntry;
    38	        uint128 lastEntry;
    39	    }
    40	
    41	    // Constants
    42	
    43	    /// @inheritdoc IRaffle
    44	    uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;
    45	
    46	    /// @inheritdoc IRaffle
    47	    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;
    48	
    49	    /// @inheritdoc IRaffle
    50	    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;
    51	
    52	    // Immutables and state
    53	
    54	    /// @inheritdoc IRaffle
    55	    address public immutable override factory;
    56	
    57	    /// @inheritdoc IRaffle
    58	    IERC20 public immutable override quoteToken;
    59	
    60	    /// @inheritdoc IRaffle
    61	    address public override sponsor;
    62	
    63	    /// @inheritdoc IRaffle
    64	    address public override sponsorRecipient;
    65	
    66	    /// @inheritdoc IRaffle
    67	    address public override protocolTreasury;
    68	
    69	    /// @inheritdoc IRaffle
    70	    IERC721 public override prizeToken;
    71	
    72	    /// @inheritdoc IRaffle
    73	    uint256 public override prizeTokenId;
    74	
    75	    /// @inheritdoc IRaffle
    76	    uint256 public override raffleId;
    77	
    78	    /// @inheritdoc IRaffle
    79	    uint128 public override reserveEntries;
    80	
    81	    /// @inheritdoc IRaffle
    82	    uint64 public override endTime;
    83	
    84	    /// @inheritdoc IRaffle
    85	    uint128 public override totalEntries;
    86	
    87	    /// @inheritdoc IRaffle
    88	    uint128 public override ticketCount;
    89	
    90	    /// @inheritdoc IRaffle
    91	    uint256 public override unsettledPot;
    92	
    93	    /// @inheritdoc IRaffle
    94	    uint256 public override remainingRefundLiability;
    95	
    96	    /// @inheritdoc IRaffle
    97	    address public override winnerRecipient;
    98	
    99	    /// @inheritdoc IRaffle
   100	    uint256 public override winnerProceeds;
   101	
   102	    /// @inheritdoc IRaffle
   103	    uint256 public override sponsorProceeds;
   104	
   105	    /// @inheritdoc IRaffle
   106	    uint256 public override protocolFees;
   107	
   108	    /// @inheritdoc IRaffle
   109	    uint256 public override vrfRequestId;
   110	
   111	    /// @inheritdoc IRaffle
   112	    uint64 public override drawRequestedAt;
   113	
   114	    /// @inheritdoc IRaffle
   115	    uint64 public override resolvedAt;
   116	
   117	    /// @inheritdoc IRaffle
   118	    uint128 public override winningEntry;
   119	
   120	    /// @inheritdoc IRaffle
   121	    uint256 public override winningTicketId;
   122	
   123	    /// @inheritdoc IRaffle
   124	    Status public override status;
   125	
   126	    /// @inheritdoc IRaffle
   127	    bool public override settlementComplete;
   128	
   129	    /// @inheritdoc IRaffle
   130	    bool public override winnerRedeemed;
   131	
   132	    /// @inheritdoc IRaffle
   133	    bool public override prizeClaimed;
   134	
   135	    /// @inheritdoc IRaffle
   136	    bool public override initialized;
   137	
   138	    /// @dev Historical ticket ranges remain stored after burns so indexers and callers can reconstruct entry coverage.
   139	    mapping(uint256 ticketId => TicketRange range) private _ticketRanges;
   140	
   141	    /// @dev True only while the wrapper request call is executing, so a synchronous callback cannot resolve early.
   142	    bool private _requestInFlight;
   143	
   144	    // Errors
   145	
   146	    /// @notice Raised when native currency is sent outside the payable draw-request path.
   147	    error DirectNativeTransfer();
   148	
   149	    // Constructor
   150	
   151	    /// @notice Deploys and locks the implementation shared by one factory's minimal-proxy raffles.
   152	    /// @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
   153	    /// @param quoteToken_ Canonical six-decimal USDC contract fixed for the implementation and every clone.
   154	    /// @param vrfWrapper_ Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.
   155	    constructor(address quoteToken_, address vrfWrapper_)
   156	        ERC721("", "")
   157	        VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
   158	    {
   159	        if (msg.sender == address(0) || quoteToken_ == address(0)) revert ZeroAddress();
   160	
   161	        factory = msg.sender;
   162	        quoteToken = IERC20(quoteToken_);
   163	
   164	        initialized = true;
   165	        status = Status.Refunding;
   166	    }
   167	
   168	    // External state-changing functions
   169	
   170	    /// @notice Rejects direct native-token transfers that are not attached to `requestDraw`.
   171	    receive() external payable {
   172	        revert DirectNativeTransfer();
   173	    }
   174	
   175	    /// @inheritdoc IRaffle
   176	    function initialize(RaffleInitParams calldata params) external override {
   177	        if (initialized) revert AlreadyInitialized();
   178	        if (msg.sender != factory) revert OnlyFactory();
   179	        initialized = true;
   180	
   181	        if (
   182	            params.sponsor == address(0) || params.sponsorRecipient == address(0)
   183	                || params.protocolTreasury == address(0) || params.prizeToken == address(0)
   184	        ) {
   185	            revert ZeroAddress();
   186	        }
   187	        if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
   188	            revert UnsafeProtocolDestination(params.sponsor);
   189	        }
   190	        if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
   191	            revert UnsafeProtocolDestination(params.protocolTreasury);
   192	        }
   193	        if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
   194	            revert UnsafeProtocolDestination(params.sponsorRecipient);
   195	        }
   196	
   197	        sponsor = params.sponsor;
   198	        sponsorRecipient = params.sponsorRecipient;
   199	        protocolTreasury = params.protocolTreasury;
   200	        prizeToken = IERC721(params.prizeToken);
   201	        prizeTokenId = params.prizeTokenId;
   202	        raffleId = params.raffleId;
   203	        reserveEntries = params.reserveEntries;
   204	        endTime = params.endTime;
   205	        status = Status.AwaitingPrize;
   206	    }
   207	
   208	    /// @inheritdoc IRaffle
   209	    function buyEntries(address recipient, uint128 entryCount)
   210	        external
   211	        override
   212	        nonReentrant
   213	        returns (uint256 ticketId)
   214	    {
   215	        _requireStatus(Status.Active);
   216	        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
   217	        if (recipient == address(0)) revert InvalidRecipient();
   218	        if (entryCount == 0) revert ZeroEntryCount();
   219	        if (entryCount > type(uint128).max - totalEntries) {
   220	            revert TotalEntriesOverflow(totalEntries, entryCount);
   221	        }
   222	
   223	        uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
   224	        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
   225	
   226	        uint128 firstEntry = totalEntries + 1;
   227	        uint128 lastEntry = totalEntries + entryCount;
   228	        ticketId = uint256(ticketCount) + 1;
   229	
   230	        totalEntries = lastEntry;
   231	        ++ticketCount;
   232	        _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
   233	        unsettledPot += grossAmount;
   234	
   235	        _safeMint(recipient, ticketId);
   236	        emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
   237	    }
   238	
   239	    /// @inheritdoc IRaffle
   240	    function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
   241	        _requireStatus(Status.Active);
   242	        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
   243	        if (totalEntries == 0) revert NoEntriesSold();
   244	        uint256 requestDeadline = drawRequestDeadline();
   245	        if (block.timestamp >= requestDeadline) {
   246	            revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
   247	        }
   248	
   249	        uint256 quotedFee = getVrfRequestPrice();
   250	        if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);
   251	
   252	        status = Status.Drawing;
   253	        drawRequestedAt = uint64(block.timestamp);
   254	        _requestInFlight = true;
   255	        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
   256	        uint256 paidPrice;
   257	        (requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
   258	        if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
   259	        vrfRequestId = requestId;
   260	        _requestInFlight = false;
   261	
   262	        uint256 excess = msg.value - paidPrice;
   263	        if (excess != 0) {
   264	            bool success;
   265	            address refundRecipient = msg.sender;
   266	            assembly ("memory-safe") {
   267	                success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
   268	            }
   269	            if (!success) revert NativeRefundFailed(msg.sender, excess);
   270	        }
   271	
   272	        emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
   273	    }
   274	
   275	    /// @inheritdoc IRaffle
   276	    function enableRefunds() external override nonReentrant {
   277	        uint256 deadline;
   278	
   279	        if (status == Status.Active) {
   280	            if (totalEntries == 0) {
   281	                deadline = endTime;
   282	                if (msg.sender != sponsor && block.timestamp < deadline) {
   283	                    revert RefundsNotAvailable(deadline, block.timestamp);
   284	                }
   285	            } else {
   286	                deadline = drawRequestDeadline();
   287	                if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
   288	            }
   289	        } else if (status == Status.Drawing) {
   290	            deadline = callbackDeadline();
   291	            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
   292	        } else {
   293	            revert InvalidStatus(status);
   294	        }
   295	
   296	        uint256 liability = unsettledPot;
   297	        unsettledPot = 0;
   298	        remainingRefundLiability = liability;
   299	        status = Status.Refunding;
   300	        emit RefundsEnabled(msg.sender, liability);
   301	    }
   302	
   303	    /// @inheritdoc IRaffle
   304	    function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
   305	        cashAmount = _settleWinningTicket(ticketId);
   306	    }
   307	
   308	    /// @inheritdoc IRaffle
   309	    function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
   310	        if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
   311	        Status result = status;
   312	        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
   313	
   314	        if (!settlementComplete) {
   315	            _settleWinningTicket(ticketId);
   316	        } else if (ticketId != winningTicketId) {
   317	            revert WinningTicketMismatch(ticketId, winningTicketId);
   318	        }
   319	
   320	        address winner = ownerOf(ticketId);
   321	        if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);
   322	
   323	        winnerRecipient = winner;
   324	        winnerRedeemed = true;
   325	        _burn(ticketId);
   326	
   327	        address deliveredPrizeToken = address(0);
   328	        uint256 deliveredPrizeTokenId = 0;
   329	        if (result == Status.NftWon) {
   330	            if (prizeClaimed) revert PrizeAlreadyClaimed();
   331	            prizeClaimed = true;
   332	            deliveredPrizeToken = address(prizeToken);
   333	            deliveredPrizeTokenId = prizeTokenId;
   334	            prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
   335	            if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
   336	                revert PrizeDeliveryVerificationFailed(winner);
   337	            }
   338	        } else {
   339	            cashAmount = winnerProceeds;
   340	            if (cashAmount == 0) revert NoWinnerProceeds();
   341	            winnerProceeds = 0;
   342	            _transferQuote(winner, cashAmount);
   343	        }
   344	
   345	        emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
   346	    }
   347	
   348	    /// @inheritdoc IRaffle
   349	    function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
   350	        _requireStatus(Status.Refunding);
   351	        uint256 ticketQuantity = ticketIds.length;
   352	        if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
   353	            revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
   354	        }
   355	
   356	        uint256 aggregateEntries = 0;
   357	        for (uint256 index; index < ticketQuantity; ++index) {
   358	            uint256 ticketId = ticketIds[index];
   359	            address owner = ownerOf(ticketId);
   360	            if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);
   361	
   362	            (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
   363	            aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
   364	            _burn(ticketId);
   365	        }
   366	
   367	        amount = aggregateEntries * ENTRY_PRICE;
   368	        remainingRefundLiability -= amount;
   369	        _transferQuote(msg.sender, amount);
   370	        uint256 liabilityAfter = remainingRefundLiability;
   371	        emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
   372	    }
   373	
   374	    /// @inheritdoc IRaffle
   375	    function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
   376	        amount = sponsorProceeds;
   377	        if (amount == 0) revert NoSponsorProceeds();
   378	        sponsorProceeds = 0;
   379	        address recipient = sponsorRecipient;
   380	        _transferQuote(recipient, amount);
   381	        emit SponsorProceedsReleased(msg.sender, recipient, amount);
   382	    }
   383	
   384	    /// @inheritdoc IRaffle
   385	    function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
   386	        amount = protocolFees;
   387	        if (amount == 0) revert NoProtocolFees();
   388	        protocolFees = 0;
   389	        address treasury = protocolTreasury;
   390	        _transferQuote(treasury, amount);
   391	        emit ProtocolFeesReleased(msg.sender, treasury, amount);
   392	    }
   393	
   394	    /// @inheritdoc IRaffle
   395	    function releaseSponsorPrize() external override nonReentrant {
   396	        Status currentStatus = status;
   397	        if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
   398	            revert SponsorPrizeUnavailable(currentStatus);
   399	        }
   400	        if (prizeClaimed) revert PrizeAlreadyClaimed();
   401	
   402	        address recipient = sponsorRecipient;
   403	        prizeClaimed = true;
   404	        prizeToken.transferFrom(address(this), recipient, prizeTokenId);
   405	        if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
   406	        emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
   407	    }
   408	
   409	    /// @notice Accepts only the exact configured prize deposited by the factory for the sponsor.
   410	    /// @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be
   411	    ///      rescued.
   412	    /// @param operator ERC-721 transfer operator, which must be the canonical factory.
   413	    /// @param from Previous owner, which must be the configured sponsor.
   414	    /// @param tokenId Transferred token ID, which must match the configured prize.
   415	    /// @return selector ERC-721 receiver acceptance selector.
   416	    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
   417	        external
   418	        override
   419	        returns (bytes4 selector)
   420	    {
   421	        if (
   422	            status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
   423	                || from != sponsor || operator != factory
   424	        ) {
   425	            revert UnexpectedPrize(msg.sender, tokenId, from, operator);
   426	        }
   427	
   428	        status = Status.Active;
   429	        emit PrizeDeposited(msg.sender, tokenId, from);
   430	        selector = IERC721Receiver.onERC721Received.selector;
   431	    }
   432	
   433	    // Public view and pure functions
   434	
   435	    /// @inheritdoc IRaffle
   436	    function getVrfRequestPrice() public view override returns (uint256 fee) {
   437	        fee = i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1);
   438	    }
   439	
   440	    /// @inheritdoc IRaffle
   441	    function estimateVrfRequestPrice(uint256 requestGasPriceWei) public view override returns (uint256 fee) {
   442	        fee = i_vrfV2PlusWrapper.estimateRequestPriceNative(callbackGasLimit, 1, requestGasPriceWei);
   443	    }
   444	
   445	    /// @inheritdoc IRaffle
   446	    function vrfWrapper() public view override returns (IVRFV2PlusWrapper wrapper) {
   447	        wrapper = i_vrfV2PlusWrapper;
   448	    }
   449	
   450	    /// @inheritdoc IRaffle
   451	    function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
   452	        TicketRange storage range = _ticketRanges[ticketId];
   453	        firstEntry = range.firstEntry;
   454	        lastEntry = range.lastEntry;
   455	    }
   456	
   457	    /// @inheritdoc IRaffle
   458	    function drawRequestDeadline() public view override returns (uint256 deadline) {
   459	        deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
   460	    }
   461	
   462	    /// @inheritdoc IRaffle
   463	    function callbackDeadline() public view override returns (uint256 deadline) {
   464	        if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
   465	    }
   466	
   467	    /// @inheritdoc IRaffle
   468	    function accountedQuoteBalance() public view override returns (uint256 amount) {
   469	        amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
   470	    }
   471	
   472	    /// @inheritdoc IRaffle
   473	    function grossSales() public view override returns (uint256 amount) {
   474	        amount = uint256(totalEntries) * ENTRY_PRICE;
   475	    }
   476	
   477	    /// @notice Returns the fixed display name shared by every raffle ticket collection.
   478	    /// @return Exact ERC-721 collection name, `raffle.fun Ticket`.
   479	    function name() public pure override returns (string memory) {
   480	        return "raffle.fun Ticket";
   481	    }
   482	
   483	    /// @notice Returns the fixed display symbol shared by every raffle ticket collection.
   484	    /// @return Exact ERC-721 collection symbol, `RAFFLE`.
   485	    function symbol() public pure override returns (string memory) {
   486	        return "RAFFLE";
   487	    }
   488	
   489	    // Internal state-changing functions
   490	
   491	    /// @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected
   492	    ///      before their ownership could make a claim unreachable. Burns pass the zero address and remain permitted.
   493	    /// @param to Prospective ticket recipient, or the zero address for a burn.
   494	    /// @param ticketId Ticket being minted, transferred, or burned.
   495	    /// @param auth Caller whose owner or operator authority is checked by ERC-721.
   496	    /// @return previousOwner Ticket owner before the update, or the zero address for a mint.
   497	    function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
   498	        if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
   499	            revert UnsafeProtocolDestination(to);
   500	        }
   501	        previousOwner = super._update(to, ticketId, auth);
   502	    }
   503	
   504	    /// @dev Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer
   505	    ///      occurs. In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for
   506	    ///      liveness; malformed ABI calldata reverts during Solidity decoding before this handler runs.
   507	    /// @param requestId Wrapper-authenticated request identifier supplied by the callback.
   508	    /// @param randomWords Callback words; exactly one word is required for resolution.
   509	    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
   510	        if (
   511	            _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
   512	                || block.timestamp >= callbackDeadline()
   513	        ) {
   514	            emit VrfCallbackIgnored(requestId, vrfRequestId, status);
   515	            return;
   516	        }
   517	
   518	        uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
   519	        winningEntry = resolvedEntry;
   520	        resolvedAt = uint64(block.timestamp);
   521	        status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;
   522	
   523	        emit RaffleResolved(requestId, resolvedEntry, status);
   524	    }
   525	
   526	    // Private state-changing helpers
   527	
   528	    /// @dev Validates the winning range once and allocates all terminal quote-token liabilities without transferring
   529	    ///      an asset or reading ticket ownership. Both percentage allocations round down; sponsor proceeds are the
   530	    ///      remainder.
   531	    /// @param ticketId Ticket whose inclusive range must contain the selected winning entry.
   532	    /// @return cashAmount Raw six-decimal quote-token units allocated to the cash winner, or zero for `NftWon`.
   533	    function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
   534	        if (settlementComplete) revert SettlementAlreadyComplete();
   535	        Status result = status;
   536	        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
   537	
   538	        _requireWinningTicket(ticketId);
   539	        uint256 grossPot = unsettledPot;
   540	        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
   541	        uint256 sponsorAmount;
   542	
   543	        if (result == Status.NftWon) {
   544	            sponsorAmount = grossPot - protocolFee;
   545	        } else {
   546	            cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
   547	            sponsorAmount = grossPot - protocolFee - cashAmount;
   548	            winnerProceeds = cashAmount;
   549	        }
   550	
   551	        settlementComplete = true;
   552	        winningTicketId = ticketId;
   553	        unsettledPot = 0;
   554	        sponsorProceeds = sponsorAmount;
   555	        protocolFees = protocolFee;
   556	
   557	        emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
   558	    }
   559	
   560	    /// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
   561	    ///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
   562	    /// @param to Immutable or owner-derived recipient of the claim.
   563	    /// @param amount Raw six-decimal USDC units transferred.
   564	    function _transferQuote(address to, uint256 amount) private {
   565	        if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
   566	        quoteToken.safeTransfer(to, amount);
   567	    }
   568	
   569	    // Private view and pure helpers
   570	
   571	    /// @dev Reverts unless the raffle is in the expected lifecycle state.
   572	    /// @param expected Status required by the calling operation.
   573	    function _requireStatus(Status expected) private view {
   574	        if (status != expected) revert InvalidStatus(status);
   575	    }
   576	
   577	    /// @dev Reverts unless the supplied ticket's stored inclusive range contains the selected winning entry.
   578	    /// @param ticketId Candidate winning ticket ID.
   579	    function _requireWinningTicket(uint256 ticketId) private view {
   580	        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
   581	        uint128 selectedEntry = winningEntry;
   582	        if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
   583	            revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
   584	        }
   585	    }
   586	
   587	    /// @dev Identifies same-factory protocol plumbing that cannot safely own a ticket or receive a payout.
   588	    ///      Initialization supplies the prospective prize token because clone storage is not populated yet; runtime
   589	    ///      checks pass the stored prize token. Code-less addresses are not queried in the registry.
   590	    /// @param destination Address being screened.
   591	    /// @param prizeToken_ Configured or prospective prize-token address to reject.
   592	    /// @return unsafeDestination True when the address is known same-factory protocol plumbing.
   593	    function _isProtocolDestination(address destination, address prizeToken_)
   594	        private
   595	        view
   596	        returns (bool unsafeDestination)
   597	    {
   598	        IRaffleFactory canonicalFactory = IRaffleFactory(factory);
   599	        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
   600	            || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
   601	            || destination == canonicalFactory.raffleImplementation();
   602	        if (!unsafeDestination && destination.code.length != 0) {
   603	            unsafeDestination = canonicalFactory.isRaffle(destination);
   604	        }
   605	    }
   606	
   607	    /// @dev Validates the wrapper before passing it to the inherited constructor initializer.
   608	    /// @param wrapper Prospective Chainlink wrapper address.
   609	    /// @return validatedWrapper The same nonzero wrapper address.
   610	    function _validatedVrfWrapper(address wrapper) private pure returns (address validatedWrapper) {
   611	        if (wrapper == address(0)) revert ZeroAddress();
   612	        validatedWrapper = wrapper;
   613	    }
   614	}
```

### packages/contracts/src/RaffleFactory.sol

```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity 0.8.36;
     3	
     4	import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
     5	import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
     6	import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
     7	import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
     8	import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
     9	
    10	import { Raffle } from "./Raffle.sol";
    11	import { IRaffle } from "./interfaces/IRaffle.sol";
    12	import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
    13	import { RaffleConstants } from "./libraries/RaffleConstants.sol";
    14	
    15	/// @title raffle.fun Canonical USDC Raffle Factory
    16	/// @author heesho
    17	/// @notice Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.
    18	/// @dev The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable. The
    19	///      factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.
    20	/// @custom:version 1.0.0
    21	contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
    22	    // Constants
    23	
    24	    /// @inheritdoc IRaffleFactory
    25	    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;
    26	
    27	    /// @inheritdoc IRaffleFactory
    28	    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;
    29	
    30	    // Immutables and state
    31	
    32	    /// @inheritdoc IRaffleFactory
    33	    address public immutable override quoteToken;
    34	
    35	    /// @inheritdoc IRaffleFactory
    36	    address public immutable override vrfWrapper;
    37	
    38	    /// @inheritdoc IRaffleFactory
    39	    address public immutable override protocolTreasury;
    40	
    41	    /// @inheritdoc IRaffleFactory
    42	    address public immutable override raffleImplementation;
    43	
    44	    /// @inheritdoc IRaffleFactory
    45	    uint256 public override raffleCount;
    46	
    47	    /// @inheritdoc IRaffleFactory
    48	    mapping(uint256 raffleId => address raffle) public override raffleById;
    49	
    50	    /// @inheritdoc IRaffleFactory
    51	    mapping(address raffle => uint256 raffleId) public override idByRaffle;
    52	
    53	    /// @inheritdoc IRaffleFactory
    54	    mapping(address raffle => bool registered) public override isRaffle;
    55	
    56	    // Constructor
    57	
    58	    /// @notice Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.
    59	    /// @dev The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code.
    60	    ///      Deployment tooling must supply and verify the target chain's official USDC address because the constructor
    61	    ///      cannot prove token identity from metadata.
    62	    /// @param quoteToken_ Target chain's official six-decimal USDC contract trusted by every raffle.
    63	    /// @param vrfWrapper_ Official Chainlink VRF v2.5 native direct-funding wrapper for the target chain.
    64	    /// @param protocolTreasury_ Immutable protocol-fee recipient used by every raffle.
    65	    constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    66	        _requireContract(quoteToken_);
    67	        _requireContract(vrfWrapper_);
    68	        if (protocolTreasury_ == address(0)) revert ZeroAddress();
    69	
    70	        uint8 quoteDecimals = 0;
    71	        try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
    72	            quoteDecimals = decimals_;
    73	        } catch {
    74	            revert UnsupportedQuoteToken(quoteToken_);
    75	        }
    76	        if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
    77	            revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
    78	        }
    79	
    80	        if (protocolTreasury_ == address(this) || protocolTreasury_ == quoteToken_ || protocolTreasury_ == vrfWrapper_)
    81	        {
    82	            revert UnsafeProtocolDestination(protocolTreasury_);
    83	        }
    84	
    85	        quoteToken = quoteToken_;
    86	        vrfWrapper = vrfWrapper_;
    87	        protocolTreasury = protocolTreasury_;
    88	
    89	        address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
    90	        if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
    91	        raffleImplementation = implementation;
    92	    }
    93	
    94	    // External state-changing functions
    95	
    96	    /// @inheritdoc IRaffleFactory
    97	    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    98	        _validateCreateParams(params);
    99	        uint256 currentTime = block.timestamp;
   100	        if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
   101	        uint256 saleDuration = uint256(params.endTime) - currentTime;
   102	        if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
   103	            revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
   104	        }
   105	        uint256 raffleId = ++raffleCount;
   106	        raffle = Clones.clone(raffleImplementation);
   107	        // The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
   108	        // slither-disable-next-line reentrancy-no-eth
   109	        IRaffle(raffle)
   110	            .initialize(
   111	                IRaffle.RaffleInitParams({
   112	                sponsor: msg.sender,
   113	                sponsorRecipient: params.sponsorRecipient,
   114	                protocolTreasury: protocolTreasury,
   115	                prizeToken: params.prizeToken,
   116	                prizeTokenId: params.prizeTokenId,
   117	                raffleId: raffleId,
   118	                reserveEntries: params.reserveEntries,
   119	                endTime: params.endTime
   120	            })
   121	            );
   122	
   123	        raffleById[raffleId] = raffle;
   124	        idByRaffle[raffle] = raffleId;
   125	        isRaffle[raffle] = true;
   126	
   127	        IERC721 prize = IERC721(params.prizeToken);
   128	        prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
   129	        if (prize.ownerOf(params.prizeTokenId) != raffle) {
   130	            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
   131	        }
   132	        if (IRaffle(raffle).status() != IRaffle.Status.Active) {
   133	            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
   134	        }
   135	
   136	        emit RaffleCreated(
   137	            raffleId,
   138	            raffle,
   139	            msg.sender,
   140	            params.sponsorRecipient,
   141	            params.prizeToken,
   142	            params.prizeTokenId,
   143	            quoteToken,
   144	            protocolTreasury,
   145	            params.reserveEntries,
   146	            params.endTime
   147	        );
   148	    }
   149	
   150	    // Private view helpers
   151	
   152	    /// @dev Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.
   153	    /// @param params Prospective raffle configuration supplied by the sponsor.
   154	    function _validateCreateParams(CreateRaffleParams calldata params) private view {
   155	        _requireContract(params.prizeToken);
   156	        if (params.sponsorRecipient == address(0)) revert ZeroAddress();
   157	        if (
   158	            params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
   159	                || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
   160	        ) {
   161	            revert UnsafeProtocolDestination(params.prizeToken);
   162	        }
   163	        if (
   164	            params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
   165	                || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
   166	                || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
   167	        ) {
   168	            revert UnsafeProtocolDestination(params.sponsorRecipient);
   169	        }
   170	
   171	        bool supports721 = false;
   172	        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
   173	            supports721 = supported;
   174	        } catch {
   175	            revert UnsupportedPrizeToken(params.prizeToken);
   176	        }
   177	        if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
   178	        if (params.reserveEntries == 0) revert ZeroReserveEntries();
   179	    }
   180	
   181	    /// @dev Reverts unless an address contains deployed code.
   182	    /// @param account Address required to be a contract.
   183	    function _requireContract(address account) private view {
   184	        if (account.code.length == 0) revert NotContract(account);
   185	    }
   186	}
```

### packages/contracts/src/interfaces/IRaffle.sol

```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity 0.8.36;
     3	
     4	import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
     5	import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
     6	import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
     7	
     8	/// @title raffle.fun Raffle Interface
     9	/// @author heesho
    10	/// @notice Defines one autonomous NFT raffle using fixed-price USDC entries and one transferable ERC-721 ticket per
    11	///         purchase.
    12	/// @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable
    13	///      bearer claim until its owner atomically burns it for redemption or refund. The immutable quote token is trusted
    14	///      canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest,
    15	///      standards-compliant ERC-721s.
    16	/// @custom:version 1.0.0
    17	interface IRaffle {
    18	    // Types
    19	
    20	    /// @notice The single authoritative raffle lifecycle and economic result.
    21	    enum Status {
    22	        /// @notice The clone is initialized and waiting for the factory to escrow the configured prize.
    23	        AwaitingPrize,
    24	        /// @notice The prize is escrowed and entry sales or post-sale draw initiation are available.
    25	        Active,
    26	        /// @notice A Chainlink VRF request was accepted and its callback window is open.
    27	        Drawing,
    28	        /// @notice The reserve was met and the winning ticket may redeem the prize NFT.
    29	        NftWon,
    30	        /// @notice The reserve was missed and the winning ticket may redeem its cash allocation.
    31	        CashWon,
    32	        /// @notice Full ticket refunds are enabled and the sponsor may recover the prize NFT.
    33	        Refunding
    34	    }
    35	
    36	    /// @notice Complete clone-specific configuration supplied once by the canonical factory.
    37	    /// @param sponsor Prize depositor and empty-raffle cancellation authority.
    38	    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    39	    /// @param protocolTreasury Immutable recipient of protocol fees.
    40	    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    41	    /// @param prizeTokenId Token ID of the prize escrowed by this raffle.
    42	    /// @param raffleId One-based canonical factory identifier for this raffle.
    43	    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    44	    /// @param endTime Unix timestamp, in seconds, at which entry sales end exclusively.
    45	    struct RaffleInitParams {
    46	        address sponsor;
    47	        address sponsorRecipient;
    48	        address protocolTreasury;
    49	        address prizeToken;
    50	        uint256 prizeTokenId;
    51	        uint256 raffleId;
    52	        uint128 reserveEntries;
    53	        uint64 endTime;
    54	    }
    55	
    56	    // Events
    57	
    58	    /// @notice Emitted when the factory deposits the configured prize and activates the raffle.
    59	    /// @param prizeToken ERC-721 contract of the deposited prize.
    60	    /// @param prizeTokenId Token ID of the deposited prize.
    61	    /// @param sponsor Address that deposited the prize through the factory.
    62	    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);
    63	
    64	    /// @notice Emitted when a buyer pays for entries and one range ticket is minted.
    65	    /// @param buyer Address that paid the six-decimal quote-token amount.
    66	    /// @param recipient Address that received the newly minted ticket.
    67	    /// @param ticketId Sequential ticket ID assigned to the purchase.
    68	    /// @param firstEntry First global raffle entry represented by the ticket, inclusive.
    69	    /// @param lastEntry Last global raffle entry represented by the ticket, inclusive.
    70	    /// @param entryCount Number of entries represented by the ticket.
    71	    /// @param grossAmount Raw six-decimal quote-token units paid, equal to `entryCount * ENTRY_PRICE`.
    72	    event TicketPurchased(
    73	        address indexed buyer,
    74	        address indexed recipient,
    75	        uint256 indexed ticketId,
    76	        uint128 firstEntry,
    77	        uint128 lastEntry,
    78	        uint128 entryCount,
    79	        uint256 grossAmount
    80	    );
    81	
    82	    /// @notice Emitted when the raffle pays for and records its one Chainlink VRF request.
    83	    /// @param requestId Wrapper-assigned request identifier.
    84	    /// @param requester Address that initiated and funded the request.
    85	    /// @param fee Native-token wei actually paid to the wrapper for the request.
    86	    /// @param excessReturned Native-token wei returned to the requester after paying the actual fee.
    87	    /// @param drawRequestedAt Unix timestamp, in seconds, when the request was accepted.
    88	    /// @param callbackDeadline Exclusive Unix-timestamp deadline for accepting the authenticated callback.
    89	    event DrawRequested(
    90	        uint256 indexed requestId,
    91	        address indexed requester,
    92	        uint256 fee,
    93	        uint256 excessReturned,
    94	        uint256 drawRequestedAt,
    95	        uint256 callbackDeadline
    96	    );
    97	
    98	    /// @notice Emitted when an authenticated, ABI-decodable callback cannot resolve the raffle.
    99	    /// @param receivedRequestId Request ID supplied by the wrapper callback.
   100	    /// @param expectedRequestId Request ID currently recorded by the raffle, or zero before request persistence.
   101	    /// @param status Current raffle status when the callback is ignored.
   102	    event VrfCallbackIgnored(uint256 indexed receivedRequestId, uint256 indexed expectedRequestId, Status status);
   103	
   104	    /// @notice Emitted when an authenticated callback selects the winning entry and final result.
   105	    /// @param requestId Request ID that produced the accepted randomness.
   106	    /// @param winningEntry Selected one-based global entry number in `[1,totalEntries]`.
   107	    /// @param result Final `NftWon` or `CashWon` result.
   108	    event RaffleResolved(uint256 indexed requestId, uint128 indexed winningEntry, Status indexed result);
   109	
   110	    /// @notice Emitted when the raffle enters the full-refund branch.
   111	    /// @param finalizer Address that enabled refunds.
   112	    /// @param remainingRefundLiability Raw six-decimal quote-token units initially available for ticket refunds.
   113	    event RefundsEnabled(address indexed finalizer, uint256 remainingRefundLiability);
   114	
   115	    /// @notice Emitted when the winning ticket is proven and all terminal quote-token liabilities are allocated.
   116	    /// @param ticketId Ticket proven to contain the selected winning entry.
   117	    /// @param settler Address that performed permissionless settlement.
   118	    /// @param result Final `NftWon` or `CashWon` result.
   119	    /// @param cashAmount Raw six-decimal quote-token units allocated to the cash winner; zero for `NftWon`.
   120	    /// @param protocolFee Raw six-decimal quote-token units allocated to the treasury, rounded down from gross sales.
   121	    /// @param sponsorAmount Raw six-decimal quote-token units allocated to the sponsor recipient as the remainder.
   122	    event WinningTicketSettled(
   123	        uint256 indexed ticketId,
   124	        address indexed settler,
   125	        Status indexed result,
   126	        uint256 cashAmount,
   127	        uint256 protocolFee,
   128	        uint256 sponsorAmount
   129	    );
   130	
   131	    /// @notice Emitted when the winning ticket owner burns the ticket and receives the corresponding prize.
   132	    /// @param ticketId Burned winning ticket ID.
   133	    /// @param winner Ticket owner that received the prize at redemption time.
   134	    /// @param result Final `NftWon` or `CashWon` result.
   135	    /// @param cashAmount Raw six-decimal quote-token units paid for `CashWon`; zero for `NftWon`.
   136	    /// @param prizeToken ERC-721 prize contract for `NftWon`; the zero address for `CashWon`.
   137	    /// @param prizeTokenId ERC-721 prize token ID for `NftWon`; zero for `CashWon`.
   138	    event WinningTicketRedeemed(
   139	        uint256 indexed ticketId,
   140	        address indexed winner,
   141	        Status indexed result,
   142	        uint256 cashAmount,
   143	        address prizeToken,
   144	        uint256 prizeTokenId
   145	    );
   146	
   147	    /// @notice Emitted when an owner burns one or more tickets for a full quote-token refund.
   148	    /// @param owner Ticket owner that burned the tickets and received the refund.
   149	    /// @param ticketQuantity Number of tickets burned in this transaction.
   150	    /// @param entryQuantity Aggregate number of entries represented by the burned tickets.
   151	    /// @param amount Raw six-decimal quote-token units refunded, equal to `entryQuantity * ENTRY_PRICE`.
   152	    /// @param remainingRefundLiability Raw six-decimal quote-token units still claimable after this refund.
   153	    event TicketsRefunded(
   154	        address indexed owner,
   155	        uint256 ticketQuantity,
   156	        uint256 entryQuantity,
   157	        uint256 amount,
   158	        uint256 remainingRefundLiability
   159	    );
   160	
   161	    /// @notice Emitted when the complete current sponsor balance is released to its immutable recipient.
   162	    /// @param caller Address that triggered the permissionless release.
   163	    /// @param recipient Immutable sponsor recipient that received the payment.
   164	    /// @param amount Raw six-decimal quote-token units paid.
   165	    event SponsorProceedsReleased(address indexed caller, address indexed recipient, uint256 amount);
   166	
   167	    /// @notice Emitted when the complete current protocol-fee balance is released to the immutable treasury.
   168	    /// @param caller Address that triggered the permissionless release.
   169	    /// @param treasury Immutable protocol treasury that received the payment.
   170	    /// @param amount Raw six-decimal quote-token units paid.
   171	    event ProtocolFeesReleased(address indexed caller, address indexed treasury, uint256 amount);
   172	
   173	    /// @notice Emitted when the escrowed prize is returned after a cash result or refund transition.
   174	    /// @param caller Address that triggered the permissionless release.
   175	    /// @param recipient Immutable sponsor recipient that received the prize.
   176	    /// @param prizeToken ERC-721 contract of the returned prize.
   177	    /// @param prizeTokenId Token ID of the returned prize.
   178	    event SponsorPrizeReleased(
   179	        address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId
   180	    );
   181	
   182	    // Errors
   183	
   184	    /// @notice Raised when a caller other than the immutable factory attempts clone initialization.
   185	    error OnlyFactory();
   186	
   187	    /// @notice Raised when initialization is attempted more than once or on the locked implementation.
   188	    error AlreadyInitialized();
   189	
   190	    /// @notice Raised when a required address is the zero address.
   191	    error ZeroAddress();
   192	
   193	    /// @notice Raised when an operation is unavailable in the current lifecycle state.
   194	    /// @param actual Current raffle status.
   195	    error InvalidStatus(Status actual);
   196	
   197	    /// @notice Raised when an ERC-721 receiver callback does not exactly match the configured factory prize deposit.
   198	    /// @param token ERC-721 contract that invoked the receiver callback.
   199	    /// @param tokenId Token ID supplied by the callback.
   200	    /// @param from Address identified as the previous token owner.
   201	    /// @param operator Address identified as the transfer operator.
   202	    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);
   203	
   204	    /// @notice Raised when an entry purchase is submitted at or after the exclusive sale end.
   205	    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
   206	    /// @param currentTime Current block Unix timestamp, in seconds.
   207	    error SaleEnded(uint256 endTime, uint256 currentTime);
   208	
   209	    /// @notice Raised when an entry ticket would be minted to the zero address.
   210	    error InvalidRecipient();
   211	
   212	    /// @notice Raised when a purchase requests no entries.
   213	    error ZeroEntryCount();
   214	
   215	    /// @notice Raised when a purchase would exceed the `uint128` global entry-number representation.
   216	    /// @param totalEntries Current global sold-entry count.
   217	    /// @param requestedEntries Prospective entry count requested by the purchase.
   218	    error TotalEntriesOverflow(uint128 totalEntries, uint128 requestedEntries);
   219	
   220	    /// @notice Raised when a refund batch is empty or exceeds the bounded ticket limit.
   221	    /// @param quantity Number of supplied ticket IDs.
   222	    /// @param maximum Maximum ticket IDs accepted per refund transaction.
   223	    error InvalidTicketBatchSize(uint256 quantity, uint256 maximum);
   224	
   225	    /// @notice Raised when a quote-token claim targets a known protocol destination that could strand the claim.
   226	    /// @param destination Rejected payout recipient.
   227	    error InvalidQuoteDestination(address destination);
   228	
   229	    /// @notice Raised when a draw request is submitted before the sale end.
   230	    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
   231	    /// @param currentTime Current block Unix timestamp, in seconds.
   232	    error RaffleNotEnded(uint256 endTime, uint256 currentTime);
   233	
   234	    /// @notice Raised when a draw request is submitted at or after the exclusive request deadline.
   235	    /// @param deadline Exclusive draw-request Unix-timestamp deadline, in seconds.
   236	    /// @param currentTime Current block Unix timestamp, in seconds.
   237	    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);
   238	
   239	    /// @notice Raised when draw initiation is attempted for a raffle with zero sold entries.
   240	    error NoEntriesSold();
   241	
   242	    /// @notice Raised when refunds are requested before the applicable liveness deadline.
   243	    /// @param deadline Unix timestamp, in seconds, at which refunds become available.
   244	    /// @param currentTime Current block Unix timestamp, in seconds.
   245	    error RefundsNotAvailable(uint256 deadline, uint256 currentTime);
   246	
   247	    /// @notice Raised when supplied native value cannot cover the quoted or actual Chainlink request fee.
   248	    /// @param requiredFee Native-token wei required for the request.
   249	    /// @param suppliedValue Native-token wei supplied by the caller.
   250	    error InsufficientVrfFee(uint256 requiredFee, uint256 suppliedValue);
   251	
   252	    /// @notice Raised when excess native value cannot be returned to the draw requester.
   253	    /// @param recipient Draw requester that was due the refund.
   254	    /// @param amount Native-token wei that could not be returned.
   255	    error NativeRefundFailed(address recipient, uint256 amount);
   256	
   257	    /// @notice Raised when no current cash-winner proceeds remain claimable.
   258	    error NoWinnerProceeds();
   259	
   260	    /// @notice Raised when no current sponsor proceeds remain claimable.
   261	    error NoSponsorProceeds();
   262	
   263	    /// @notice Raised when no current protocol fees remain claimable.
   264	    error NoProtocolFees();
   265	
   266	    /// @notice Raised when initialization or a ticket transfer targets known protocol plumbing.
   267	    /// @param destination Rejected address.
   268	    error UnsafeProtocolDestination(address destination);
   269	
   270	    /// @notice Raised when the caller is not the current owner of the supplied ticket.
   271	    /// @param ticketId Ticket whose ownership was checked.
   272	    /// @param caller Address attempting the owner-only operation.
   273	    /// @param owner Current ticket owner.
   274	    error NotTicketOwner(uint256 ticketId, address caller, address owner);
   275	
   276	    /// @notice Raised when the supplied ticket range does not contain the selected winning entry.
   277	    /// @param ticketId Supplied ticket ID.
   278	    /// @param winningEntry Selected one-based global winning entry.
   279	    error TicketDoesNotContainWinningEntry(uint256 ticketId, uint128 winningEntry);
   280	
   281	    /// @notice Raised when terminal liabilities have already been allocated.
   282	    error SettlementAlreadyComplete();
   283	
   284	    /// @notice Raised when redemption supplies a ticket other than the recorded winning ticket.
   285	    /// @param suppliedTicketId Ticket ID supplied for redemption.
   286	    /// @param winningTicketId Previously settled winning ticket ID.
   287	    error WinningTicketMismatch(uint256 suppliedTicketId, uint256 winningTicketId);
   288	
   289	    /// @notice Raised when the winning ticket has already been burned and redeemed.
   290	    error WinningTicketAlreadyRedeemed();
   291	
   292	    /// @notice Raised when the sponsor prize cannot be returned in the current result state.
   293	    /// @param status Current raffle status.
   294	    error SponsorPrizeUnavailable(Status status);
   295	
   296	    /// @notice Raised when the escrowed prize has already been released.
   297	    error PrizeAlreadyClaimed();
   298	
   299	    /// @notice Raised when the prize token does not report the expected owner after transfer.
   300	    /// @param recipient Address that should own the prize after delivery.
   301	    error PrizeDeliveryVerificationFailed(address recipient);
   302	
   303	    // External state-changing functions
   304	
   305	    /// @notice Initializes a fresh fixed-target clone with its immutable-per-raffle configuration.
   306	    /// @dev Callable exactly once and only by the immutable canonical factory. Prize escrow activates the raffle later.
   307	    /// @param params Clone-specific sponsor, prize, accounting, identifier, reserve, and timing configuration.
   308	    function initialize(RaffleInitParams calldata params) external;
   309	
   310	    /// @notice Buys any positive number of entries and mints one sequential ticket containing their inclusive range.
   311	    /// @param recipient Address that receives the newly minted ERC-721 range ticket.
   312	    /// @param entryCount Prospective number of entries to buy for this ticket.
   313	    /// @return ticketId Sequential ID of the newly minted ticket.
   314	    function buyEntries(address recipient, uint128 entryCount) external returns (uint256 ticketId);
   315	
   316	    /// @notice Pays the current native Chainlink fee and requests the raffle's one random word.
   317	    /// @dev Callable by anyone only in `[endTime,drawRequestDeadline())` after at least one entry is sold. Any native
   318	    ///      value above the wrapper's actual fee is returned to the caller atomically.
   319	    /// @return requestId Wrapper-assigned request identifier recorded by the raffle.
   320	    function requestDraw() external payable returns (uint256 requestId);
   321	
   322	    /// @notice Enables full refunds after the sold-raffle request deadline or an accepted request's callback deadline.
   323	    ///         Also closes an empty raffle immediately for the sponsor and after sale end for anyone.
   324	    function enableRefunds() external;
   325	
   326	    /// @notice Proves which ticket contains the winning entry and allocates winner, sponsor, and protocol liabilities.
   327	    /// @dev Anyone may execute; ownership is not read, the ticket remains transferable, and no external asset transfer
   328	    ///      occurs. The cash-winner allocation is rounded down; the sponsor receives the remaining raw units.
   329	    /// @param ticketId Ticket whose stored inclusive range must contain `winningEntry`.
   330	    /// @return cashAmount Raw six-decimal quote-token units allocated to the winner, or zero for an NFT result.
   331	    function settleWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);
   332	
   333	    /// @notice Lets the current winning-ticket owner atomically burn the ticket and receive the NFT or cash prize.
   334	    /// @dev If necessary, this first settles the supplied winning ticket so the owner can complete both steps in one
   335	    ///      transaction. Any failed delivery reverts the burn and every redemption state change.
   336	    /// @param ticketId Winning ticket to settle if needed, burn, and redeem.
   337	    /// @return cashAmount Raw six-decimal quote-token units paid for `CashWon`, or zero for `NftWon`.
   338	    function redeemWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);
   339	
   340	    /// @notice Burns an owner-selected batch of tickets and returns their full entry purchase value.
   341	    /// @dev Accepts one to 100 tickets. Duplicate, nonexistent, or foreign-owned IDs revert the entire batch.
   342	    /// @param ticketIds Ticket IDs owned by the caller and submitted for refund.
   343	    /// @return amount Raw six-decimal quote-token units paid, equal to represented entries times `ENTRY_PRICE`.
   344	    function refundTickets(uint256[] calldata ticketIds) external returns (uint256 amount);
   345	
   346	    /// @notice Releases the complete current sponsor-proceeds balance to the immutable sponsor recipient.
   347	    /// @return amount Raw six-decimal quote-token units paid in this release.
   348	    function releaseSponsorProceeds() external returns (uint256 amount);
   349	
   350	    /// @notice Releases the complete current protocol-fee balance to the immutable treasury.
   351	    /// @return amount Raw six-decimal quote-token units paid in this release.
   352	    function releaseProtocolFees() external returns (uint256 amount);
   353	
   354	    /// @notice Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`.
   355	    function releaseSponsorPrize() external;
   356	
   357	    // External view functions
   358	
   359	    /// @notice Returns the wrapper's current native direct-funding price for the configured callback.
   360	    /// @return fee Native-token wei currently quoted by the wrapper; the value may change before request inclusion.
   361	    function getVrfRequestPrice() external view returns (uint256 fee);
   362	
   363	    /// @notice Estimates the native direct-funding price at a caller-selected gas price.
   364	    /// @param requestGasPriceWei Prospective transaction gas price in wei per gas.
   365	    /// @return fee Estimated native-token wei for the configured callback and one random word.
   366	    function estimateVrfRequestPrice(uint256 requestGasPriceWei) external view returns (uint256 fee);
   367	
   368	    /// @notice Returns the inclusive global entry range represented by a ticket ID.
   369	    /// @dev Returns zeros for an ID that has never been minted; ranges remain historical after ticket burns.
   370	    /// @param ticketId Sequential ticket ID to inspect.
   371	    /// @return firstEntry First represented one-based global entry, inclusive.
   372	    /// @return lastEntry Last represented one-based global entry, inclusive.
   373	    function ticketRange(uint256 ticketId) external view returns (uint128 firstEntry, uint128 lastEntry);
   374	
   375	    /// @notice Returns the exclusive deadline for initiating the draw.
   376	    /// @return deadline Unix timestamp, in seconds, equal to `endTime + 2 days`.
   377	    function drawRequestDeadline() external view returns (uint256 deadline);
   378	
   379	    /// @notice Returns the exclusive deadline for accepting the authenticated callback.
   380	    /// @return deadline Unix timestamp, in seconds, equal to `drawRequestedAt + 2 days`, or zero before a request.
   381	    function callbackDeadline() external view returns (uint256 deadline);
   382	
   383	    /// @notice Returns all currently outstanding quote-token liabilities tracked by the raffle.
   384	    /// @return amount Raw six-decimal quote-token units across the unsettled pot, refunds, and allocated claims.
   385	    function accountedQuoteBalance() external view returns (uint256 amount);
   386	
   387	    /// @notice Returns lifetime gross sales derived from the global sold-entry count.
   388	    /// @dev No redundant gross-sales value is stored.
   389	    /// @return amount Raw six-decimal quote-token units equal to `totalEntries * ENTRY_PRICE`.
   390	    function grossSales() external view returns (uint256 amount);
   391	
   392	    // Public generated getters
   393	
   394	    /// @notice Returns the fixed raw six-decimal quote-token price of one entry.
   395	    /// @return price One entry price, exactly 1,000,000 raw units.
   396	    function ENTRY_PRICE() external view returns (uint256 price);
   397	
   398	    /// @notice Returns the fixed Chainlink callback execution limit.
   399	    /// @return gasLimit Callback gas units requested from the wrapper.
   400	    function callbackGasLimit() external view returns (uint32 gasLimit);
   401	
   402	    /// @notice Returns the fixed Chainlink confirmation count.
   403	    /// @return confirmations Blocks requested before callback fulfillment.
   404	    function requestConfirmations() external view returns (uint16 confirmations);
   405	
   406	    /// @notice Returns the immutable factory authorized to initialize this implementation's clones.
   407	    /// @return factoryAddress Canonical factory address.
   408	    function factory() external view returns (address factoryAddress);
   409	
   410	    /// @notice Returns the prize depositor and pre-end empty-raffle refund authority.
   411	    /// @return sponsorAddress Immutable-per-raffle sponsor address.
   412	    function sponsor() external view returns (address sponsorAddress);
   413	
   414	    /// @notice Returns the immutable recipient of sponsor quote proceeds and returned prizes.
   415	    /// @return recipient Sponsor recipient address.
   416	    function sponsorRecipient() external view returns (address recipient);
   417	
   418	    /// @notice Returns the immutable recipient of this raffle's protocol fees.
   419	    /// @return treasury Protocol treasury address.
   420	    function protocolTreasury() external view returns (address treasury);
   421	
   422	    /// @notice Returns the immutable canonical six-decimal USDC contract.
   423	    /// @return token Canonical USDC contract trusted by this factory deployment.
   424	    function quoteToken() external view returns (IERC20 token);
   425	
   426	    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper.
   427	    /// @return wrapper Wrapper contract.
   428	    function vrfWrapper() external view returns (IVRFV2PlusWrapper wrapper);
   429	
   430	    /// @notice Returns the configured ERC-721 prize contract.
   431	    /// @return token Prize-token contract.
   432	    function prizeToken() external view returns (IERC721 token);
   433	
   434	    /// @notice Returns the configured ERC-721 prize token ID.
   435	    /// @return tokenId Escrowed prize token ID.
   436	    function prizeTokenId() external view returns (uint256 tokenId);
   437	
   438	    /// @notice Returns this raffle's one-based canonical factory identifier.
   439	    /// @return id Raffle identifier.
   440	    function raffleId() external view returns (uint256 id);
   441	
   442	    /// @notice Returns the global entry threshold that selects the NFT outcome when met or exceeded.
   443	    /// @return entries Reserve entry count.
   444	    function reserveEntries() external view returns (uint128 entries);
   445	
   446	    /// @notice Returns the exclusive sale-end timestamp.
   447	    /// @return timestamp Unix timestamp, in seconds.
   448	    function endTime() external view returns (uint64 timestamp);
   449	
   450	    /// @notice Returns the lifetime global number of entries sold.
   451	    /// @return entries Sold-entry count; also the last assigned global entry number.
   452	    function totalEntries() external view returns (uint128 entries);
   453	
   454	    /// @notice Returns the lifetime number of range tickets minted.
   455	    /// @return tickets Ticket count; also the latest assigned ticket ID.
   456	    function ticketCount() external view returns (uint128 tickets);
   457	
   458	    /// @notice Returns the current unallocated sale pot.
   459	    /// @return amount Raw six-decimal quote-token units collected before settlement or refund activation.
   460	    function unsettledPot() external view returns (uint256 amount);
   461	
   462	    /// @notice Returns the current aggregate full-refund liability.
   463	    /// @return amount Raw six-decimal quote-token units still claimable by unrefunded tickets.
   464	    function remainingRefundLiability() external view returns (uint256 amount);
   465	
   466	    /// @notice Returns the address that burned and redeemed the winning ticket.
   467	    /// @return recipient Winner at redemption time, or the zero address before redemption.
   468	    function winnerRecipient() external view returns (address recipient);
   469	
   470	    /// @notice Returns the current cash-winner liability.
   471	    /// @return amount Raw six-decimal quote-token units claimable by the winning ticket, or zero otherwise.
   472	    function winnerProceeds() external view returns (uint256 amount);
   473	
   474	    /// @notice Returns the current sponsor liability.
   475	    /// @return amount Raw six-decimal quote-token units claimable by the immutable sponsor recipient.
   476	    function sponsorProceeds() external view returns (uint256 amount);
   477	
   478	    /// @notice Returns the current protocol-fee liability.
   479	    /// @return amount Raw six-decimal quote-token units claimable by the immutable treasury.
   480	    function protocolFees() external view returns (uint256 amount);
   481	
   482	    /// @notice Returns the accepted Chainlink request ID.
   483	    /// @return requestId Wrapper-assigned ID, or zero before request persistence.
   484	    function vrfRequestId() external view returns (uint256 requestId);
   485	
   486	    /// @notice Returns when the accepted draw request was recorded.
   487	    /// @return timestamp Unix timestamp, in seconds, or zero before request persistence.
   488	    function drawRequestedAt() external view returns (uint64 timestamp);
   489	
   490	    /// @notice Returns when an authenticated callback resolved the raffle.
   491	    /// @return timestamp Unix timestamp, in seconds, or zero before resolution.
   492	    function resolvedAt() external view returns (uint64 timestamp);
   493	
   494	    /// @notice Returns the selected one-based global winning entry.
   495	    /// @return entry Entry in `[1,totalEntries]`, or zero before resolution.
   496	    function winningEntry() external view returns (uint128 entry);
   497	
   498	    /// @notice Returns the ticket proven to contain the winning entry.
   499	    /// @return ticketId Sequential ticket ID, or zero before settlement.
   500	    function winningTicketId() external view returns (uint256 ticketId);
   501	
   502	    /// @notice Returns the current lifecycle and economic result.
   503	    /// @return currentStatus Current `Status` value.
   504	    function status() external view returns (Status currentStatus);
   505	
   506	    /// @notice Returns whether terminal winner, sponsor, and protocol liabilities have been allocated.
   507	    /// @return complete True after winning-ticket settlement.
   508	    function settlementComplete() external view returns (bool complete);
   509	
   510	    /// @notice Returns whether the winning ticket has been burned and its NFT or cash prize delivered.
   511	    /// @return redeemed True after successful winner redemption.
   512	    function winnerRedeemed() external view returns (bool redeemed);
   513	
   514	    /// @notice Returns whether the prize has been delivered to the winner or returned to the sponsor recipient.
   515	    /// @return claimed True after successful prize release.
   516	    function prizeClaimed() external view returns (bool claimed);
   517	
   518	    /// @notice Returns whether this implementation or clone has completed its one-time initialization step.
   519	    /// @return complete True for the locked implementation and every initialized clone.
   520	    function initialized() external view returns (bool complete);
   521	}
```

### packages/contracts/src/interfaces/IRaffleFactory.sol

```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity 0.8.36;
     3	
     4	/// @title raffle.fun Raffle Factory Interface
     5	/// @author heesho
     6	/// @notice Defines atomic ERC-1167 raffle creation for one immutable USDC, treasury, and Chainlink configuration.
     7	/// @dev The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration. Deployment tooling must
     8	///      verify that the immutable quote-token address is the target chain's official USDC; onchain construction checks
     9	///      only code presence and six-decimal metadata.
    10	/// @custom:version 1.0.0
    11	interface IRaffleFactory {
    12	    // Types
    13	
    14	    /// @notice Sponsor-selected configuration for one new raffle.
    15	    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    16	    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    17	    /// @param prizeTokenId Token ID to escrow atomically during creation.
    18	    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    19	    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    20	    struct CreateRaffleParams {
    21	        address sponsorRecipient;
    22	        address prizeToken;
    23	        uint256 prizeTokenId;
    24	        uint128 reserveEntries;
    25	        uint64 endTime;
    26	    }
    27	
    28	    // Events
    29	
    30	    /// @notice Emitted after a raffle clone is initialized, registered, funded, and active.
    31	    /// @param raffleId One-based canonical raffle identifier.
    32	    /// @param raffle Newly created fixed-target ERC-1167 clone.
    33	    /// @param sponsor Prize depositor and pre-end empty-raffle refund authority.
    34	    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    35	    /// @param prizeToken ERC-721 contract of the escrowed prize.
    36	    /// @param prizeTokenId Token ID of the escrowed prize.
    37	    /// @param quoteToken Immutable canonical six-decimal USDC contract used by the raffle.
    38	    /// @param protocolTreasury Immutable recipient of protocol fees.
    39	    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    40	    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    41	    event RaffleCreated(
    42	        uint256 indexed raffleId,
    43	        address indexed raffle,
    44	        address indexed sponsor,
    45	        address sponsorRecipient,
    46	        address prizeToken,
    47	        uint256 prizeTokenId,
    48	        address quoteToken,
    49	        address protocolTreasury,
    50	        uint128 reserveEntries,
    51	        uint64 endTime
    52	    );
    53	
    54	    // Errors
    55	
    56	    /// @notice Raised when a required address is the zero address.
    57	    error ZeroAddress();
    58	
    59	    /// @notice Raised when an address required to contain deployed code is not a contract.
    60	    /// @param account Address whose code length was zero.
    61	    error NotContract(address account);
    62	
    63	    /// @notice Raised when the quote token cannot report its decimal precision.
    64	    /// @param quoteToken Rejected quote-token contract.
    65	    error UnsupportedQuoteToken(address quoteToken);
    66	
    67	    /// @notice Raised when the quote token does not use the required six-decimal precision.
    68	    /// @param actualDecimals Decimal precision reported by the quote token.
    69	    /// @param requiredDecimals Required decimal precision, exactly six.
    70	    error InvalidQuoteTokenDecimals(uint8 actualDecimals, uint8 requiredDecimals);
    71	
    72	    /// @notice Raised when the prize contract does not report ERC-721 interface support.
    73	    /// @param prizeToken Rejected prize-token contract.
    74	    error UnsupportedPrizeToken(address prizeToken);
    75	
    76	    /// @notice Raised when a raffle is configured with a zero reserve entry threshold.
    77	    error ZeroReserveEntries();
    78	
    79	    /// @notice Raised when the sale end is not strictly after the creation block timestamp.
    80	    /// @param currentTime Current block Unix timestamp, in seconds.
    81	    /// @param endTime Supplied exclusive sale-end Unix timestamp, in seconds.
    82	    error InvalidEndTime(uint256 currentTime, uint256 endTime);
    83	
    84	    /// @notice Raised when the prospective sale duration exceeds the fixed 30-day limit.
    85	    /// @param duration Prospective sale duration in seconds.
    86	    /// @param maximumDuration Maximum permitted sale duration in seconds.
    87	    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);
    88	
    89	    /// @notice Raised when a configured token or recipient is known protocol plumbing.
    90	    /// @param destination Rejected address.
    91	    error UnsafeProtocolDestination(address destination);
    92	
    93	    /// @notice Raised when the exact configured prize is not owned by an active clone after escrow.
    94	    /// @param raffle Newly created clone expected to hold the prize and report `Active`.
    95	    /// @param prizeToken ERC-721 prize contract.
    96	    /// @param prizeTokenId Configured prize token ID.
    97	    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);
    98	
    99	    // External state-changing functions
   100	
   101	    /// @notice Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.
   102	    /// @param params Sponsor-selected recipient, prize, reserve, and timing configuration.
   103	    /// @return raffle Address of the newly created and activated clone.
   104	    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);
   105	
   106	    // Public generated getters
   107	
   108	    /// @notice Returns the immutable canonical six-decimal USDC contract used by every raffle.
   109	    /// @return quoteTokenAddress Canonical USDC contract address trusted by this deployment.
   110	    function quoteToken() external view returns (address quoteTokenAddress);
   111	
   112	    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.
   113	    /// @return wrapperAddress Wrapper contract address.
   114	    function vrfWrapper() external view returns (address wrapperAddress);
   115	
   116	    /// @notice Returns the immutable recipient of protocol fees from every raffle.
   117	    /// @return treasuryAddress Protocol treasury address.
   118	    function protocolTreasury() external view returns (address treasuryAddress);
   119	
   120	    /// @notice Returns the fixed Chainlink callback execution limit used by every raffle.
   121	    /// @return gasLimit Callback gas units requested from the wrapper.
   122	    function callbackGasLimit() external view returns (uint32 gasLimit);
   123	
   124	    /// @notice Returns the fixed Chainlink confirmation count used by every raffle.
   125	    /// @return confirmations Blocks requested before callback fulfillment.
   126	    function requestConfirmations() external view returns (uint16 confirmations);
   127	
   128	    /// @notice Returns the immutable implementation targeted by every registered ERC-1167 clone.
   129	    /// @return implementation Locked raffle implementation address.
   130	    function raffleImplementation() external view returns (address implementation);
   131	
   132	    /// @notice Returns the lifetime number of successfully created raffles.
   133	    /// @return count Latest one-based raffle identifier and total registered raffle count.
   134	    function raffleCount() external view returns (uint256 count);
   135	
   136	    /// @notice Returns whether an address is a raffle registered by this factory.
   137	    /// @param raffle Address to check.
   138	    /// @return registered True only for a successfully created canonical clone.
   139	    function isRaffle(address raffle) external view returns (bool registered);
   140	
   141	    /// @notice Returns the canonical raffle address for an identifier.
   142	    /// @param raffleId One-based raffle identifier.
   143	    /// @return raffle Registered clone address, or the zero address for an unknown identifier.
   144	    function raffleById(uint256 raffleId) external view returns (address raffle);
   145	
   146	    /// @notice Returns the canonical identifier assigned to a raffle address.
   147	    /// @param raffle Address to query.
   148	    /// @return raffleId One-based identifier, or zero for an unregistered address.
   149	    function idByRaffle(address raffle) external view returns (uint256 raffleId);
   150	}
```

### packages/contracts/src/libraries/RaffleConstants.sol

```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity 0.8.36;
     3	
     4	/// @title raffle.fun Protocol Constants
     5	/// @author heesho
     6	/// @notice Defines the fixed v1 economics, timing, and bounded-execution limits shared by the factory and raffles.
     7	/// @dev Quote-token amounts use raw six-decimal units. Basis-point calculations round down through `Math.mulDiv`, and
     8	///      the sponsor receives the remaining raw units after winner and protocol allocations.
     9	/// @custom:version 1.0.0
    10	library RaffleConstants {
    11	    /// @notice Denominator used for every global protocol basis-point rate.
    12	    uint256 internal constant BPS = 10_000;
    13	
    14	    /// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
    15	    uint256 internal constant PROTOCOL_FEE_BPS = 500;
    16	
    17	    /// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
    18	    uint256 internal constant CASH_WINNER_BPS = 8000;
    19	
    20	    /// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
    21	    uint256 internal constant ENTRY_PRICE = 1_000_000;
    22	
    23	    /// @notice Decimal precision required from the immutable quote token.
    24	    uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;
    25	
    26	    /// @notice Refund execution is bounded by tickets, while each ticket may represent any uint128 entry count.
    27	    uint256 internal constant MAX_REFUND_TICKET_BATCH_SIZE = 100;
    28	
    29	    /// @notice Maximum prospective raffle sale duration, measured from creation to the exclusive sale end.
    30	    uint256 internal constant MAX_SALE_DURATION = 30 days;
    31	
    32	    /// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
    33	    uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;
    34	
    35	    /// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
    36	    uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;
    37	
    38	    /// @notice Gas-unit limit requested for the single-word Chainlink callback.
    39	    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 300_000;
    40	
    41	    /// @notice Block confirmations requested from Chainlink before callback fulfillment.
    42	    uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 30;
    43	}
```

# Money Map — raffle.fun (`Raffle` ERC-1167 clone + `RaffleFactory`)

Scope: `Raffle.sol` (614 lines), `RaffleFactory.sol` (186), `IRaffle.sol` (521), `IRaffleFactory.sol` (150), `RaffleConstants.sol` (43). Spec: repo-root `DESIGN.md` (included at the top of `source.md`).

**Empty sections, stated up front:** there are NO shares or exchange rates, NO interest/index accrual, NO price oracles, NO liquidations, NO cross-chain messaging, NO owner/admin/pause/upgrade. The accounting is five USDC liability buckets plus one escrowed NFT per clone. Lenses whose home turf is absent (share-rate, liquidation, cross-chain) should map their lens onto the nearest analogue — the VRF request→callback is the only async two-step flow; the reserve threshold is the only outcome switch; the refund path is the only "withdraw" queue — and report nothing rather than force a finding.

## Plain-English model
- A sponsor (the `msg.sender` of `RaffleFactory::createRaffle`) escrows exactly one ERC-721 prize into a fresh clone. Buyers pay 1 USDC (1_000_000 raw units) per entry; each purchase mints ONE transferable ticket NFT covering a contiguous inclusive entry range `[firstEntry,lastEntry]`.
- After `endTime`, anyone may pay Chainlink VRF (in native ETH) to draw one entry. Reserve met (`totalEntries >= reserveEntries`) → `NftWon`: winner gets the NFT; 95% sponsorRecipient / 5% treasury. Reserve missed → `CashWon`: winner gets 80% of gross, sponsor 15% (remainder), treasury 5%, NFT goes back to sponsorRecipient.
- If nobody requests a draw within 2 days of `endTime`, or the callback misses its 2-day window, anyone flips the raffle to `Refunding`: each ticket burns for 100% of its entries and the NFT goes back to sponsorRecipient. An empty raffle can be closed by the sponsor any time, by anyone after `endTime`.
- Nobody earns yield. The only parties who can absorb a loss are: buyers (expected 20% haircut in `CashWon` vs. a refund), the draw requester (pays the VRF fee, never reimbursed), secondary-market counterparties of tickets, and whoever holds a claim that can never be collected (no sweep, no expiry, no admin).

## 1. Assets
| Asset | In | Out |
| --- | --- | --- |
| USDC `quoteToken` (trusted canonical; blacklistable/pausable) | `buyEntries` L224 `safeTransferFrom(msg.sender)`, gross = `entryCount * 1e6` | `redeemWinningTicket` L342 (CashWon → ticket owner), `refundTickets` L369 (→ caller = owner), `releaseSponsorProceeds` L380 (→ `sponsorRecipient`), `releaseProtocolFees` L390 (→ `protocolTreasury`). All via `_transferQuote` (destination-screened) |
| Prize ERC-721 (untrusted contract) | `RaffleFactory::createRaffle` L128 `prize.safeTransferFrom(sponsor, clone)` → `Raffle::onERC721Received` (status → Active) | `redeemWinningTicket` L334 (NftWon → ticket owner; `transferFrom` + `ownerOf` check), `releaseSponsorPrize` L404 (CashWon/Refunding → `sponsorRecipient`; `transferFrom` + `ownerOf` check). NOT destination-screened at release time |
| Native ETH | `requestDraw` `msg.value` | `paidPrice` → VRF wrapper (inside `requestRandomnessPayInNative`); `excess` → `msg.sender` via raw `call(gas())` L267. `receive()` reverts; force-sent ETH has no exit |
| Ticket ERC-721 (this clone's own collection) | minted in `buyEntries` (`_safeMint` → recipient callback) | burned in `refundTickets`, `redeemWinningTicket`. Transferable in EVERY status (DESIGN). `_update` screens `to` via `_isProtocolDestination` |
| Unsolicited USDC / NFTs / ETH | donations | none ("cannot be rescued"); never read by accounting — there is no `balanceOf(this)` anywhere |

## 2. Tracked totals (every writer)
| Variable | + / set | − / clear |
| --- | --- | --- |
| `unsettledPot` | `buyEntries` L233 `+= grossAmount` | `enableRefunds` L297 `= 0` (moved to refund bucket); `_settleWinningTicket` L553 `= 0` (split three ways) |
| `remainingRefundLiability` | `enableRefunds` L298 `= unsettledPot` | `refundTickets` L368 `-= entries * ENTRY_PRICE` |
| `winnerProceeds` | `_settleWinningTicket` L548 `= cashAmount` (CashWon only) | `redeemWinningTicket` L341 `= 0` (CashWon) |
| `sponsorProceeds` | `_settleWinningTicket` L554 `= grossPot - fee [- cash]` | `releaseSponsorProceeds` L378 `= 0` |
| `protocolFees` | `_settleWinningTicket` L555 `= floor(gross * 500 / 10000)` | `releaseProtocolFees` L388 `= 0` |
| `totalEntries` (lifetime; never decremented, not even on refund) | `buyEntries` L230 | — |
| `ticketCount` | `buyEntries` L231 | — |
| `_ticketRanges[id]` (historical, survives burn) | `buyEntries` L232 | — |
| `prizeClaimed` | `redeemWinningTicket` L331 (NftWon); `releaseSponsorPrize` L403 | — |
| `winnerRedeemed`, `winnerRecipient` | `redeemWinningTicket` L323-324 | — |
| `settlementComplete`, `winningTicketId` | `_settleWinningTicket` L551-552 | — |
| `status` | impl ctor → Refunding; `initialize` → AwaitingPrize; `onERC721Received` → Active; `requestDraw` → Drawing; `fulfillRandomWords` → NftWon/CashWon; `enableRefunds` → Refunding | — |
| `drawRequestedAt`, `vrfRequestId`, `_requestInFlight` | `requestDraw` L253-260 | — |
| `winningEntry`, `resolvedAt` | `fulfillRandomWords` L519-520 | — |
| Factory `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle` | `createRaffle` L105, L123-125 | — |

`accountedQuoteBalance()` = `unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees` (view only; never used to size a payout).

## 3. Asymmetry table
Orchestrator pass found NO USDC moved-without-tracking and NO one-branch-only write: every USDC outflow zeroes or decrements exactly its own bucket, and settlement splits `grossPot` exactly (`ENTRY_PRICE = 1e6`, so 5% = 50_000/entry and 80% = 800_000/entry — no rounding remainder exists for any entry count). Lenses: VERIFY this, do not assume it. The seams below are where drift-like shapes remain:

| Seam | Where | Shape |
| --- | --- | --- |
| Destination screening applied on some exits, not others | `_transferQuote` L565 and `_update` L498 call `_isProtocolDestination`; `releaseSponsorPrize` L404 and `redeemWinningTicket` L334 (NFT) do not; ETH excess L267 does not | screened in one branch only (DESIGN: "Never move assets between raffle clones") |
| Screening is a point-in-time check against a growing registry | `_isProtocolDestination` L602 skips `isRaffle` for code-less addresses; clones come from `Clones.clone` (CREATE → address predictable from factory nonce); `sponsorRecipient` validated only at `initialize`/factory | check-at-init vs. state-at-payout |
| Prize custody is "verified" only by the prize contract's own answers | factory L128-134 (`ownerOf`, clone `status`); raffle L335 / L405 (`ownerOf`); `onERC721Received` L421-424 trusts caller-supplied `operator`/`from` arguments | untrusted input faithfully propagated |
| Ticket transferability across `Drawing` → resolution | `fulfillRandomWords` result is computable from the pending fulfillment tx; tickets transferable in every status | mistimed snapshot / ordering |
| Draw initiation cost borne by one volunteer | `requestDraw` caller pays VRF in ETH, unreimbursed; draw vs. refund preference differs by cohort (holders prefer refund when reserve missed; sponsor/treasury prefer draw) | cohort incentive asymmetry |
| Refund/redeem require `msg.sender == ownerOf` (approved operators excluded) | L321, L360 | integration assumption |

## 4. Invariants
- I1 `quoteToken.balanceOf(clone) >= accountedQuoteBalance()` at all times (solvency; DESIGN "remainder must be allocated without loss").
- I2 Pre-terminal (Active / Drawing / NftWon / CashWon before settlement): `unsettledPot == totalEntries * ENTRY_PRICE`.
- I3 Refunding: `remainingRefundLiability == Σ_{unburned tickets} (lastEntry - firstEntry + 1) * ENTRY_PRICE`; the last refunder is paid in full and the bucket reaches exactly 0.
- I4 Settlement: `cash + sponsor + fee == grossPot`; fee = floor(5%); cash = floor(80%) in CashWon, 0 in NftWon; sponsor = remainder.
- I5 The prize NFT leaves exactly once, to exactly one party: NftWon → winning-ticket owner; CashWon/Refunding → `sponsorRecipient`.
- I6 Refund branch and win branch are mutually exclusive per clone.
- I7 Ticket ranges partition `[1, totalEntries]`; exactly one ticket contains `winningEntry ∈ [1, totalEntries]`.
- I8 Status is monotone: AwaitingPrize → Active → (Drawing → (NftWon | CashWon | Refunding)) | Refunding. No back-edges, no second request, no re-roll.
- I9 Time windows (DESIGN): buy `< endTime`; request `[endTime, endTime + 2d)`; callback `< drawRequestedAt + 2d`; refunds open exactly at the applicable deadline; empty raffle: sponsor any time, anyone `>= endTime`.
- I10 Only VRF determines the winner: no actor can choose, preview-and-react, censor-and-retry, or bias the drawn entry.
- I11 Claims are independent: sponsor, treasury, winner, and each refunder can each collect regardless of the others (blacklist, malicious receiver, malicious prize).
- I12 Assets never move between raffle clones; the factory never holds assets.
- I13 Redemption: only the current ticket owner; burn is atomic with delivery; any delivery failure reverts everything.
- I14 Each clone is initialized once, only by the factory, and becomes Active only by receiving its exact configured prize from the sponsor via the factory.

## 5. Lifecycles (state touched per step)
- L1 Create: factory `_validateCreateParams` → `++raffleCount` → `Clones.clone` → `initialize` (sponsor, sponsorRecipient, treasury, prizeToken/Id, raffleId, reserveEntries, endTime; status = AwaitingPrize) → register `raffleById` / `idByRaffle` / `isRaffle` → `prize.safeTransferFrom(sponsor, clone)` → `onERC721Received` (status = Active) → factory checks `ownerOf` and clone `status`.
- L2 Buy: `buyEntries` (USDC in; `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`; `_safeMint` → recipient callback).
- L3 Draw: `requestDraw` (status = Drawing, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId`; ETH to wrapper, excess to caller) → wrapper `rawFulfillRandomWords` → `fulfillRandomWords` (`winningEntry`, `resolvedAt`, status = NftWon | CashWon) or ignored (emit only; the wrapper has already consumed the request — no retry).
- L4 NftWon: `settleWinningTicket` (anyone; `unsettledPot` → `sponsorProceeds`, `protocolFees`; `settlementComplete`, `winningTicketId`) → `redeemWinningTicket` (owner; `winnerRecipient`, `winnerRedeemed`, burn, `prizeClaimed`, NFT out); `releaseSponsorProceeds`, `releaseProtocolFees` (anyone, independent).
- L5 CashWon: settle (also `winnerProceeds`) → redeem (USDC out); `releaseSponsorPrize` (NFT → sponsorRecipient); releases.
- L6 Refund: `enableRefunds` (`unsettledPot` → `remainingRefundLiability`, status = Refunding) → `refundTickets` batches of ≤100 (burn, USDC out); `releaseSponsorPrize`.
- L7 Empty raffle: sponsor `enableRefunds` any time (anyone at `>= endTime`) → `releaseSponsorPrize`.
- L8 Secondary market: ticket `transferFrom` / `safeTransferFrom` in any status (no status guard; only `_update` screening).

## 6. Cohorts and what each is owed
| Actor | Gives | Owed / powers |
| --- | --- | --- |
| Sponsor (creator) | prize NFT, gas | via `sponsorRecipient`: 95% gross (NftWon) / 15% + NFT (CashWon) / NFT (Refunding, empty). Power: close an empty raffle early |
| `sponsorRecipient` (fixed per clone) | — | sponsor's USDC and the returned NFT |
| `protocolTreasury` (immutable in factory, shared by every clone) | — | 5% gross in NftWon/CashWon; 0 on refund |
| Buyer / ticket holder (bearer) | 1 USDC per entry | 100% back on refund; otherwise a chance at the NFT or 80% of the pot |
| Winner (owner of the winning ticket at redemption) | burns the ticket | NFT (NftWon) or 80% gross (CashWon) |
| Draw requester (anyone) | VRF fee in ETH | excess ETH back; nothing else |
| Settler / releaser / refund-enabler (anyone) | gas | nothing |
| Secondary-market counterparties | price paid for a ticket | the claim the ticket represented when they traded |
| Untrusted: prize contract, ticket-recipient contracts, ETH-refund recipient | — | — |
| Trusted: USDC, Chainlink VRF v2.5 wrapper/coordinator | — | — |

## 7. External calls and reentrancy surface
- `nonReentrant`: `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`; factory `createRaffle`. (OZ 5.6.1 guard uses an ERC-7201 slot; clone starts at 0 ≠ ENTERED, so it works without a constructor.)
- Unguarded: ticket `transferFrom` / `safeTransferFrom` / `approve` / `setApprovalForAll`, `onERC721Received`, `rawFulfillRandomWords` (wrapper-only), inherited `getBalance` / `getLinkToken`, views.
- Untrusted callouts: prize `transferFrom` / `ownerOf` / `safeTransferFrom` / `supportsInterface`; recipient `onERC721Received` (`_safeMint`, ticket `safeTransferFrom`); requester ETH `call(gas())` (after `vrfRequestId` is set, before the event). Factory views `raffleImplementation()` / `isRaffle()` are called from every `_update` and `_transferQuote`.
- Constants: ENTRY_PRICE 1e6; fee 500 bps; cash 8000 bps; refund batch ≤ 100 tickets; sale ≤ 30 d; request window 2 d; callback window 2 d; callback gas 300k; 30 confirmations.
- Dependency sources present under `packages/contracts/node_modules/` (OZ 5.6.1, Chainlink 1.5.0 `VRFV2PlusWrapperConsumerBase`, `IVRFV2PlusWrapper`). The wrapper implementation itself is not vendored — reason from the trusted canonical VRF v2.5 wrapper.
# The 0xSimao Method

Derived from 869 published findings across 143 reviews. This is HOW to think. Your lens file is WHAT to look for. Work them together.

## The core thesis

Most auditors read code looking for bad lines. That finds the bugs a linter finds.

0xSimao reads code looking for **a claim that has drifted from what actually backs it**. Value moves through a protocol in sequences: deposit, accrue, borrow, liquidate, withdraw. Each step writes some subset of the accounting state, and drift is any way that state stops describing reality:

| Drift | Shape |
| --- | --- |
| The write is missing | value moved and no variable recorded it — or one branch updates it and the sibling branch does not |
| The write is wrong | the variable is updated with the wrong amount, direction, rounding, units, or decimals |
| The write is mistimed | the right value at the wrong moment, so someone's snapshot is taken against state that is about to change |
| The write goes to the wrong party | the total is intact; the split between cohorts is not |
| The input was never trustworthy | the number is faithfully propagated from an oracle, a live balance, or a caller-supplied parameter an attacker controls |
| The state is unreachable | the accounting is correct but a revert, a pause, an unbounded loop, or a missing path means it can never be settled |

The drift is invisible at any single line. It only appears when you ask: *after this whole sequence, does the protocol still owe exactly what it holds — and can everyone actually collect it?*

A defect nobody can be shown to lose money from is a curiosity. So every candidate gets one more question, and it is the one that separates a finding from a smell:

> **Who is left holding the loss?**

Answer with a named class of actor, never "users". For accounting drift it is often whoever withdraws last, because a shortfall stays invisible until the balance runs out — but for a bricked liquidation it is the solvent lenders eating the bad debt, for a mistimed snapshot it is the cohort that held through the accrual, and for a forged signature it is whoever the forged message was drawn against. If the only person worse off is the caller, there is no finding.

**This lens is the sharpest one, not the only one.** Accounting drift is the largest single class in his corpus, but it is not the majority of it. The rest is DoS and permanently stuck funds, access control and signature defects, token- and integration-behaviour assumptions (`USDT` approvals, fee-on-transfer, blacklists, pausable collateral), oracle and parameter validation, and cross-chain state — and those are what your lens file owns. Work the money map first because it is what makes the drift class visible; then work your lens on its own terms. When the target has little accounting to speak of — a router, a registry, a verifier, a signature scheme — say so, keep the money map short, and go straight to your lens. Do not force a finding into the drift frame to make it sound like his.

## Phase 0 — Learn the protocol's own vocabulary before reading for bugs

His findings are written in the protocol's language: `cdsPoolValue`, `abond`, `downsideProtected`, `unassignedEarnings`, `raBalance`, `floatingBackupBorrowed`. He does not audit "a vault"; he audits *this* vault's specific accounting model.

Before hunting, be able to state in plain English:
- What does a user give, and what claim do they receive in return?
- What is that claim worth, and which variables determine the value?
- Where does yield come from, and who is entitled to it?
- What happens when the protocol is short — who absorbs the shortfall?

If you cannot answer these without Solidity jargon, you are not ready to find his class of bug. Any spot where your plain-English explanation goes fuzzy is exactly where the bug is; mark it and come back.

## Phase 1 — Build the money map

For every storage variable that claims to be an aggregate — `total*`, `*Supply`, `*Balance`, `*Deposited`, `*Locked`, `*Reserve`, `*Debt`, `*Accrued`, indices, cumulative rates — enumerate **every** function that writes it and whether that write increases or decreases it.

Then build the asymmetry table. Three columns of pure gold:

| Asymmetry | What to look for | Real finding |
| --- | --- | --- |
| Moved without tracking | value transferred out with no matching decrement | *"Users redeeming early will withdraw `Ra` without decreasing the amount locked, which will lead to stolen funds when withdrawing after expiry"* |
| Tracked in one branch only | `if` updates the total, `else` does not | *"Users will steal excess funds from the Vault due to `VaultPoolLib::redeem()` not always decreasing `raBalance` and `paBalance`"* |
| Never tracked at all | a balance is real but no variable represents it | *"Total `ETH`, `WETH` and `gameETH` are not tracked which will lead to insolvency"* |

Also flag every place a **live balance read** (`token.balanceOf(address(this))`, `address(this).balance`) is used as an accounting source. That is a donation attack or a cross-user theft waiting to happen — *"`ManagedLeveragedVault::openDen()` using all `asset()` balance"*, *"SDAIPriceFeed is vulnerable to donation attack via manipulatable vault rate"*.

## Phase 2 — Write the invariants down

5–15 statements that must always hold. Concretely, not vaguely:

- `Σ(all user withdrawable) <= actual token balance` — the solvency invariant, his single most productive one
- `totalX == Σ userX` for every aggregate with a per-user counterpart
- every credited unit is debited exactly once, in exactly one place
- monotonic things (indices, cumulative rates, timestamps) never go backwards and cannot be advanced for free
- a user's claim cannot increase from an action that costs them nothing
- state on chain A and chain B agree after every message settles

An invariant you can state and then break with a sequence is a finding. An invariant the docs assert and the code does not enforce is his highest-yield source of all.

## Phase 3 — Run the lifecycles, not the functions

Do not audit function by function. Audit *sequences*, and after each step write down which accounting variables changed and which should have.

Canonical sequences to run:

1. deposit → accrue yield → withdraw
2. deposit → borrow → price moves → liquidate → withdraw
3. stake → rewards distributed → unstake → claim
4. deposit → withdraw → deposit again (re-entry into the same accounting slot — *"Borrower deposit, withdraw, deposit will reinit `omniChainData.cdsPoolValue`"*)
5. open → adjust position → close (does the adjust path keep every invariant the open path established? — *"The health of a `ProtectedListing` is incorrectly calculated if `tokenTaken` has been changed through `adjustPosition()`"*)
6. source chain send → destination chain receive → failure/retry
7. the same sequence at expiry / after maturity / after the vault has ended

For each, ask at every step: **what did we just change that something else still assumes the old value of?**

## Phase 4 — Attack across cohorts and across time

This is the most distinctive part of his method, and the least commonly imitated.

Value in DeFi is split pro-rata among a changing set of holders. Any calculation that uses a *current* total to distribute a *historically accumulated* amount lets someone join late and take a share of value they did not earn.

Three questions, applied to every distribution, reward, fee, yield, and profit path:

1. **Can I join immediately before a distribution and take a share of it?**
   *"Immediately start getting rewards belonging to others after staking"*, *"Late abond holders steal USDa amount from liquidations from earlier abond holders"*, *"increaseNetworkTotal() allows big arbitrage opportunities by depositing before an increase transaction"*
2. **Can I leave immediately before a loss and push it onto whoever stays?**
   *"Borrower withdrawing at a loss will cause losses for cds depositors that only withdraw after the price recovers"*
3. **The Last User Out test.** Have every user withdraw, in sequence, in the worst order. Does the last one get paid? If the protocol is short by even dust, the money map has a leak upstream — go find it.
   *"`totalEarnings` is incorrect when withdrawing after ending which will withdraw too many funds leaving the `Vault` insolvent"*

Cumulative-rate and index-based accounting deserves special hostility: check whether the index can be advanced without cost (*"Malicious user can call `calculateCumulativeRate()` any number of times to inflate debt rate as `lastEventTime` is not updated"*), and whether a user's snapshot is taken at the right moment (*"Depositing to another receiver other than `msg.sender` will lead to stuck funds by increasing `avgStart` without claiming"*).

## Phase 5 — Saturate the subsystem

When you find one bug, **do not move on**. His reports cluster: 38 findings in one protocol, most in a single accounting subsystem. That is not luck. Once the accounting model is in your head, mine it out.

After every finding:
1. Search the codebase for every other site with the same code shape — by function name *and* by pattern. If `redeem()` forgets a decrement, check `withdraw()`, `emergencyWithdraw()`, `redeemExpired()`, and the cross-chain variant.
2. Attack the other branches of the function where you found it.
3. Escalate: a DoS often conceals fund theft; a rounding error often compounds into drain. Push each finding to its worst exploitable variant before writing it up.

A repeat instance you missed is an audit failure, not an omission.

## Phase 6 — Prove it, with preconditions stated honestly

His writeups make the reader's job trivial by separating what the protocol must look like from what the world must look like:

- **Internal pre-conditions** — protocol state required (a maturity exists, a position is near liquidation, deposits are non-zero). "None" is common and is the strongest possible case.
- **External pre-conditions** — market/oracle/chain conditions required (price moves X%, sequencer down, gas above Y). "None" is again the strongest case.
- **Attack path** — numbered, concrete, with actors and numbers. Not "an attacker could manipulate the rate" but "1. User deposits 100e18. 2. User is liquidated via `liquidationType1()`, adding 5e18 USDa. 3. Attacker deposits via flashloan and withdraws, taking 4.9e18 of it."
- **Impact** — who loses what. Name the victim class.

If you cannot fill the attack path with real numbers, you have a LEAD. Say so. A well-described lead is worth more than a finding you inflated.

## Phase 7 — Minimal mitigation

One change, the smallest that removes the defect, stated in the protocol's own terms:

- "Add a cumulative tracking variable to handle this case."
- "Set the vesting interest to 0 when the new interest is 0."
- "Decrease `raBalance` in the early-redemption branch as well."
- "Use `mulDiv` when converting between token and share amounts."

Not "refactor the accounting system." Not "consider adding validation." Name the operation to add, remove, or reorder.

## Three habits that separate his findings from noise

**Root cause is a missing operation at a named line.** Very often the bug is not a wrong line but an absent one. Write it that way: *"In `PsmLib.sol:125`, `self.psm.balances.ra.decLocked(amount)` is not called."* Pointing at the absence is what makes the fix obvious.

**Judge what the code allows, never what the deployer intends.** "The admin wouldn't do that" is not a mitigation. But equally, "admin can rug" with no concrete mechanism is not a finding.

**Doubt the clean-looking path hardest.** The functions that read as obviously correct are the ones everyone else also skipped. When a guard looks sufficient, name three specific ways to defeat it — with addresses, values, and states, not abstractions — before you accept it.

## Do not report

Admin-only functions doing admin things. Standard, accepted DeFi tradeoffs (ordinary MEV on a swap the user chose, rounding dust with no amplification, first-depositor inflation where `MINIMUM_LIQUIDITY` or a virtual-share offset is already present). Self-harm-only bugs. "Centralization risk" with no mechanism. Gas optimizations dressed as vulnerabilities. Missing zero-address checks on admin setters.
# Lens 5 — Cross-Chain & Asynchronous State

You own every message that crosses a trust or latency boundary: LayerZero, CCIP, Connext, native bridges, and any request/callback pair where state is written on one side and read on the other.

If the protocol is single-chain and fully synchronous, say so explicitly and spend your effort on the request/callback and escrow paths instead — the same failure modes appear wherever an action is split across two transactions.

## The shape

Two chains hold copies of a "global" state. Messages are asynchronous, can arrive out of order, can fail, and can be sent by anyone with the right payload. Any design that treats the remote write as immediate, ordered, or atomic with the local write is broken — and the resulting desync is permanent because there is no path that reconciles it.

## Attack surfaces

**Non-atomic global state.** The core LayerZero/CCIP failure: chain A updates a global aggregate and sends it to chain B, while chain B does the same. Whichever message lands last overwrites the other's update, silently destroying it.
> *Using LayerZero for synchronizing global states between two chains may lead to overwriting of global states*
> *`borrowing::liquidate()` sends the wrong liquidation index to the destination chain, overwriting liquidation information and getting collateral stuck*
> *Cds amounts to reduce from each chain are incorrect and will lead to the inability to withdraw cds in one of the chains*

**Value debited here, credited nowhere.** If the destination handler can revert — for any reason, including gas, a paused token, a blacklist, or an unset peer — the source funds are already gone. Enumerate every revert in the receive path and ask what happens to the debited amount.
> *Exercise option cross chain message in the (m)TapiocaOFT will always revert in the destination, losing debited funds in the source chain*
> *Users will lock raffle prizes on the `WinnablesPrizeManager` contract by calling `WinnablesTicketManager::propagateRaffleWinner` with wrong CCIP inputs*
> *Attacker can block LayerZero channel due to missing check of minimum gas passed*
> *Send should revert if the gas limit has not been set for a destination chain (peer)*

**Unvalidated message parameters.** The payload is attacker-controlled unless proven otherwise. Check the sender, the source chain, the peer registration, the recipient, and every amount/share field independently — a mismatch between an amount field and a shares field is a classic drain.
> *All assets of (m)TapiocaOFT can be stolen by depositing to strategy cross chain call with 1 amount but maximum shares possible*
> *TOFT in (m)TapiocaOft contracts can be stolen by calling `removeCollateral()` with a malicious `removeParams.market`*
> *`triggerSendFrom()` will send all the ETH in the destination chain to the `refundAddress` in the LzCallParams argument*
> *NFTs can be stolen by calling `send()` and receiving the nfts in another chain*

**Address assumptions across chains.** The same address is not the same entity on every chain. Smart wallets, contracts deployed with different nonces, and CREATE2 with different init code all break the "send to msg.sender on the other side" pattern.
> *Lost nfts due to smart wallets having different addresses on different chains*
> *AaveETHYieldBackend uses wrong WETH address for Polygon (returns WETH instead of WPOL)*

**Fees and gas asymmetry.** Fees quoted on the source chain rarely equal costs on the destination. Charging symmetric fees, hardcoding gas limits, or forgetting to forward `msg.value` for the message fee all fail.
> *`GlobalVariables::oftOrCollateralReceiveFromOtherChains()` calculates the fee as if it was the same in both chains, which is false*
> *`GlobalVariables::oftOrCollateralReceiveFromOtherChains()` always charges twice the collateral on `COLLATERAL_TRANSFER`, which is not needed*
> *mTapiocaOFT can't be rebalanced because the Balancer calls `swapETH()` or `swap()` of the RouterETH but does not forward ether for the message fee*
> *BlsBn254 is not available in certain chains due to hardcoded gas limit*

**Yield and collateral on the wrong chain.** When a protocol tracks positions on one chain and assets on another, verify every update lands where the asset actually is.
> *`treasury.updateYieldsFromLiquidatedLrts()` updates the yield in the current chain, but collateral may be in the other chain*

**Callbacks and retries.** Failed-message retry paths, `executeFailedWithUpdatedArgs`, and generic callback handlers are entry points with the weakest validation in the codebase. Treat them as fully permissionless until proven otherwise, and check for reentrancy into the main accounting.
> *ConnextHandler `executeFailedWithUpdatedArgs(...)` reentrancy allowedCaller can steal all ConnextHandler tokens*
> *Funds may be stolen by calling `onMoreFlashLoan()` directly*
> *In BaseRouter, the beneficiary isn't checked when starting a flashloan action and it replaces the previous beneficiary*

**Self-destruct and upgrade exposure on proxied modules.** Module contracts reached by delegatecall inherit the caller's storage and can be destroyed or reinitialized.
> *TOFT and USDO Modules Can Be Selfdestructed*

## Every finding needs the two-chain trace

State the ordering explicitly: what chain A does, what chain B does, in which order the messages land, and what the two states are afterwards. Name the value that is now unrecoverable.
# Shared Lens Rules

## Bundle contents

Your bundle is five concatenated parts: all in-scope source, the protocol's **money map** (built by the orchestrator), the **method** (how to think), your **lens** (what you own), and these shared rules (output format and protocol).

Read the whole bundle once at the start. Do not re-read in-scope files for the initial scan. Read or search the repo only for cross-file lookups or out-of-scope context (`interfaces/`, `lib/`, `mocks/`, `test/`).

**Start from the money map, not the file list.** Pick the tracked totals, lifecycles, and cohorts your lens owns, and attack those. The file list is where you go to confirm, not where you begin.

When matching function names, check both `functionName` and `_functionName` (Solidity convention), and check library variants (`XLib::function`).

## Mandatory reasoning protocol

Four markers. Each has a trigger. When the trigger fires you MUST emit the marker before continuing. Markers live in your working text — they do NOT go inside FINDING/LEAD blocks.

| Trigger | Marker | Content |
| --- | --- | --- |
| You open a function that moves value or writes a tracked total | `[Model: <name>]` | Explain in plain English what a user gives, what they get, and which totals change. No Solidity jargon — no `safeTransfer`, `mload`, `shares`, `wad`. Where you have to reach for a Solidity term to stay accurate, mark that spot: that is where the bug is. |
| You stop on a line whose purpose is not immediately obvious | `[Why: <file:line>]` | One question that drills past "because that is how it is written." If your answer restates the code, ask again. Stop when the answer exposes the implicit belief the code rests on. |
| A path reads as clean, or a guard looks sufficient | `[Defeat: <function>]` | Three concrete attacker moves against it. Specific addresses, values, and states — never abstractions. |
| You finish a lifecycle from the money map | `[LastOut: <lifecycle>]` | Walk every user withdrawing in the worst order. State explicitly whether the last one gets paid in full, and if not, by how much the protocol is short. |

Heavy use of these is what produces the audit. Skipping them yields surface-level scanning, which is the failure mode of every junior auditor. The orchestrator checks marker counts.

## Saturation is mandatory

When you find a bug, weaponize the pattern across the entire codebase before moving on. Search by function name AND by code shape. If one redemption path forgets a decrement, check every other redemption, withdrawal, emergency, expiry, and cross-chain variant. Then attack the other branches of the function where you found it. Then escalate the finding to its worst exploitable variant — a DoS often hides fund theft.

A repeat instance you missed is an audit failure.

## Do not report

Admin-only functions doing admin things. Accepted DeFi tradeoffs (ordinary MEV on a user-chosen swap, rounding dust with no amplification path, first-depositor inflation where a virtual-share offset or `MINIMUM_LIQUIDITY` already exists). Self-harm-only bugs. "Centralization risk" or "admin can rug" without a concrete mechanism. Missing zero-address checks on admin setters. Gas findings.

## Output

FINDINGs have a concrete, unguarded, exploitable path with a named victim. LEADs have a real accounting or logic smell with a partial path. Default to LEAD over dropping — never drop.

**One vulnerability per block.** Same root cause = one block. Needs a different fix = separate block.

```
FINDING | contract: Name | function: func | bug_class: kebab-tag | group_key: Contract | function | bug-class
root_cause: the defect at File.sol:LINE, naming the missing or wrong operation
internal_pre: protocol state required, or None
external_pre: market/oracle/chain conditions required, or None
path:
  1. actor does X with concrete amount
  2. state changes to Y
  3. actor does Z
impact: who loses what, and who is left holding the loss
mitigation: the single smallest change that removes the defect
```

```
LEAD | contract: Name | function: func | bug_class: kebab-tag | group_key: Contract | function | bug-class
smell: what you found
unverified: precisely what you could not establish
description: one sentence on the trail
```

`group_key` drives deduplication and is always `ContractName | functionName | bug_class`.

An `internal_pre` or `external_pre` of `None` is the strongest possible finding — never pad these to look thorough. State the truth.
