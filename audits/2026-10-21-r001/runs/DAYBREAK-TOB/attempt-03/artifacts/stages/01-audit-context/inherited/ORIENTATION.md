# S1-ORIENT — Raffle Contracts

Target SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`

Language and build: Solidity 0.8.36, compiled for Cancun with optimization enabled at 200 runs in both configured build systems (`target/packages/contracts/src/Raffle.sol:L2`; `target/packages/contracts/src/RaffleFactory.sol:L2`; `target/packages/contracts/foundry.toml:L7-L11`; `target/packages/contracts/hardhat.config.ts:L14-L34`).

This is context building only: modules, externally reachable entrypoints, actors, persistent state, and a ranked per-function work queue.

## Modules

| Module | Role and evidence |
|---|---|
| RaffleFactory deployment and registry | Deploys the fixed implementation, creates ERC-1167 clones, initializes and registers them, and deposits each sponsor-selected prize (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`, `L97-L148`). |
| Raffle lifecycle, escrow, and accounting | Stores clone configuration and lifecycle state; sells range tickets; coordinates draw/refund branches; allocates quote-token liabilities; and releases NFT or quote-token claims (`target/packages/contracts/src/Raffle.sol:L52-L142`, `L176-L430`, `L509-L567`). |
| Transferable range-ticket ledger | Raffle inherits ERC721 and screens every non-burn ticket destination through its update override; inherited ownership, approval, transfer, and metadata calls remain reachable (`target/packages/contracts/src/Raffle.sol:L28`, `L477-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L19-L34`, `L44-L136`). |
| Chainlink VRF adapter | Quotes and requests one native-funded word, authenticates the wrapper callback, and maps an accepted word to a winning entry and terminal result (`target/packages/contracts/src/Raffle.sol:L240-L272`, `L436-L448`, `L509-L524`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L107`). |
| Protocol interfaces | Defines lifecycle/configuration types and the callable ABI for both contracts (`target/packages/contracts/src/interfaces/IRaffle.sol:L17-L54`, `L303-L520`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L11-L26`, `L99-L149`). |
| Fixed parameters | Defines rates, entry price, token decimals, refund batch bound, sale/draw timeouts, and VRF parameters (`target/packages/contracts/src/libraries/RaffleConstants.sol:L10-L42`). |
| Asset, clone, and call utilities | SafeERC20 supplies ERC-20 call wrappers, Clones deploys the proxy, and ReentrancyGuard supplies the shared fixed-slot call guard (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L47`, `L176-L244`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L62`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L35-L72`, `L94-L105`). |
| Build surface | Package scripts build with Hardhat and Foundry; both select Solidity 0.8.36, Cancun, optimizer enabled, 200 runs (`target/packages/contracts/package.json:L9-L11`, `L27-L30`; `target/packages/contracts/foundry.toml:L1-L14`; `target/packages/contracts/hardhat.config.ts:L14-L35`). |

## Externally reachable entrypoints

### RaffleFactory

- Deployment-only: `constructor(address,address,address)` fixes quote token, wrapper, treasury, and implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`).
- State-changing: `createRaffle(CreateRaffleParams)` is callable by any sponsor and performs validation, clone creation, initialization, registration, and prize deposit (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`).
- Generated getters: `callbackGasLimit()`, `requestConfirmations()`, `quoteToken()`, `vrfWrapper()`, `protocolTreasury()`, `raffleImplementation()`, `raffleCount()`, `raffleById(uint256)`, `idByRaffle(address)`, and `isRaffle(address)` (`target/packages/contracts/src/RaffleFactory.sol:L24-L54`; matching interface declarations at `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L106-L149`).

### Raffle — direct implementation surface

- Deployment/native entrypoints: `constructor(address,address)` is invoked by the factory when deploying the implementation, and `receive()` rejects direct native transfers (`target/packages/contracts/src/Raffle.sol:L155-L173`; factory deployment at `target/packages/contracts/src/RaffleFactory.sol:L89`).
- Configuration/custody callbacks: `initialize(RaffleInitParams)` accepts only the immutable factory once; `onERC721Received(address,address,uint256,bytes)` accepts only the exact factory-mediated configured prize deposit (`target/packages/contracts/src/Raffle.sol:L176-L206`, `L416-L431`).
- Purchase/draw/refund: `buyEntries(address,uint128)`, `requestDraw()`, `enableRefunds()`, and `refundTickets(uint256[])` (`target/packages/contracts/src/Raffle.sol:L209-L301`, `L349-L372`).
- Settlement and releases: `settleWinningTicket(uint256)`, `redeemWinningTicket(uint256)`, `releaseSponsorProceeds()`, `releaseProtocolFees()`, and `releaseSponsorPrize()` (`target/packages/contracts/src/Raffle.sol:L304-L346`, `L375-L407`).
- Explicit views: `getVrfRequestPrice()`, `estimateVrfRequestPrice(uint256)`, `vrfWrapper()`, `ticketRange(uint256)`, `drawRequestDeadline()`, `callbackDeadline()`, `accountedQuoteBalance()`, `grossSales()`, `name()`, and `symbol()` (`target/packages/contracts/src/Raffle.sol:L435-L487`).
- Generated getters: `ENTRY_PRICE()`, `callbackGasLimit()`, `requestConfirmations()`, `factory()`, `quoteToken()`, `sponsor()`, `sponsorRecipient()`, `protocolTreasury()`, `prizeToken()`, `prizeTokenId()`, `raffleId()`, `reserveEntries()`, `endTime()`, `totalEntries()`, `ticketCount()`, `unsettledPot()`, `remainingRefundLiability()`, `winnerRecipient()`, `winnerProceeds()`, `sponsorProceeds()`, `protocolFees()`, `vrfRequestId()`, `drawRequestedAt()`, `resolvedAt()`, `winningEntry()`, `winningTicketId()`, `status()`, `settlementComplete()`, `winnerRedeemed()`, `prizeClaimed()`, and `initialized()` (`target/packages/contracts/src/Raffle.sol:L41-L136`; ABI declarations at `target/packages/contracts/src/interfaces/IRaffle.sol:L392-L520`).

### Raffle — inherited surface

- VRF base: `i_vrfV2PlusWrapper()`, `rawFulfillRandomWords(uint256,uint256[])`, `getBalance()`, and `getLinkToken()`; only the configured wrapper passes the callback caller check (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L35`, `L101-L117`; inheritance at `target/packages/contracts/src/Raffle.sol:L28`).
- ERC-721 views/metadata: `supportsInterface(bytes4)`, `balanceOf(address)`, `ownerOf(uint256)`, `tokenURI(uint256)`, `getApproved(uint256)`, and `isApprovedForAll(address,address)` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L102`, `L109-L112`; inheritance at `target/packages/contracts/src/Raffle.sol:L28`).
- ERC-721 approvals/transfers: `approve(address,uint256)`, `setApprovalForAll(address,bool)`, `transferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256)`, and `safeTransferFrom(address,address,uint256,bytes)` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L136`; each ticket update dispatches through `target/packages/contracts/src/Raffle.sol:L497-L502`).

