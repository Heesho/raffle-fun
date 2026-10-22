# Requirement extraction — DESIGN.md

Extracted 44 independently checkable claims from the clean design paragraph. Compound economic allocations, access permissions, immutability guarantees and trust assumptions are split even where sharing a verbatim quote preserves its condition. All quotes are exact substrings of target/DESIGN.md. Background provenance statements are excluded. Mandatory force is assigned to explicit must/never language; narrative statements retain descriptive force. Ambiguities about fee denominators, return recipient, deadline selection and storage-only semantics are recorded in checkable fields. This task performs no source alignment or implementation verdict.

## REQ-01

> immutable factory

invariant; descriptive. Factory behavior and configuration are immutable.

## REQ-02

> ERC-1167 clones

other; descriptive. Raffles use the ERC-1167 clone architecture.

## REQ-03

> immutable implementation

invariant; descriptive. The implementation associated with deployed clones cannot be changed.

## REQ-04

> One entry costs 1,000,000 units of canonical six-decimal USDC.

formula; descriptive. Each entry costs exactly 1,000,000 base units.

## REQ-05

> canonical six-decimal USDC

trust-boundary; descriptive. The payment token is canonical USDC with six decimals; the deployment network is not identified in this document.

## REQ-06

> One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range.

other; descriptive. Each purchase mints one ERC721 ticket.

## REQ-07

> transferable ERC721 ticket

access-control; descriptive. Tickets support transfer of ownership.

## REQ-08

> representing a contiguous inclusive range

invariant; descriptive. Each ticket represents a contiguous entry range with both endpoints included.

## REQ-09

> Exactly one ERC721 prize is escrowed atomically at creation.

invariant; descriptive. Each raffle escrows exactly one ERC721 prize.

## REQ-10

> Exactly one ERC721 prize is escrowed atomically at creation.

ordering; descriptive. Creation and custody of the prize succeed or revert atomically.

## REQ-11

> Reserve met awards NFT

state-machine; descriptive. The reserve-met outcome awards the NFT prize.

## REQ-12

> Reserve met awards NFT and 95% sponsor / 5% treasury.

formula; descriptive. In the reserve-met outcome the sponsor allocation is 95%; the denominator is implicit in this clause and should be checked against gross proceeds.

## REQ-13

> Reserve met awards NFT and 95% sponsor / 5% treasury.

formula; descriptive. In the reserve-met outcome the treasury allocation is 5%; the denominator is implicit in this clause and should be checked against gross proceeds.

## REQ-14

> Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury.

formula; descriptive. In the reserve-missed outcome the winner receives 80% of gross proceeds.

## REQ-15

> Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury.

formula; descriptive. In the reserve-missed outcome the sponsor receives 15% of gross proceeds.

## REQ-16

> Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury.

formula; descriptive. In the reserve-missed outcome the treasury receives 5% of gross proceeds.

## REQ-17

> Refund outcome pays 100% per entry

formula; descriptive. The refund outcome returns the full entry price for each entry.

## REQ-18

> Refund outcome pays 100% per entry and returns prize.

state-machine; descriptive. The refund outcome returns the prize; the recipient is not explicitly named in this clause.

## REQ-19

> Rounding is floor on aggregate protocol fee

formula; descriptive. The aggregate protocol fee is rounded down.

## REQ-20

> remainder must be allocated without loss.

invariant; mandatory. All residual amounts from rounding remain allocated and are not lost.

## REQ-21

> No administrator, mutable configuration or upgrade.

access-control; descriptive. The protocol has no administrator.

## REQ-22

> No administrator, mutable configuration or upgrade.

invariant; descriptive. Deployed protocol configuration cannot be changed.

## REQ-23

> No administrator, mutable configuration or upgrade.

invariant; descriptive. The protocol cannot be upgraded.

## REQ-24

> Request window [sale end, end+2days)

state-machine; descriptive. Draw requests are accepted at sale end and rejected before sale end.

## REQ-25

> Request window [sale end, end+2days)

state-machine; descriptive. Draw requests are rejected at or after two days following sale end.

## REQ-26

> callback accepted strictly before request timestamp+2days.

state-machine; descriptive. Randomness callbacks are accepted only before the request timestamp plus two days.

## REQ-27

> Refunds open at deadline.

state-machine; descriptive. Refunds become available at the applicable deadline; this clause does not explicitly distinguish request expiry from callback expiry.

## REQ-28

> Callback records result only.

ordering; descriptive. The callback records the result without settling or transferring assets.

## REQ-29

> Settlement is permissionless

access-control; descriptive. Any caller may perform settlement when settlement prerequisites hold.

## REQ-30

> Settlement is permissionless, storage-only

ordering; descriptive. Settlement changes storage without asset transfers or other external execution; storage-only is not further defined.

## REQ-31

> redemption requires current ticket owner

access-control; descriptive. Redemption authority is checked against the current ticket owner.

## REQ-32

> burns claim atomically

ordering; descriptive. Redemption consumes the claim atomically with redemption.

## REQ-33

> must revert all effects on delivery failure.

error-handling; mandatory. If delivery fails all effects of redemption revert.

## REQ-34

> Sponsor and treasury can claim independently after settlement.

access-control; descriptive. The sponsor can claim its allocation after settlement.

## REQ-35

> Sponsor and treasury can claim independently after settlement.

access-control; descriptive. The treasury can claim its allocation after settlement.

## REQ-36

> Sponsor and treasury can claim independently after settlement.

invariant; descriptive. The sponsor claim does not depend on the treasury claim succeeding.

## REQ-37

> Sponsor and treasury can claim independently after settlement.

invariant; descriptive. The treasury claim does not depend on the sponsor claim succeeding.

## REQ-38

> Never move assets between raffle clones.

invariant; mandatory. No execution path transfers assets from one raffle clone to another.

## REQ-39

> Quote token and Chainlink wrapper are trusted canonical dependencies

trust-boundary; descriptive. The quote token is a trusted canonical dependency; correctness of that external token is assumed.

## REQ-40

> Quote token and Chainlink wrapper are trusted canonical dependencies

trust-boundary; descriptive. The Chainlink wrapper is a trusted canonical dependency; correctness of that external wrapper is assumed.

## REQ-41

> arbitrary prize contracts and ticket recipients are untrusted.

trust-boundary; descriptive. Prize contracts are arbitrary untrusted external contracts.

## REQ-42

> arbitrary prize contracts and ticket recipients are untrusted.

trust-boundary; descriptive. Ticket recipients are untrusted external actors or contracts.

## REQ-43

> Frontend discovery is advisory

trust-boundary; descriptive. Frontend discovery results alone are not authoritative for transaction decisions.

## REQ-44

> transaction decisions must reread current chain state.

ordering; mandatory. Transaction decisions refresh relevant state from the chain before acting.

