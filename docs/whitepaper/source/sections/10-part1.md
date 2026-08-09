:::part id="part-i" no="Part I" title="The Idea"
raffle.fun replaces manually administered custody, ticket records, random selection,
and payout bookkeeping with a fixed onchain process.
- 1|Executive Summary
- 2|raffle.fun in 60 Seconds
- 3|The Problem
- 4|The Core Idea
- 5|What Onchain Means
:::

# Part I | The Idea

## 1. Executive Summary

raffle.fun is experimental software for one-prize NFT raffles on Base. A sponsor
chooses the price, the minimum-ticket threshold, the sale dates, and a fixed recovery
recipient. The canonical factory deploys one independent raffle, registers it, moves
the exact prize NFT into escrow, and verifies custody in one transaction. If any step
fails, every step rolls back.

The factory is bound to one quote-token contract. The reviewed implementation calls
this token USDC and deployment tooling requires the official chain-specific USDC
address. Users therefore do not select an arbitrary ERC-20 when creating a raffle.
The factory also fixes one Pyth Entropy v2 address and one callback gas limit.

Any user may create a raffle while new creation is not paused, using the factory-wide
USDC and an ERC-721 prize contract that reports ERC-721 interface support. This is open
creation with bounded inputs, not completely unrestricted creation.

A buyer approves USDC and calls `buyTickets`. The complete gross price is
`ticketPrice x quantity`. The raffle checks that its balance increased by exactly that
amount before it safely mints sequential ERC-721 ticket IDs. A purchase may mint from
1 through {{MAX_TICKETS_PER_PURCHASE}} tickets. Total sales can continue above the
minimum threshold until the exclusive sale end.

Every ticket is a bearer right. It remains transferable in every lifecycle state
until it is burned. There is no ownership snapshot and no draw-time transfer freeze.
If Maya transfers ticket 12 to Leo, Leo owns the potential award or refund. If Leo
then transfers it to Noor before redemption, Noor becomes the owner of that right.
Only the actual current owner, not merely an approved operator, can burn a winning or
refundable ticket.

After the sale, anyone may pay the current Pyth Entropy fee and request the one draw.
The request is permitted at `endTime` and strictly before `endTime +
{{REQUEST_GRACE_DAYS}} days`. The fee is paid in Base's native currency, not from the
USDC ticket pot. Any overpayment is returned immediately. If the return fails, the
complete request transaction reverts.

The later Entropy callback is accepted only through the configured Entropy wrapper,
for the stored sequence, while the raffle is `Drawing`, and after the request call has
finished. Wrong, early, stale, duplicate, and post-failure callbacks are ignored. A
valid callback computes:

`winningTicketId = (randomNumber % totalTickets) + 1`

The mapping includes every ticket ID from 1 through `totalTickets`. It has negligible
but nonzero mathematical modulo bias for most ticket counts. Pyth correctness remains
an external assumption.

If the threshold is met, status becomes `NftWon`. The winning ticket owner burns the
ticket for the NFT. The protocol treasury receives a {{PROTOCOL_FEE_PERCENT}} pull
claim and the sponsor receives the complete post-fee USDC pot as a separate pull
claim.

If the threshold is missed but a valid callback arrives, status becomes `CashWon`.
This is a successful cash fallback, not a refund. The winning ticket owner burns the
ticket for {{CASH_WINNER_PERCENT}} of the post-fee pot. The sponsor receives the exact
remainder. The protocol receives the same {{PROTOCOL_FEE_PERCENT}} fee. The fixed
recovery recipient claims the NFT. Other ticket owners receive no refund.

If no request succeeds by the request-grace deadline, or no valid callback wins before
timeout finalization at `drawRequestedAt + {{CALLBACK_TIMEOUT_DAYS}} days`, anyone may
call `enableRefunds`. No winner is selected, no fee is charged, and no sponsor proceeds
are created. Each current owner may burn up to {{MAX_REFUND_BATCH}} owned tickets in
one transaction for exactly one ticket price per ticket. Tickets remain transferable
until burned.

If zero tickets sell, the sponsor may close the raffle before the end and anyone may
close it at or after the end. The recovery recipient then claims the NFT. There is no
separate cancellation status. `Closed` is the zero-sales outcome.

Sponsor and treasury quote proceeds are pull claims so one recipient cannot block
another. Winning cash and refunds are direct exact transfers made when bearer tickets
burn. The recovery recipient initiates its NFT claim and chooses a safe nonzero
destination. `claimQuoteFor` may be called by anyone, but can pay only the rightful
account itself.

The factory owner can pause future creation, change the treasury captured by future
raffles, and use OpenZeppelin's two-step ownership transfer. The owner cannot change,
pause, upgrade, settle, rescue, or redirect an existing raffle.

The largest risks are external token behavior, oracle correctness, Base ordering and
availability, wallet security, user-selected non-callable ticket destinations,
immutable-code defects, and legal or operational failures. Internal testing is strong
evidence, not proof that vulnerabilities do not exist.

