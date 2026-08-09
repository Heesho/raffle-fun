:::part id="part-ii" no="Part II" title="The People and the Assets"
Who does what in a raffle, and exactly which digital assets are at stake.
- 6|Participants
- 7|The Prize NFT
- 8|The Payment Token
- 9|Ticket NFTs
:::

# Chapter 6 | Participants

A raffle involves a handful of roles. One person can hold several of them at once
(the sponsor can buy tickets; a buyer can gift tickets to a friend), but each role
has exactly defined powers.

:::figure src="diagrams/participants.svg" num="3" title="Participant and role map" caption="Everyone who touches a raffle, arranged around the raffle contract that enforces the rules between them. The dashed border marks the one party with no path into a live raffle: the protocol administrator."
:::

The **sponsor** creates the raffle, deposits the prize, and fixes every rule in one
transaction, including a **recovery address** where the prize returns in each ending
where the winner does not take it (by default, the sponsor itself). After the first
ticket sells, the sponsor has no special powers left except receiving its own
settlement. The **buyer** pays for tickets; the **ticket recipient** is whoever the
buyer names to receive them, which enables gifts. The **current ticket holder** is
whoever owns a ticket at a given moment; tickets are transferable assets, so this can
change. The **winner** is the holder of the winning ticket at the instant the random
result arrives, recorded permanently. The **draw requester** is any person who pays
the small randomness fee after the sale closes; this is a public service anyone can
perform, as is the **refund finalizer** role that opens and credits refunds after a
failed draw. The **protocol treasury** is a fixed address credited the 5 percent fee
when a draw resolves a raffle. The **factory owner** administers only the creation
of future raffles. **Pyth Entropy** is the external randomness service. The
**frontend and indexer** display and organize; they hold no power.

<!-- table:breakable -->
| Participant | Can do | Cannot do | Must trust |
| --- | --- | --- | --- |
| Sponsor | create the raffle, fix all rules, cancel while zero tickets sold, claim its settlement | change any rule after creation, cancel after a sale, pick the winner, touch the pot | that enough buyers find the raffle attractive |
| Buyer | buy 1 to 100 tickets per transaction at the fixed price, direct tickets to any recipient | buy outside the sale window, pay a different price, exceed contract-level checks | the prize's authenticity, the payment token's issuer |
| Ticket holder | hold or transfer tickets while transfers are open, win, claim refunds for tickets held at failure | transfer during the draw freeze or before an uncredited refund, change odds except by holding more tickets | the same external parties as buyers |
| Winner | claim the NFT or cash exactly as the branch dictates, choose a safe destination | claim twice, claim someone else's share, be skipped by anyone | that they keep control of their own wallet keys |
| Draw requester | trigger the one draw within its 3-day window by paying the oracle fee | influence the random result, request twice | Pyth to answer; else refunds open |
| Refund finalizer | flip a failed raffle into refund mode after its deadline, credit refund batches | choose who is refunded or how much, take a cut | nothing; the action is mechanical |
| Protocol treasury | claim its 5 percent fee after a resolved draw | charge more, charge on refunds or cancellations, intervene anywhere | nothing inside the raffle |
| Factory owner | admit or remove payment tokens for future raffles, set future treasury, pause new creation, hand over ownership | touch any existing raffle in any way | its own key security (a multisig is expected) |
| Pyth Entropy | deliver the one random result for the stored request | forge a request, deliver twice, redirect funds | its own cryptographic and operational design |
| Frontend / indexer | display, search, and simplify | change state, block claims, alter outcomes | nothing; users should verify against the chain |

# Chapter 7 | The Prize NFT

:::callout kind="sentence"
The prize is a specific token from a specific NFT contract, locked inside the raffle
from the moment of creation until exactly one authorized claim releases it.
:::

An **NFT** (non-fungible token) is a blockchain record that says "token number N of
collection C belongs to address A." The standard that defines how such tokens behave
on Ethereum-style chains is called **ERC-721**. Owning an NFT means controlling the
key of the address the ledger lists as its owner; nothing more, nothing less.

**Escrow** means handing an asset to a neutral keeper until an outcome decides who
gets it. Here the keeper is the raffle contract itself. In the same transaction that
creates the raffle, the factory moves the prize from the sponsor's wallet into the
new raffle contract. From that moment, the sponsor cannot sell, move, or reclaim the
NFT except through the raffle's own endings.

## How the contract validates the prize

The raffle refuses everything except the exact expected deposit: it must be in its
initial waiting state, the token must come from the configured collection, carry the
configured token ID, come from the sponsor, and be delivered by the factory. After
the transfer, the factory additionally asks the NFT contract who owns the token now
and requires the answer to be the raffle. A collection that lies about ownership
fails this check and the whole creation reverts, sponsor unharmed.

