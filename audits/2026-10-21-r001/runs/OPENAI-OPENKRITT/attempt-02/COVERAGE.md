# Native mapping/flow coverage evidence

This table is derived solely from the requested model’s native stage0 output. It records mapped entrypoints, not instrumented line coverage or proof that every dependency function was read. Full per-flow traces and investigation outputs remain in native-results.json.

| Path | Line | Handler | Entrypoint |
|---|---|---|---|
| packages/contracts/src/RaffleFactory.sol | 97 | RaffleFactory.createRaffle(CreateRaffleParams) | RaffleFactory.createRaffle |
| packages/contracts/src/Raffle.sol | 176 | Raffle.initialize(RaffleInitParams) | Raffle.initialize |
| packages/contracts/src/Raffle.sol | 171 | Raffle.receive() | Raffle.receive |
| packages/contracts/src/Raffle.sol | 209 | Raffle.buyEntries(address,uint128) | Raffle.buyEntries |
| packages/contracts/src/Raffle.sol | 240 | Raffle.requestDraw() | Raffle.requestDraw |
| packages/contracts/src/Raffle.sol | 276 | Raffle.enableRefunds() | Raffle.enableRefunds |
| packages/contracts/src/Raffle.sol | 304 | Raffle.settleWinningTicket(uint256) | Raffle.settleWinningTicket |
| packages/contracts/src/Raffle.sol | 309 | Raffle.redeemWinningTicket(uint256) | Raffle.redeemWinningTicket |
| packages/contracts/src/Raffle.sol | 349 | Raffle.refundTickets(uint256[]) | Raffle.refundTickets |
| packages/contracts/src/Raffle.sol | 375 | Raffle.releaseSponsorProceeds() | Raffle.releaseSponsorProceeds |
| packages/contracts/src/Raffle.sol | 385 | Raffle.releaseProtocolFees() | Raffle.releaseProtocolFees |
| packages/contracts/src/Raffle.sol | 395 | Raffle.releaseSponsorPrize() | Raffle.releaseSponsorPrize |
| packages/contracts/src/Raffle.sol | 416 | Raffle.onERC721Received(address,address,uint256,bytes) | Raffle.onERC721Received |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 101 | VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords(uint256,uint256[]) | Raffle.rawFulfillRandomWords |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 93 | ERC721.approve(address,uint256) | Raffle.approve(address,uint256) |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 105 | ERC721.setApprovalForAll(address,bool) | Raffle.setApprovalForAll(address,bool) |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 115 | ERC721.transferFrom(address,address,uint256) | Raffle.transferFrom(address,address,uint256) |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 128 | ERC721.safeTransferFrom(address,address,uint256) | Raffle.safeTransferFrom(address,address,uint256) |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 133 | ERC721.safeTransferFrom(address,address,uint256,bytes) | Raffle.safeTransferFrom(address,address,uint256,bytes) |
| packages/contracts/src/Raffle.sol | 436 | Raffle.getVrfRequestPrice() | Raffle.getVrfRequestPrice |
| packages/contracts/src/Raffle.sol | 441 | Raffle.estimateVrfRequestPrice(uint256) | Raffle.estimateVrfRequestPrice |
| packages/contracts/src/Raffle.sol | 446 | Raffle.vrfWrapper() | Raffle.vrfWrapper |
| packages/contracts/src/Raffle.sol | 451 | Raffle.ticketRange(uint256) | Raffle.ticketRange |
| packages/contracts/src/Raffle.sol | 458 | Raffle.drawRequestDeadline() | Raffle.drawRequestDeadline |
| packages/contracts/src/Raffle.sol | 463 | Raffle.callbackDeadline() | Raffle.callbackDeadline |
| packages/contracts/src/Raffle.sol | 468 | Raffle.accountedQuoteBalance() | Raffle.accountedQuoteBalance |
| packages/contracts/src/Raffle.sol | 473 | Raffle.grossSales() | Raffle.grossSales |
| packages/contracts/src/Raffle.sol | 479 | Raffle.name() | Raffle.name |
| packages/contracts/src/Raffle.sol | 485 | Raffle.symbol() | Raffle.symbol |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 45 | ERC721.supportsInterface(bytes4) | Raffle.supportsInterface |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 53 | ERC721.balanceOf(address) | Raffle.balanceOf |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 61 | ERC721.ownerOf(uint256) | Raffle.ownerOf |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 76 | ERC721.tokenURI(uint256) | Raffle.tokenURI |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 98 | ERC721.getApproved(uint256) | Raffle.getApproved |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 110 | ERC721.isApprovedForAll(address,address) | Raffle.isApprovedForAll |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 110 | VRFV2PlusWrapperConsumerBase.getBalance() | Raffle.getBalance |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 115 | VRFV2PlusWrapperConsumerBase.getLinkToken() | Raffle.getLinkToken |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 35 | VRFV2PlusWrapperConsumerBase.i_vrfV2PlusWrapper() generated getter | Raffle.i_vrfV2PlusWrapper |
| packages/contracts/src/Raffle.sol | 44 | Raffle.ENTRY_PRICE() generated getter | Raffle.ENTRY_PRICE |
| packages/contracts/src/Raffle.sol | 47 | Raffle.callbackGasLimit() generated getter | Raffle.callbackGasLimit |
| packages/contracts/src/Raffle.sol | 50 | Raffle.requestConfirmations() generated getter | Raffle.requestConfirmations |
| packages/contracts/src/Raffle.sol | 55 | Raffle.factory() generated getter | Raffle.factory |
| packages/contracts/src/Raffle.sol | 58 | Raffle.quoteToken() generated getter | Raffle.quoteToken |
| packages/contracts/src/Raffle.sol | 61 | Raffle.sponsor() generated getter | Raffle.sponsor |
| packages/contracts/src/Raffle.sol | 64 | Raffle.sponsorRecipient() generated getter | Raffle.sponsorRecipient |
| packages/contracts/src/Raffle.sol | 67 | Raffle.protocolTreasury() generated getter | Raffle.protocolTreasury |
| packages/contracts/src/Raffle.sol | 70 | Raffle.prizeToken() generated getter | Raffle.prizeToken |
| packages/contracts/src/Raffle.sol | 73 | Raffle.prizeTokenId() generated getter | Raffle.prizeTokenId |
| packages/contracts/src/Raffle.sol | 76 | Raffle.raffleId() generated getter | Raffle.raffleId |
| packages/contracts/src/Raffle.sol | 79 | Raffle.reserveEntries() generated getter | Raffle.reserveEntries |
| packages/contracts/src/Raffle.sol | 82 | Raffle.endTime() generated getter | Raffle.endTime |
| packages/contracts/src/Raffle.sol | 85 | Raffle.totalEntries() generated getter | Raffle.totalEntries |
| packages/contracts/src/Raffle.sol | 88 | Raffle.ticketCount() generated getter | Raffle.ticketCount |
| packages/contracts/src/Raffle.sol | 91 | Raffle.unsettledPot() generated getter | Raffle.unsettledPot |
| packages/contracts/src/Raffle.sol | 94 | Raffle.remainingRefundLiability() generated getter | Raffle.remainingRefundLiability |
| packages/contracts/src/Raffle.sol | 97 | Raffle.winnerRecipient() generated getter | Raffle.winnerRecipient |
| packages/contracts/src/Raffle.sol | 100 | Raffle.winnerProceeds() generated getter | Raffle.winnerProceeds |
| packages/contracts/src/Raffle.sol | 103 | Raffle.sponsorProceeds() generated getter | Raffle.sponsorProceeds |
| packages/contracts/src/Raffle.sol | 106 | Raffle.protocolFees() generated getter | Raffle.protocolFees |
| packages/contracts/src/Raffle.sol | 109 | Raffle.vrfRequestId() generated getter | Raffle.vrfRequestId |
| packages/contracts/src/Raffle.sol | 112 | Raffle.drawRequestedAt() generated getter | Raffle.drawRequestedAt |
| packages/contracts/src/Raffle.sol | 115 | Raffle.resolvedAt() generated getter | Raffle.resolvedAt |
| packages/contracts/src/Raffle.sol | 118 | Raffle.winningEntry() generated getter | Raffle.winningEntry |
| packages/contracts/src/Raffle.sol | 121 | Raffle.winningTicketId() generated getter | Raffle.winningTicketId |
| packages/contracts/src/Raffle.sol | 124 | Raffle.status() generated getter | Raffle.status |
| packages/contracts/src/Raffle.sol | 127 | Raffle.settlementComplete() generated getter | Raffle.settlementComplete |
| packages/contracts/src/Raffle.sol | 130 | Raffle.winnerRedeemed() generated getter | Raffle.winnerRedeemed |
| packages/contracts/src/Raffle.sol | 133 | Raffle.prizeClaimed() generated getter | Raffle.prizeClaimed |
| packages/contracts/src/Raffle.sol | 136 | Raffle.initialized() generated getter | Raffle.initialized |
| packages/contracts/src/RaffleFactory.sol | 25 | RaffleFactory.callbackGasLimit() generated getter | RaffleFactory.callbackGasLimit |
| packages/contracts/src/RaffleFactory.sol | 28 | RaffleFactory.requestConfirmations() generated getter | RaffleFactory.requestConfirmations |
| packages/contracts/src/RaffleFactory.sol | 33 | RaffleFactory.quoteToken() generated getter | RaffleFactory.quoteToken |
| packages/contracts/src/RaffleFactory.sol | 36 | RaffleFactory.vrfWrapper() generated getter | RaffleFactory.vrfWrapper |
| packages/contracts/src/RaffleFactory.sol | 39 | RaffleFactory.protocolTreasury() generated getter | RaffleFactory.protocolTreasury |
| packages/contracts/src/RaffleFactory.sol | 42 | RaffleFactory.raffleImplementation() generated getter | RaffleFactory.raffleImplementation |
| packages/contracts/src/RaffleFactory.sol | 45 | RaffleFactory.raffleCount() generated getter | RaffleFactory.raffleCount |
| packages/contracts/src/RaffleFactory.sol | 48 | RaffleFactory.raffleById(uint256) generated getter | RaffleFactory.raffleById |
| packages/contracts/src/RaffleFactory.sol | 51 | RaffleFactory.idByRaffle(address) generated getter | RaffleFactory.idByRaffle |
| packages/contracts/src/RaffleFactory.sol | 54 | RaffleFactory.isRaffle(address) generated getter | RaffleFactory.isRaffle |
