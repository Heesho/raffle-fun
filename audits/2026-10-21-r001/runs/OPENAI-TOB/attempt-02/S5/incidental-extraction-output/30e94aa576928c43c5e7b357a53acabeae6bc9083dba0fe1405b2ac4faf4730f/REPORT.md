# IRaffleFactory requirement extraction

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L1-L150`.
Requested frozen commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` (supplied by the request).

This report contains 102 independently scoped requirements extracted from the interface's NatSpec: one mandatory requirement and 101 descriptive requirements. This native request is the extraction stage; implementation compliance verdicts are outside its scope.

## Evidence and extraction method

- Read the complete specified file using `nl -ba target/packages/contracts/src/interfaces/IRaffleFactory.sol`.
- Read that same file using `cat target/packages/contracts/src/interfaces/IRaffleFactory.sol` to check exact quotation text.
- Literal substring searches for all 62 distinct extracted quotes matched the source; there were no unmatched quotes.
- No other source or specification files were read. No implementation behavior was executed.
- Compound statements use separate records with independently scoped `checkable` properties. The original sentence is retained where a smaller verbatim fragment would lose its predicate or context.
- Repeated descriptions of the same property are consolidated. Event-payload accuracy, getter accuracy, state invariants, and error-payload accuracy remain separate where an implementation could satisfy one and violate another.
- Multiline quotes preserve the source's NatSpec continuation markers to keep them literal.
- The document's lowercase “must” makes deployment-tooling verification mandatory. Its other claims describe behavior without a mandatory modal.
- “Autonomous,” “locked,” and “known protocol plumbing” lack operational definitions here. The scope of “required” addresses is also not enumerated. The affected records identify those limits instead of supplying unstated definitions.

The machine-readable extraction is in `requirements.json`.

## Requirements

### REQ-001

> The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7, factory @dev`  
Kind: `access-control` · Force: `descriptive`

Checkable: The factory has no owner role or owner authority.

---

### REQ-002

> The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7, factory @dev`  
Kind: `state-machine` · Force: `descriptive`

Checkable: The factory exposes no pause mechanism.

---

### REQ-003

> The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7, factory @dev`  
Kind: `invariant` · Force: `descriptive`

Checkable: The factory has no upgrade mechanism.

---

### REQ-004

> The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7, factory @dev`  
Kind: `access-control` · Force: `descriptive`

Checkable: The factory exposes no asset-rescue mechanism.

---

### REQ-005

> The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7, factory @dev`  
Kind: `invariant` · Force: `descriptive`

Checkable: Protocol configuration cannot be changed after factory deployment.

---

### REQ-006

> Deployment tooling must
> ///      verify that the immutable quote-token address is the target chain's official USDC;

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L7-L8, factory @dev`  
Kind: `trust-boundary` · Force: `mandatory`

Checkable: Deployment tooling verifies the configured quote-token address against official USDC on the target chain; this interface supplies no chain-specific address.

---

### REQ-007

> onchain construction checks
> ///      only code presence and six-decimal metadata.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L8-L9, factory @dev`  
Kind: `error-handling` · Force: `descriptive`

Checkable: Factory construction checks that the quote-token address contains deployed code.

---

### REQ-008

> onchain construction checks
> ///      only code presence and six-decimal metadata.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L8-L9, factory @dev`  
Kind: `error-handling` · Force: `descriptive`

Checkable: Factory construction checks that quote-token metadata reports six decimals.

---

### REQ-009

> onchain construction checks
> ///      only code presence and six-decimal metadata.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L8-L9, factory @dev`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: Onchain construction verifies quote-token identity only through code presence and six-decimal metadata; official-USDC identity is left to deployment tooling.

---

### REQ-010

> Sponsor-selected configuration for one new raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14, CreateRaffleParams @notice`  
Kind: `access-control` · Force: `descriptive`

Checkable: The sponsor can select the new raffle's recipient, prize, reserve, and timing parameters, subject to validation.

---

### REQ-011

> Immutable recipient of sponsor quote proceeds and any returned prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L15, CreateRaffleParams.sponsorRecipient`  
Kind: `invariant` · Force: `descriptive`

Checkable: A raffle's configured sponsorRecipient cannot change after creation.

---

### REQ-012

> Immutable recipient of sponsor quote proceeds and any returned prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L15, CreateRaffleParams.sponsorRecipient`  
Kind: `economic` · Force: `descriptive`

Checkable: Sponsor quote proceeds are paid to sponsorRecipient.

---

### REQ-013

> Immutable recipient of sponsor quote proceeds and any returned prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L15, CreateRaffleParams.sponsorRecipient`  
Kind: `economic` · Force: `descriptive`

