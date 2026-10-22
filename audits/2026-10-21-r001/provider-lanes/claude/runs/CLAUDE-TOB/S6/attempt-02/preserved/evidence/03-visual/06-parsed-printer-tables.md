# Parsed Slither printer tables for the five production files (derived from raw printer outputs)

## Raffle — function-summary (195 rows incl. inherited)

| Function | Visibility | Modifiers | Writes | External calls | CC |
|---|---|---|---|---|---|
| constructor(address) | internal | [] | ['i_linkToken', 'i_vrfV2PlusWrapper'] | [] | 1 |
| requestRandomness(uint32,uint16,uint32,bytes) | internal | [] | [] | [] | 0 |
|  |  |  |  | [] |  |
| requestRandomnessPayInNative(uint32,uint16,uint32,bytes) | internal | [] | [] | [] | 0 |
| fulfillRandomWords(uint256,uint256[]) | internal | [] | [] | [] | 2 |
| rawFulfillRandomWords(uint256,uint256[]) | external | [] | [] | [] | 2 |
| getBalance() | public | [] | [] | [] | 1 |
| getLinkToken() | public | [] | [] | [] | 1 |
| onERC721Received(address,address,uint256,bytes) | external | [] | [] | [] | 2 |
| constructor() | internal | [] | [] | [] | 1 |
| _nonReentrantBeforeView() | private | [] | [] | [] | 2 |
| _nonReentrantBefore() | private | [] | [] | [] | 1 |
| _nonReentrantAfter() | private | [] | [] | [] | 1 |
| _reentrancyGuardEntered() | internal | [] | [] | [] | 1 |
| _reentrancyGuardStorageSlot() | internal | [] | [] | [] | 1 |
| constructor(string,string) | internal | [] | ['_name', '_symbol'] | [] | 1 |
| supportsInterface(bytes4) | public | [] | [] | [] | 1 |
|  |  |  |  | [] |  |
| balanceOf(address) | public | [] | [] | [] | 2 |
| ownerOf(uint256) | public | [] | [] | [] | 1 |
| name() | public | [] | [] | [] | 1 |
| symbol() | public | [] | [] | [] | 1 |
| tokenURI(uint256) | public | [] | [] | [] | 1 |
|  |  |  |  | [] |  |
| _baseURI() | internal | [] | [] | [] | 1 |
| approve(address,uint256) | public | [] | [] | [] | 1 |
| getApproved(uint256) | public | [] | [] | [] | 1 |
| setApprovalForAll(address,bool) | public | [] | [] | [] | 1 |
| isApprovedForAll(address,address) | public | [] | [] | [] | 1 |
| transferFrom(address,address,uint256) | public | [] | [] | [] | 3 |
|  |  |  |  | [] |  |
| safeTransferFrom(address,address,uint256) | public | [] | [] | [] | 1 |
| safeTransferFrom(address,address,uint256,bytes) | public | [] | [] | [] | 1 |
| _ownerOf(uint256) | internal | [] | [] | [] | 1 |
| _getApproved(uint256) | internal | [] | [] | [] | 1 |
| _isAuthorized(address,address,uint256) | internal | [] | [] | [] | 1 |
| _checkAuthorized(address,address,uint256) | internal | [] | [] | [] | 3 |
|  |  |  |  | [] |  |
| _increaseBalance(address,uint128) | internal | [] | ['_balances'] | [] | 1 |
| _update(address,uint256,address) | internal | [] | ['_balances', '_owners'] | [] | 4 |
|  |  |  |  | [] |  |
| _mint(address,uint256) | internal | [] | [] | [] | 3 |
|  |  |  |  | [] |  |
| _safeMint(address,uint256) | internal | [] | [] | [] | 1 |
| _safeMint(address,uint256,bytes) | internal | [] | [] | [] | 1 |
| _burn(uint256) | internal | [] | [] | [] | 2 |
| _transfer(address,address,uint256) | internal | [] | [] | [] | 4 |
|  |  |  |  | [] |  |
| _safeTransfer(address,address,uint256) | internal | [] | [] | [] | 1 |
| _safeTransfer(address,address,uint256,bytes) | internal | [] | [] | [] | 1 |
| _approve(address,uint256,address) | internal | [] | [] | [] | 1 |
| _approve(address,uint256,address,bool) | internal | [] | ['_tokenApprovals'] | [] | 4 |
|  |  |  |  | [] |  |
| _setApprovalForAll(address,address,bool) | internal | [] | ['_operatorApprovals'] | [] | 3 |
| _requireOwned(uint256) | internal | [] | [] | [] | 2 |
| name() | external | [] | [] | [] | 2 |
| symbol() | external | [] | [] | [] | 2 |
| tokenURI(uint256) | external | [] | [] | [] | 2 |
| balanceOf(address) | external | [] | [] | [] | 2 |
| ownerOf(uint256) | external | [] | [] | [] | 2 |
| safeTransferFrom(address,address,uint256,bytes) | external | [] | [] | [] | 2 |
| safeTransferFrom(address,address,uint256) | external | [] | [] | [] | 2 |
| transferFrom(address,address,uint256) | external | [] | [] | [] | 2 |
| approve(address,uint256) | external | [] | [] | [] | 2 |
| setApprovalForAll(address,bool) | external | [] | [] | [] | 2 |
| getApproved(uint256) | external | [] | [] | [] | 2 |
| isApprovedForAll(address,address) | external | [] | [] | [] | 2 |
| supportsInterface(bytes4) | external | [] | [] | [] | 2 |
| supportsInterface(bytes4) | public | [] | [] | [] | 1 |
| _msgSender() | internal | [] | [] | [] | 1 |
| _msgData() | internal | [] | [] | [] | 1 |
| _contextSuffixLength() | internal | [] | [] | [] | 1 |
| initialize(IRaffle.RaffleInitParams) | external | [] | [] | [] | 2 |
| buyEntries(address,uint128) | external | [] | [] | [] | 2 |
| requestDraw() | external | [] | [] | [] | 2 |
| enableRefunds() | external | [] | [] | [] | 2 |
| settleWinningTicket(uint256) | external | [] | [] | [] | 2 |
| redeemWinningTicket(uint256) | external | [] | [] | [] | 2 |
| refundTickets(uint256[]) | external | [] | [] | [] | 2 |
| releaseSponsorProceeds() | external | [] | [] | [] | 2 |
| releaseProtocolFees() | external | [] | [] | [] | 2 |
| releaseSponsorPrize() | external | [] | [] | [] | 2 |
| getVrfRequestPrice() | external | [] | [] | [] | 2 |
| estimateVrfRequestPrice(uint256) | external | [] | [] | [] | 2 |
| ticketRange(uint256) | external | [] | [] | [] | 2 |
| drawRequestDeadline() | external | [] | [] | [] | 2 |
| callbackDeadline() | external | [] | [] | [] | 2 |
| accountedQuoteBalance() | external | [] | [] | [] | 2 |
| grossSales() | external | [] | [] | [] | 2 |
| ENTRY_PRICE() | external | [] | [] | [] | 2 |
| callbackGasLimit() | external | [] | [] | [] | 2 |
| requestConfirmations() | external | [] | [] | [] | 2 |
| factory() | external | [] | [] | [] | 2 |
| sponsor() | external | [] | [] | [] | 2 |
| sponsorRecipient() | external | [] | [] | [] | 2 |
| protocolTreasury() | external | [] | [] | [] | 2 |
| quoteToken() | external | [] | [] | [] | 2 |
| vrfWrapper() | external | [] | [] | [] | 2 |
| prizeToken() | external | [] | [] | [] | 2 |
| prizeTokenId() | external | [] | [] | [] | 2 |
| raffleId() | external | [] | [] | [] | 2 |
| reserveEntries() | external | [] | [] | [] | 2 |
| endTime() | external | [] | [] | [] | 2 |
| totalEntries() | external | [] | [] | [] | 2 |
| ticketCount() | external | [] | [] | [] | 2 |
| unsettledPot() | external | [] | [] | [] | 2 |
| remainingRefundLiability() | external | [] | [] | [] | 2 |
| winnerRecipient() | external | [] | [] | [] | 2 |
| winnerProceeds() | external | [] | [] | [] | 2 |
| sponsorProceeds() | external | [] | [] | [] | 2 |
| protocolFees() | external | [] | [] | [] | 2 |
| vrfRequestId() | external | [] | [] | [] | 2 |
| drawRequestedAt() | external | [] | [] | [] | 2 |
| resolvedAt() | external | [] | [] | [] | 2 |
| winningEntry() | external | [] | [] | [] | 2 |
| winningTicketId() | external | [] | [] | [] | 2 |
| status() | external | [] | [] | [] | 2 |
| settlementComplete() | external | [] | [] | [] | 2 |
| winnerRedeemed() | external | [] | [] | [] | 2 |
| prizeClaimed() | external | [] | [] | [] | 2 |
| initialized() | external | [] | [] | [] | 2 |
| constructor(address,address) | public | [] | ['factory', 'initialized'] | [] | 2 |
|  |  |  | ['quoteToken', 'status'] | [] |  |
| receive() | external | [] | [] | [] | 1 |
| initialize(IRaffle.RaffleInitParams) | external | [] | ['endTime', 'initialized'] | [] | 7 |
|  |  |  | ['prizeToken', 'prizeTokenId'] | [] |  |
|  |  |  | ['protocolTreasury', 'raffleId'] | [] |  |
|  |  |  | ['reserveEntries', 'sponsor'] | [] |  |
|  |  |  | ['sponsorRecipient', 'status'] | [] |  |
| buyEntries(address,uint128) | external | ['nonReentrant'] | ['_ticketRanges', 'ticketCount'] | [] | 5 |
|  |  |  | ['totalEntries', 'unsettledPot'] | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| requestDraw() | external | ['nonReentrant'] | ['_requestInFlight', 'drawRequestedAt'] | [] | 8 |
|  |  |  | ['status', 'vrfRequestId'] | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| enableRefunds() | external | ['nonReentrant'] | ['remainingRefundLiability', 'status'] | [] | 7 |
|  |  |  | ['unsettledPot'] | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| settleWinningTicket(uint256) | external | ['nonReentrant'] | [] | [] | 1 |
| redeemWinningTicket(uint256) | external | ['nonReentrant'] | ['prizeClaimed', 'winnerProceeds'] | [] | 10 |
|  |  |  | ['winnerRecipient', 'winnerRedeemed'] | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| refundTickets(uint256[]) | external | ['nonReentrant'] | ['remainingRefundLiability'] | [] | 4 |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| releaseSponsorProceeds() | external | ['nonReentrant'] | ['sponsorProceeds'] | [] | 2 |
|  |  |  |  | [] |  |
| releaseProtocolFees() | external | ['nonReentrant'] | ['protocolFees'] | [] | 2 |
|  |  |  |  | [] |  |
| releaseSponsorPrize() | external | ['nonReentrant'] | ['prizeClaimed'] | [] | 4 |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| onERC721Received(address,address,uint256,bytes) | external | [] | ['status'] | [] | 2 |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| getVrfRequestPrice() | public | [] | [] | [] | 1 |
| estimateVrfRequestPrice(uint256) | public | [] | [] | [] | 1 |
| vrfWrapper() | public | [] | [] | [] | 1 |
| ticketRange(uint256) | public | [] | [] | [] | 1 |
| drawRequestDeadline() | public | [] | [] | [] | 1 |
| callbackDeadline() | public | [] | [] | [] | 2 |
| accountedQuoteBalance() | public | [] | [] | [] | 1 |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| grossSales() | public | [] | [] | [] | 1 |
| name() | public | [] | [] | [] | 1 |
| symbol() | public | [] | [] | [] | 1 |
| _update(address,uint256,address) | internal | [] | [] | [] | 2 |
|  |  |  |  | [] |  |
| fulfillRandomWords(uint256,uint256[]) | internal | [] | ['resolvedAt', 'status'] | [] | 2 |
|  |  |  | ['winningEntry'] | [] |  |
|  |  |  |  | [] |  |
| _settleWinningTicket(uint256) | private | [] | ['protocolFees', 'settlementComplete'] | [] | 4 |
|  |  |  | ['sponsorProceeds', 'unsettledPot'] | [] |  |
|  |  |  | ['winnerProceeds', 'winningTicketId'] | [] |  |
| _transferQuote(address,uint256) | private | [] | [] | [] | 2 |
| _requireStatus(IRaffle.Status) | private | [] | [] | [] | 2 |
| _requireWinningTicket(uint256) | private | [] | [] | [] | 2 |
| _isProtocolDestination(address,address) | private | [] | [] | [] | 2 |
|  |  |  |  | [] |  |
| _validatedVrfWrapper(address) | private | [] | [] | [] | 2 |
| slitherConstructorConstantVariables() | internal | [] | ['ENTRY_PRICE', 'callbackGasLimit'] | [] | 1 |
|  |  |  | ['requestConfirmations'] | [] |  |