:::figure src="diagrams/prize-custody.svg" num="4" title="Prize custody flow" caption="The prize's whole life: one road in, and exactly two doors out. The winner's door opens only in the NftAwarded outcome; the recovery address's door opens in every other ending. The claim can be retried if a delivery fails, and anyone may push the prize to the recorded claimant, but never anywhere else."
:::

:::callout kind="risk"
Escrow proves possession, not authenticity or value. A counterfeit "copy" of a famous
artwork is a perfectly valid ERC-721 token, and the contract will escrow it
faithfully. Some NFT collections are also upgradeable or administratively controlled,
meaning their own operator could freeze or alter tokens while they sit in escrow.
Buyers must judge the collection itself; Chapter 36 shows how.
:::

# Chapter 8 | The Payment Token

:::callout kind="sentence"
All ticket money in a raffle is denominated in one ERC-20 token, chosen by the
sponsor from a short list the factory owner has reviewed and admitted.
:::

An **ERC-20 token** is the standard for interchangeable blockchain money: units are
identical, divisible, and held as balances. USDC, a token redeemable one-to-one for
US dollars, is the typical example. In raffle.fun this is called the **quote token**
because it is the unit the ticket price is quoted in.

Internally, token amounts are integers in the token's smallest unit. USDC has six
decimal places, so "10 USDC" is stored as the raw integer 10,000,000. Every formula
in this document operates on such raw units, which is why rounding, when it happens,
is always a matter of a single indivisible unit (a millionth of a dollar for USDC).

## Why an allowlist?

ERC-20 is a loose standard, and hostile or merely unusual tokens can break naive
accounting: some skim a fee from every transfer, some rebase balances up and down,
some return misleading values. The raffle defends itself mechanically: on every
purchase it measures its own balance before and after and requires the increase to
equal the price exactly, and on every payout it verifies both its own decrease and
the recipient's increase. A token that fails these checks makes transactions revert
rather than corrupting accounts. On top of that, the factory only allows raffle
creation with tokens its owner has reviewed and admitted (at most 32 at a time).
Removing a token later stops new raffles from using it but changes nothing for
raffles that already exist.

:::callout kind="noguarantee"
The allowlist and the exact-transfer checks cannot remove issuer power. A token like
USDC has a blacklist function: if the issuer blacklists a claimant's address, that
claimant's withdrawal will fail while everyone else's still works, and the claim
simply waits (it can also be sent to a different destination the claimant chooses,
or the token issuer may unblock the address). If an issuer pauses the entire token,
all withdrawals in that token wait until it resumes. The raffle cannot print
replacement money.
:::

# Chapter 9 | Ticket NFTs

:::callout kind="sentence"
Every ticket is itself an ERC-721 token with a sequential number, equal odds, and
normal transferability except during two well-defined freezes.
:::

When Ben pays 50 USDC for 5 tickets in Ava's raffle, the contract mints him tickets
numbered, say, 6 through 10. Making tickets real tokens rather than database rows
has three consequences. First, the supply is provable: totalTickets is public state,
so "you hold 5 of 87 tickets" is a verifiable statement, and the contract even
exposes a convenience view that computes your current odds. Second, tickets are
property: you can transfer one to a friend, sell it, or hold it in another wallet
you control, all before the draw is requested. Third, the winner is determined by
ownership at a precisely defined instant, not by whoever's name is on a list.

## Numbering and odds

Tickets are numbered from 1 upward with no gaps; each purchase mints a contiguous
block to the chosen recipient. The draw picks one number in that range with equal
probability for every ticket, including ticket 1 and the last ticket sold. Holding
ten tickets gives exactly ten times the chance of holding one; there are no
weighted, discounted, or bonus tickets.

## When transfers freeze

Transfers work normally while the raffle is Active, including after the sale closes
but before a draw is requested. The moment a draw request succeeds, transfers freeze
so that nobody can trade tickets while the random result is in flight. If the raffle
resolves normally, transfers reopen immediately, but by then the winner has been
recorded permanently, so the tickets become transferable souvenirs whose movement
changes nothing. If the raffle instead fails into refund mode, each individual
ticket stays frozen until its refund has been credited to its holder, and then
becomes a souvenir too. Chapter 16 walks through the timing in detail.

:::callout kind="holder"
Buying a ticket for someone else? Purchases take a recipient address, so the ticket
can be minted directly to your friend's wallet. Whoever holds the ticket at the
draw, or at refund crediting, gets the winnings or the refund. Gift accordingly.
:::
