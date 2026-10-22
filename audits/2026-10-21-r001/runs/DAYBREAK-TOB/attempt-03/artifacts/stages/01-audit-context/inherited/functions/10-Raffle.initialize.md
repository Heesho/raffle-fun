## `initialize` in `target/packages/contracts/src/Raffle.sol` (L176-L206)

**Purpose:** Establishes the complete per-raffle configuration in a fresh ERC-1167 clone, permanently closes the clone's initialization gate, and places the clone in `AwaitingPrize` so that only the subsequently configured factory-mediated prize deposit can activate it (`Raffle.sol:L176-L206`, `L416-L430`). The implementation contract is not an initialization target: its constructor sets its own `initialized` storage to true and its status to `Refunding`, while the source states that clones share the implementation's immutables but keep isolated storage (`Raffle.sol:L151-L165`).

---

**Inputs & Assumptions:**

- `params.sponsor` (`address`): the prize depositor and the authority that may close an empty active raffle before its end time (`IRaffle.sol:L36-L53`; `Raffle.sol:L279-L284`). Trust: **untrusted origin**. `RaffleFactory.createRaffle` is externally callable and maps its `msg.sender` into this field (`RaffleFactory.sol:L97`, `L109-L120`).
- `params.sponsorRecipient` (`address`): the immutable-per-raffle destination of sponsor quote proceeds and a returned prize (`IRaffle.sol:L36-L53`; `Raffle.sol:L375-L380`, `L395-L405`). Trust: **untrusted origin**. It comes directly from the sponsor's creation parameters (`RaffleFactory.sol:L97`, `L111-L120`).
- `params.protocolTreasury` (`address`): the destination of protocol-fee releases (`IRaffle.sol:L36-L53`; `Raffle.sol:L385-L390`). Trust: **trusted configuration**. The caller copies the factory's constructor-fixed `protocolTreasury` into this field (`RaffleFactory.sol:L38-L39`, `L65-L91`, `L109-L120`).
- `params.prizeToken` (`address`) and `params.prizeTokenId` (`uint256`): the sponsor-selected ERC-721 contract and token identifier that the factory attempts to escrow after initialization (`IRaffle.sol:L36-L53`; `RaffleFactory.sol:L127-L134`). Trust: **semi-trusted token / untrusted identifier**. Before cloning, the factory requires code at the token address, excludes listed protocol destinations, and requires an ERC-165 call to return support for the ERC-721 interface (`RaffleFactory.sol:L154-L177`, `L181-L185`). The interface nevertheless explicitly assumes that supported prizes are honest, standards-compliant ERC-721s (`IRaffle.sol:L12-L15`).
- `params.raffleId` (`uint256`): the intended one-based factory identifier (`IRaffle.sol:L36-L53`). Trust: **trusted factory-generated value**. `createRaffle` pre-increments `raffleCount`, supplies that value here, and records the clone under the same value after initialization (`RaffleFactory.sol:L105-L125`).
- `params.reserveEntries` (`uint128`): the threshold later compared against `totalEntries` to choose `NftWon` or `CashWon` (`IRaffle.sol:L36-L53`; `Raffle.sol:L518-L523`). Trust: **untrusted origin, factory-validated**. The factory rejects zero before cloning (`RaffleFactory.sol:L154-L178`).
- `params.endTime` (`uint64`): the exclusive sale end later read by purchase, draw, and refund paths (`IRaffle.sol:L36-L53`; `Raffle.sol:L215-L216`, `L240-L246`, `L279-L291`). Trust: **untrusted origin, factory-validated**. The factory requires it to be later than the creation block timestamp and no more than the fixed 30-day maximum away (`RaffleFactory.sol:L99-L104`; `RaffleConstants.sol:L29-L30`).
- Implicit `msg.sender`: must equal the implementation-baked `factory` immutable (`Raffle.sol:L54-L55`, `L178`). The factory becomes that immutable because it deploys the implementation with `new Raffle` and the implementation constructor records its `msg.sender` (`RaffleFactory.sol:L89-L91`; `Raffle.sol:L155-L162`).
- Implicit clone storage: `initialized` must be false on entry (`Raffle.sol:L177`). The implementation is deliberately locked with `initialized = true`, while clone storage is described as isolated from constructor state (`Raffle.sol:L151-L165`); the factory calls the initializer immediately after creating a fresh fixed-target clone (`RaffleFactory.sol:L105-L121`; `Clones.sol:L10-L16`, `L23-L62`).
- Implicit immutable configuration: the screening helper reads `factory`, `quoteToken`, and the inherited VRF-wrapper immutable, and treats `address(this)` as the executing clone (`Raffle.sol:L54-L58`, `L593-L604`; `VRFV2PlusWrapperConsumerBase.sol:L34-L47`). These values are fixed during implementation construction and are reached through the clone's fixed delegate target (`RaffleFactory.sol:L85-L91`; `Clones.sol:L10-L16`, `L51-L62`).
- Implicit factory state: `_isProtocolDestination` reads the factory's immutable `raffleImplementation` and its `isRaffle` registry (`Raffle.sol:L598-L604`; `RaffleFactory.sol:L41-L54`). The factory writes `isRaffle[raffle] = true` only after this initializer returns, so initialization sees earlier registered clones; the current clone is independently excluded through `destination == address(this)` (`RaffleFactory.sol:L109-L125`; `Raffle.sol:L599-L604`).
- Precondition: the fixed implementation address supplied to `Clones.clone` contains the freshly deployed `Raffle` code. Established by the factory constructor deploying that implementation and storing the resulting immutable address (`RaffleFactory.sol:L89-L91`), then using exactly it in `Clones.clone` (`RaffleFactory.sol:L105-L106`). The generic clone library itself does not perform an implementation-code check (`Clones.sol:L23-L33`).
- Precondition: the configured quote token and VRF wrapper are the intended canonical deployments. The factory checks that both contain code, checks that the quote token reports six decimals, and documents that deployment tooling must verify official identity (`RaffleFactory.sol:L58-L78`). **Nothing found** in the target source proves the external deployment identities.
- Precondition: the prize contract continues to behave as an honest ERC-721 during escrow and later delivery. The factory checks code and a claimed ERC-721 interface response and later verifies ownership/state after escrow (`RaffleFactory.sol:L127-L134`, `L154-L177`), while the interface declares honest standards-compliant prize behavior as an assumption (`IRaffle.sol:L12-L15`). **Nothing found** makes arbitrary sponsor-selected code honor that behavior on every path.