Checkable: Any returned prize is sent to sponsorRecipient.

---

### REQ-014

> Standards-compliant ERC-721 prize contract.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L16, CreateRaffleParams.prizeToken`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: The configured prizeToken is a standards-compliant ERC-721 contract; this interface does not enumerate conformance criteria.

---

### REQ-015

> Token ID to escrow atomically during creation.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L17, CreateRaffleParams.prizeTokenId`  
Kind: `ordering` · Force: `descriptive`

Checkable: Creation atomically escrows the configured prizeTokenId from the configured prizeToken contract.

---

### REQ-016

> Global raw entry-count threshold selecting the NFT outcome when met or exceeded.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L18, CreateRaffleParams.reserveEntries`  
Kind: `formula` · Force: `descriptive`

Checkable: The NFT outcome is selected when the raffle's global raw entry count is greater than or equal to reserveEntries.

---

### REQ-017

> Exclusive sale-end

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L19, CreateRaffleParams.endTime`  
Kind: `ordering` · Force: `descriptive`

Checkable: Sales are no longer permitted at or after endTime.

---

### REQ-018

> Unix timestamp, in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L19, CreateRaffleParams.endTime`  
Kind: `other` · Force: `descriptive`

Checkable: endTime is interpreted as Unix time in seconds.

---

### REQ-019

> Emitted after a raffle clone is initialized, registered, funded, and active.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30, RaffleCreated @notice`  
Kind: `other` · Force: `descriptive`

Checkable: Successful raffle creation emits RaffleCreated.

---

### REQ-020

> Emitted after a raffle clone is initialized, registered, funded, and active.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30, RaffleCreated @notice`  
Kind: `ordering` · Force: `descriptive`

Checkable: RaffleCreated is emitted only after the clone has been initialized.

---

### REQ-021

> Emitted after a raffle clone is initialized, registered, funded, and active.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30, RaffleCreated @notice`  
Kind: `ordering` · Force: `descriptive`

Checkable: RaffleCreated is emitted only after the clone has been registered.

---

### REQ-022

> Emitted after a raffle clone is initialized, registered, funded, and active.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30, RaffleCreated @notice`  
Kind: `ordering` · Force: `descriptive`

Checkable: RaffleCreated is emitted only after the clone has been funded.

---

### REQ-023

> Emitted after a raffle clone is initialized, registered, funded, and active.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L30, RaffleCreated @notice`  
Kind: `ordering` · Force: `descriptive`

Checkable: The clone is active when RaffleCreated is emitted.

---

### REQ-024

> One-based canonical raffle identifier.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L31, RaffleCreated.raffleId`  
Kind: `invariant` · Force: `descriptive`

Checkable: Canonical raffle identifiers start at one.

---

### REQ-025

> One-based canonical raffle identifier.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L31, RaffleCreated.raffleId`  
Kind: `invariant` · Force: `descriptive`

Checkable: RaffleCreated.raffleId equals the canonical identifier assigned to the emitted raffle address.

---

### REQ-026

> Newly created fixed-target ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L32, RaffleCreated.raffle`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.raffle is the address of the clone newly created by that creation operation.

---

### REQ-027

> Newly created fixed-target ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L32, RaffleCreated.raffle`  
Kind: `invariant` · Force: `descriptive`

Checkable: A created clone's implementation target cannot change.

---

### REQ-028

> Newly created fixed-target ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L32, RaffleCreated.raffle`  
Kind: `invariant` · Force: `descriptive`

Checkable: Created raffle clones conform to ERC-1167.

---

### REQ-029

> Prize depositor

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L33, RaffleCreated.sponsor`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.sponsor identifies the prize depositor.

---

### REQ-030

> pre-end empty-raffle refund authority.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L33, RaffleCreated.sponsor`  
Kind: `access-control` · Force: `descriptive`

Checkable: The sponsor is authorized to trigger a refund before endTime when the raffle is empty.

---

### REQ-031

> Immutable recipient of sponsor quote proceeds and any returned prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L34, RaffleCreated.sponsorRecipient`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.sponsorRecipient equals the new raffle's configured sponsorRecipient.

---

### REQ-032

> ERC-721 contract of the escrowed prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L35, RaffleCreated.prizeToken`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.prizeToken identifies the contract of the prize actually escrowed.

---

### REQ-033

> Token ID of the escrowed prize.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L36, RaffleCreated.prizeTokenId`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.prizeTokenId identifies the token actually escrowed.

---

### REQ-034

