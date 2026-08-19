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
| Ownership changes around draw        | live `ownerOf` bearer semantics; claim burns atomically                                |
| Missing draw caller                  | permissionless full refunds at `endTime + 2 days`                                      |
| Missing callback                     | permissionless full refunds two days after the accepted request                        |
| Broken winner delivery               | settlement is transfer-free; failure affects only the winner's later release           |
| Fake or replayed randomness          | immutable-wrapper authentication, request match, one-way status                        |
| Callback griefing                    | callback performs storage only and no user or token calls                              |
| Cash branch diverts sponsor value    | fixed gross split: 80% winner / 5% protocol / 15% sponsor                              |
| Double settlement                    | winning and refund tickets burn; claims zero before their individual transfers         |
| Taxed or rebasing quote token        | exact inbound and outbound balance-delta verification                                  |
| One claimant blocks another          | separate winner, sponsor, treasury, and refund paths                                   |
| Contract winner rejects NFT callback | fixed-owner delivery uses `transferFrom` plus ownership verification                   |
| Protocol sink receives claim         | known factory, raffle, implementation, token, wrapper, and prize destinations rejected |

## Adversaries

The tests model malicious buyers, ticket receivers, prize receivers, ERC-20 return
values and balance behavior, reentrancy attempts, wrapper-authenticated ABI-decodable
synchronous or wrong-word-count callbacks, unauthorized or undecodable calls that
revert earlier, wrong request IDs, strict request/callback deadline boundaries,
duplicate tickets, and failed outgoing transfers.

The factory owner is treated as potentially compromised after deployment. Its only
power is pausing or unpausing future creation, so compromise cannot change an existing
raffle. The sponsor is untrusted except that the prize collection itself must satisfy
the supported-asset assumptions.

## External dependencies and explicit limitations

### Prize collection

ERC-165 admission cannot prove honest future behavior. A malicious or upgradeable
collection may lie about ownership, reenter, freeze, burn, or misdirect a prize. The
post-transfer ownership check prevents a no-op or misdirected release from committing.
A noncompliant NFT can block the winner's prize release indefinitely, but settlement
and the independent quote claims remain available.

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
NFT or initiate its own refunds. Permissionless winning-ticket settlement snapshots
the current owner; later winner, sponsor, and treasury releases always use their fixed
recorded recipients. A bad winner destination can therefore strand only its own claim.

Lost keys, mistaken external transfers, and unrelated NFTs forced into a raffle are
not recoverable. There is no administrator rescue desk.

### Operations and law

RPCs, subgraphs, websites, wallets, metadata hosts, keepers, and key management can
fail or mislead; onchain state remains authoritative. Chance-based prize distribution
may be regulated or prohibited, and legal/compliance review is outside smart-contract
correctness.
