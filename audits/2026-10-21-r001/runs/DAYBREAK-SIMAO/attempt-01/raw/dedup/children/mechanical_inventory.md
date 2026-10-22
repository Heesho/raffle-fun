# Child response transcript — `mechanical_inventory`

## Message 1

Mechanical lens inventory complete: 11 FINDING + 4 LEAD = 15 explicit blocks across the 12 requested `raw/lenses/lens-*.md` files. `lens-01`, `lens-06`, `lens-07` explicitly report none. Separate money-map evidence could not be located under attempt-01/raw: only the 12 lens files (plus a later ancillary lens file), empty raw/{dedup,judges,proofs,report}, three 0-byte preflight JSONLs, and runner SQLite tables with 0 content rows; no raw/runner byte matches money-map/FINDING/LEAD. I’m assembling exact line/block inventory and will flag the negative evidence rather than infer.

## Message 2

Correction to my preceding count: 10 FINDING + 5 LEAD = 15 explicit blocks across the 12 lenses. I will now read only `evidence/bundles-pre-cleanup/money-map.md` as directed and include its exact block inventory.

## Final answer

Mechanical inventory complete. No deduplication or judgment applied.

Totals: **10 FINDING blocks, 5 LEAD blocks**. None has an explicit ID/title field.

- `raw/lenses/lens-02-shares.md:78–89`
  - `FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: premature-proceeds-release | group_key: Raffle | _settleWinningTicket | premature-proceeds-release`
  - Exact tuple: `(Raffle, _settleWinningTicket)`
  - Stated code locations: `Raffle.sol:543-555`, `Raffle.sol:334`, `Raffle.sol:375-390`

- `raw/lenses/lens-03-temporal.md:116–127`
  - `FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-proceeds-release`
  - Exact tuple: `(Raffle, releaseSponsorProceeds)`
  - Stated code locations: `Raffle.sol:375-381`, `Raffle.sol:385-391`

- `raw/lenses/lens-03-temporal.md:137–140`
  - `LEAD | contract: Raffle | function: buyEntries | bug_class: sponsor-last-minute-reserve-manipulation | group_key: Raffle | buyEntries | sponsor-last-minute-reserve-manipulation`
  - Exact tuple: `(Raffle, buyEntries)`
  - No code-line locator stated inside the block.

- `raw/lenses/lens-04-liquidation.md:113–125`
  - `FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: unbacked-prize-settlement | group_key: Raffle | _settleWinningTicket | unbacked-prize-settlement`
  - Exact tuple: `(Raffle, _settleWinningTicket)`
  - Stated code locations: `Raffle.sol:539-555`, `Raffle.sol:332-336`, `RaffleFactory.sol:127-134`

- `raw/lenses/lens-05-crosschain.md:83–94`
  - `FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-escrow | group_key: RaffleFactory | createRaffle | untrusted-prize-escrow`
  - Exact tuple: `(RaffleFactory, createRaffle)`
  - Stated code locations: `RaffleFactory.sol:154-176`, `RaffleFactory.sol:128-133`, `Raffle.sol:334`

- `raw/lenses/lens-08-dos.md:61–72`
  - `FINDING | contract: Raffle | function: settleWinningTicket | bug_class: untrusted-prize-payout-theft | group_key: Raffle | settleWinningTicket | untrusted-prize-payout-theft`
  - Exact tuple: `(Raffle, settleWinningTicket)`
  - Stated code locations: `Raffle.sol:543-555`, `RaffleFactory.sol:172`

- `raw/lenses/lens-09-access.md:158–168`
  - `FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation`
  - Exact tuple: `(RaffleFactory, createRaffle)`
  - Stated code locations: `RaffleFactory.sol:171-177`, `RaffleFactory.sol:128-133`, `Raffle.sol:421-428`

- `raw/lenses/lens-10-integration.md:47–57`
  - `FINDING | contract: Raffle | function: _transferQuote | bug_class: usdc-denylist-escrow-lock | group_key: Raffle | _transferQuote | usdc-denylist-escrow-lock`
  - Exact tuple: `(Raffle, _transferQuote)`
  - Stated code location: `Raffle.sol:564-568`

- `raw/lenses/lens-10-integration.md:59–69`
  - `FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: usdc-denylisted-fixed-recipient | group_key: Raffle | releaseSponsorProceeds | usdc-denylisted-fixed-recipient`
  - Exact tuple: `(Raffle, releaseSponsorProceeds)`
  - Stated code location: `Raffle.sol:375-390`

- `raw/lenses/lens-10-integration.md:71–74`
  - `LEAD | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation`
  - Exact tuple: `(RaffleFactory, createRaffle)`
  - Stated code locations: `RaffleFactory.sol:128-134`, `RaffleFactory.sol:171-178`, `Raffle.sol:416-429`

- `raw/lenses/lens-10-integration.md:76–79`
  - `LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: counterfactual-clone-destination | group_key: Raffle | _isProtocolDestination | counterfactual-clone-destination`
  - Exact tuple: `(Raffle, _isProtocolDestination)`
  - Stated code location: `Raffle.sol:593-604`

- `raw/lenses/lens-11-edges.md:126–137`
  - `FINDING | contract: Raffle | function: settleWinningTicket | bug_class: prize-delivery-decoupling | group_key: Raffle | settleWinningTicket | prize-delivery-decoupling`
  - Exact tuple: `(Raffle, settleWinningTicket)`
  - Stated code locations: `Raffle.sol:543-555`, `Raffle.sol:375-390`

- `raw/lenses/lens-11-edges.md:139–142`
  - `LEAD | contract: Raffle | function: requestDraw | bug_class: timestamp-downcast-saturation | group_key: Raffle | requestDraw | timestamp-downcast-saturation`
  - Exact tuple: `(Raffle, requestDraw)`
  - Stated code locations: `Raffle.sol:253`, `Raffle.sol:520`

- `raw/lenses/lens-12-flow.md:157–168`
  - `FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-contract | group_key: RaffleFactory | createRaffle | untrusted-prize-contract`
  - Exact tuple: `(RaffleFactory, createRaffle)`
  - Stated code locations: `RaffleFactory.sol:154`, `RaffleFactory.sol:172-176`, `RaffleFactory.sol:128-132`, `Raffle.sol:334-336`

- `raw/lenses/lens-12-flow.md:170–173`
  - `LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: incomplete-protocol-destination-screening | group_key: Raffle | _isProtocolDestination | incomplete-protocol-destination-screening`
  - Exact tuple: `(Raffle, _isProtocolDestination)`
  - Stated code location: `Raffle.sol:599-603`

Files with no blocks:

- `raw/lenses/lens-01-accounting.md`: 0 FINDING, 0 LEAD; explicit declaration at line 5.
- `raw/lenses/lens-06-rounding.md`: 0 FINDING, 0 LEAD; explicit declaration at line 117.
- `raw/lenses/lens-07-ordering.md`: 0 FINDING, 0 LEAD; explicit declaration at line 175.

Preserved money map:

- `evidence/bundles-pre-cleanup/money-map.md`, read completely at lines 1–128.
- 0 FINDING and 0 LEAD blocks; consequently no IDs/titles, tuples, or record locators to enumerate.
