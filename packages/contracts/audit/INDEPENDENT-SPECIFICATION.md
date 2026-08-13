# Independently derived protocol specification

> Historical baseline: this specification predates the 2026-08-13 transfer lock,
> NFT-delivery refund fallback, and removal of the cross-raffle recovery dispatcher.
> See [`ETHSKILLS-REVIEW-2026-08-13.md`](ETHSKILLS-REVIEW-2026-08-13.md).

This specification was derived from production Solidity and executable interfaces in
the reviewed worktree. Existing architecture documents were consulted only after the
code-derived model was written.

## Contract graph and immutable configuration

`RaffleFactory` is a non-upgradeable `Ownable2Step` registry and constructor deployer.
It permanently fixes one quote token, one Pyth Entropy v2 contract, and one callback
gas limit. It stores a mutable creation pause and treasury, both of which affect only
future raffles.

Every `Raffle` is an independent, non-upgradeable ERC-721 deployment. Its constructor
fixes factory, sponsor, sponsor recovery recipient, treasury, quote token, Entropy,
prize token and ID, raffle ID, ticket price, threshold, timestamps, callback gas, and
metadata. It has no owner or administrator.

`RaffleLens` is read-only. It authenticates raffle addresses against one immutable
factory registry before forwarding bounded reads. Its maximum batch is 64.

## Lifecycle and transitions

| From            | To              | Caller                                  | Exact condition                                                                                     |
| --------------- | --------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------- |
| construction    | `AwaitingPrize` | factory constructor                     | all required addresses nonzero and caller equals declared factory                                   |
| `AwaitingPrize` | `Active`        | configured prize via receiver hook      | exact token, ID, sponsor, factory operator, and state tuple                                         |
| `Active`        | `Closed`        | sponsor before end; anyone at/after end | zero sold tickets                                                                                   |
| `Active`        | `Drawing`       | anyone                                  | at/after end, before grace deadline, at least one ticket, current Entropy fee paid, request returns |
| `Active`        | `Refunding`     | anyone                                  | at/after `end + 3 days`, at least one ticket, no accepted request                                   |
| `Drawing`       | `NftWon`        | authenticated Entropy callback          | matching stored sequence, not in-flight, threshold met                                              |
| `Drawing`       | `CashWon`       | authenticated Entropy callback          | matching stored sequence, not in-flight, threshold missed                                           |
| `Drawing`       | `Refunding`     | anyone                                  | at/after `drawRequestedAt + 2 days` before callback wins                                            |

`NftWon`, `CashWon`, `Refunding`, and `Closed` are terminal lifecycle results. Asset
claims change liabilities and burn tickets but do not introduce another status.

At the exact callback deadline, either an authenticated callback or `enableRefunds`
may be ordered first. The first state transition wins; the other call becomes invalid
or harmless. A callback remains acceptable after the nominal deadline until the
timeout transaction changes the status.

## Tickets, sale boundaries, and bearer rights

- Sales are inclusive at `startTime` and exclusive at `endTime`.
- Each purchase mints 1-100 contiguous ticket IDs starting at 1.
- Every ticket costs the same raw quote-token `ticketPrice`.
- Tickets remain transferable in every lifecycle while they exist.
- The current owner of `winningTicketId` is the winner credential.
- The current owner of each ticket in `Refunding` is its refund credential.
- A successful NFT or cash redemption burns the winning ticket.
- A successful refund burns each supplied ticket.
- There is no owner snapshot, freeze, credited souvenir, or separate refund marker.
- Duplicate refund IDs revert atomically because the first tentative burn makes the
  second `ownerOf` fail, and transaction rollback restores the first burn.

Because ownership is the claim credential, transfers to protocol contracts that
cannot initiate a redemption are security-sensitive and are not merely display data.

## Timing bounds

- maximum start delay: 7 days;
- maximum sale duration: 30 days;
- randomness request grace: 3 days after end;
- callback timeout: 2 days after accepted request;
- purchase batch: 100 tickets;
- refund redemption batch: 100 tickets;
- metadata URI: 2,048 bytes;
- Lens batch: 64 raffles.

## Normal economics

Let `G = grossSales`.

```text
protocolFee = floor(G * 500 / 10,000)
distributable = G - protocolFee
```

If `totalTickets >= minimumTickets`, status is `NftWon`, the sponsor receives the
complete distributable amount as a pull claim, and the winning bearer burns for the
NFT.

Otherwise status is `CashWon`:

```text
winnerCash = floor(distributable * 8,000 / 10,000)
sponsorCash = distributable - winnerCash
```

The winner burns for `winnerCash`; the sponsor receives `sponsorCash` as a pull claim;
the fixed recovery recipient may withdraw the NFT. Division remainders belong to the
sponsor. The 5% fee applies to both successful branches.

## Failed-liveness economics

`enableRefunds` moves the complete `unsettledPot` to
`remainingRefundLiability`, clears `unsettledPot`, selects no winner, and creates no
treasury or sponsor claim. Each outstanding ticket burns for exactly one ticket price.
The recovery recipient may withdraw the NFT independently of refunds.

## Quote accounting

The authoritative identity is:

```text
accountedQuoteBalance
  = unsettledPot
  + remainingRefundLiability
  + winnerCashLiability
  + totalClaimableQuote
```

For a supported token, contract balance must cover that sum. Direct donations are
reported as surplus and never affect economics. Incoming transfers must produce the
exact raffle balance increase. Outgoing transfers must produce both the exact raffle
debit and exact destination credit. Reverts restore ticket burns and cleared
liabilities atomically.