## Raffle — vars-and-auth (144 rows incl. inherited)

| Function | State variables written | Conditions on msg.sender |
|---|---|---|
| constructor | ['i_linkToken', 'i_vrfV2PlusWrapper'] | [] |
| requestRandomness | [] | [] |
| requestRandomnessPayInNative | [] | [] |
| fulfillRandomWords | [] | [] |
| rawFulfillRandomWords | ['resolvedAt', 'status', 'winningEntry'] | ['msg.sender != vrfWrapperAddr'] |
| getBalance | [] | [] |
| getLinkToken | [] | [] |
| onERC721Received | [] | [] |
| constructor | [] | [] |
| _nonReentrantBeforeView | [] | [] |
| _nonReentrantBefore | [] | [] |
| _nonReentrantAfter | [] | [] |
| _reentrancyGuardEntered | [] | [] |
| _reentrancyGuardStorageSlot | [] | [] |
| constructor | ['_name', '_symbol'] | [] |
| supportsInterface | [] | [] |
| balanceOf | [] | [] |
| ownerOf | [] | [] |
| name | [] | [] |
| symbol | [] | [] |
| tokenURI | [] | [] |
| _baseURI | [] | [] |
| approve | ['_tokenApprovals'] | [] |
| getApproved | [] | [] |
| setApprovalForAll | ['_operatorApprovals'] | [] |
| isApprovedForAll | [] | [] |
| transferFrom | ['_balances', '_owners', '_tokenApprovals'] | [] |
| safeTransferFrom | ['_balances', '_owners', '_tokenApprovals'] | [] |
| safeTransferFrom | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _ownerOf | [] | [] |
| _getApproved | [] | [] |
| _isAuthorized | [] | [] |
| _checkAuthorized | [] | [] |
| _increaseBalance | ['_balances'] | [] |
| _update | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _mint | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _safeMint | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _safeMint | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _burn | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _transfer | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _safeTransfer | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _safeTransfer | ['_balances', '_owners', '_tokenApprovals'] | [] |
| _approve | ['_tokenApprovals'] | [] |
| _approve | ['_tokenApprovals'] | [] |
| _setApprovalForAll | ['_operatorApprovals'] | [] |
| _requireOwned | [] | [] |
| name | [] | [] |
| symbol | [] | [] |
| tokenURI | [] | [] |
| balanceOf | [] | [] |
| ownerOf | [] | [] |
| safeTransferFrom | [] | [] |
| safeTransferFrom | [] | [] |
| transferFrom | [] | [] |
| approve | [] | [] |
| setApprovalForAll | [] | [] |
| getApproved | [] | [] |
| isApprovedForAll | [] | [] |
| supportsInterface | [] | [] |
| supportsInterface | [] | [] |
| _msgSender | [] | [] |
| _msgData | [] | [] |
| _contextSuffixLength | [] | [] |
| initialize | [] | [] |
| buyEntries | [] | [] |
| requestDraw | [] | [] |
| enableRefunds | [] | [] |
| settleWinningTicket | [] | [] |
| redeemWinningTicket | [] | [] |
| refundTickets | [] | [] |
| releaseSponsorProceeds | [] | [] |
| releaseProtocolFees | [] | [] |
| releaseSponsorPrize | [] | [] |
| getVrfRequestPrice | [] | [] |
| estimateVrfRequestPrice | [] | [] |
| ticketRange | [] | [] |
| drawRequestDeadline | [] | [] |
| callbackDeadline | [] | [] |
| accountedQuoteBalance | [] | [] |
| grossSales | [] | [] |
| ENTRY_PRICE | [] | [] |
| callbackGasLimit | [] | [] |
| requestConfirmations | [] | [] |
| factory | [] | [] |
| sponsor | [] | [] |
| sponsorRecipient | [] | [] |
| protocolTreasury | [] | [] |
| quoteToken | [] | [] |
| vrfWrapper | [] | [] |
| prizeToken | [] | [] |
| prizeTokenId | [] | [] |
| raffleId | [] | [] |
| reserveEntries | [] | [] |
| endTime | [] | [] |
| totalEntries | [] | [] |
| ticketCount | [] | [] |
| unsettledPot | [] | [] |
| remainingRefundLiability | [] | [] |
| winnerRecipient | [] | [] |
| winnerProceeds | [] | [] |
| sponsorProceeds | [] | [] |
| protocolFees | [] | [] |
| vrfRequestId | [] | [] |
| drawRequestedAt | [] | [] |
| resolvedAt | [] | [] |
| winningEntry | [] | [] |
| winningTicketId | [] | [] |
| status | [] | [] |
| settlementComplete | [] | [] |
| winnerRedeemed | [] | [] |
| prizeClaimed | [] | [] |
| initialized | [] | [] |
| constructor | ['_name', '_symbol', 'factory', 'i_linkToken', 'i_vrfV2PlusWrapper', 'initialized', 'quoteToken', 'status'] | ['msg.sender == address(0) || quoteToken_ == address(0)'] |
| receive | [] | [] |
| initialize | ['endTime', 'initialized', 'prizeToken', 'prizeTokenId', 'protocolTreasury', 'raffleId', 'reserveEntries', 'sponsor', 'sponsorRecipient', 'status'] | ['msg.sender != factory'] |
| buyEntries | ['_balances', '_owners', '_ticketRanges', '_tokenApprovals', 'ticketCount', 'totalEntries', 'unsettledPot'] | [] |
| requestDraw | ['_requestInFlight', 'drawRequestedAt', 'status', 'vrfRequestId'] | [] |
| enableRefunds | ['remainingRefundLiability', 'status', 'unsettledPot'] | ['msg.sender != sponsor && block.timestamp < deadline'] |
| settleWinningTicket | ['protocolFees', 'settlementComplete', 'sponsorProceeds', 'unsettledPot', 'winnerProceeds', 'winningTicketId'] | [] |
| redeemWinningTicket | ['_balances', '_owners', '_tokenApprovals', 'prizeClaimed', 'protocolFees', 'settlementComplete', 'sponsorProceeds', 'unsettledPot', 'winnerProceeds', 'winnerRecipient', 'winnerRedeemed', 'winningTicketId'] | ['msg.sender != winner'] |
| refundTickets | ['_balances', '_owners', '_tokenApprovals', 'remainingRefundLiability'] | ['msg.sender != owner'] |
| releaseSponsorProceeds | ['sponsorProceeds'] | [] |
| releaseProtocolFees | ['protocolFees'] | [] |
| releaseSponsorPrize | ['prizeClaimed'] | [] |
| onERC721Received | ['status'] | ['status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId || from != sponsor || operator != factory'] |
| getVrfRequestPrice | [] | [] |
| estimateVrfRequestPrice | [] | [] |
| vrfWrapper | [] | [] |
| ticketRange | [] | [] |
| drawRequestDeadline | [] | [] |
| callbackDeadline | [] | [] |
| accountedQuoteBalance | [] | [] |
| grossSales | [] | [] |
| name | [] | [] |
| symbol | [] | [] |
| _update | ['_balances', '_owners', '_tokenApprovals'] | [] |
| fulfillRandomWords | ['resolvedAt', 'status', 'winningEntry'] | [] |
| _settleWinningTicket | ['protocolFees', 'settlementComplete', 'sponsorProceeds', 'unsettledPot', 'winnerProceeds', 'winningTicketId'] | [] |
| _transferQuote | [] | [] |
| _requireStatus | [] | [] |
| _requireWinningTicket | [] | [] |
| _isProtocolDestination | [] | [] |
| _validatedVrfWrapper | [] | [] |
| slitherConstructorConstantVariables | ['ENTRY_PRICE', 'callbackGasLimit', 'requestConfirmations'] | [] |

