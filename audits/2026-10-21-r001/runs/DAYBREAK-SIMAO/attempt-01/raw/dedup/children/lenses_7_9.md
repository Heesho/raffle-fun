Exhaustive inventory:

- `raw/lenses/lens-07-ordering.md`
  - FINDING entries: none.
  - LEAD entries: none.
  - Confirmation: line 175 states, “No FINDING or LEAD is warranted for the Ordering/MEV lens.”

- `raw/lenses/lens-08-dos.md`
  - Source location: line 61; full record spans lines 61–72.
  - Type: `FINDING`
  - ID/title: none present.
  - Exact fields: `(contract: Raffle, function: settleWinningTicket)`
  - Exact header:
    `FINDING | contract: Raffle | function: settleWinningTicket | bug_class: untrusted-prize-payout-theft | group_key: Raffle | settleWinningTicket | untrusted-prize-payout-theft`
  - LEAD entries: none.

- `raw/lenses/lens-09-access.md`
  - Source location: line 158; full record spans lines 158–168.
  - Type: `FINDING`
  - ID/title: none present.
  - Exact fields: `(contract: RaffleFactory, function: createRaffle)`
  - Exact header:
    `FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation`
  - LEAD entries: none.

Total: 2 FINDING entries; 0 LEAD entries.