Sponsor and treasury amounts are stored in `claimableQuote`. `claimQuote(to)` lets the
rightful account choose a nonzero, non-raffle destination. `claimQuoteFor(account)` is
permissionless but fixes the destination to `account`. Winner cash and ticket refunds
are deliberately tied to bearer-ticket burns instead of ordinary pull balances.

## Native currency

The raffle holds no accounted native liability. `requestDraw` forwards the current
Entropy fee and returns any excess immediately; failure to return excess reverts the
entire request. Direct `receive` transfers revert. Forced native currency is
unaccounted surplus and cannot affect quote solvency.

## Prize custody and claimants

- `NftWon`: current winning-ticket owner, to a chosen safe destination;
- `CashWon`: fixed recovery recipient, to a chosen safe destination;
- `Refunding`: fixed recovery recipient, to a chosen safe destination;
- `Closed`: fixed recovery recipient, to a chosen safe destination.

The prize receiver accepts only the exact configured deposit tuple from the factory.
Claim effects mark `prizeClaimed` or burn the bearer before calling the external NFT.
A reverting destination restores all effects. No factory owner, treasury, or rescue
function can move the prize.

## Randomness integration

`requestDraw` calls `getFeeV2(callbackGasLimit)`, marks `Drawing` and request-in-flight,
calls the matching payable `requestV2(callbackGasLimit)`, stores the returned sequence,
then clears the in-flight guard. A synchronous callback is authenticated but ignored.
The internal callback accepts only `Drawing`, not-in-flight, matching-sequence calls.
It chooses `(uint256(randomNumber) % totalTickets) + 1`, performs bounded storage
writes, and makes no user or asset call. Modulo mapping has negligible but nonzero bias
unless the random domain is evenly divisible by `totalTickets`.

## External calls

Production external interactions are limited to:

- factory ERC-165 support check, prize safe transfer, prize `ownerOf`, and raffle
  status verification;
- raffle quote `balanceOf`, `safeTransferFrom`, and `safeTransfer`;
- raffle Entropy fee read and request;
- raffle prize safe transfer;
- ticket receiver callbacks during bounded safe mints;
- immediate native refund to the request caller;
- Lens registry and raffle view calls.

State-changing entry points that perform calls are reentrancy guarded. The Entropy
callback itself performs no external call.

## Owner powers and fixed destinations

The factory owner can pause new creation, update the treasury captured by future
raffles, and transfer/renounce ownership through OpenZeppelin's two-step mechanism.
The owner cannot change or pause an existing raffle. A sponsor chooses its recovery
recipient at creation, defaulting to itself. Both are configuration-time fixed
destinations and must not resolve to the newly created raffle or another known
non-callable protocol component.

Because ordinary `CREATE` addresses are predictable before code exists, a later
same-factory raffle can still become an earlier ticket, quote, or prize claimant. Its
permissionless `recoverProtocolOwnedClaim` dispatcher accepts only same-factory
registered targets, exposes only winning-ticket, bounded-refund, quote, and
sponsor-prize selectors, and fixes every payout to the holder raffle's immutable
recovery recipient.

## Loops and bounds

- ticket minting loops over caller-supplied quantity, capped at 100;
- refund redemption loops over caller-supplied ticket IDs, capped at 100;
- Lens loops over input raffles, capped at 64;
- no terminal state transition iterates over total tickets or claimants.

## Supported assets

The quote token must be non-rebasing, expose honest balances, and preserve exact
available transfers. The prize must preserve honest ERC-721 ownership and safe
transfers. Issuer freezes, behavior upgrades, dishonest reads, burns, blacklists, and
pauses are external risks. ERC-721 unsafe transfers can force unrelated NFTs into the
raffle but cannot alter configured-prize accounting.

## SDK, subgraph, frontend, and deployment assumptions

- generated ABIs and enum ordinals must match production artifacts;
- every SDK and frontend write must be simulated against live state;
- subgraph state is discovery/history data, not authorization;
- generated subgraph sources must exist before clean-build typechecking;
- missing deployment records must disable live writes;
- deployment scripts must validate chain, runtime code, immutable dependencies,
  callback gas, owner, treasury, and quote token;
- metadata is untrusted content and must not be executed as HTML or script.

## Reconciliation with the attached audit prompt

| Prompt assumption                    | Reviewed code                                                   | Audit treatment                                                     |
| ------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| EIP-1167 implementation and clones   | ordinary constructor `CREATE`                                   | clone/initializer/CREATE2 properties not applicable                 |
| quote-token admission list           | one immutable token per factory                                 | test immutable factory token and future factory replacement process |
| cancellation plus no-sales closure   | one zero-sales close, sponsor early or anyone after end         | equivalent bounded recovery property                                |
| transfers frozen during draw         | transfers remain enabled; bearer credential determines claimant | test current-owner settlement and protocol-self destinations        |
| refund credit then souvenir transfer | burn current-owner ticket for immediate exact refund            | test ownership, burn atomicity, duplicate batches, solvency         |
| pull-based native refund             | immediate excess return or request rollback                     | test exact forwarding, rejection rollback, and forced surplus       |
| `claimPrizeFor`                      | no permissionless prize-for function                            | fixed recipient must initiate and may choose destination            |
| Lens batch 100                       | Lens batch 64                                                   | enforce and document actual bound                                   |

These differences are intentional outcomes of the approved simplification and are not
findings by themselves.