## RaffleFactory — function-summary (30 rows incl. inherited)

| Function | Visibility | Modifiers | Writes | External calls | CC |
|---|---|---|---|---|---|
| constructor() | internal | [] | [] | [] | 1 |
| _nonReentrantBeforeView() | private | [] | [] | [] | 2 |
| _nonReentrantBefore() | private | [] | [] | [] | 1 |
| _nonReentrantAfter() | private | [] | [] | [] | 1 |
| _reentrancyGuardEntered() | internal | [] | [] | [] | 1 |
| _reentrancyGuardStorageSlot() | internal | [] | [] | [] | 1 |
| createRaffle(IRaffleFactory.CreateRaffleParams) | external | [] | [] | [] | 2 |
| quoteToken() | external | [] | [] | [] | 2 |
| vrfWrapper() | external | [] | [] | [] | 2 |
| protocolTreasury() | external | [] | [] | [] | 2 |
| callbackGasLimit() | external | [] | [] | [] | 2 |
| requestConfirmations() | external | [] | [] | [] | 2 |
| raffleImplementation() | external | [] | [] | [] | 2 |
| raffleCount() | external | [] | [] | [] | 2 |
| isRaffle(address) | external | [] | [] | [] | 2 |
| raffleById(uint256) | external | [] | [] | [] | 2 |
| idByRaffle(address) | external | [] | [] | [] | 2 |
| constructor(address,address,address) | public | [] | ['protocolTreasury', 'quoteToken'] | [] | 7 |
|  |  |  | ['raffleImplementation', 'vrfWrapper'] | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| createRaffle(IRaffleFactory.CreateRaffleParams) | external | ['nonReentrant'] | ['idByRaffle', 'isRaffle'] | [] | 5 |
|  |  |  | ['raffleById', 'raffleCount'] | [] |  |
|  |  |  |  | [] |  |
| _validateCreateParams(IRaffleFactory.CreateRaffleParams) | private | [] | [] | [] | 8 |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
|  |  |  |  | [] |  |
| _requireContract(address) | private | [] | [] | [] | 2 |
| slitherConstructorConstantVariables() | internal | [] | ['callbackGasLimit', 'requestConfirmations'] | [] | 1 |