> Immutable canonical six-decimal USDC contract used by the raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L37, RaffleCreated.quoteToken`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.quoteToken equals the quote-token address used by the new raffle.

---

### REQ-035

> Immutable recipient of protocol fees.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L38, RaffleCreated.protocolTreasury`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.protocolTreasury equals the new raffle's protocol-fee recipient.

---

### REQ-036

> Global raw entry-count threshold selecting the NFT outcome when met or exceeded.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L39, RaffleCreated.reserveEntries`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.reserveEntries equals the new raffle's configured reserve-entry threshold.

---

### REQ-037

> Exclusive sale-end Unix timestamp, in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L40, RaffleCreated.endTime`  
Kind: `other` · Force: `descriptive`

Checkable: RaffleCreated.endTime equals the new raffle's configured sale-end timestamp.

---

### REQ-038

> Raised when a required address is the zero address.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L56, ZeroAddress @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: ZeroAddress is raised for a zero value in a required address; this interface does not enumerate all addresses covered.

---

### REQ-039

> Raised when an address required to contain deployed code is not a contract.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L59, NotContract @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: NotContract is raised when an address requiring deployed code has none; this interface does not enumerate all such addresses.

---

### REQ-040

> Address whose code length was zero.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L60, NotContract.account`  
Kind: `error-handling` · Force: `descriptive`

Checkable: NotContract.account is the offending address whose code length was zero.

---

### REQ-041

> Raised when the quote token cannot report its decimal precision.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L63, UnsupportedQuoteToken @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsupportedQuoteToken is raised when the quote token cannot report its decimal precision.

---

### REQ-042

> Rejected quote-token contract.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L64, UnsupportedQuoteToken.quoteToken`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsupportedQuoteToken.quoteToken identifies the rejected quote-token contract.

---

### REQ-043

> Raised when the quote token does not use the required six-decimal precision.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L67, InvalidQuoteTokenDecimals @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidQuoteTokenDecimals is raised when the quote token reports a decimal precision other than six.

---

### REQ-044

> Decimal precision reported by the quote token.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L68, InvalidQuoteTokenDecimals.actualDecimals`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidQuoteTokenDecimals.actualDecimals equals the precision reported by the rejected quote token.

---

### REQ-045

> Required decimal precision, exactly six.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L69, InvalidQuoteTokenDecimals.requiredDecimals`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidQuoteTokenDecimals.requiredDecimals equals six.

---

### REQ-046

> Raised when the prize contract does not report ERC-721 interface support.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L72, UnsupportedPrizeToken @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsupportedPrizeToken is raised when the prize contract does not report ERC-721 interface support.

---

### REQ-047

> Rejected prize-token contract.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L73, UnsupportedPrizeToken.prizeToken`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsupportedPrizeToken.prizeToken identifies the rejected prize-token contract.

---

### REQ-048

> Raised when a raffle is configured with a zero reserve entry threshold.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L76, ZeroReserveEntries @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: ZeroReserveEntries is raised when reserveEntries is zero.

---

### REQ-049

> Raised when the sale end is not strictly after the creation block timestamp.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L79, InvalidEndTime @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidEndTime is raised when endTime is less than or equal to the creation block timestamp.

---

### REQ-050

> Current block Unix timestamp, in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L80, InvalidEndTime.currentTime`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidEndTime.currentTime equals the current block timestamp in Unix seconds.

---

### REQ-051

> Supplied exclusive sale-end Unix timestamp, in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L81, InvalidEndTime.endTime`  
Kind: `error-handling` · Force: `descriptive`

Checkable: InvalidEndTime.endTime equals the supplied sale-end timestamp in Unix seconds.

---

### REQ-052

> Raised when the prospective sale duration exceeds the fixed 30-day limit.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L84, SaleDurationTooLong @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: SaleDurationTooLong is raised when the prospective duration, endTime minus the creation block timestamp, exceeds 30 days.

---

### REQ-053

> Prospective sale duration in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L85, SaleDurationTooLong.duration`  
Kind: `error-handling` · Force: `descriptive`

Checkable: SaleDurationTooLong.duration reports the prospective sale duration in seconds.

---

### REQ-054

> Maximum permitted sale duration in seconds.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L84-L86, SaleDurationTooLong.maximumDuration`  
Kind: `error-handling` · Force: `descriptive`

Checkable: SaleDurationTooLong.maximumDuration reports the fixed maximum of 30 days expressed in seconds.

---

### REQ-055

> Raised when a configured token or recipient is known protocol plumbing.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L89, UnsafeProtocolDestination @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsafeProtocolDestination is raised for a configured token that is known protocol plumbing; the interface does not define the covered token fields or the plumbing-address set.

---

### REQ-056

> Raised when a configured token or recipient is known protocol plumbing.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L89, UnsafeProtocolDestination @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsafeProtocolDestination is raised for a configured recipient that is known protocol plumbing; the interface does not define the covered recipient fields or the plumbing-address set.

---

### REQ-057

> Rejected address.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L90, UnsafeProtocolDestination.destination`  
Kind: `error-handling` · Force: `descriptive`

