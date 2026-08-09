:::part id="part-i" no="Part I" title="The Idea"
What raffle.fun is, the problem it answers, and what "onchain" really buys you.
- 1|Executive Summary
- 2|raffle.fun in 60 Seconds
- 3|The Problem
- 4|The Core Idea
- 5|What "Onchain" Means
:::

# Chapter 1 | Executive Summary

raffle.fun is a protocol for running prize raffles where the prize is a digital
collectible (an NFT) and every rule is enforced by a program on a public blockchain
rather than by a person. This chapter compresses the whole document into two pages.

## What is raffle.fun?

raffle.fun lets anyone whose payment token is on an approved list run a provably fair
raffle for a single NFT. The person giving away the prize, called the sponsor, locks
the NFT into a small, single-purpose program called a raffle contract. That contract,
not the sponsor and not the raffle.fun team, then holds the prize, sells the tickets,
holds the money, runs the draw, and pays everyone out according to rules that were
fixed the moment the raffle was created.

The software consists of onchain contracts (a factory that creates raffles, the
raffle logic itself, and a read-only helper), plus supporting tools: a web
application, a developer kit, and an indexer that makes raffle history searchable.
The contracts target Ethereum, the largest smart-contract network, and Base, a
low-fee network built on Ethereum technology. At the commit this document
describes, the contracts are complete and tested but not yet deployed to any
public network, and they have not been independently audited.

## Who is it for?

Three groups. Sponsors: artists, collectors, brands, and communities who want to
distribute an NFT by chance instead of by auction or fixed-price sale. Participants:
anyone who wants a transparent, equal-odds chance at that NFT for the price of a
ticket. Builders: developers who want raffle mechanics they can integrate without
trusting an operator, because every rule is public and enforced by code.

## How does a raffle work?

A sponsor creates a raffle by choosing the prize NFT, a payment token from the
factory's approved list (for example USDC, a digital dollar), a ticket price, a
minimum number of tickets, a sale window of up to 30 days, and a recovery address
that can reclaim the prize in every ending where the winner does not take it. The
prize moves into the contract in the same transaction. Buyers then purchase tickets
at the fixed price. Each ticket is itself a small digital asset with equal odds, and
tickets can be transferred to other people while the sale runs.

When the sale closes, anyone may pay a small fee to ask Pyth Entropy, an independent
randomness service, for one random number. That number picks exactly one winning
ticket. If at least the minimum number of tickets was sold, the winning ticket's
holder claims the NFT, the sponsor is credited 95 percent of the ticket money, and
the protocol treasury is credited a 5 percent fee. If fewer than the minimum sold,
the winner instead is credited 76 percent of the pot in cash, the sponsor is credited
19 percent, the treasury still receives 5 percent, and the prize returns to the
recovery address.

If the draw never happens, the protocol does not strand anyone. When no draw request
succeeds within 3 days of closing, or a requested draw is unanswered for 2 days,
anyone can flip the raffle into a refund mode in which every ticket is credited its
exact purchase price back, no fee is charged, and the recovery address reclaims the
prize. Every payout in every ending is pull-based: the contract records what each
person is owed, and they withdraw it themselves whenever they choose. Claims never
expire.

## What does the administrator control?

Remarkably little, and nothing inside a live raffle. The factory owner, expected to
be a multisig (an account requiring multiple signatures), can admit or remove payment
tokens for future raffles, change the treasury address for future raffles, and pause
the creation of new raffles. It cannot touch an existing raffle's prize, money,
rules, deadlines, winner, or refunds, because no function exists that would let it.

## The most important risks

The software is unaudited, and testing cannot prove the absence of bugs. The prize
NFT can be counterfeit or worthless: the contract escrows whatever the sponsor
deposits and cannot judge authenticity. Payment tokens are real-world instruments
whose issuers may freeze accounts. Normal settlement depends on the Pyth randomness
service; if it stalls, the outcome is a full refund rather than a prize. Chance-based
prize distribution is regulated differently across jurisdictions, and this document
makes no compliance claims. Chapter 33 lists everything the protocol cannot promise.

# Chapter 2 | raffle.fun in 60 Seconds

This page is the whole protocol in one picture. If you read nothing else, read this.

:::figure src="diagrams/at-a-glance.svg" num="1" title="raffle.fun at a glance" caption="The five steps of every raffle, the two payout branches the ticket count selects, and the built-in exits for every way a raffle can end without a draw. Percentages are fixed constants compiled into the contract: a 5 percent protocol fee, then in the cash branch an 80/20 split of the remainder between winner and sponsor."
:::

:::callout kind="sentence"
A sponsor locks one NFT in a contract that sells equal-odds tickets, has an
independent service pick one winning ticket, and lets everyone withdraw exactly what
the fixed rules say they are owed, with full refunds if the draw never happens.
:::

# Chapter 3 | The Problem

Prize raffles are ancient and popular, but running one fairly requires the operator
to make promises that participants cannot verify. This chapter describes the general
weaknesses of manually run raffles. They are design problems inherent to trusting an
operator, not accusations against any specific business.