## RaffleFactory — vars-and-auth (22 rows incl. inherited)

| Function | State variables written | Conditions on msg.sender |
|---|---|---|
| constructor | [] | [] |
| _nonReentrantBeforeView | [] | [] |
| _nonReentrantBefore | [] | [] |
| _nonReentrantAfter | [] | [] |
| _reentrancyGuardEntered | [] | [] |
| _reentrancyGuardStorageSlot | [] | [] |
| createRaffle | [] | [] |
| quoteToken | [] | [] |
| vrfWrapper | [] | [] |
| protocolTreasury | [] | [] |
| callbackGasLimit | [] | [] |
| requestConfirmations | [] | [] |
| raffleImplementation | [] | [] |
| raffleCount | [] | [] |
| isRaffle | [] | [] |
| raffleById | [] | [] |
| idByRaffle | [] | [] |
| constructor | ['protocolTreasury', 'quoteToken', 'raffleImplementation', 'vrfWrapper'] | [] |
| createRaffle | ['idByRaffle', 'isRaffle', 'raffleById', 'raffleCount'] | [] |
| _validateCreateParams | [] | [] |
| _requireContract | [] | [] |
| slitherConstructorConstantVariables | ['callbackGasLimit', 'requestConfirmations'] | [] |

## IRaffle — function-summary (49 rows incl. inherited)

