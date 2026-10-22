# Run 1 — solidity-auditor

<!--RUN pass=1 of=1 stamp=20261021-004900 sha=9238b6ce8eb7f768c0dcd0cfcef26e1427a03155 agents=5/12-->

Pass 1 of 1 · 2026-10-21 · `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` · 5/12 agents returned — access-control, economic-security, periphery, asymmetry, boundary, trust-gap, and flow-gap failed through the runtime cybersecurity-risk filter. Coverage is INCOMPLETE.

## Findings

## Leads

<!--F key=raffle|releasesponsorproceeds|untrusted-prize-payout kind=LEAD agents=2-->

- **The sponsor receives proceeds before prize delivery** — `Raffle.releaseSponsorProceeds` — Code smells: Sponsor payment precedes prize delivery; `NftWon` has no refund transition. — A sponsor can receive 95% before prize delivery; the supplied source does not prove a prize contract that later blocks delivery.

<!--/F-->