## Actors and trust

| Actor | Trust | Basis |
|---|---|---|
| Factory deployer / deployment tooling | trusted | Selects quote token, wrapper, and treasury; source states tooling must verify official USDC identity (`target/packages/contracts/src/RaffleFactory.sol:L58-L65`). |
| Canonical RaffleFactory | trusted | Sole accepted clone initializer and required prize-deposit operator (`target/packages/contracts/src/Raffle.sol:L176-L179`, `L421-L424`; calls at `target/packages/contracts/src/RaffleFactory.sol:L105-L128`). |
| Sponsor / creator | untrusted | Any caller supplies creation parameters and prize; stored sponsor has only the scoped empty-raffle transition (`target/packages/contracts/src/RaffleFactory.sol:L97-L128`; `target/packages/contracts/src/Raffle.sol:L279-L284`). |
| Buyer / permissionless keeper | untrusted | Any caller may buy, request, settle, or trigger releases subject to local gates (`target/packages/contracts/src/Raffle.sol:L209-L250`, `L304-L306`, `L375-L407`). |
| Ticket owner / approved operator | untrusted | Tickets are bearer claims with inherited approvals/transfers; refund and redemption check current ownership (`target/packages/contracts/src/interfaces/IRaffle.sol:L10-L15`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L92-L136`; `target/packages/contracts/src/Raffle.sol:L320-L325`, `L357-L365`). |
| Quote-token contract | trusted | Interface assumes canonical standard six-decimal, non-rebasing, fee-free behavior; factory checks code and decimals (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/src/RaffleFactory.sol:L66-L78`). |
| Sponsor-selected prize ERC-721 | semi-trusted | Factory checks code and ERC-721 interface support; interface assumes honest standards-compliant behavior (`target/packages/contracts/src/RaffleFactory.sol:L154-L178`; `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). |
| Chainlink wrapper | trusted | Fixed by deployer; sole accepted caller of the inherited callback gateway (`target/packages/contracts/src/RaffleFactory.sol:L65-L67`, `L85-L91`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`). |
| Sponsor recipient / treasury | untrusted | Immutable asset destinations without special call authority (`target/packages/contracts/src/RaffleFactory.sol:L64-L68`, `L97-L104`; `target/packages/contracts/src/Raffle.sol:L375-L406`). |
| Ticket receiver contract | untrusted | Safe mint/transfer may invoke receiver code after the ownership update (`target/packages/contracts/src/Raffle.sol:L235`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L127-L136`, `L279-L290`). |
| Block timestamp environment | semi-trusted | Drives sale, request, callback, and refund eligibility (`target/packages/contracts/src/Raffle.sol:L216`, `L242-L246`, `L282-L291`, `L512`; `target/packages/contracts/src/RaffleFactory.sol:L99-L104`). |

## Persistent state

| State group | Writers and evidence |
|---|---|
| Factory configuration and implementation | Constructor fixes `quoteToken`, `vrfWrapper`, `protocolTreasury`, and `raffleImplementation`; constants bind callback parameters (`target/packages/contracts/src/RaffleFactory.sol:L24-L45`, `L65-L92`). |
| Factory registry | `createRaffle` increments `raffleCount` and writes `raffleById`, `idByRaffle`, and `isRaffle` (`target/packages/contracts/src/RaffleFactory.sol:L44-L54`, `L105-L125`). |
| Raffle shared immutables/constants | Constructor fixes `factory` and `quoteToken`; inherited constructor fixes wrapper/LINK; constants bind economics/VRF parameters (`target/packages/contracts/src/Raffle.sol:L41-L58`, `L155-L164`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`). |
| Per-clone configuration | `initialize` writes sponsor, recipients, prize, identifier, reserve, end time, and initial clone status (`target/packages/contracts/src/Raffle.sol:L60-L82`, `L176-L205`). |
| Lifecycle flags/result | Constructor, initialization, prize receipt, draw request, refund transition, callback, settlement, redemption, and prize release write `status`, `initialized`, `settlementComplete`, `winnerRedeemed`, and `prizeClaimed` (`target/packages/contracts/src/Raffle.sol:L123-L136`, `L164-L165`, `L177-L205`, `L421-L429`, `L252-L260`, `L296-L300`, `L518-L523`, `L551-L555`, `L323-L341`, `L395-L405`). |
| Entry/ticket ranges | `buyEntries` advances `totalEntries` and `ticketCount` and stores `_ticketRanges[ticketId]` (`target/packages/contracts/src/Raffle.sol:L84-L88`, `L138-L139`, `L226-L233`). |
| ERC-721 ledger | Inherited `_update`, `_approve`, and `_setApprovalForAll` maintain owners, balances, and approvals; Raffle routes mint/transfer/burn through its override (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L28-L34`, `L216-L242`, `L383-L417`; `target/packages/contracts/src/Raffle.sol:L497-L502`). |
| Quote-token liabilities | Purchases grow `unsettledPot`; refunds move/decrease liabilities; settlement allocates winner/sponsor/protocol buckets; payout paths zero their bucket before transfer (`target/packages/contracts/src/Raffle.sol:L90-L106`, `L223-L233`, `L296-L299`, `L367-L390`, `L539-L555`). |
| Draw coordination | `requestDraw` writes `drawRequestedAt`, `_requestInFlight`, and `vrfRequestId` around the wrapper call (`target/packages/contracts/src/Raffle.sol:L108-L112`, `L141-L142`, `L252-L260`). |
| Winning result | Callback writes `winningEntry` and `resolvedAt`; settlement writes `winningTicketId`; redemption writes `winnerRecipient` (`target/packages/contracts/src/Raffle.sol:L96-L97`, `L114-L121`, `L518-L521`, `L551-L555`, `L320-L324`). |
| Fixed guard slot | The inherited guard writes ENTERED on entry and NOT_ENTERED on exit for protected calls (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L35-L51`, `L69-L72`, `L94-L105`; protected target entrypoints at `target/packages/contracts/src/RaffleFactory.sol:L97` and `target/packages/contracts/src/Raffle.sol:L209-L212`, `L240`, `L276`, `L304`, `L309`, `L349`, `L375`, `L385`, `L395`). |
| Native balance | `requestDraw` receives value, funds the wrapper, and may refund excess; direct receive reverts (`target/packages/contracts/src/Raffle.sol:L170-L173`, `L240-L270`; balance view at `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L109-L112`). |
| Quote-token custody | Purchase pulls quote token in; redemption/refund/release paths send it out through `_transferQuote` (`target/packages/contracts/src/Raffle.sol:L223-L224`, `L339-L342`, `L367-L390`, `L564-L567`). |
| Prize custody | Factory deposits and verifies the NFT; NFT-result redemption or sponsor-prize release transfers and verifies it out (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L329-L337`, `L395-L406`). |

## Ranked per-function candidates

1. `RaffleFactory.createRaffle` — validation, registry mutation, clone creation/initialization, sponsor-selected NFT calls, and custody/state verification (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`).
2. `Raffle.requestDraw` — lifecycle/timestamp writes, wrapper quote/request, request-ID persistence, temporary flag, and native excess return (`target/packages/contracts/src/Raffle.sol:L240-L273`).
3. `Raffle.buyEntries` — untrusted quantity/recipient checks, quote-token pull, range/accounting mutation, and safe mint (`target/packages/contracts/src/Raffle.sol:L209-L237`).
4. `Raffle.fulfillRandomWords` — callback gates, selected-entry derivation, timestamp, and terminal result (`target/packages/contracts/src/Raffle.sol:L509-L524`).
5. `Raffle.redeemWinningTicket` — optional settlement, current-owner check, burn, claim-state writes, and NFT/quote delivery (`target/packages/contracts/src/Raffle.sol:L309-L346`).
6. `Raffle.enableRefunds` — lifecycle, sold count, sponsor identity, deadline branches, and whole-pot liability transition (`target/packages/contracts/src/Raffle.sol:L276-L301`).
7. `Raffle.refundTickets` — bounded batch, per-ticket ownership/range reads, burns, aggregate liability decrement, and payout (`target/packages/contracts/src/Raffle.sol:L349-L372`).
8. `Raffle._settleWinningTicket` — winning-range validation and terminal allocation of the entire unsettled pot (`target/packages/contracts/src/Raffle.sol:L533-L558`).
9. `Raffle.onERC721Received` — callback-field authentication and AwaitingPrize-to-Active transition (`target/packages/contracts/src/Raffle.sol:L416-L431`).
10. `Raffle.initialize` — one-time factory gate, destination screening, and establishment of clone configuration (`target/packages/contracts/src/Raffle.sol:L176-L206`).
11. `Raffle._update` — shared mint/transfer/burn destination screen and inherited ledger dispatch (`target/packages/contracts/src/Raffle.sol:L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L244`).
12. `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` — external wrapper authentication boundary and callback dispatch (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).
13. `Raffle.releaseSponsorPrize` — result-state gate, one-time prize disposition, NFT transfer, and ownership verification (`target/packages/contracts/src/Raffle.sol:L395-L407`).
14. `RaffleFactory._validateCreateParams` — address screening, ERC-165 query paths, and reserve enforcement (`target/packages/contracts/src/RaffleFactory.sol:L154-L179`).
15. `Raffle._isProtocolDestination` — local address classification plus conditional external factory-registry lookup (`target/packages/contracts/src/Raffle.sol:L593-L605`).
16. `Raffle._transferQuote` — common destination screen and quote-token transfer for four claim paths (`target/packages/contracts/src/Raffle.sol:L564-L567`, `L342`, `L369`, `L380`, `L390`).
17. `ERC721.transferFrom` — inherited authorization/ownership path with dynamic dispatch to `Raffle._update` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L125`; `target/packages/contracts/src/Raffle.sol:L497-L502`).
18. `ERC721.safeTransferFrom(address,address,uint256,bytes)` — ticket transfer followed by recipient acceptance dispatch (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L132-L136`).
19. `Raffle._requireWinningTicket` — maps a selected entry to the caller-supplied historical ticket range used by settlement (`target/packages/contracts/src/Raffle.sol:L538`, `L579-L585`).
20. `Raffle.releaseSponsorProceeds` — consumes and clears the full sponsor liability before the shared payout helper (`target/packages/contracts/src/Raffle.sol:L375-L382`).
21. `Raffle.releaseProtocolFees` — consumes and clears the full protocol liability before the shared payout helper (`target/packages/contracts/src/Raffle.sol:L385-L392`).
22. `RaffleFactory.constructor` — establishes deployment trust anchors, queries token metadata, screens treasury, and deploys implementation (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`).
23. `Raffle.constructor` — establishes implementation-baked configuration and locks implementation storage (`target/packages/contracts/src/Raffle.sol:L155-L166`).
24. `ReentrancyGuard.nonReentrant` path — one fixed word brackets all protected state-changing entrypoints (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`).

## Coverage

The five requested first-party files were read completely: `Raffle.sol` (`L1-L614`), `RaffleFactory.sol` (`L1-L186`), `IRaffle.sol` (`L1-L521`), `IRaffleFactory.sol` (`L1-L150`), and `RaffleConstants.sol` (`L1-L43`). Relevant target-contained build files and dependency source paths used to resolve inherited entrypoints/state are itemized with exact coverage in `raw/orientation-response.json`.