| Function | Visibility | Modifiers | Writes | External calls | CC |
|---|---|---|---|---|---|
| initialize(IRaffle.RaffleInitParams) | external | [] | [] | [] | 2 |
| buyEntries(address,uint128) | external | [] | [] | [] | 2 |
| requestDraw() | external | [] | [] | [] | 2 |
| enableRefunds() | external | [] | [] | [] | 2 |
| settleWinningTicket(uint256) | external | [] | [] | [] | 2 |
| redeemWinningTicket(uint256) | external | [] | [] | [] | 2 |
| refundTickets(uint256[]) | external | [] | [] | [] | 2 |
| releaseSponsorProceeds() | external | [] | [] | [] | 2 |
| releaseProtocolFees() | external | [] | [] | [] | 2 |
| releaseSponsorPrize() | external | [] | [] | [] | 2 |
| getVrfRequestPrice() | external | [] | [] | [] | 2 |
| estimateVrfRequestPrice(uint256) | external | [] | [] | [] | 2 |
| ticketRange(uint256) | external | [] | [] | [] | 2 |
| drawRequestDeadline() | external | [] | [] | [] | 2 |
| callbackDeadline() | external | [] | [] | [] | 2 |
| accountedQuoteBalance() | external | [] | [] | [] | 2 |
| grossSales() | external | [] | [] | [] | 2 |
| ENTRY_PRICE() | external | [] | [] | [] | 2 |
| callbackGasLimit() | external | [] | [] | [] | 2 |
| requestConfirmations() | external | [] | [] | [] | 2 |
| factory() | external | [] | [] | [] | 2 |
| sponsor() | external | [] | [] | [] | 2 |
| sponsorRecipient() | external | [] | [] | [] | 2 |
| protocolTreasury() | external | [] | [] | [] | 2 |
| quoteToken() | external | [] | [] | [] | 2 |
| vrfWrapper() | external | [] | [] | [] | 2 |
| prizeToken() | external | [] | [] | [] | 2 |
| prizeTokenId() | external | [] | [] | [] | 2 |
| raffleId() | external | [] | [] | [] | 2 |
| reserveEntries() | external | [] | [] | [] | 2 |
| endTime() | external | [] | [] | [] | 2 |
| totalEntries() | external | [] | [] | [] | 2 |
| ticketCount() | external | [] | [] | [] | 2 |
| unsettledPot() | external | [] | [] | [] | 2 |
| remainingRefundLiability() | external | [] | [] | [] | 2 |
| winnerRecipient() | external | [] | [] | [] | 2 |
| winnerProceeds() | external | [] | [] | [] | 2 |
| sponsorProceeds() | external | [] | [] | [] | 2 |
| protocolFees() | external | [] | [] | [] | 2 |
| vrfRequestId() | external | [] | [] | [] | 2 |
| drawRequestedAt() | external | [] | [] | [] | 2 |
| resolvedAt() | external | [] | [] | [] | 2 |
| winningEntry() | external | [] | [] | [] | 2 |
| winningTicketId() | external | [] | [] | [] | 2 |
| status() | external | [] | [] | [] | 2 |
| settlementComplete() | external | [] | [] | [] | 2 |
| winnerRedeemed() | external | [] | [] | [] | 2 |
| prizeClaimed() | external | [] | [] | [] | 2 |
| initialized() | external | [] | [] | [] | 2 |