Checkable: UnsafeProtocolDestination.destination equals the address rejected as an unsafe protocol destination.

---

### REQ-058

> Raised when the exact configured prize is not owned by an active clone after escrow.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L93, PrizeEscrowVerificationFailed @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: PrizeEscrowVerificationFailed is raised if the newly created clone does not own the exact configured prize after escrow.

---

### REQ-059

> Raised when the exact configured prize is not owned by an active clone after escrow.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L93, PrizeEscrowVerificationFailed @notice`  
Kind: `error-handling` · Force: `descriptive`

Checkable: PrizeEscrowVerificationFailed is raised if the newly created clone is not Active after escrow.

---

### REQ-060

> Newly created clone expected to hold the prize and report `Active`.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L94, PrizeEscrowVerificationFailed.raffle`  
Kind: `error-handling` · Force: `descriptive`

Checkable: PrizeEscrowVerificationFailed.raffle identifies the newly created clone whose escrow or Active state verification failed.

---

### REQ-061

> ERC-721 prize contract.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L95, PrizeEscrowVerificationFailed.prizeToken`  
Kind: `error-handling` · Force: `descriptive`

Checkable: PrizeEscrowVerificationFailed.prizeToken equals the configured ERC-721 prize contract.

---

### REQ-062

> Configured prize token ID.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L96, PrizeEscrowVerificationFailed.prizeTokenId`  
Kind: `error-handling` · Force: `descriptive`

Checkable: PrizeEscrowVerificationFailed.prizeTokenId equals the configured prize token ID.

---

### REQ-063

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `state-machine` · Force: `descriptive`

Checkable: A successful createRaffle call creates one new raffle clone.

---

### REQ-064

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `state-machine` · Force: `descriptive`

Checkable: A successful createRaffle call initializes the new clone.

---

### REQ-065

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `state-machine` · Force: `descriptive`

Checkable: A successful createRaffle call registers the new clone.

---

### REQ-066

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `economic` · Force: `descriptive`

Checkable: A successful createRaffle call funds the new clone with the configured prize.

---

### REQ-067

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `other` · Force: `descriptive`

Checkable: Too vague to fully check: the interface does not define what additional properties make a raffle clone autonomous.

---

### REQ-068

> Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L101, createRaffle @notice`  
Kind: `ordering` · Force: `descriptive`

Checkable: Clone creation, initialization, registration, and prize funding succeed or revert together as one atomic operation.

---

### REQ-069

> Address of the newly created and activated clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L103, createRaffle @return raffle`  
Kind: `other` · Force: `descriptive`

Checkable: createRaffle returns the address of the clone created by that call.

---

### REQ-070

> Address of the newly created and activated clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L103, createRaffle @return raffle`  
Kind: `state-machine` · Force: `descriptive`

Checkable: The clone returned by a successful createRaffle call is activated.

---

### REQ-071

> Returns the immutable canonical six-decimal USDC contract used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L108, quoteToken @notice`  
Kind: `other` · Force: `descriptive`

Checkable: quoteToken() returns the quote-token contract address configured for this deployment.

---

### REQ-072

> Returns the immutable canonical six-decimal USDC contract used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L108, quoteToken @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured quote-token address is immutable.

---

### REQ-073

> Returns the immutable canonical six-decimal USDC contract used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L108, quoteToken @notice`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: The configured quote token is the target chain's canonical USDC contract; the interface does not supply its chain-specific address.

---

### REQ-074

> Returns the immutable canonical six-decimal USDC contract used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L108, quoteToken @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured quote token uses six decimal places.

---

### REQ-075

> Returns the immutable canonical six-decimal USDC contract used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L108, quoteToken @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every raffle created by the factory uses the factory's configured quote-token contract.

---

### REQ-076

> Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L112, vrfWrapper @notice`  
Kind: `other` · Force: `descriptive`

Checkable: vrfWrapper() returns the wrapper contract address configured for this deployment.

---

### REQ-077

> Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L112, vrfWrapper @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured VRF-wrapper address is immutable.

---

### REQ-078

> Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L112, vrfWrapper @notice`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: The configured wrapper is a Chainlink VRF v2.5 native direct-funding wrapper.

---

### REQ-079

> Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L112, vrfWrapper @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every raffle created by the factory uses the factory's configured VRF wrapper.

---

### REQ-080

> Returns the immutable recipient of protocol fees from every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L116, protocolTreasury @notice`  
Kind: `other` · Force: `descriptive`

