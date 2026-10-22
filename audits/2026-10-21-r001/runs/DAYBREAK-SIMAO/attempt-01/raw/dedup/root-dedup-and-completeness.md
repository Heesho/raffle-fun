# Native Turn 6 — Deduplication and completeness evidence

Timestamp: 2026-10-21T08:17:49Z

Inputs: all 12 raw lens responses in `raw/lenses/lens-01-accounting.md` through `lens-12-flow.md`. The ancillary lens-02 arithmetic check was preserved but did not add a new record. This pass did not read proof output or any external finding corpus.

Raw record count: 10 `FINDING` blocks and 5 `LEAD` blocks.

## Unique `(Contract, function)` inventory

1. `Raffle::_settleWinningTicket` — raw findings from lenses 2 and 4.
2. `Raffle::releaseSponsorProceeds` — raw findings from lenses 3 and 10.
3. `Raffle::buyEntries` — raw lead from lens 3.
4. `RaffleFactory::createRaffle` — raw findings/leads from lenses 5, 9, 10, and 12.
5. `Raffle::settleWinningTicket` — raw findings from lenses 8 and 11.
6. `Raffle::_transferQuote` — raw finding from lens 10.
7. `Raffle::requestDraw` — raw lead from lens 11.
8. `Raffle::_isProtocolDestination` — raw leads from lenses 10 and 12.

Completeness: 8 unique (Contract, function) in raw, 8 covered in final.

## Function-isolated groups

- `Raffle::_settleWinningTicket | premature/unbacked prize settlement` `[lenses: 2]`: merged synonymous bug classes `premature-proceeds-release` and `unbacked-prize-settlement`. Preserved two distinct remedies: withhold proceeds plus bounded refund fallback; or restrict prize implementations.
- `Raffle::releaseSponsorProceeds | premature proceeds release` `[lenses: 1]`: kept separate from settlement and from its USDC-recipient mechanism.
- `Raffle::releaseSponsorProceeds | denylisted fixed recipient` `[lenses: 1]`: separate mechanism and mitigation; not merged with premature release.
- `Raffle::buyEntries | sponsor last-minute reserve manipulation` `[lenses: 1]`: retained as unverified lead.
- `RaffleFactory::createRaffle | untrusted prize self-attestation` `[lenses: 4]`: merged synonymous escrow/self-attestation/contract groups only within this function. Preserved the downstream pot-lock/refund option separately from a trusted-prize restriction.
- `Raffle::settleWinningTicket | prize-delivery decoupling` `[lenses: 2]`: retained separately from the internal helper because function isolation is hard.
- `Raffle::_transferQuote | USDC denylist escrow lock` `[lenses: 1]`: separate integration mechanism.
- `Raffle::requestDraw | timestamp downcast saturation` `[lenses: 1]`: retained as unverified lead.
- `Raffle::_isProtocolDestination | incomplete destination screening` `[lenses: 2]`: merged synonymous counterfactual-clone/incomplete-screening leads within the same function.

## Composite chain

`RaffleFactory::createRaffle` admits an attacker-controlled prize; `Raffle::settleWinningTicket` / `Raffle::_settleWinningTicket` allocate the buyer-funded pot without delivery; `Raffle::releaseSponsorProceeds` lets the attacker extract the sponsor share before the winner can redeem. The combined path crosses the untrusted-prize boundary and causes the entire entrant payment to leave while the winning NFT claim remains unpayable. Hard function isolation requires the component items to remain separately visible.
