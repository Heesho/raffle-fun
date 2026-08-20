# Threat model

## Security objective

For an honest standards-compliant ERC-721 prize and available exact-transfer official
USDC, each protocol-controlled state should expose a bounded path for the rightful
ticket owner or sponsor to consume the prize and every accounted quote liability.
No administrator may alter an existing raffle, choose its winner, or seize its assets.

## Enforced controls

| Threat                               | Control                                                                                |
| ------------------------------------ | -------------------------------------------------------------------------------------- |
| Clone initialization theft           | implementation locked; clone initialization factory-only and one-time                  |
| Partial creation                     | clone, registration, exact prize escrow, and postconditions are atomic                 |
| Admin rewrite                        | fixed-target clone; no upgrade, raffle owner, rescue, or settlement override           |
| Sponsor cancels after sales          | no sold-raffle cancellation path                                                       |
| Unbounded entry work                 | one stored range per ticket; purchase, callback, and winner proof are O(1)             |
| Ownership changes around draw        | live `ownerOf` bearer semantics; owner redemption burns atomically                     |
| Missing draw caller                  | permissionless full refunds at `endTime + 2 days`                                      |
| Missing callback                     | permissionless full refunds two days after the accepted request                        |
| Broken winner delivery               | accounting-only settlement; failed redemption restores ticket and claim                |
| Fake or replayed randomness          | immutable-wrapper authentication, request match, one-way status                        |
| Callback griefing                    | callback performs storage only and no user or token calls                              |
| Cash branch diverts sponsor value    | fixed gross split: 80% winner / 5% protocol / 15% sponsor                              |
| Double settlement or redemption      | one-time markers; winner/refund tickets burn atomically with payment                   |
| Taxed or rebasing quote token        | exact inbound and outbound balance-delta verification                                  |
| One claimant blocks another          | separate winner, sponsor, treasury, and refund paths                                   |
| Contract winner rejects NFT callback | owner redemption uses `transferFrom` plus ownership verification                       |
| Protocol sink receives claim         | known factory, raffle, implementation, token, wrapper, and prize destinations rejected |

## Adversaries

The tests model malicious buyers, ticket receivers, prize receivers, ERC-20 return
values and balance behavior, reentrancy attempts, wrapper-authenticated ABI-decodable
synchronous or wrong-word-count callbacks, unauthorized or undecodable calls that
revert earlier, wrong request IDs, strict request/callback deadline boundaries,
duplicate tickets, and failed outgoing transfers.

The factory has no owner, role, pause, upgrade, rescue, or mutable configuration. The
sponsor is untrusted except that the prize collection itself must satisfy the
supported-asset assumptions. Incident containment for future creation is therefore
offchain discovery/UI action plus migration to a new factory, not an administrative
transaction against the deployed factory.

## External dependencies and explicit limitations

### Prize collection

ERC-165 admission cannot prove honest future behavior. A malicious or upgradeable
collection may lie about ownership, reenter, freeze, burn, or misdirect a prize. The
post-transfer ownership check prevents a no-op or misdirected redemption from committing.
A noncompliant NFT can block winner redemption indefinitely, but failed delivery
restores the ticket, redemption markers, and any settlement performed inside that
transaction. Anyone can settle separately so sponsor and treasury quote claims remain
available while the winning ticket stays transferable and unburned.

### USDC

Issuer blacklists, pauses, upgrades, and chain-specific behavior can prevent payments.
Balance-delta checks turn non-exact behavior into a revert; they cannot restore token
availability. Direct USDC donations are surplus with no rescue path.

### Chainlink and Ethereum

The official wrapper authenticates delivered words, but fulfillment may be delayed or
absent. Ethereum may reorder transactions, reorganize, censor, or halt. Deadline
boundaries are hard and disjoint: requests and callbacks must be included before their
cutoffs, while the corresponding refund path opens at the cutoff. Censorship or a
reorganization that removes a request or callback after its cutoff prevents replay and
can force the refund outcome. Thirty confirmations reduce, rather than eliminate,
reorg risk.

### Users and destinations

The protocol blocks known internal sinks, not every arbitrary contract or future
address. A user can still transfer a ticket to a contract that cannot manage a received
NFT, initiate its own refunds, or call winner redemption. Permissionless settlement
does not read or fix the ticket owner. After settlement the ticket remains transferable,
and only its current owner can atomically burn it for the winner NFT or cash. Sponsor
and treasury releases always use their immutable recipients, so a bad winner
destination can strand only its own bearer claim.

Lost keys, mistaken external transfers, and unrelated NFTs forced into a raffle are
not recoverable. There is no administrator rescue desk.

### Operations and law

RPCs, subgraphs, websites, wallets, metadata hosts, keepers, and key management can
fail or mislead; onchain state remains authoritative. Chance-based prize distribution
may be regulated or prohibited, and legal/compliance review is outside smart-contract
correctness.