## IRaffle — vars-and-auth (49 rows incl. inherited)

| Function | State variables written | Conditions on msg.sender |
|---|---|---|
| initialize | [] | [] |
| buyEntries | [] | [] |
| requestDraw | [] | [] |
| enableRefunds | [] | [] |
| settleWinningTicket | [] | [] |
| redeemWinningTicket | [] | [] |
| refundTickets | [] | [] |
| releaseSponsorProceeds | [] | [] |
| releaseProtocolFees | [] | [] |
| releaseSponsorPrize | [] | [] |
| getVrfRequestPrice | [] | [] |
| estimateVrfRequestPrice | [] | [] |
| ticketRange | [] | [] |
| drawRequestDeadline | [] | [] |
| callbackDeadline | [] | [] |
| accountedQuoteBalance | [] | [] |
| grossSales | [] | [] |
| ENTRY_PRICE | [] | [] |
| callbackGasLimit | [] | [] |
| requestConfirmations | [] | [] |
| factory | [] | [] |
| sponsor | [] | [] |
| sponsorRecipient | [] | [] |
| protocolTreasury | [] | [] |
| quoteToken | [] | [] |
| vrfWrapper | [] | [] |
| prizeToken | [] | [] |
| prizeTokenId | [] | [] |
| raffleId | [] | [] |
| reserveEntries | [] | [] |
| endTime | [] | [] |
| totalEntries | [] | [] |
| ticketCount | [] | [] |
| unsettledPot | [] | [] |
| remainingRefundLiability | [] | [] |
| winnerRecipient | [] | [] |
| winnerProceeds | [] | [] |
| sponsorProceeds | [] | [] |
| protocolFees | [] | [] |
| vrfRequestId | [] | [] |
| drawRequestedAt | [] | [] |
| resolvedAt | [] | [] |
| winningEntry | [] | [] |
| winningTicketId | [] | [] |
| status | [] | [] |
| settlementComplete | [] | [] |
| winnerRedeemed | [] | [] |
| prizeClaimed | [] | [] |
| initialized | [] | [] |

