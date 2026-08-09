# Threat model

## Security property

For an honest standards-compliant ERC-721 prize and an available exact-transfer,
non-rebasing USDC token, every protocol-controlled status exposes a bounded path for
the authorized bearer or recovery recipient to recover the configured prize and every
accounted quote-token liability.

## Enforced controls

| Threat                                      | Control                                                                               |
| ------------------------------------------- | ------------------------------------------------------------------------------------- |
| Unauthorized raffle deployment              | constructor requires its configured factory                                           |
| Partial creation / stranded `AwaitingPrize` | deployment, registry, deposit, and verification are one reverting transaction         |
| Wrong or duplicate prize                    | exact receiver checks and one-way status                                              |
| Admin changes existing raffle               | no raffle admin, proxy, upgrade, rescue, or override                                  |
| Indefinite sale                             | seven-day start-delay and 30-day sale-duration bounds                                 |
| Nobody requests randomness                  | permissionless refunds after three-day grace                                          |
| Accepted request never returns              | permissionless refunds after two-day callback timeout                                 |
| Callback reentrancy or recipient griefing   | callback is bounded storage-only work                                                 |
| Winner ownership ambiguity                  | current owner must burn the selected ticket                                           |
| Refund ownership ambiguity or double spend  | current owner must burn each refundable ticket                                        |
| Unbounded refund loop                       | maximum 100 tickets per redemption                                                    |
| Cash branch avoids protocol fee             | same 5% calculation precedes both successful branches                                 |
| Taxed or rebasing quote token               | exact incoming and outgoing balance-delta checks                                      |
| One claimant blocks another                 | sponsor/treasury pull claims and independent bearer redemptions                       |
| Protocol contract becomes a claimant        | known destinations rejected; future-raffle claims recover only to its fixed recipient |

## Explicit limitations

No contract can guarantee recovery against a malicious or upgraded ERC-721, collection
pause/burn/freeze/blacklist, malicious or frozen ERC-20, halted or reorganized chain,
lost keys, or an unrelated NFT forced in with unsafe `transferFrom`. There is no broad
rescue function because it would also create an administrator seizure path.

Pyth Entropy remains an oracle dependency. The protocol bounds that dependency with
refund deadlines; it does not replace an unavailable oracle with administrator-selected
randomness. At the exact callback deadline, callback and refund transactions race and
the first valid terminal transition included onchain wins.

Unsafe transfer to an arbitrary unrelated non-callable contract remains deliberate
bearer-destination risk. The protocol does not claim to detect every contract capable
of receiving a ticket but incapable of later initiating redemption. It does prevent
known and deterministically created protocol-self destinations, without adding an
administrator seizure path.
