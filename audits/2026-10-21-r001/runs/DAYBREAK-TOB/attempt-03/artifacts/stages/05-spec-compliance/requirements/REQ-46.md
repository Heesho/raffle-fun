## REQ-46 — sponsor and treasury claims remain independent

> "Sponsor and treasury can claim independently after settlement."
> — DESIGN.md:L2, sentence 14

---

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** A successful settlement must create separate sponsor and treasury entitlements. Either entitlement must be releasable while the other remains outstanding, in both release orders, and releasing one must neither consume nor disable the other. This availability must hold for every raffle configuration accepted by the factory; the document states no condition that a previously accepted sponsor recipient must remain outside the factory's registry.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L539-L555
uint256 grossPot = unsettledPot;
uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
uint256 sponsorAmount;

if (result == Status.NftWon) {
    sponsorAmount = grossPot - protocolFee;
} else {
    cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
    sponsorAmount = grossPot - protocolFee - cashAmount;
    winnerProceeds = cashAmount;
}

settlementComplete = true;
winningTicketId = ticketId;
unsettledPot = 0;
sponsorProceeds = sponsorAmount;
protocolFees = protocolFee;
```

- Both terminal-result branches converge on distinct `sponsorProceeds` and `protocolFees` writes; neither amount is represented by a shared claimed flag (`Raffle.sol:L533-L555`). A terminal result requires a draw with at least one sold entry (`Raffle.sol:L240-L260`, `L509-L523`), each purchase contributes a positive multiple of the 1,000,000-unit entry price (`Raffle.sol:L215-L233`; `RaffleConstants.sol:L20-L21`), and the fixed rates are 5% protocol plus either a 95% or 15% sponsor remainder (`RaffleConstants.sol:L11-L18`). Thus both release buckets are nonzero on every successful settlement path.

```solidity
// target/packages/contracts/src/Raffle.sol:L375-L391
function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
    amount = sponsorProceeds;
    if (amount == 0) revert NoSponsorProceeds();
    sponsorProceeds = 0;
    address recipient = sponsorRecipient;
    _transferQuote(recipient, amount);
    emit SponsorProceedsReleased(msg.sender, recipient, amount);
}

function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
    amount = protocolFees;
    if (amount == 0) revert NoProtocolFees();
    protocolFees = 0;
    address treasury = protocolTreasury;
    _transferQuote(treasury, amount);
    emit ProtocolFeesReleased(msg.sender, treasury, amount);
}
```

- On the ordinary path, each permissionless entrypoint reads and clears only its own bucket and pays its separately stored recipient; neither body reads or writes the other bucket (`Raffle.sol:L375-L391`). The only four assignments to these two buckets are their individual clears and the two settlement writes (`Raffle.sol:L378`, `L388`, `L554-L555`).
- Both entrypoints use the inherited shared guard. It rejects only while the guard equals `ENTERED`, sets that value around the body, and restores `NOT_ENTERED` after a successful return, so it blocks a nested claim but permits either completed claim to be followed by the other (`ReentrancyGuard.sol:L69-L72`, `L88-L105`). A fresh clone's zero-valued guard slot also passes the equality-to-`ENTERED` check before its first protected call (`ReentrancyGuard.sol:L88-L100`).
- `_transferQuote` invokes `SafeERC20.safeTransfer`; a false return or failed token call reverts rather than completing only the local bucket clear (`Raffle.sol:L560-L566`; `SafeERC20.sol:L30-L37`, `L168-L199`). The supplied implementation expressly trusts canonical, standard, fee-free, non-rebasing USDC semantics (`IRaffle.sol:L12-L15`).

The accepted-recipient and payout-time checks create an uncovered branch:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L154-L169
function _validateCreateParams(CreateRaffleParams calldata params) private view {
    _requireContract(params.prizeToken);
    if (params.sponsorRecipient == address(0)) revert ZeroAddress();
    if (
        params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
            || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
    ) {
        revert UnsafeProtocolDestination(params.prizeToken);
    }
    if (
        params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
            || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
            || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
    ) {
        revert UnsafeProtocolDestination(params.sponsorRecipient);
    }
```

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L125
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
// ... initialize the clone ...
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;
```

```solidity
// target/packages/contracts/src/Raffle.sol:L564-L566, L593-L604
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}

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

- Creation rejects only a sponsor recipient that is already a registered raffle or one of the listed current protocol addresses (`RaffleFactory.sol:L154-L169`). Clone initialization applies the same current-state classification and then stores the recipient (`Raffle.sol:L181-L205`, `L593-L604`). It does not reject an otherwise ordinary code-less address.
- The factory deploys clones with `Clones.clone` and then marks each deployed address permanently registered (`RaffleFactory.sol:L105-L125`). The selected library's used overload executes the EVM `create` opcode (`Clones.sol:L32-L61`), so a later clone address can be selected as an earlier raffle's sponsor recipient while that address is still code-less and unregistered.
- Every quote release re-runs `_isProtocolDestination` (`Raffle.sol:L560-L566`). Once that recipient address has become a registered clone, its nonzero code causes the registry lookup to return true and the sponsor release to revert before transfer (`Raffle.sol:L598-L604`). There is no alternate sponsor-proceeds release function or recipient setter in the supplied implementation; the only recipient assignment is initialization (`Raffle.sol:L176-L205`), and the only release declaration and implementation are `IRaffle.sol:L346-L352` and `Raffle.sol:L374-L391`.

