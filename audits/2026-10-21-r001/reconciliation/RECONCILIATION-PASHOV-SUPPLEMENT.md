# Late sealed Pashov supplement

2026-10-21T18:06:16.080633+00:00. This supplement preserves the already sealed reconciliation addendum and its register.

DAYBREAK-PASHOV attempt-03 FIRST-PASS is verified against SEAL.json: `e0f6f414a66a23835b7410a8f17d6aee4db9e97fa3ef67d507c0e934765b748f`; exact target `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. The source-only report has two findings, both confidence 90, with no assigned security severity and no post-seal reproduction claim. Finding 1 (`rafflefactory|createraffle|fake-prize-escrow`) and finding 2 (`raffle|releasesponsorproceeds|payout-before-prize-delivery`) map to RF-001. They corroborate source paths but do not add independent economic root causes or resolve the honest-prize/untrusted-prize scope dispute.

The report's proposed Option C is **not a ready remediation**. NftWon can exist before settlement: sponsorProceeds and protocolFees are zero while unsettledPot contains sales. The proposed NftWon branch migrates only the two zero terminal balances, changes status to Refunding and leaves unsettledPot. The positive refund deduction at Raffle.sol:368 would then underflow. This is source reasoning about a proposed patch, not a defect in the frozen implementation and not an executed mutant. It is tracked as AQ-008 in the companion patch register.

A correct fallback design must cover both unsettled and settled NftWon, preserve every promised refund unit including protocol fees, and define treatment of successful delivery and any already-paid claim. The report's sponsor-only gate cannot fund a full refund; gating both payments without a fallback can simply exchange a stuck prize for stuck quote claims. An allowlist must address pausing, upgrades and administrative seizure rather than treating registration as proof of permanent transferability. None of these proposals was applied, and no owner acceptance is inferred.

The verified seal reports zero native-judge provider rejections and 90 auxiliary rejection-log occurrences with affected routes not retried or counted. This boundary is retained without retry. The separate independent OpenKritt validation remains provider-rejected and incomplete as recorded in the previous addendum.

[Register patch](/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/reconciliation/findings-register-PASHOV-SUPPLEMENT.json) preserves both native keys, IDs, source lines and proposal limits. No original report, register or seal changed.