## Opaque custody

In a conventional online raffle, the operator holds the prize and the money at the
same time. Participants cannot see whether the prize actually exists, whether it is
already promised to someone else, or whether ticket revenue is kept separate from the
operator's own funds. If the operator disappears mid-raffle, both prize and payments
usually go with them.

## Rules that can change

The price, the deadline, the number of tickets, and the payout split live in a
database the operator edits at will. Extending a sale that is going well, quietly
adding tickets, or changing the split after money has arrived are all one keystroke
away, and participants would rarely be able to tell.

## Unclear odds

"One winner will be chosen from all entries" says nothing about how many entries
exist. Without a public count of tickets sold, a participant cannot know whether they
hold one chance in fifty or one in fifty thousand, and the operator can inflate the
count invisibly.

## Discretionary winner selection

A drawing performed on a spreadsheet, a stream, or a website widget is a drawing the
operator can redo until it likes the answer. Even honest operators cannot prove a
single, final, untampered draw; dishonest ones can pick a friend and produce a
plausible-looking ceremony.

## Settlement risk

Winning is not the same as being paid. The winner of a manual raffle receives the
prize if and when the operator sends it. Refunds after a failed or cancelled raffle
arrive if and when the operator processes them. Every step depends on the operator's
solvency, honesty, and continued existence.

## A single point of failure

One website, one database, one bank account, one person with the password. If any of
these fails, is hacked, or is seized, the raffle and its assets fail with it.

:::callout kind="why"
Every one of these weaknesses is a promise a human must keep. The design question
behind raffle.fun is: how many of those promises can be replaced with a program whose
behavior anyone can inspect and no one can quietly change?
:::

# Chapter 4 | The Core Idea

raffle.fun moves the raffle itself, custody, rules, tickets, accounting, drawing,
and payouts, into a smart contract: a program deployed on a public blockchain that
runs exactly as written and cannot be edited afterward.

## What moves into the contract

The prize sits inside the contract from creation until the outcome is settled, so it
provably exists and provably cannot be sold twice. The rules (price, minimum,
deadlines, splits, recovery address) are fixed at creation; there is no edit
function. The tickets are numbered digital assets minted by the contract itself, so
the total count is public at every moment and the advertised odds are checkable.
The money accumulates inside the contract, and the payout logic that eventually
distributes it is the same public code everyone inspected before buying. The draw
comes from an external randomness service through a single authenticated channel,
and the contract accepts exactly one result. Finally, the failure paths are part of
the program: fixed deadlines convert a missing draw into full refunds without asking
anyone's permission.

## What stays outside the contract

Honesty about the boundary matters as much as the boundary itself. The contract
cannot verify that an NFT is authentic or valuable, only that a specific token from a
specific contract was deposited. It cannot control the payment token's issuer, who
may be able to freeze balances. It does not generate randomness itself; it verifies
the source and consumes one result. The website people use is replaceable
infrastructure, not the raffle. And no code can decide whether running a raffle is
lawful where you live.

:::callout kind="sentence"
raffle.fun replaces the promises a raffle operator makes with rules a program
enforces, and is explicit about the few promises no program can enforce.
:::

# Chapter 5 | What "Onchain" Means

"Onchain" is shorthand for "recorded in a blockchain's shared ledger, where everyone
sees the same data and no single party can rewrite it." This chapter separates what
lives onchain from what merely talks about it, because the difference decides what
you can safely trust.

A blockchain is a public record book kept simultaneously by thousands of computers
that continuously check each other. Ethereum and Base, the networks raffle.fun
targets, are such ledgers: they store account balances, program code, and program
state, and they execute transactions, which are signed instructions submitted by
users. A wallet is the app that holds your signing key and submits those
transactions; gas is the small fee the network charges to process one.

For a raffle, the ledger holds everything that decides who gets what: the raffle's
rules and current stage, who owns the prize, who owns each ticket, how much money
the contract holds and who may claim it, the stored randomness request, and a
permanent log of events. Around that core sits convenience infrastructure that lives
offchain: the raffle.fun website, the images and descriptions attached to NFTs, the
subgraph (a searchable index rebuilt from onchain events), the RPC providers that
relay your requests to the network, and your wallet software itself.

:::figure src="diagrams/onchain-offchain.svg" num="2" title="The hierarchy of authority" caption="Five layers, from the blockchain state at the top to websites at the bottom. Each lower layer is more convenient and less authoritative. A compromised website can lie about the chain, but it cannot change the chain; the defense is checking important facts against a higher layer before signing."
:::

:::callout kind="risk"
Most real-world losses in blockchain applications happen at the bottom two layers: a
fake or hacked website presents false information, and a user signs a transaction
based on it. The raffle.fun web application re-reads contract state and simulates
every transaction immediately before asking a wallet to sign, but no page can protect
a user who signs whatever a hostile page requests. When the stakes are high, verify
the raffle's address and rules against the chain itself.
:::
