:::part id="part-viii" no="Part VIII" title="Frequently Asked Questions"
Direct answers to the questions sponsors, buyers, and reviewers actually ask: twenty-six of them, each verifiable against the code.
:::

<!-- h1continue -->
# | Frequently Asked Questions

Answers below are statements about the contracts at the reviewed commit; each is
verifiable in the code and cross-referenced in the fact-check record.

:::html
<div class="faq-q">Who holds the NFT during the raffle?</div>
:::

The raffle contract itself. From the creation transaction until a terminal claim,
the ledger lists the contract as the owner. No person, including the sponsor and the
raffle.fun team, holds keys that can move it.

:::html
<div class="faq-q">Can the sponsor take the NFT back after tickets are sold?</div>
:::

No. Cancellation requires zero tickets sold, permanently. After the first sale, the
prize can only leave through the raffle's own endings.

:::html
<div class="faq-q">Can the administrator choose or influence the winner?</div>
:::

No. Winner selection happens inside the randomness callback from the oracle's
number, and no administrative function exists on a raffle at all.

:::html
<div class="faq-q">Can anyone change the ticket price, minimum, or dates after creation?</div>
:::

No. There are no setter functions. The configuration written at creation is the
configuration forever.

:::html
<div class="faq-q">Is the minimum a cap? Can sales pass it?</div>
:::

The minimum is not a cap. Sales continue until the fixed closing time; each further
ticket grows the pot and dilutes all odds. There is no maximum ticket count.

:::html
<div class="faq-q">Can tickets be transferred, and who wins if a ticket changes hands?</div>
:::

Tickets transfer freely while the raffle is Active. Whoever holds the winning ticket
at the instant the callback executes is the winner; for refunds, whoever holds a
ticket when its refund is credited receives it. Transfers freeze during the draw and
per-ticket during refunds precisely so these snapshots cannot be gamed.

:::html
<div class="faq-q">What happens if not enough tickets sell?</div>
:::

The draw still happens. The winner receives 76 percent of the pot in cash, the
sponsor 19 percent plus rounding, the treasury 5 percent, and the prize returns to
the recovery address.

:::html
<div class="faq-q">What happens if nobody buys a single ticket?</div>
:::

After the close, anyone may finalize the no-sales outcome and the recovery address
reclaims the prize. No money existed, so nothing else needs to happen.

:::html
<div class="faq-q">Who pays the randomness fee, and what if I overpay?</div>
:::

Whoever volunteers to request the draw pays the oracle's current fee in ETH. Any
overpayment is credited back to that requester as a withdrawable balance.

:::html
<div class="faq-q">What happens if the random number never arrives?</div>
:::

Deadlines take over. No successful request within 3 days of closing, or no callback
within 2 days of a request, lets anyone flip the raffle into refunds: full ticket
price back per ticket, no fee, prize home to the recovery address.

:::html
<div class="faq-q">Are refunds automatic?</div>
:::

Almost. Entering refund mode and crediting each ticket are permissionless
transactions someone must send (the app operator, a holder, anyone); your withdrawal
is then yours to make whenever you wish. No step depends on a privileged party.

:::html
<div class="faq-q">Why do I have to claim instead of just receiving my money?</div>
:::

So that nobody else's failure can block you. Push-payouts let one rejecting
recipient jam an entire settlement; pull-claims isolate every participant. Chapter
23 is the full argument.

:::html
<div class="faq-q">What if my claim transaction fails?</div>
:::

It reverts harmlessly and your claim survives. Retry any time, or claim to a
different destination you control.

:::html
<div class="faq-q">Can a malicious payment token trap funds?</div>
:::

A token that misdelivers makes transactions revert rather than corrupting balances,
and only factory-admitted tokens can be used at creation. What remains is issuer
power: a pause or blacklist can delay or block specific withdrawals, which no
contract can cure. That residual risk is why the admission list exists.

:::html
<div class="faq-q">Can any NFT be raffled?</div>
:::

Any token from a deployed contract that affirmatively reports ERC-721 support and
honestly transfers ownership at escrow. Authenticity and value are explicitly not
checked; judge the collection yourself.

:::html
<div class="faq-q">Does the raffle.fun website control the raffle?</div>
:::

No. The website displays and assists. Every action it offers is a public contract
function anyone can call with any wallet; if the site vanished, every raffle would
proceed and settle unchanged.

:::html
<div class="faq-q">Can the contracts be upgraded?</div>
:::

No. Raffles are non-upgradeable clones of a locked implementation. New protocol
versions mean new contracts deployed separately; existing raffles never change.

:::html
<div class="faq-q">What exactly does the factory owner control?</div>
:::

For future raffles only: the admitted payment-token list, the treasury address, and
a creation pause. Nothing about any existing raffle. Chapter 30 is the complete
inventory.

:::html
<div class="faq-q">How are fees calculated, exactly?</div>
:::

Once, at resolution: 5 percent of the whole pot, rounded down, credited to the
treasury. Failure and no-sales endings charge nothing. There are no other protocol
fees; the draw requester separately pays the oracle's fee, and every transaction
costs its sender ordinary gas.

:::html
<div class="faq-q">Can the same ticket win twice, or a raffle draw twice?</div>
:::

No. One request, one accepted sequence, one winner, recorded once. Duplicates and
replays are ignored by construction.

:::html
<div class="faq-q">Is the last ticket sold actually eligible?</div>
:::

Yes. The formula (random mod tickets) plus 1 covers every ticket from 1 through the
last, inclusive, each with equal probability; a one-ticket raffle picks ticket 1.

:::html
<div class="faq-q">Can a sponsor rig the draw by picking the moment it happens?</div>
:::

Requesting earlier or later does not help: the random value comes from the oracle's
commit-reveal process, not from block data, and the request locks transfers before
any result exists. A sponsor can buy tickets like anyone else, publicly; that is
participation, not rigging.

:::html
<div class="faq-q">Is raffle.fun legal in my country?</div>
:::

This document cannot answer that. Chance-based prize distribution is regulated
differently everywhere, and nothing here is legal advice. Obtain advice for your
jurisdiction before operating or participating.

:::html
<div class="faq-q">Has the protocol been independently audited?</div>
:::

No. Extensive internal testing exists (Chapter 34), and the deployment runbook
requires an independent review before production, but at the reviewed commit no
external audit has been performed.

:::html
<div class="faq-q">What should I verify before interacting, in one breath?</div>
:::

The domain, the factory address, the raffle address, the prize collection's
authenticity, the payment token, the price, the minimum versus tickets sold, and
the closing time. The checklists in Chapter 38 expand each item.
