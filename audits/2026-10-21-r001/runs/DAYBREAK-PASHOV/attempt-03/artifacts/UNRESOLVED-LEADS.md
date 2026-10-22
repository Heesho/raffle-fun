# Unresolved leads

No unresolved lead survived the native Turn 4 deduplication and four-gate review.

- Agent 5's raw `premature-nft-proceeds-release` lead was promoted into final finding G2, `raffle|releasesponsorproceeds|payout-before-prize-delivery`, because the merged corrected corpus supplied a complete source-supported, unprivileged asymmetric-token path.
- G3, `raffle|settlewinningticket|payout-before-prize-delivery`, was rejected at Gate 3 because its only supplied trigger required a privileged prize-token administrator action.
- G4, `raffle|requestdraw|timestamp-downcast-deadline-rollover`, was rejected at Gate 2 because its required `2^64` timestamp is not a plausible live-deployment state.
- G5, `raffle|buyentries|prize-custody-not-revalidated`, was rejected at Gate 3 because its only supplied trigger required a privileged prize-token administrator action.

The authoritative candidate-by-candidate record is `gate-decisions.md`; the exact native report contains two findings and zero leads. Rejected candidates are retained as audit evidence, not represented as report leads.
