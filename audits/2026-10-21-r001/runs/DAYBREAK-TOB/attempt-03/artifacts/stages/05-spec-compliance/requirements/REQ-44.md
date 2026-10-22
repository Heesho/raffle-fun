## REQ-44 — Independent sponsor and treasury claims

> "Sponsor and treasury can claim independently after settlement."
> — DESIGN.md:L2, sentence 14

---

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** For the quoted requirement to hold, a successful settlement must create separately payable sponsor and treasury entitlements. Either entitlement must then be releasable in either order, each release must pay the complete corresponding allocation, and releasing one must neither consume nor gate the other. Because the sentence does not qualify the accepted raffle configurations for which this is true, the property must also survive configuration changes that the factory itself permits.

---

**Where enforcement lives:**

Settlement computes the protocol fee once, gives the sponsor the remainder in both result branches, and records the sponsor and protocol amounts in separate storage buckets:

```solidity
// packages/contracts/src/Raffle.sol:L539-L555
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

`Math.mulDiv` performs floor division (`packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L206,L210-L220,L274-L276`). The fixed rates are 5% protocol and 80% cash winner, while one sold entry contributes 1,000,000 raw units (`packages/contracts/src/libraries/RaffleConstants.sol:L11-L21`). Thus both the NFT-result sponsor remainder and the cash-result sponsor remainder are positive, and the protocol bucket is positive, on every settleable raffle: draw initiation requires at least one sold entry (`packages/contracts/src/Raffle.sol:L240-L247`), and purchases add `entryCount * ENTRY_PRICE` to `unsettledPot` (`packages/contracts/src/Raffle.sol:L209-L233`). The post-settlement zero-balance checks therefore do not block either first release on the ordinary path.

The two release entrypoints read the full value of only their own bucket, clear only that bucket, and transfer that exact value to their separately stored destination:

```solidity
// packages/contracts/src/Raffle.sol:L375-L391
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

Neither body has a caller-identity, winner-redemption, prize-release, other-bucket, or ordering condition (`packages/contracts/src/Raffle.sol:L375-L391`). The only modifier is `nonReentrant`; it marks the call entered before the body and restores `NOT_ENTERED` after the body, so it prevents nested execution without imposing a permanent order between separate transactions (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72,L88-L105`). `SafeERC20.safeTransfer` passes the requested amount to the token and reverts when the low-level operation reports failure (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L37,L176-L199`).

The gap is in the common payout helper's dynamic destination classification:

```solidity
// packages/contracts/src/Raffle.sol:L564-L566
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

```solidity
// packages/contracts/src/Raffle.sol:L598-L604
IRaffleFactory canonicalFactory = IRaffleFactory(factory);
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```

At creation, a sponsor recipient is rejected only if it is one of the fixed protocol addresses or is *already* registered as a raffle; a code-less, not-yet-registered address is accepted (`packages/contracts/src/RaffleFactory.sol:L154-L169`). Clone initialization repeats a current-state destination check and then stores that recipient (`packages/contracts/src/Raffle.sol:L176-L205,L593-L604`). The factory does not reserve stored recipients against later clone creation: it deploys a new clone and then sets `isRaffle[raffle] = true` (`packages/contracts/src/RaffleFactory.sol:L97-L125`). The selected `Clones.clone` path uses the EVM `CREATE` opcode (`packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L24-L33,L47-L60`), whose future address is deterministic from the creator and nonce.

Consequently, a sponsor can supply a code-less future same-factory clone address as `sponsorRecipient`. It passes the current checks. After a later creation deploys and registers the clone at that address, the earlier raffle's payout-time `_isProtocolDestination` query returns true and `releaseSponsorProceeds` reverts before calling the quote token (`packages/contracts/src/Raffle.sol:L564-L566,L598-L604`). The independently stored protocol fee remains releasable through `releaseProtocolFees` (`packages/contracts/src/Raffle.sol:L385-L391`), but the sponsor cannot claim its allocated bucket on this accepted path.

---

**Paths walked:**

- `settleWinningTicket` → `_settleWinningTicket`: the permissionless external caller reaches the private helper directly (`packages/contracts/src/Raffle.sol:L303-L306,L533-L558`). After the status and winning-range checks, both `NftWon` and `CashWon` allocate distinct sponsor and protocol buckets (`packages/contracts/src/Raffle.sol:L534-L555,L579-L585`). ✓
- `redeemWinningTicket` → `_settleWinningTicket`: when not yet settled, redemption invokes the same helper (`packages/contracts/src/Raffle.sol:L309-L318`). Its NFT branch changes only prize state, and its cash branch consumes only `winnerProceeds`; neither consumes `sponsorProceeds` nor `protocolFees` (`packages/contracts/src/Raffle.sol:L320-L345`). After a successful redemption transaction, both release buckets therefore remain available. ✓
- Stable destination, sponsor first: `releaseSponsorProceeds` clears and transfers the complete sponsor bucket; a later `releaseProtocolFees` still reads and transfers the untouched protocol bucket (`packages/contracts/src/Raffle.sol:L375-L391`). ✓
- Stable destination, treasury first: `releaseProtocolFees` clears and transfers only `protocolFees`; a later `releaseSponsorProceeds` still reads and transfers the untouched sponsor bucket (`packages/contracts/src/Raffle.sol:L375-L391`). ✓
- Nested callback attempt during either quote-token transfer: the shared guard rejects a nested `nonReentrant` entry, then resets after a successful outer call, so it does not prevent the other bucket from being released in a later call (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72,L88-L105`). ✓
- Stored sponsor recipient remains code-less or remains outside the same-factory registry: the helper's destination branch is false and the full recorded amount reaches `SafeERC20.safeTransfer` (`packages/contracts/src/Raffle.sol:L564-L566,L598-L604`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L37,L176-L199`). ✓
- Stored sponsor recipient is initially unregistered but later becomes a registered same-factory clone: creation-time validation accepts the initially code-less address (`packages/contracts/src/RaffleFactory.sol:L154-L169`; `packages/contracts/src/Raffle.sol:L181-L205,L598-L604`), a later `CREATE` clone can be registered there (`packages/contracts/src/RaffleFactory.sol:L105-L125`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L60`), and the payout-time destination branch then reverts (`packages/contracts/src/Raffle.sol:L564-L566,L598-L604`). ✗ — the sponsor's complete allocated entitlement is stranded while the treasury's separate path remains callable.

---

**Searched:**

- Scope inventory → exactly 5 first-party production files under `packages/contracts/src` and 31 paths in `dependency-hashes.json`; all were read, and all 31 dependency SHA-256 checks returned `OK`.
- `sponsorProceeds` across the 5 production files and 31 dependencies → 6 hits: declaration (`Raffle.sol:L103`), release read and clear (`L376,L378`), aggregate-balance read (`L469`), settlement write (`L554`), and interface getter (`IRaffle.sol:L476`); 0 dependency hits.
- `protocolFees` across the same scope → 6 hits: declaration (`Raffle.sol:L106`), release read and clear (`L386,L388`), aggregate-balance read (`L469`), settlement write (`L555`), and interface getter (`IRaffle.sol:L480`); 0 dependency hits.
- `settlementComplete` across the same scope → 5 hits: declaration (`Raffle.sol:L127`), redemption read (`L314`), duplicate-settlement check (`L534`), settlement write (`L551`), and interface getter (`IRaffle.sol:L508`).
- `releaseSponsorProceeds|releaseProtocolFees` followed by `(` → 4 hits: the two implementations (`Raffle.sol:L375,L385`) and two interface declarations (`IRaffle.sol:L348,L352`); no contract caller, wrapper, base implementation, or dependency implementation was found.
- `settleWinningTicket|_settleWinningTicket` → 5 hits: external implementation and direct call (`Raffle.sol:L304-L305`), redemption call (`L315`), private helper (`L533`), and interface declaration (`IRaffle.sol:L331`).
- Varied claim vocabulary `claim|claims|claimable|release|released|releases|withdraw|withdrawal|payout|payouts` → hits in only `Raffle.sol` (6 matching lines) and `IRaffle.sol` (23 matching lines); 0 matching dependency files.
- `isRaffle` across the same scope → 6 hits: payout-time lookup (`Raffle.sol:L603`), interface getter (`IRaffleFactory.sol:L139`), mapping declaration (`RaffleFactory.sol:L54`), its sole `true` write (`L125`), and the two creation-time current-registry checks (`L159,L166`).
- Exact recipient state writes `^\s*(sponsorRecipient|protocolTreasury)\s*=` → 3 hits: factory treasury construction (`RaffleFactory.sol:L87`) and clone initialization of sponsor recipient and treasury (`Raffle.sol:L198-L199`); no later setter.
- Reservation vocabulary `reserve(d|ation)?Recipient|recipient(s)?By|payoutRecipient|beneficiary|pendingRecipient|future.*raffle|predict.*raffle` → 0 hits across all 36 scoped source files. No reverse index or reservation prevents a later clone from taking a previously stored sponsor-recipient address.
- Modifiers and base contracts on both release entrypoints → `nonReentrant` only (`Raffle.sol:L375,L385`); its complete implementation was read at `ReentrancyGuard.sol:L32-L119`, including both guard branches and reset.

---

**How the verdict was reached:** This is `partial`, not `implemented`, because the ordinary NFT-result and cash-result paths genuinely allocate two independent buckets and permit full releases in either order, but an accepted, initially code-less sponsor recipient can later become a registered same-factory clone and trigger the payout-time rejection branch. It is not `contradicted` because every stable-recipient path works, the treasury remains independently releasable in the failing sponsor scenario, and the release functions do not cross-consume state. The failing path is source-visible and reachable without relying on missing quote-token behavior, so confidence is high.

---

**Open questions:**

- None for this verdict.
