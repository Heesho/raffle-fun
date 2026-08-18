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
| Missing draw caller                  | request remains permissionless forever after sale end                                  |
| Missing callback                     | permissionless full refunds after two days                                             |
| Broken winner delivery               | honest ERC-721 behavior is an explicit supported-asset assumption                      |
| Fake or replayed randomness          | immutable-wrapper authentication, request match, one-way status                        |
| Callback griefing                    | callback performs storage only and no user or token calls                              |
| Cash branch diverts sponsor value    | fixed gross split: 80% winner / 5% protocol / 15% sponsor                              |
| Double settlement                    | winning and refund tickets burn; liabilities zero before transfer                      |
| Taxed or rebasing quote token        | exact inbound and outbound balance-delta verification                                  |
| One claimant blocks another          | separate winner, sponsor, treasury, and refund paths                                   |
| Contract winner rejects NFT callback | fixed-owner delivery uses `transferFrom` plus ownership verification                   |
| Protocol sink receives claim         | known factory, raffle, implementation, token, wrapper, and prize destinations rejected |

## Adversaries

The tests model malicious buyers, ticket receivers, prize receivers, ERC-20 return
values and balance behavior, reentrancy attempts, malformed or synchronous VRF
callbacks, wrong request IDs, timeout races, duplicate tickets, and failed outgoing
transfers.

The factory owner is treated as potentially compromised after deployment. Its only
power is pausing or unpausing future creation, so compromise cannot change an existing
raffle. The sponsor is untrusted except that the prize collection itself must satisfy
the supported-asset assumptions.

## External dependencies and explicit limitations

### Prize collection

ERC-165 admission cannot prove honest future behavior. A malicious or upgradeable
collection may lie about ownership, reenter, freeze, burn, or misdirect a prize. The
post-transfer ownership check prevents a no-op or misdirected transfer from committing,
but after a valid random result a noncompliant NFT can block settlement indefinitely.

### USDC

Issuer blacklists, pauses, upgrades, and chain-specific behavior can prevent payments.
Balance-delta checks turn non-exact behavior into a revert; they cannot restore token
availability. Direct USDC donations are surplus with no rescue path.

### Chainlink and Ethereum

The official wrapper authenticates delivered words, but fulfillment may be delayed or
absent. Ethereum may reorder transactions, reorganize, censor, or halt. Deadline
boundaries intentionally use first-valid-inclusion semantics. Thirty confirmations
reduce, rather than eliminate, reorg risk.

### Users and destinations

The protocol blocks known internal sinks, not every arbitrary contract or future
address. A user can still transfer a ticket to a contract that cannot manage a received
NFT or initiate its own refunds. Permissionless winning-ticket settlement always pays
the current owner; sponsor and treasury releases always use their immutable recipients.

Lost keys, mistaken external transfers, and unrelated NFTs forced into a raffle are
not recoverable. There is no administrator rescue desk.

### Operations and law

RPCs, subgraphs, websites, wallets, metadata hosts, keepers, and key management can
fail or mislead; onchain state remains authoritative. Chance-based prize distribution
may be regulated or prohibited, and legal/compliance review is outside smart-contract
correctness.