---

**Paths walked:**

- `settleWinningTicket` → `_settleWinningTicket`, `NftWon`: allocates protocol fee and the remaining pot to separate treasury and sponsor buckets (`Raffle.sol:L303-L306`, `L533-L555`). ✓
- `settleWinningTicket` → `_settleWinningTicket`, `CashWon`: allocates winner proceeds, then writes the separate sponsor remainder and protocol fee (`Raffle.sol:L303-L306`, `L533-L555`). ✓
- `redeemWinningTicket` → `_settleWinningTicket`: when settlement has not happened, redemption reaches the same allocator before any winner delivery (`Raffle.sol:L309-L345`). ✓
- Sponsor first → treasury second: the first call clears only `sponsorProceeds`; `protocolFees` remains readable and releasable by the second call (`Raffle.sol:L375-L391`). The guard resets between completed calls (`ReentrancyGuard.sol:L69-L72`, `L94-L105`). ✓
- Treasury first → sponsor second: the first call clears only `protocolFees`; `sponsorProceeds` remains readable and releasable by the second call (`Raffle.sol:L375-L391`). The same guard-reset path applies (`ReentrancyGuard.sol:L69-L72`, `L94-L105`). ✓
- Repeat the same entitlement: its own zero check rejects a second release without touching the other entitlement (`Raffle.sol:L375-L391`). ✓
- Accepted future-clone sponsor recipient: create raffle A with a code-less address of a later `CREATE` clone as `sponsorRecipient`; current-registry validation accepts it (`RaffleFactory.sol:L97-L106`, `L154-L169`; `Raffle.sol:L181-L205`, `L593-L604`; `Clones.sol:L32-L61`). Create and register that later clone B before A settles (`RaffleFactory.sol:L105-L125`). Settlement still allocates both A liabilities (`Raffle.sol:L533-L555`), and the treasury release remains available, but A's sponsor release now reclassifies B as a protocol destination and reverts (`Raffle.sol:L375-L391`, `L560-L566`, `L593-L604`). ✗ — a factory-accepted lifecycle path blocks the sponsor entitlement independently of claim order.
- Quote-token transfer failure: `SafeERC20` rejects a false or reverting transfer (`SafeERC20.sol:L30-L37`, `L176-L199`); this does not introduce a path that consumes the other bucket, although delivery ultimately relies on the documented trusted-token assumption (`IRaffle.sol:L12-L15`). ✓ for bucket independence.

---

**Searched:**

- Dependency manifest scope → all 31 listed dependency hashes matched; exact-name and vocabulary searches covered those dependencies plus all five production Solidity files.
- `sponsorProceeds|protocolFees` → 11 hits: two declarations, four release read/write uses, one aggregate-balance expression, two settlement writes, and two interface getters (`Raffle.sol:L103-L106`, `L375-L391`, `L467-L470`, `L533-L555`; `IRaffle.sol:L474-L480`).
- assignments matching `(sponsorProceeds|protocolFees) =` → exactly 4 hits: `Raffle.sol:L378`, `L388`, `L554`, and `L555`; no base contract or dependency writes either entitlement.
- `releaseSponsorProceeds(` / `releaseProtocolFees(` → exactly 4 hits: the two interface declarations and the two external implementations (`IRaffle.sol:L346-L352`; `Raffle.sol:L374-L391`); no in-scope caller, wrapper, or alternate claim entrypoint.
- `_transferQuote(` → exactly 5 hits: winner, refund, sponsor, and protocol call sites plus the helper definition (`Raffle.sol:L339-L342`, `L367-L369`, `L375-L390`, `L560-L566`); all branches of the helper and its destination classifier were read (`Raffle.sol:L593-L604`).
- `claim|claims|claimable|release|released|withdraw|withdrawal|payout|proceeds|protocol fee|treasury` → 46 hits across the scoped Solidity files; no additional sponsor/protocol withdrawal route was present.
- `sponsorRecipient =|protocolTreasury =` → the clone recipients are assigned only during initialization (`Raffle.sol:L197-L200`), while the factory treasury is assigned only in construction (`RaffleFactory.sol:L65-L91`).
- `isRaffle[...] = false` / registry `delete` variants → 0 hits; registration has one `true` write (`RaffleFactory.sol:L123-L125`).
- release modifiers and inherited implementation → both releases use `nonReentrant` (`Raffle.sol:L374-L391`); the modifier and its before/after branches are in `ReentrancyGuard.sol:L69-L105`.

---

**How the verdict was reached:** The implementation is not wholly contradicted: for recipients that remain outside the factory registry, settlement produces two nonzero buckets, either release can go first, and each release leaves the other bucket untouched (`Raffle.sol:L533-L555`, `L375-L391`). It is not fully implemented because the factory accepts a code-less future clone address as `sponsorRecipient`, later registers that address, and the payout-time classifier then makes the sponsor bucket unreleaseable (`RaffleFactory.sol:L105-L125`, `L154-L169`; `Clones.sol:L32-L61`; `Raffle.sol:L560-L566`, `L593-L604`). Because the requirement holds on the ordinary recipient paths and fails on this reachable accepted-recipient path, `partial` is the precise category rather than `implemented` or `contradicted`.

---

**Open questions:** None.