Checkable: protocolTreasury() returns the configured protocol-fee recipient address.

---

### REQ-081

> Returns the immutable recipient of protocol fees from every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L116, protocolTreasury @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured protocol treasury address is immutable.

---

### REQ-082

> Returns the immutable recipient of protocol fees from every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L116, protocolTreasury @notice`  
Kind: `economic` · Force: `descriptive`

Checkable: Protocol fees are paid to the configured protocol treasury.

---

### REQ-083

> Returns the immutable recipient of protocol fees from every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L116, protocolTreasury @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every raffle created by the factory uses the same configured protocol-fee recipient.

---

### REQ-084

> Returns the fixed Chainlink callback execution limit used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L120, callbackGasLimit @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured Chainlink callback execution limit is fixed.

---

### REQ-085

> Callback gas units requested from the wrapper.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L121, callbackGasLimit @return gasLimit`  
Kind: `other` · Force: `descriptive`

Checkable: callbackGasLimit() returns the number of callback gas units requested from the wrapper.

---

### REQ-086

> Returns the fixed Chainlink callback execution limit used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L120, callbackGasLimit @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every raffle created by the factory uses the configured callback execution limit.

---

### REQ-087

> Returns the fixed Chainlink confirmation count used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L124, requestConfirmations @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured Chainlink confirmation count is fixed.

---

### REQ-088

> Blocks requested before callback fulfillment.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L125, requestConfirmations @return confirmations`  
Kind: `other` · Force: `descriptive`

Checkable: requestConfirmations() returns the number of blocks requested before callback fulfillment.

---

### REQ-089

> Returns the fixed Chainlink confirmation count used by every raffle.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L124, requestConfirmations @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every raffle created by the factory uses the configured Chainlink confirmation count.

---

### REQ-090

> Returns the immutable implementation targeted by every registered ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L128, raffleImplementation @notice`  
Kind: `other` · Force: `descriptive`

Checkable: raffleImplementation() returns the configured raffle implementation address.

---

### REQ-091

> Returns the immutable implementation targeted by every registered ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L128, raffleImplementation @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured raffle implementation address is immutable.

---

### REQ-092

> Returns the immutable implementation targeted by every registered ERC-1167 clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L128, raffleImplementation @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: Every registered clone targets the factory's configured raffle implementation.

---

### REQ-093

> Locked raffle implementation address.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L129, raffleImplementation @return implementation`  
Kind: `other` · Force: `descriptive`

Checkable: Too vague to fully check: the interface calls the implementation locked but does not define what locking must prevent.

---

### REQ-094

> Returns the lifetime number of successfully created raffles.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L132, raffleCount @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: raffleCount() equals the lifetime number of successful raffle creations.

---

### REQ-095

> Latest one-based raffle identifier and total registered raffle count.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L133, raffleCount @return count`  
Kind: `invariant` · Force: `descriptive`

Checkable: raffleCount() equals the latest assigned one-based raffle identifier when any raffle has been created.

---

### REQ-096

> Latest one-based raffle identifier and total registered raffle count.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L133, raffleCount @return count`  
Kind: `invariant` · Force: `descriptive`

Checkable: raffleCount() equals the total number of registered raffles.

---

### REQ-097

> Returns whether an address is a raffle registered by this factory.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L136, isRaffle @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: isRaffle(address) reports whether that address belongs to this factory's raffle registry.

---

### REQ-098

> True only for a successfully created canonical clone.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L138, isRaffle @return registered`  
Kind: `invariant` · Force: `descriptive`

Checkable: isRaffle(address) can return true only for a successfully created canonical clone.

---

### REQ-099

> Returns the canonical raffle address for an identifier.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L141, raffleById @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: raffleById(raffleId) returns the registered raffle address assigned to that canonical identifier.

---

### REQ-100

> Registered clone address, or the zero address for an unknown identifier.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L143, raffleById @return raffle`  
Kind: `error-handling` · Force: `descriptive`

Checkable: raffleById returns the zero address for an unknown identifier.

---

### REQ-101

> Returns the canonical identifier assigned to a raffle address.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L146, idByRaffle @notice`  
Kind: `invariant` · Force: `descriptive`

Checkable: idByRaffle(raffle) returns the canonical identifier assigned to the registered raffle address.

---

### REQ-102

> One-based identifier, or zero for an unregistered address.

Source: `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L148, idByRaffle @return raffleId`  
Kind: `error-handling` · Force: `descriptive`

Checkable: idByRaffle returns zero for an unregistered address.

