# Raffle.sol requirement extraction

Source: `target/packages/contracts/src/Raffle.sol`, read in full at L1-L614. Requested frozen revision: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` (supplied by the request).

This is the native requirements-extraction stage. It records documented claims and proposed checks, not compliance verdicts. No target code was executed or modified. No tests, compilation, analyzers, scanners, fuzzing, chain calls, or network research were performed.

Evidence is limited to local NatSpec in Raffle.sol. Bare `@inheritdoc IRaffle` annotations supply no local requirement wording; other documents were not imported. Author, title, version, section labels, and parameter labels with no additional behavioral constraint were excluded. Repeated descriptions of the same property are consolidated where possible. Shared quotations are repeated where distinct clauses or outcomes require separate checks.

Quotes preserve the document wording, with NatSpec delimiters and tags removed and wrapped prose joined by spaces. Explicit “must” clauses are mandatory; narrative guarantees and assumptions remain descriptive. External token assumptions are distinguished from validation obligations. Undefined or incompletely specified terms are identified in checkable criteria.

## Source reads and searches

- `nl -ba target/packages/contracts/src/Raffle.sol` — read the complete 614-line source and its local documentation.
- `rg -n '^\s*///' target/packages/contracts/src/Raffle.sol` — located local NatSpec and inherited-documentation placeholders; all explicit behavioral prose was reviewed.

## Extracted requirements (91)

Machine-readable record: `Raffle.sol.requirements.json`. Locations below identify documentary evidence. Checkable criteria describe a later review, not findings.

### REQ-01

> Escrows one NFT

Source: `target/packages/contracts/src/Raffle.sol:L21`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Each raffle escrows one configured NFT prize.

### REQ-02

> sells fixed-price USDC entries

Source: `target/packages/contracts/src/Raffle.sol:L21`  
Kind: `economic` · Force: `descriptive`

**Checkable:** The USDC price per entry is fixed across purchases.

### REQ-03

> one transferable ERC-721 ticket per purchase.

Source: `target/packages/contracts/src/Raffle.sol:L21`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Each successful entry purchase creates exactly one ERC-721 ticket, regardless of the number of entries purchased.

### REQ-04

> Ticket IDs are sequential

Source: `target/packages/contracts/src/Raffle.sol:L22`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** Successive ticket issuances use consecutive ticket IDs.

### REQ-05

> map to one inclusive `[firstEntry,lastEntry]` uint128 range.

Source: `target/packages/contracts/src/Raffle.sol:L22`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Each ticket maps to a single inclusive entry interval whose endpoints are uint128 values.

### REQ-06

> Purchases, Chainlink callbacks, and winner proofs are O(1) in entry count.

Source: `target/packages/contracts/src/Raffle.sol:L22-L23`  
Kind: `other` · Force: `descriptive`

**Checkable:** Purchase work does not grow with the number of entries.

### REQ-07

> Purchases, Chainlink callbacks, and winner proofs are O(1) in entry count.

Source: `target/packages/contracts/src/Raffle.sol:L22-L23`  
Kind: `other` · Force: `descriptive`

**Checkable:** Chainlink callback work does not grow with the number of entries.

### REQ-08

> Purchases, Chainlink callbacks, and winner proofs are O(1) in entry count.

Source: `target/packages/contracts/src/Raffle.sol:L22-L23`  
Kind: `other` · Force: `descriptive`

**Checkable:** Winner-proof verification work does not grow with the number of entries.

### REQ-09

> Tickets remain transferable bearer claims in every lifecycle state.

Source: `target/packages/contracts/src/Raffle.sol:L491`  
Kind: `state-machine` · Force: `descriptive`

**Checkable:** An existing, unburned ticket remains transferable in every raffle lifecycle state.

### REQ-10

> Tickets remain transferable bearer claims until their owners burn them for redemption or refund.

Source: `target/packages/contracts/src/Raffle.sol:L23-L24`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** The claim represented by an unburned ticket belongs to its current owner and follows ownership transfers.

### REQ-11

> owners burn them for redemption or refund.

Source: `target/packages/contracts/src/Raffle.sol:L24`  
Kind: `state-machine` · Force: `descriptive`

**Checkable:** Obtaining a ticket refund requires the owner to burn the refunded ticket.

### REQ-12

> Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue path.

Source: `target/packages/contracts/src/Raffle.sol:L24-L25`  
Kind: `other` · Force: `descriptive`

**Checkable:** Each raffle instance uses the ERC-1167 minimal-proxy clone architecture.

### REQ-13

> Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue path.

Source: `target/packages/contracts/src/Raffle.sol:L24-L25`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** A deployed raffle cannot change or upgrade its implementation.

### REQ-14

> Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue path.

Source: `target/packages/contracts/src/Raffle.sol:L24-L25`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** A raffle exposes no administrator role or administrative control path.

### REQ-15

> Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue path.

Source: `target/packages/contracts/src/Raffle.sol:L24-L25`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** A raffle exposes no asset-rescue path, including for unrelated NFTs forced into it as described at L410-L411.

### REQ-16

> Permissionless settlement only allocates liabilities

Source: `target/packages/contracts/src/Raffle.sol:L25`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** Any caller can settle a valid winning ticket without a privileged role or ticket-owner authorization.

### REQ-17

> the winning-ticket owner atomically burns the ticket while receiving the NFT or cash prize.

Source: `target/packages/contracts/src/Raffle.sol:L25-L26`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** For an NFT win, burning the winning owner's ticket and delivering the NFT to that owner succeed or revert atomically.

### REQ-18

> the winning-ticket owner atomically burns the ticket while receiving the NFT or cash prize.

Source: `target/packages/contracts/src/Raffle.sol:L25-L26`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** For a cash win, burning the winning owner's ticket and delivering the cash to that owner succeed or revert atomically.

### REQ-19

> First represented one-based global entry.

Source: `target/packages/contracts/src/Raffle.sol:L34`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** TicketRange.firstEntry denotes the first covered global entry using one-based numbering.

### REQ-20

> Last represented one-based global entry.

Source: `target/packages/contracts/src/Raffle.sol:L35`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** TicketRange.lastEntry denotes the last covered global entry using one-based numbering.

### REQ-21

> Historical ticket ranges remain stored after burns so indexers and callers can reconstruct entry coverage.

Source: `target/packages/contracts/src/Raffle.sol:L138`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Burning a ticket preserves its stored historical entry range for subsequent reconstruction of coverage.

### REQ-22

> True only while the wrapper request call is executing

Source: `target/packages/contracts/src/Raffle.sol:L141`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** _requestInFlight is never true outside the execution interval of the wrapper request call.

### REQ-23

> a synchronous callback cannot resolve early.

Source: `target/packages/contracts/src/Raffle.sol:L141`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** A callback arriving synchronously during the wrapper request cannot resolve the raffle before that request completes.

### REQ-24

> Deploys and locks the implementation shared by one factory's minimal-proxy raffles.

Source: `target/packages/contracts/src/Raffle.sol:L151`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** Deployment locks the implementation itself against subsequent raffle initialization.

### REQ-25

> the implementation shared by one factory's minimal-proxy raffles.

Source: `target/packages/contracts/src/Raffle.sol:L151`  
Kind: `other` · Force: `descriptive`

**Checkable:** The minimal-proxy raffles belonging to one factory share its implementation.

### REQ-26

> Constructor state belongs to the implementation.

Source: `target/packages/contracts/src/Raffle.sol:L152`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Constructor storage writes affect the implementation rather than initializing clone storage.

### REQ-27

> Clones share these immutables

Source: `target/packages/contracts/src/Raffle.sol:L152`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Every clone uses the immutable configuration embedded in the shared implementation.

### REQ-28

> hold isolated storage.

Source: `target/packages/contracts/src/Raffle.sol:L152`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Each clone has independent mutable storage, isolated from the implementation and other clones.

### REQ-29

> Canonical six-decimal USDC contract fixed for the implementation and every clone.

Source: `target/packages/contracts/src/Raffle.sol:L153`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The configured quoteToken_ is assumed to identify canonical USDC; the deployment context must establish that identity.

### REQ-30

> Canonical six-decimal USDC contract fixed for the implementation and every clone.

Source: `target/packages/contracts/src/Raffle.sol:L153`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The configured quote token is assumed to have six decimal places.

### REQ-31

> Canonical six-decimal USDC contract fixed for the implementation and every clone.

Source: `target/packages/contracts/src/Raffle.sol:L153`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** The quote-token address is fixed for the implementation and identical across all its clones.

### REQ-32

> Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.

Source: `target/packages/contracts/src/Raffle.sol:L154`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The configured vrfWrapper_ is a Chainlink VRF v2.5 wrapper supporting native direct funding.

### REQ-33

> Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.

Source: `target/packages/contracts/src/Raffle.sol:L154`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** The VRF-wrapper address is fixed for the implementation and identical across all its clones.

### REQ-34

> Raised when native currency is sent outside the payable draw-request path.

Source: `target/packages/contracts/src/Raffle.sol:L146`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** Native currency sent outside the payable draw-request path reverts with DirectNativeTransfer.

### REQ-35

> Rejects direct native-token transfers that are not attached to `requestDraw`.

Source: `target/packages/contracts/src/Raffle.sol:L170`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** The direct native-token receive path rejects transfers rather than accepting them outside requestDraw.

### REQ-36

> Accepts only the exact configured prize deposited by the factory for the sponsor.

Source: `target/packages/contracts/src/Raffle.sol:L409`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** The ERC-721 receiver accepts a prize only from the configured prize-token contract; token ID, operator, and previous owner are separate requirements below.

### REQ-37

> Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting

Source: `target/packages/contracts/src/Raffle.sol:L410`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** An unrelated NFT deposited using unsafe transferFrom does not enter protocol prize or liability accounting.

### REQ-38

> ERC-721 transfer operator, which must be the canonical factory.

Source: `target/packages/contracts/src/Raffle.sol:L412`  
Kind: `access-control` · Force: `mandatory`

**Checkable:** onERC721Received accepts only an operator equal to the canonical factory.

### REQ-39

> Previous owner, which must be the configured sponsor.

Source: `target/packages/contracts/src/Raffle.sol:L413`  
Kind: `access-control` · Force: `mandatory`

**Checkable:** onERC721Received accepts only a from address equal to the configured sponsor.

### REQ-40

> Transferred token ID, which must match the configured prize.

Source: `target/packages/contracts/src/Raffle.sol:L414`  
Kind: `invariant` · Force: `mandatory`

**Checkable:** onERC721Received accepts only the configured prizeTokenId.

### REQ-41

> ERC-721 receiver acceptance selector.

Source: `target/packages/contracts/src/Raffle.sol:L415`  
Kind: `other` · Force: `descriptive`

**Checkable:** A successful onERC721Received call returns the ERC-721 receiver acceptance selector.

### REQ-42

> Exact ERC-721 collection name, `raffle.fun Ticket`.

Source: `target/packages/contracts/src/Raffle.sol:L478`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** name() always returns raffle.fun Ticket for every raffle ticket collection, as also stated at L477.

### REQ-43

> Exact ERC-721 collection symbol, `RAFFLE`.

Source: `target/packages/contracts/src/Raffle.sol:L484`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** symbol() always returns RAFFLE for every raffle ticket collection, as also stated at L483.

### REQ-44

> Known protocol sinks are rejected before their ownership could make a claim unreachable.

Source: `target/packages/contracts/src/Raffle.sol:L491-L492`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** Ticket ownership updates reject known protocol-sink recipients before those recipients acquire ownership.

### REQ-45

> Burns pass the zero address

Source: `target/packages/contracts/src/Raffle.sol:L492`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** A ticket burn passes address(0) as the destination of the ownership update.

### REQ-46

> Burns pass the zero address and remain permitted.

Source: `target/packages/contracts/src/Raffle.sol:L492`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** The ticket-destination screen permits the zero-address destination used for otherwise valid burns.

### REQ-47

> Caller whose owner or operator authority is checked by ERC-721.

Source: `target/packages/contracts/src/Raffle.sol:L495`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** ERC-721 checks the owner or operator authority of the caller supplied in auth.

### REQ-48

> Ticket owner before the update, or the zero address for a mint.

Source: `target/packages/contracts/src/Raffle.sol:L496`  
Kind: `other` · Force: `descriptive`

**Checkable:** _update returns the ticket's owner from before a non-mint ownership update.

### REQ-49

> Ticket owner before the update, or the zero address for a mint.

Source: `target/packages/contracts/src/Raffle.sol:L496`  
Kind: `other` · Force: `descriptive`

**Checkable:** _update returns address(0) when minting a ticket.

### REQ-50

> Authenticated randomness selects only an entry.

Source: `target/packages/contracts/src/Raffle.sol:L504`  
Kind: `state-machine` · Force: `descriptive`

**Checkable:** Randomness resolution selects an entry rather than identifying a winning ticket or choosing a ticket owner.

### REQ-51

> No ticket search, loop, user call, or token transfer occurs.

Source: `target/packages/contracts/src/Raffle.sol:L504-L505`  
Kind: `other` · Force: `descriptive`

**Checkable:** The randomness callback performs no ticket search.

### REQ-52

> No ticket search, loop, user call, or token transfer occurs.

Source: `target/packages/contracts/src/Raffle.sol:L504-L505`  
Kind: `other` · Force: `descriptive`

**Checkable:** The randomness callback executes no loop.

### REQ-53

> No ticket search, loop, user call, or token transfer occurs.

Source: `target/packages/contracts/src/Raffle.sol:L504-L505`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The randomness callback makes no user call.

### REQ-54

> No ticket search, loop, user call, or token transfer occurs.

Source: `target/packages/contracts/src/Raffle.sol:L504-L505`  
Kind: `economic` · Force: `descriptive`

**Checkable:** The randomness callback performs no token transfer.

### REQ-55

> In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness

Source: `target/packages/contracts/src/Raffle.sol:L505-L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** An ABI-decodable callback arriving while the wrapper request is in flight is ignored without resolving or reverting in the handler.