## IRaffleFactory — function-summary (11 rows incl. inherited)

| Function | Visibility | Modifiers | Writes | External calls | CC |
|---|---|---|---|---|---|
| createRaffle(IRaffleFactory.CreateRaffleParams) | external | [] | [] | [] | 2 |
| quoteToken() | external | [] | [] | [] | 2 |
| vrfWrapper() | external | [] | [] | [] | 2 |
| protocolTreasury() | external | [] | [] | [] | 2 |
| callbackGasLimit() | external | [] | [] | [] | 2 |
| requestConfirmations() | external | [] | [] | [] | 2 |
| raffleImplementation() | external | [] | [] | [] | 2 |
| raffleCount() | external | [] | [] | [] | 2 |
| isRaffle(address) | external | [] | [] | [] | 2 |
| raffleById(uint256) | external | [] | [] | [] | 2 |
| idByRaffle(address) | external | [] | [] | [] | 2 |

## IRaffleFactory — vars-and-auth (11 rows incl. inherited)

| Function | State variables written | Conditions on msg.sender |
|---|---|---|
| createRaffle | [] | [] |
| quoteToken | [] | [] |
| vrfWrapper | [] | [] |
| protocolTreasury | [] | [] |
| callbackGasLimit | [] | [] |
| requestConfirmations | [] | [] |
| raffleImplementation | [] | [] |
| raffleCount | [] | [] |
| isRaffle | [] | [] |
| raffleById | [] | [] |
| idByRaffle | [] | [] |

