:::part id="part-ii" no="Part II" title="People and Assets" compact="true"
The protocol separates prize custody, bearer ownership, fixed recovery rights,
randomness delivery, and future-only administration.
- 6|Participant Roles
- 7|The Prize NFT
- 8|The Quote Token
- 9|Ticket NFTs
:::

# Part II | People and Assets

## 6. Participant Roles

:::figure src="diagrams/02-participant-role-map.svg" num="3" title="Participant role map" caption="One address may hold several roles, but each contract permission is defined separately."
:::

**Sponsor.** The account that calls the factory and deposits the prize. It selects the
prize, price, threshold, dates, metadata, and optional recovery recipient. It receives
normal sponsor USDC proceeds. It does not own or administer the deployed raffle.

**Sponsor-side prize-recovery recipient.** The fixed address that may withdraw the NFT
after `CashWon`, `Refunding`, or `Closed`. A zero creation input defaults to the sponsor.
The recipient may choose a safe nonzero destination when it claims. It cannot be
changed later.

**Buyer.** The account that pays USDC. The buyer may mint tickets to another recipient,
so payment and ticket ownership can belong to different accounts.

**Ticket recipient and current holder.** The recipient receives new ticket NFTs. After
any transfers, the current owner holds the bearer right. Only the current owner may
burn a winning or refundable ticket, even if another account has transfer approval.

**Winner.** The owner of the selected unburned ticket when redemption occurs. Winner
identity can change after selection because the ticket remains transferable until it
burns.

**Draw requester.** Any account that pays at least the current Entropy fee during the
request window. The requester need not be a sponsor or ticket holder and receives no
reimbursement from the USDC pot.

**Refund finalizer.** Any account that calls `enableRefunds` after the applicable
liveness deadline. The finalizer does not receive the refund money and does not select
owners.

**Quote claimant.** The sponsor or protocol treasury when successful settlement
creates its pull claim. A claimant can choose a nonzero destination with `claimQuote`.

**Prize claimant.** The winning bearer in `NftWon`, or the fixed recovery recipient in
`CashWon`, `Refunding`, and `Closed`.

**Protocol treasury.** The account captured by a raffle at creation. It receives the
successful-settlement fee as a quote pull claim. Later factory treasury updates do not
change it.

**Factory owner.** The OpenZeppelin `Ownable2Step` administrator for future creation
pause and future treasury selection. No existing raffle grants this owner a selector.

**Pyth Entropy.** The configured external randomness contract. It accepts the request
and later authenticates callback entry. Oracle correctness and infrastructure remain
external assumptions.

**Frontend, SDK, Lens, and subgraph.** Convenience layers. The Lens authenticates
registered raffle addresses and reads bounded state. The SDK simulates writes. The
subgraph indexes events. None can choose the winner or settle a raffle.

<!-- table:breakable -->
| Role | Can do | Cannot do | Must trust or verify |
| --- | --- | --- | --- |
| Sponsor | Create terms; deposit prize; claim successful proceeds | Cancel after a sale; change deployed terms; seize prize | Factory address, token behavior, recovery address, legality |
| Recovery recipient | Claim NFT in cash, refund, or empty result | Change itself; take NFT from `NftWon` | Key security and destination capability |
| Buyer | Pay USDC; choose ticket recipient | Force settlement; obtain a general cash-fallback refund | Price, dates, quote token, recipient, transaction result |
| Current ticket holder | Transfer ticket; burn winner or refunds | Redeem without actual ownership; redeem twice | Ticket ID, status, destination, Base inclusion |
| Draw requester | Pay current Pyth fee and request once | Choose random value; charge the ticket pot | Fee quote, request window, overpayment return capability |
| Refund finalizer | Enable deadline-based refunds | Select refund owner or take a fee | Correct deadline and chain inclusion |
| Treasury | Claim successful fee | Change existing fee or divert other claims | Factory creation snapshot and token availability |
| Factory owner | Pause future creation; change future treasury; transfer ownership | Upgrade, pause, rescue, reroll, or settle an existing raffle | Owner-key or multisig operations |
| Pyth Entropy | Deliver callback through authenticated wrapper | Override status after terminal transition | Provider, keeper, and oracle correctness |
| Frontend or subgraph | Present and index data | Authoritatively settle or change contract state | Correct deployment configuration and fresh reads |