:::callout kind="sentence" title="What this design optimizes for"
The design favors fixed rules, independent asset claims, bounded recovery deadlines,
and minimal administrator power over upgradeability or discretionary rescue.
:::

## 2. raffle.fun in 60 Seconds

:::figure src="diagrams/01-at-a-glance.svg" num="1" title="raffle.fun at a glance" caption="A successful raffle moves from atomic prize escrow through ticket sales and one randomness request to bearer redemption; oracle-liveness failure moves instead to exact bearer refunds."
:::

1. **Create.** Sofia selects Pixel Passport #42, 10.00 USDC tickets, a 100-ticket
   threshold, seven sale days, and her recovery wallet.
2. **Escrow.** The factory deploys and registers one raffle, then transfers and
   verifies the exact NFT in the same transaction.
3. **Sell.** Buyers pay the full ticket price and receive transferable ticket NFTs.
4. **Request.** After the sale, Alex or anyone else pays Pyth's current native fee.
5. **Resolve.** A valid callback selects one ticket. The threshold decides NFT versus
   cash, not whether a winner exists.
6. **Recover from liveness failure.** Missing request or callback deadlines enable
   exact ticket refunds without an administrator.
7. **Redeem.** Current ticket owners burn winning or refundable tickets. Sponsor and
   treasury withdraw recorded quote claims. The recovery recipient claims the NFT in
   cash, refund, or empty outcomes.

## 3. The Problem

A manually operated raffle asks participants to trust several facts that may be hard
to verify. Who owns the prize during the sale? Can the sponsor change the terms? Were
all tickets counted? Who produced the random result? Who can move the money? What
happens if the random service never answers?

The problem is not that every operator is dishonest. The problem is that informal
processes often leave custody, timing, and failure recovery ambiguous. A spreadsheet
can record ticket numbers but cannot prevent an administrator from editing the sheet.
A livestream can show a random draw but may not prove the prize was continuously held
or the winning number was mapped correctly.

Common weaknesses include:

- unclear prize custody;
- mutable sale terms;
- discretionary winner selection;
- opaque payment handling;
- no defined oracle-failure recovery;
- payouts that depend on one operator acting later;
- dependence on one website to explain or execute the result.

raffle.fun addresses only the onchain mechanics. It does not establish whether a
particular raffle is lawful, whether metadata describes a genuine asset, whether a
token issuer will keep transfers available, or whether participants understand the
risk.

## 4. The Core Idea

The contract is like a transparent lockbox with a rulebook attached. Sofia places the
prize in the lockbox. Buyers receive numbered bearer receipts. After the deadline, an
external randomness service supplies a value that the lockbox maps to one receipt.
The lockbox then exposes only the asset paths belonging to the selected outcome.

The rulebook moves seven responsibilities into contracts:

- **custody:** the raffle owns the configured NFT;
- **ticket ownership:** ERC-721 ownership identifies current bearer rights;
- **timing:** inclusive start, exclusive end, request grace, and callback timeout;
- **randomness authentication:** only the configured Pyth Entropy wrapper can deliver
  the stored sequence;
- **payout accounting:** successful branches allocate every raw USDC unit;
- **refunds:** failure branches reserve the gross pot for exact ticket burns;
- **claims:** independent recipients can retry their own asset transfers.

:::callout kind="noguarantee" title="What the contract cannot guarantee"
The contract cannot force a frozen USDC token to transfer, make a malicious NFT tell
the truth, restore lost wallet keys, compel a Base transaction to be included, or make
a chance-based promotion legal in every jurisdiction.
:::

## 5. What Onchain Means

Onchain does not mean every part of the experience is automatic or free from external
dependencies. It means the authoritative rules and state are available through the
contract on Base.

| Onchain authority | Offchain or external dependency |
| --- | --- |
| Raffle configuration and registered address | Website presentation and transaction prompts |
| Prize and ticket ownership | RPC availability and indexing latency |
| Start, end, grace, and timeout timestamps | Wallet software and key custody |
| Accepted Entropy sequence and raffle status | Pyth provider and keeper infrastructure |
| Winning ticket ID and quote liabilities | NFT metadata hosting and truthfulness |
| Bearer burns, claims, and emitted events | USDC issuer controls and prize-contract behavior |
| Factory owner and future-only policy | Legal classification, sanctions, tax, licensing, and age rules |

:::figure src="diagrams/17-onchain-offchain.svg" num="2" title="Onchain versus offchain" caption="The blockchain is authoritative for raffle state and asset ownership. Access layers, metadata, external services, and legal meaning remain outside the raffle contracts."
:::

If the frontend disappears, a technically capable user can still read the contracts
and submit transactions through another interface. That does not remove dependency on
Base, an RPC endpoint, a wallet, or the external token contracts.