## RaffleConstants — function-summary (6 rows incl. inherited)

| Function | Visibility | Modifiers | Writes | External calls | CC |
|---|---|---|---|---|---|
| slitherConstructorConstantVariables() | internal | [] | ['BPS', 'CASH_WINNER_BPS'] | [] | 1 |
|  |  |  | ['DRAW_CALLBACK_TIMEOUT', 'DRAW_REQUEST_TIMEOUT'] | [] |  |
|  |  |  | ['ENTRY_PRICE', 'MAX_REFUND_TICKET_BATCH_SIZE'] | [] |  |
|  |  |  | ['MAX_SALE_DURATION', 'PROTOCOL_FEE_BPS'] | [] |  |
|  |  |  | ['QUOTE_TOKEN_DECIMALS', 'VRF_CALLBACK_GAS_LIMIT'] | [] |  |
|  |  |  | ['VRF_REQUEST_CONFIRMATIONS'] | [] |  |

## RaffleConstants — vars-and-auth (1 rows incl. inherited)

| Function | State variables written | Conditions on msg.sender |
|---|---|---|
| slitherConstructorConstantVariables | ['BPS', 'CASH_WINNER_BPS', 'DRAW_CALLBACK_TIMEOUT', 'DRAW_REQUEST_TIMEOUT', 'ENTRY_PRICE', 'MAX_REFUND_TICKET_BATCH_SIZE', 'MAX_SALE_DURATION', 'PROTOCOL_FEE_BPS', 'QUOTE_TOKEN_DECIMALS', 'VRF_CALLBACK_GAS_LIMIT', 'VRF_REQUEST_CONFIRMATIONS'] | [] |

