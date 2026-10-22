# SUP-S1 file and function coverage

All source line numbers refer to clean-context/packages/contracts/src unless a dependency path is stated. Manual review covers source behavior; the independent check script is not EVM test coverage. No percentages derived from repository test or line coverage were consulted.

## RaffleFactory.sol (1–186): complete production function pass

| Function/surface | Lines | Review focus and conclusion |
|---|---:|---|
| constructor | 65–92 | code checks, six-decimal metadata, immutable treasury sinks, implementation creation; canonical identities remain deployment assumptions |
| createRaffle | 97–148 | time bounds, monotonically assigned registry, CREATE clone, factory-only atomic init, registration-before-deposit, safe receiver activation, escrow/status verification, all-or-nothing rollback |
| _validateCreateParams | 154–179 | positive reserve, contract/interface checks, same-factory prize and sponsor sinks; untrusted interface report cannot prove token honesty |
| _requireContract | 183–185 | extcodesize requirement; excludes token under construction/EOAs |
| generated getters | 24–54 | no mutable configuration entry point; IDs and registry mapping consistent per successful atomic create |

## Raffle.sol (1–614): complete production function pass

| Function/surface | Lines | Review focus and conclusion |
|---|---:|---|
| constructor | 155–166 | implementation lock; factory/quote/wrapper immutables shared by clones; no clone configuration in constructor |
| receive | 171–173 | direct native transfer rejected; forced native balances are not a claim |
| initialize | 176–206 | one time, immutable factory only; nonzero/sink validation; trusts factory for reserve/time/code/interface validation |
| buyEntries | 209–237 | active/exclusive time, recipient, positive amount, cap, USDC before state, contiguous range, guard and safeMint rollback |
| requestDraw | 240–273 | nonempty draw, inclusive/open and exclusive/close boundaries, double quote, request/id persistence, in-flight callback, fee refund and transaction rollback |
| enableRefunds | 276–301 | empty sponsor early cancel, public ended-empty cancel, sold deadline and drawing deadline, one-time liability migration |
| settleWinningTicket | 304–306 | nonReentrant permissionless storage-only proof, helper below |
| redeemWinningTicket | 309–346 | implicit settlement, current-owner-only burn, cash/NFT branch, delivery verification, atomic rollback |
| refundTickets | 349–372 | bounded 1..100, owner-only, historical ranges, duplicate IDs fail, exact liability subtraction, transfer rollback |
| releaseSponsorProceeds | 375–382 | permissionless immutable recipient, clear-before-transfer, independent failure |
| releaseProtocolFees | 385–392 | permissionless immutable treasury, clear-before-transfer, independent failure |
| releaseSponsorPrize | 395–407 | only CashWon/Refunding, one-time flag, transfer plus ownerOf verification, atomic rollback |
| onERC721Received | 416–431 | exact status/token/id/from/operator, one activation; untrusted token cannot be proven honest |
| getVrfRequestPrice | 436–438 | configured callback/one word; trusted wrapper view |
| estimateVrfRequestPrice | 441–443 | explicit caller-selected gas price, quote not binding until transaction |
| vrfWrapper | 446–448 | wrapper immutable getter |
| ticketRange | 451–455 | historical getter; zero unknown ranges |
| drawRequestDeadline | 458–460 | uint256 addition of endTime and fixed2days |
| callbackDeadline | 463–465 | zero before request; otherwise uint256 requestedAt+2days |
| accountedQuoteBalance | 468–470 | sum of five disjoint current liabilities |
| grossSales | 473–475 | historical totalEntries*fixed price; safe bound |
| name/symbol | 479–487 | pure constant overrides avoid clone constructor metadata issue |
| _update | 497–502 | all mints/transfers/burns traverse sink guard; ERC721 auth preserved |
| fulfillRandomWords | 509–524 | wrapper auth inherited, gate order, O(1), one range-bounded entry, no external calls |
| _settleWinningTicket | 533–558 | terminal states only, unique range, exact aggregate splits/remainders, one-time allocation and pot clear |
| _transferQuote | 564–567 | known sinks rejected, SafeERC20 semantics, canonical token assumptions |
| _requireStatus | 573–575 | exact state enforcement |
| _requireWinningTicket | 579–585 | inclusive range proof; winningEntry positivity excludes unknown tickets |
| _isProtocolDestination | 593–605 | own clone/factory/implementation/quote/wrapper/prize and registered same-factory clones; static external registry reads; future addresses unresolved |
| _validatedVrfWrapper | 610–613 | nonzero wrapper before base constructor; factory supplies code validation |
| generated getters | 43–136 | observed accounting/configuration/lifecycle flags only; no setters |

## Interfaces and constants

- IRaffle.sol 1–521: all types, events, errors, external functions and generated-getter signatures reconciled with implementation. Status enum ordering and zero-storage AwaitingPrize were considered. The honest-prize wording at lines12–15 conflicts with the broader untrusted-prize clean design boundary.
- IRaffleFactory.sol 1–150: complete interface pass; signatures and registry/immutable semantics reconciled. Canonical token identity explicitly delegated to deployment tooling.
- RaffleConstants.sol 1–43: every constant checked against design: BPS10000, fee500, cash8000, price1e6, decimals6, batch100, max sale30days, request/callback2days each, callback gas300000, confirmations30.
- DESIGN.md: complete four-line clean specification read; no history or accepted-risk material used.

## Inherited entry points and reachable dependency review

| Dependency path | Examined behavior | Depth/limit |
|---|---|---|
| OZ ERC721.sol | supportsInterface, balanceOf, ownerOf, name/symbol, tokenURI/baseURI, approve/getApproved, setApprovalForAll/isApprovedForAll, transferFrom/safeTransferFrom; internal _ownerOf/_getApproved/_isAuthorized/_checkAuthorized, _update, _mint/_safeMint, _burn, _transfer/_safeTransfer, _approve, _setApprovalForAll/_requireOwned | complete core file read; inherited exposed mutation behavior reviewed in raffle context |
| OZ ERC721Utils.sol | receiver call after ownership update, magic selector and failure bubbling | complete file read |
| OZ ReentrancyGuard.sol | namespaced slot, zero-init clone behavior, equality check, before/after state and shared guarded functions | complete file read |
| OZ SafeERC20.sol | safeTransfer/From wrappers and assembly implementations, false/empty-return/code semantics | used paths read; unused allowance/ERC1363 features not audited |
| OZ Clones.sol | clone overloads and fixed-address CREATE bytecode/error paths | used path lines1–62 read; deterministic/args APIs not used |
| OZ Math.sol | floor mulDiv, nonoverflow/512-bit branch and rounding | used implementation lines199–277 read; all library arithmetic not independently proved |
| Chainlink VRFV2PlusWrapperConsumerBase.sol | constructor.link, immutable wrapper, native quote/request path, rawFulfill auth, inherited native/LINK getters | complete file read; LINK payment path unreachable from production entry point |
| Chainlink IVRFV2PlusWrapper.sol | native request and price signatures; trusted external wrapper boundary | complete interface read, wrapper implementation not present |
| Chainlink VRFV2PlusClient.sol | nativePayment=true extra-args tag encoding | complete file read |
| supporting interfaces and math/string/storage imports | included in source hash inventory | transitive files not all deeply audited; no claim of comprehensive dependency audit |

Clean package/config/remapping files were read only to identify pinned dependencies/compiler/target: OZ5.6.1, Chainlink1.5.0, Solidity0.8.36, Cancun, optimizer200, via_ir=false for Foundry default. The configured test names were not executed or inspected.
