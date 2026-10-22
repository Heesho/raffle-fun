# Native mapping/flow coverage evidence

This table is derived solely from the requested model’s native stage0 output. It records mapped entrypoints, not instrumented line coverage or proof that every dependency function was read. Full per-flow traces and investigation outputs remain in native-results.json.

| Path | Line | Handler | Entrypoint |
|---|---|---|---|
| packages/contracts/src/RaffleFactory.sol | 97 | RaffleFactory.createRaffle(CreateRaffleParams) | Create raffle |
| packages/contracts/src/Raffle.sol | 171 | Raffle.receive() | Direct native-token transfer |
| packages/contracts/src/Raffle.sol | 176 | Raffle.initialize(RaffleInitParams) | Initialize raffle clone |
| packages/contracts/src/Raffle.sol | 209 | Raffle.buyEntries(address,uint128) | Buy entries |
| packages/contracts/src/Raffle.sol | 240 | Raffle.requestDraw() | Request raffle draw |
| packages/contracts/src/Raffle.sol | 276 | Raffle.enableRefunds() | Enable refunds |
| packages/contracts/src/Raffle.sol | 304 | Raffle.settleWinningTicket(uint256) | Settle winning ticket |
| packages/contracts/src/Raffle.sol | 309 | Raffle.redeemWinningTicket(uint256) | Redeem winning ticket |
| packages/contracts/src/Raffle.sol | 349 | Raffle.refundTickets(uint256[]) | Refund tickets |
| packages/contracts/src/Raffle.sol | 375 | Raffle.releaseSponsorProceeds() | Release sponsor proceeds |
| packages/contracts/src/Raffle.sol | 385 | Raffle.releaseProtocolFees() | Release protocol fees |
| packages/contracts/src/Raffle.sol | 395 | Raffle.releaseSponsorPrize() | Release sponsor prize |
| packages/contracts/src/Raffle.sol | 416 | Raffle.onERC721Received(address,address,uint256,bytes) | Receive configured prize NFT |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 101 | VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords(uint256,uint256[]) | Fulfill raffle randomness |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 93 | ERC721.approve(address,uint256) | Approve ticket operator |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 105 | ERC721.setApprovalForAll(address,bool) | Set ticket operator approval |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 115 | ERC721.transferFrom(address,address,uint256) | Transfer ticket |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 128 | ERC721.safeTransferFrom(address,address,uint256) | Safely transfer ticket without data |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | 133 | ERC721.safeTransferFrom(address,address,uint256,bytes) | Safely transfer ticket with data |