### REQ-56

> In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness

Source: `target/packages/contracts/src/Raffle.sol:L505-L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** An ABI-decodable callback arriving after its permitted callback window is ignored without resolving or reverting in the handler.

### REQ-57

> In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness

Source: `target/packages/contracts/src/Raffle.sol:L505-L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** An ABI-decodable callback for a different request ID is ignored without resolving or reverting in the handler.

### REQ-58

> In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness

Source: `target/packages/contracts/src/Raffle.sol:L505-L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** An ABI-decodable duplicate callback is ignored without changing the existing resolution or reverting in the handler.

### REQ-59

> In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for liveness

Source: `target/packages/contracts/src/Raffle.sol:L505-L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** An ABI-decodable callback whose randomWords length is not exactly one is ignored without resolving or reverting in the handler; L508 specifies the required length.

### REQ-60

> malformed ABI calldata reverts during Solidity decoding before this handler runs.

Source: `target/packages/contracts/src/Raffle.sol:L506`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** Malformed ABI callback calldata causes a revert.

### REQ-61

> malformed ABI calldata reverts during Solidity decoding before this handler runs.

Source: `target/packages/contracts/src/Raffle.sol:L506`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** Malformed ABI callback calldata is rejected by Solidity decoding before fulfillRandomWords executes.

