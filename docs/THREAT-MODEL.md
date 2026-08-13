# Threat model

## Security property

For an honest standards-compliant ERC-721 prize and an available exact-transfer,
non-rebasing USDC token, every protocol-controlled status exposes a bounded path for
the authorized bearer or recovery recipient to recover the configured prize and every
accounted quote-token liability.

## Enforced controls

| Threat                                      | Control                                                                       |
| ------------------------------------------- | ----------------------------------------------------------------------------- |
| Unauthorized raffle deployment              | constructor requires its configured factory                                   |
| Partial creation / stranded `AwaitingPrize` | deployment, registry, deposit, and verification are one reverting transaction |
| Wrong or duplicate prize                    | exact receiver checks and one-way status                                      |
| Admin changes existing raffle               | no raffle admin, proxy, upgrade, rescue, or override                          |
| Indefinite sale                             | seven-day start-delay and 30-day sale-duration bounds                         |
| Nobody requests randomness                  | permissionless refunds after three-day grace                                  |
| Accepted request never returns              | permissionless refunds after two-day callback timeout                         |
| Prize transfer later fails                  | NFT proceeds remain escrowed; full refunds open after 30 days                 |
| Callback reentrancy or recipient griefing   | callback is bounded storage-only work                                         |
| Winner capture during oracle reveal         | all transfers lock in `Drawing`; selected ticket stays locked                 |
| Refund ownership ambiguity or double spend  | current owner must burn each refundable ticket                                |
| Unbounded refund loop                       | maximum 100 tickets per redemption                                            |
| Cash branch avoids protocol fee             | same 5% calculation precedes both successful branches                         |
| Taxed or rebasing quote token               | exact incoming and outgoing balance-delta checks                              |
| One claimant blocks another                 | sponsor/treasury pull claims and independent bearer redemptions               |
| Protocol contract becomes a claimant        | known ticket and payout destinations rejected; no cross-raffle dispatcher     |

## Explicit limitations

A reverting or unavailable prize cannot release NFT-branch quote proceeds and leads
to refunds after 30 days. A malicious or upgraded ERC-721 can still lie about its
standard or ownership, and no contract can force frozen USDC, recover lost keys,
recover an unrelated NFT forced in with unsafe `transferFrom`, or make a halted chain
progress.

Pyth Entropy remains an oracle dependency. Its provider can know the final word before
reveal and selectively withhold an unfavorable result. Locking transfers prevents
post-request winner purchases, but it does not remove selective settlement for a
provider that already owns tickets. At the callback deadline, callback and refund
transactions race and the first valid transition included onchain wins.

Unsafe transfer to an arbitrary unrelated non-callable contract remains deliberate
bearer-destination risk. The protocol does not claim to detect every contract capable
of receiving a ticket but incapable of later initiating redemption. It does prevent
known protocol destinations. Assigning a claim to a future code-less address remains
unsupported, without adding an administrator seizure path.