## 7. The Prize NFT

An ERC-721 token represents one distinct token ID in one collection contract. Pixel
Passport #42 is identified by both its collection address and token ID 42. A picture
or name displayed by a website is metadata, not the ownership record.

Creation requires the prize address to contain code and report support for the
ERC-721 interface through ERC-165. The factory then performs a safe transfer from the
sponsor to the new raffle. The raffle receiver accepts only:

- the configured prize contract;
- the configured token ID;
- the immutable sponsor as `from`;
- the canonical factory as `operator`;
- the `AwaitingPrize` status.

After the transfer, the factory checks that `ownerOf(prizeTokenId)` equals the raffle
and that the raffle entered `Active`. Failure reverts the complete creation.

:::figure src="diagrams/03-atomic-creation.svg" num="4" title="Atomic creation and prize escrow" caption="Deployment, registry assignment, exact prize deposit, and verification succeed together or roll back together."
:::

This verification proves only what the prize contract reports in that transaction.
It cannot make malicious or upgradeable NFT code honest. A prize contract could later
lie about ownership, burn the escrowed token, pause transfers, reject transfers,
reenter, or change metadata.

Unsafe ERC-721 `transferFrom` can force unrelated NFTs into a raffle without calling
the receiver hook. Such tokens are outside protocol accounting. There is no factory-
owner rescue function and no generic raffle sweep.

:::callout kind="risk" title="Important prize risk"
Use only a prize whose contract, upgrade controls, ownership reporting, safe-transfer
behavior, and metadata provenance have been independently evaluated. Interface support
alone is not a safety certification.
:::

## 8. The Quote Token

The quote token is the fungible asset used for ticket payments and cash outcomes.
Every raffle from one factory uses the same immutable quote-token address. In the
reviewed implementation and deployment validation, that asset is chain-specific USDC.
Sponsors do not choose from an admission registry.

USDC commonly uses six decimal places. A human display of 10.00 USDC corresponds to
10,000,000 raw units. Solidity performs all accounting in raw integers.

Before minting tickets, the raffle measures its quote-token balance, calls
`transferFrom`, measures again, and requires the increase to equal the gross price.
Before paying USDC, it measures both the raffle and destination balances and requires
the exact expected debit and exact expected credit. A tax, fee, surcharge, dishonest
balance, or unexpected rebase makes the operation revert.

These checks reject many unsupported behaviors but do not guarantee permanent
availability. USDC may be paused, blacklisted, upgraded, or otherwise controlled by
its issuer. A later issuer action can trap an otherwise valid claim.

Direct USDC donations are not ticket purchases. They do not increase `totalTickets`,
`grossSales`, the fee, sponsor proceeds, winner cash, or refunds. They appear only as
surplus above accounted liabilities. No administrator can sweep that surplus.

## 9. Ticket NFTs

Each ticket is an ERC-721 token minted by its raffle. Ticket IDs begin at 1 and remain
sequential. One ticket equals one chance in the winner formula. A bounded purchase can
mint several IDs to one recipient.

The ticket is a bearer credential:

- while unburned, ownership can transfer in `Active`, `Drawing`, `NftWon`, `CashWon`,
  `Refunding`, or `Closed`;
- a selected winning ticket carries its NFT or cash right to each new owner;
- a refundable ticket carries its one-ticket-price refund right to each new owner;
- burning the ticket consumes that right and the ERC-721 token ceases to exist.

Known protocol destinations are rejected because they may own a ticket but lack a way
to initiate redemption. A ticket cannot transfer to its own raffle, its factory, the
quote token, the Entropy contract, the prize contract, or a registered sibling raffle.

This cannot identify every incapable third-party contract. An owner can use unsafe
transfer to send a ticket to an unrelated contract that cannot call redemption. That
ticket may become unrecoverable. A narrow helper covers future same-factory raffle
addresses that were code-less at transfer time; it is not a generic rescue.

All tickets may share one metadata URI. Metadata can be unavailable or misleading.
Tickets are receipts and bearer ownership records, not investments and not guaranteed
valuable collectibles.
