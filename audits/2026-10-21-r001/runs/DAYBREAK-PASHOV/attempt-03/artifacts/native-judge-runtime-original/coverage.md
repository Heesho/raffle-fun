
Specialist numbers in parentheses identify the accepted responses that supplied the coverage evidence.

Per-file coverage:

| Production file | Coverage |
|---|---|
| `target/packages/contracts/src/Raffle.sol` | candidate raised — payout ordering, custody, redemption, refunds, and timestamp behavior (1, 3–12) |
| `target/packages/contracts/src/RaffleFactory.sol` | candidate raised — clone activation and prize self-attestation (2–7, 9, 12) |
| `target/packages/contracts/src/interfaces/IRaffle.sol` | reviewed — lifecycle, redemption, refund, and payout expectations used in traces (1, 3–12) |
| `target/packages/contracts/src/interfaces/IRaffleFactory.sol` | reviewed — creation parameters, registration, and implementation boundary used in factory traces (2–7, 9, 12) |
| `target/packages/contracts/src/libraries/RaffleConstants.sol` | reviewed — entry price, 95/5 allocation, reserve outcomes, and two-day windows used in proofs (1–12) |

Per-property coverage:

| Property | Coverage |
|---|---|
| Access control and initialization | candidate raised — activation trusts attestations from the selected prize token despite factory-only initialization (2–7, 9, 12) |
| Lifecycle and timing | candidate raised — payout-before-delivery ordering and the `uint64` rollover trail (1, 3–12) |
| Value conservation and payout math | candidate raised — exact 95/5 allocations remain conserved, but claims can leave before delivery (1, 3–9, 11, 12) |
| Randomness request and callback | candidate raised — request timing, callback deadlines, and the rejected rollover candidate (10; callback-result traces also 1, 3–9, 11, 12) |
| Ticket ownership, redemption, and refunds | candidate raised — burned claims, failed delivery, and unavailable `NftWon` refunds (1, 3–12) |
| External calls and reentrancy | candidate raised — attacker-controlled ERC-721 callbacks, ownership reports, and transfer behavior cross the guarded entry points (1–9, 11, 12) |
| Factory clone and escrow isolation | candidate raised — false escrow and reuse of one alleged token across clones (2–7, 9, 12) |
| Boundary and dependency behavior | candidate raised — the prize-token trust boundary supplies both custody and delivery evidence (1–9, 11, 12) |
| Interface and specification conformance | candidate raised — false escrow and failed delivery conflict with the required prize and refund outcomes (5, 12) |
| Numerical-gap three-way seam | candidate raised — timestamp downcast and deadline rollover; rejected at Gate 2 (10) |
| Trust-gap three-way seam | candidate raised — custody revalidation and pre-delivery payout; the administrator-only custody path was rejected (11) |
| Flow-gap three-way seam | candidate raised — one false token can forge both creation and redemption attestations (12) |