### REQ-62

> Wrapper-authenticated request identifier supplied by the callback.

Source: `target/packages/contracts/src/Raffle.sol:L507`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The callback request identifier reaches the handler through authentication by the configured wrapper.

### REQ-63

> Validates the winning range once

Source: `target/packages/contracts/src/Raffle.sol:L528`  
Kind: `state-machine` · Force: `descriptive`

**Checkable:** The winning range is validated only once for settlement of a raffle.

### REQ-64

> allocates all terminal quote-token liabilities

Source: `target/packages/contracts/src/Raffle.sol:L528`  
Kind: `economic` · Force: `descriptive`

**Checkable:** Successful winning-ticket settlement allocates every terminal quote-token liability.

### REQ-65

> without transferring an asset or reading ticket ownership.

Source: `target/packages/contracts/src/Raffle.sol:L528-L529`  
Kind: `economic` · Force: `descriptive`

**Checkable:** Winning-ticket settlement transfers no asset; it records liabilities as also stated at L25.

### REQ-66

> without transferring an asset or reading ticket ownership.

Source: `target/packages/contracts/src/Raffle.sol:L528-L529`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** Winning-ticket settlement performs no ticket-ownership read.

### REQ-67

> Both percentage allocations round down

Source: `target/packages/contracts/src/Raffle.sol:L529`  
Kind: `formula` · Force: `descriptive`