---

**Outputs & Effects:**

- Returns no value and emits no event in the initializer itself (`Raffle.sol:L176-L206`). The factory emits `RaffleCreated` only after registration, prize transfer, ownership verification, and the clone's transition to `Active` (`RaffleFactory.sol:L123-L147`).
- Reverts with `AlreadyInitialized` whenever clone storage is already locked and on every direct call to the implementation (`Raffle.sol:L177`; `IRaffle.sol:L187-L188`; implementation lock at `Raffle.sol:L164-L165`).
- Reverts with `OnlyFactory` for a first call whose caller is not the immutable factory (`Raffle.sol:L178`; `IRaffle.sol:L184-L185`).
- Sets `initialized = true` before any destination screening call; a later revert rolls back this write with the rest of the call, while every successful path leaves the one-time gate closed (`Raffle.sol:L177-L195`).
- Rejects zero values for `sponsor`, `sponsorRecipient`, `protocolTreasury`, and `prizeToken` (`Raffle.sol:L181-L186`).
- Rejects any of the three configured human/economic destinations that `_isProtocolDestination` classifies as the current clone, factory, quote token, wrapper, prospective prize token, implementation, or an already registered same-factory raffle (`Raffle.sol:L187-L195`, `L593-L604`).
- Writes `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, and `endTime` exactly once from `params`, then explicitly writes `status = AwaitingPrize` (`Raffle.sol:L197-L205`; status meaning at `IRaffle.sol:L20-L33`).
- Makes no token transfer and takes no asset custody (`Raffle.sol:L176-L206`). The caller's next custody step is `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)`, followed by owner and lifecycle verification (`RaffleFactory.sol:L127-L134`).
- Performs no calls to the sponsor-selected prize token. Its external interactions are the source-available factory getter calls nested in `_isProtocolDestination`: `raffleImplementation()` and, for otherwise-accepted code-bearing destinations, `isRaffle(destination)` (`Raffle.sol:L593-L604`; getter state at `RaffleFactory.sol:L41-L54`).
- On success, the stored prize fields and sponsor/factory identities become the complete acceptance predicate for `onERC721Received`; only the configured token, ID, sponsor, and factory operator in `AwaitingPrize` advance the clone to `Active` (`Raffle.sol:L416-L430`).

---

**Block-by-Block:**

```solidity
// Raffle.sol:L176-L179
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;
```

- **What:** Checks the per-instance initialization lock, authenticates the caller against the immutable factory, and closes the lock (`Raffle.sol:L176-L179`).
- **Why here:** Both gates precede configuration writes. The lock write also precedes every external factory getter reached through destination screening, so a nested call that returned to `initialize` would observe `initialized == true`; any later failure reverts the whole call (`Raffle.sol:L177-L195`).
- **Assumes:** `factory` identifies the canonical caller. This is established when the factory deploys the implementation and the implementation records `msg.sender` (`RaffleFactory.sol:L89-L91`; `Raffle.sol:L155-L162`).
- **Establishes:** For the remainder of a successful execution, only the canonical factory is configuring a previously uninitialized storage instance; after success, the same storage instance cannot pass L177 again (`Raffle.sol:L177-L179`).
- **Depended on by:** Every immutable-per-raffle configuration field and every later lifecycle path assumes these fields cannot be replaced (`Raffle.sol:L60-L82`, `L197-L205`; the interface describes one-time factory initialization at `IRaffle.sol:L303-L308`).
- **Path distinction:** Because the lock check precedes the caller check, the locked implementation and an initialized clone return `AlreadyInitialized` without testing caller identity; a fresh clone called by a non-factory reaches `OnlyFactory` (`Raffle.sol:L177-L178`).

```solidity
// Raffle.sol:L181-L195
if (
    params.sponsor == address(0) || params.sponsorRecipient == address(0)
        || params.protocolTreasury == address(0) || params.prizeToken == address(0)
) {
    revert ZeroAddress();
}
if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsor);
}
if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.protocolTreasury);
}
if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```

- **What:** Rejects four zero addresses, then applies the same known-protocol-destination classifier to the sponsor, treasury, and sponsor recipient, using the prospective prize-token address because clone storage has not been populated (`Raffle.sol:L181-L195`, `L587-L604`).
- **Why here:** Zero checks occur before helper calls, and every screen occurs before any per-raffle configuration is committed at L197-L205 (`Raffle.sol:L181-L205`). Passing `params.prizeToken` into each helper lets the checks reject a destination equal to the prize token before `prizeToken` storage is assigned (`Raffle.sol:L193-L200`, `L587-L600`).
- **Assumes:** The canonical factory's generated `raffleImplementation()` and `isRaffle(address)` getters return its fixed implementation and registry state. The source establishes these as a public immutable and a public mapping; the implementation is written in the constructor and registry entries are written during successful creation (`RaffleFactory.sol:L41-L54`, `L89-L91`, `L123-L125`).
- **Establishes:** Each required address is nonzero, and the three screened destinations are not any same-factory plumbing recognized by `_isProtocolDestination` at this point in the transaction (`Raffle.sol:L181-L195`, `L593-L604`).
- **Does not establish locally:** `initialize` does not itself require prize-token code, ERC-721 interface support, a nonzero reserve, a future/bounded end time, a one-based unique `raffleId`, or equality between `params.protocolTreasury` and the factory's configured treasury (`Raffle.sol:L176-L206`). The sole source caller establishes these through `_validateCreateParams`, time checks, ID allocation, and its fixed argument construction (`RaffleFactory.sol:L98-L120`, `L154-L178`).
- **Depended on by:** The stored sponsor is later both a callback field and the scoped empty-raffle caller; the stored recipients are later payout/prize destinations; the stored prize token is later a callback caller, an asset contract, and an excluded ticket/payout destination (`Raffle.sol:L279-L284`, `L329-L342`, `L375-L405`, `L416-L430`, `L497-L502`, `L564-L566`).

The helper followed on all visible paths is:

```solidity
// Raffle.sol:L593-L604
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```

- **Direct-comparison path:** A match against the clone, factory, quote token, wrapper, or prospective prize token short-circuits before the implementation getter; a match against the factory's implementation is obtained from `raffleImplementation()` (`Raffle.sol:L598-L601`).
- **Registry path:** Only a destination not already classified and having deployed code is looked up in `isRaffle`; code-less destinations are accepted without a registry query after the direct comparisons (`Raffle.sol:L602-L604`).
- **External-call behavior:** Both potential callees are source-available factory getters over state declared at `RaffleFactory.sol:L41-L54`; neither getter path calls a sponsor-selected address. If either getter call reverts, the helper and initialization revert because there is no catch in `Raffle.sol:L593-L604`.
- **Current-clone ordering:** The factory does not register the new clone until initialization returns (`RaffleFactory.sol:L109-L125`), but `destination == address(this)` excludes the executing clone without relying on that registry entry (`Raffle.sol:L599-L604`).

```solidity
// Raffle.sol:L197-L205
sponsor = params.sponsor;
sponsorRecipient = params.sponsorRecipient;
protocolTreasury = params.protocolTreasury;
prizeToken = IERC721(params.prizeToken);
prizeTokenId = params.prizeTokenId;
raffleId = params.raffleId;
reserveEntries = params.reserveEntries;
endTime = params.endTime;
status = Status.AwaitingPrize;
```

- **What:** Copies the complete struct into typed clone storage and sets the initial lifecycle state (`Raffle.sol:L197-L205`).
- **Why here:** All validation and registry queries finish before these writes. `status` is written after every callback-authentication field, so a successfully initialized clone cannot expose the intended `AwaitingPrize` configuration with only a prefix of fields assigned (`Raffle.sol:L197-L205`; callback reads at `L421-L424`).
- **Assumes:** The factory constructed the struct with its caller as sponsor, its fixed treasury, its newly allocated ID, and the already-validated sponsor inputs. This is established in the only source call site (`RaffleFactory.sol:L97-L120`, `L154-L178`).
- **Establishes:** Stored configuration equals the caller-supplied struct, `initialized` remains true from L179, and the next intended lifecycle transition is the exact prize-receiver callback (`Raffle.sol:L179`, `L197-L205`, `L416-L430`).
- **Depended on by:** `buyEntries`, `requestDraw`, and `enableRefunds` use `endTime` and sponsor identity (`Raffle.sol:L215-L216`, `L240-L246`, `L279-L291`); fulfillment uses `reserveEntries` (`Raffle.sol:L518-L523`); redemption and release paths use the token and recipients (`Raffle.sol:L329-L342`, `L375-L405`); the callback uses sponsor, prize, and factory identity (`Raffle.sol:L421-L424`).

---

**Cross-Function Dependencies:**

- **Callee `_isProtocolDestination` (internal, `Raffle.sol:L593-L605`):** Read in full. It establishes only that a candidate does not match its enumerated current-clone/same-factory plumbing set. It passes the prospective prize token because `initialize` has not written `prizeToken` storage yet, and it conditionally consults the factory registry only for code-bearing destinations (`Raffle.sol:L587-L604`).
- **Nested callee `RaffleFactory.raffleImplementation()` (external-source-available, declaration at `RaffleFactory.sol:L41-L42`):** Supplies the fixed implementation address used by every destination screen. The constructor writes that immutable immediately after deploying and locking the implementation (`RaffleFactory.sol:L89-L91`).
- **Nested callee `RaffleFactory.isRaffle(address)` (external-source-available, declaration at `RaffleFactory.sol:L53-L54`):** Supplies whether a code-bearing destination is an already registered same-factory clone. `createRaffle` writes the mapping for the current clone only after initialization (`RaffleFactory.sol:L109-L125`).
- **Caller `RaffleFactory.createRaffle` (`RaffleFactory.sol:L97-L148`):** The only source call site. It validates sponsor-selected fields and timing, allocates an ID, creates the clone, initializes it, registers it, asks the selected ERC-721 to transfer the prize, verifies both ownership and `Active` state, and only then emits creation (`RaffleFactory.sol:L98-L147`). Its `nonReentrant` modifier surrounds this complete path (`RaffleFactory.sol:L97`; `ReentrancyGuard.sol:L69-L72`, `L94-L105`).
- **Upstream `_validateCreateParams` (`RaffleFactory.sol:L154-L179`):** Establishes prize-token code presence, prize/recipient exclusions, a successful true ERC-721 interface response, and a nonzero reserve. Its ERC-165 query treats a revert or false return as unsupported (`RaffleFactory.sol:L154-L178`). `_requireContract` is a code-length check only (`RaffleFactory.sol:L181-L185`).
- **Upstream factory constructor (`RaffleFactory.sol:L65-L92`):** Checks quote-token and wrapper code, quote-token decimals, and treasury exclusions; stores all fixed addresses; deploys the implementation; excludes the treasury from the resulting implementation address; and fixes `raffleImplementation` (`RaffleFactory.sol:L65-L92`).
- **Implementation constructor (`Raffle.sol:L151-L166`):** Validates a nonzero wrapper through `_validatedVrfWrapper`, records implementation-baked factory and quote-token immutables, and locks only the implementation's storage (`Raffle.sol:L155-L165`, `L607-L613`). The inherited wrapper constructor also calls `wrapper.link()` and stores both LINK and wrapper immutables (`VRFV2PlusWrapperConsumerBase.sol:L34-L47`).
- **Clone path `Clones.clone` (caller-side, `Clones.sol:L23-L62`):** Deploys a fixed-target minimal proxy with `create`, reverts if creation returns the zero address, and does not itself check target code (`Clones.sol:L23-L62`). Here the target is the factory's immutable, freshly deployed `raffleImplementation` (`RaffleFactory.sol:L89-L91`, `L105-L106`). Constructor storage is not copied into the clone; the Raffle source explicitly distinguishes locked implementation storage from isolated clone storage (`Raffle.sol:L151-L165`).
- **Downstream `onERC721Received` (`Raffle.sol:L416-L431`):** Consumes the configuration as an authentication tuple. It requires `AwaitingPrize`, `msg.sender == prizeToken`, the configured token ID, `from == sponsor`, and `operator == factory`; only then does it set `Active` and emit `PrizeDeposited` (`Raffle.sol:L421-L430`).
- **Downstream factory verification (`RaffleFactory.sol:L127-L134`):** After the ERC-721 transfer/callback, the factory requires the prize token to report clone ownership and the clone to report `Active` (`RaffleFactory.sol:L127-L134`). Failure anywhere after clone creation reverts the enclosing creation call; the factory describes creation/funding/registration as atomic (`RaffleFactory.sol:L15-L19`, `L96-L107`).
- **Shared state:** `initialized` is read and written only by constructor/initializer paths (`Raffle.sol:L135-L136`, `L164-L165`, `L177-L179`). The eight configuration fields are declared at `Raffle.sol:L60-L82` and written together only here (`Raffle.sol:L197-L204`). `status` is initialized here and subsequently written by prize receipt, draw request, refund activation, and accepted fulfillment (`Raffle.sol:L205`, `L428`, `L252`, `L299`, `L521`).
- **Invariant coupling — factory/clone identity:** The clone's immutable `factory` and `quoteToken` come from implementation construction, while clone-specific treasury and identifier come from the initializer. Their coherence is established by the single fixed argument construction in `createRaffle`, not by equality checks inside `initialize` (`Raffle.sol:L155-L162`, `L176-L205`; `RaffleFactory.sol:L109-L120`).
- **Invariant coupling — registry identity:** The factory increments `raffleCount`, passes that ID into the clone, then writes the bidirectional registry with the same ID/address after initialization (`RaffleFactory.sol:L105-L125`). The initializer stores the supplied ID without querying those mappings (`Raffle.sol:L202`).
- **Invariant coupling — custody activation:** Initialization alone creates no custody and leaves the clone waiting. The stored tuple controls the receiver transition, and factory-side ownership/status checks complete the activation sequence (`Raffle.sol:L200-L205`, `L416-L430`; `RaffleFactory.sol:L127-L134`).
- **Invariant coupling — later economics and timing:** `reserveEntries` fixes the result threshold and `endTime` fixes sale/draw/refund timing; neither can be modified after the one-time initializer because no other writer appears in the source (`Raffle.sol:L78-L82`, `L176-L205`, `L215-L216`, `L240-L246`, `L279-L291`, `L518-L523`).

---

**Open Questions:**

- unclear; need to inspect deployment records or live chain configuration outside the target source to confirm that the addresses passed as quote token and VRF wrapper are the intended official deployments; source checks only code presence and quote decimals and assigns identity verification to deployment tooling (`RaffleFactory.sol:L58-L78`).
- unclear; need to inspect each dynamically selected prize-token implementation to determine its behavior beyond the code-presence, ERC-165 response, transfer-time ownership check, and documented honest-ERC-721 assumption visible here (`IRaffle.sol:L12-L15`; `RaffleFactory.sol:L127-L134`, `L154-L177`).