**Checkable:** The protocol-fee percentage allocation rounds down to whole raw quote-token units.

### REQ-68

> Both percentage allocations round down

Source: `target/packages/contracts/src/Raffle.sol:L529`  
Kind: `formula` · Force: `descriptive`

**Checkable:** The cash-winner percentage allocation rounds down to whole raw quote-token units.

### REQ-69

> sponsor proceeds are the remainder.

Source: `target/packages/contracts/src/Raffle.sol:L529-L530`  
Kind: `formula` · Force: `descriptive`

**Checkable:** Sponsor proceeds equal the settled pot minus the protocol-fee allocation and any cash-winner allocation.

### REQ-70

> Ticket whose inclusive range must contain the selected winning entry.

Source: `target/packages/contracts/src/Raffle.sol:L531`  
Kind: `invariant` · Force: `mandatory`

**Checkable:** A candidate winning ticket must satisfy firstEntry <= winningEntry <= lastEntry; the helper at L577 specifies rejection otherwise.

### REQ-71

> Raw six-decimal quote-token units allocated to the cash winner, or zero for `NftWon`.

Source: `target/packages/contracts/src/Raffle.sol:L532`  
Kind: `economic` · Force: `descriptive`

**Checkable:** _settleWinningTicket returns the cash-winner allocation in raw six-decimal quote-token units for a cash outcome.

### REQ-72

> Raw six-decimal quote-token units allocated to the cash winner, or zero for `NftWon`.

Source: `target/packages/contracts/src/Raffle.sol:L532`  
Kind: `formula` · Force: `descriptive`

**Checkable:** _settleWinningTicket returns zero cashAmount for NftWon.

### REQ-73

> Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks.

Source: `target/packages/contracts/src/Raffle.sol:L560`  
Kind: `economic` · Force: `descriptive`

**Checkable:** _transferQuote transfers the entire current USDC claim being released.

### REQ-74

> Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks.

Source: `target/packages/contracts/src/Raffle.sol:L560`  
Kind: `other` · Force: `descriptive`

**Checkable:** _transferQuote uses SafeERC20 for the USDC transfer.

### REQ-75

> Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks.

Source: `target/packages/contracts/src/Raffle.sol:L560`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** _transferQuote rejects a known protocol-sink recipient before attempting the USDC transfer.

### REQ-76

> The canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.

Source: `target/packages/contracts/src/Raffle.sol:L560-L561`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** Not fully checkable from this document: standard transfer semantics is undefined beyond the separately stated non-rebasing and fee-free assumptions.

### REQ-77

> The canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.

Source: `target/packages/contracts/src/Raffle.sol:L560-L561`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The configured USDC is assumed not to rebase balances; this is an external token assumption rather than an asserted Raffle validation.

### REQ-78

> The canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.

Source: `target/packages/contracts/src/Raffle.sol:L560-L561`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** The configured USDC is assumed to transfer without fees; this is an external token assumption rather than an asserted Raffle validation.

### REQ-79

> Immutable or owner-derived recipient of the claim.

Source: `target/packages/contracts/src/Raffle.sol:L562`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** Every _transferQuote recipient is either a fixed claim recipient or derived from the current ticket owner.

### REQ-80

> Raw six-decimal USDC units transferred.

Source: `target/packages/contracts/src/Raffle.sol:L563`  
Kind: `economic` · Force: `descriptive`

**Checkable:** _transferQuote interprets amount as raw six-decimal USDC units.

### REQ-81

> Reverts unless the raffle is in the expected lifecycle state.

Source: `target/packages/contracts/src/Raffle.sol:L571`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** _requireStatus reverts whenever the current raffle status differs from the supplied expected status.

### REQ-82

> Reverts unless the supplied ticket's stored inclusive range contains the selected winning entry.

Source: `target/packages/contracts/src/Raffle.sol:L577`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** _requireWinningTicket reverts when winningEntry is outside the supplied ticket's stored inclusive range.

### REQ-83

> True when the address is known same-factory protocol plumbing.

Source: `target/packages/contracts/src/Raffle.sol:L592`  
Kind: `other` · Force: `descriptive`

**Checkable:** Partly checkable: _isProtocolDestination returns true for known same-factory protocol plumbing, but this NatSpec does not exhaustively define that set.

### REQ-84

> Initialization supplies the prospective prize token

Source: `target/packages/contracts/src/Raffle.sol:L588`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** Initialization-time destination screening passes the prospective configured prize-token address.

### REQ-85

> clone storage is not populated yet

Source: `target/packages/contracts/src/Raffle.sol:L588`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** Initialization-time destination screening occurs before the clone's prize-token storage has been populated.

### REQ-86

> runtime checks pass the stored prize token.

Source: `target/packages/contracts/src/Raffle.sol:L588-L589`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** Runtime destination screening passes the prize-token address stored in the raffle.

### REQ-87

> Code-less addresses are not queried in the registry.

Source: `target/packages/contracts/src/Raffle.sol:L589`  
Kind: `trust-boundary` · Force: `descriptive`

**Checkable:** Destination screening does not query the raffle registry about an address whose code length is zero.

### REQ-88

> Configured or prospective prize-token address to reject.

Source: `target/packages/contracts/src/Raffle.sol:L591`  
Kind: `access-control` · Force: `descriptive`

**Checkable:** Destination screening rejects the supplied configured or prospective prize-token address.

### REQ-89

> Validates the wrapper before passing it to the inherited constructor initializer.

Source: `target/packages/contracts/src/Raffle.sol:L607`  
Kind: `ordering` · Force: `descriptive`

**Checkable:** The wrapper address is validated before it is passed to the inherited constructor initializer.

### REQ-90

> The same nonzero wrapper address.

Source: `target/packages/contracts/src/Raffle.sol:L609`  
Kind: `error-handling` · Force: `descriptive`

**Checkable:** _validatedVrfWrapper cannot successfully return a zero wrapper address.

### REQ-91

> The same nonzero wrapper address.

Source: `target/packages/contracts/src/Raffle.sol:L609`  
Kind: `invariant` · Force: `descriptive`

**Checkable:** _validatedVrfWrapper returns the same wrapper address it was supplied on success.
