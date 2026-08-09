<!-- pagebreak -->

# | How to Read This Whitepaper

This document explains one piece of software: the raffle.fun smart contracts as they
exist at Git commit `a2120f5`, together with the applications built around them. It
is written for two readers at once.

The first reader has never used a blockchain. Every chapter's main text is written
for you: each new idea gets a definition, an everyday comparison, and a concrete
example before anything technical appears, and unfamiliar terms are defined where
they first appear or in the glossary in Appendix G.

The second reader is technical: a developer, auditor, investor, or integration
partner. For you, the precise details live in the "Under the hood" boxes, the tables,
the figures, and the appendices. Appendix A holds the exact state machine, Appendix B
the exact arithmetic, Appendix C the contract reference, and Appendix E the security
invariants. Nothing in an appendix contradicts the main text; it only sharpens it.

## The recurring boxes

The same few labeled boxes appear throughout the document, and they always mean the
same thing:

- **In one sentence**: the shortest true summary of the chapter.
- **Example**: the running fictional raffle, described below.
- **Why this matters**: the design motivation in plain language.
- **What the contract enforces**: rules that hold because code enforces them onchain.
- **What this does not guarantee**: the honest edge of each guarantee.
- **Under the hood**: implementation detail for technical readers, safe to skip.
- **Important risk**: something that can cost a user money.
- **For sponsors** and **For ticket holders**: advice specific to one role.

## The running example

One fictional raffle appears throughout the book so that every rule can be shown
with real numbers. Ava, an artist, raffles a one-of-one digital artwork called
Sunset Study #7: tickets cost 10 USDC, the minimum is 100 tickets, the sale runs 14
days, and Ben, Maya, Leo, and Noor buy in. Depending on the chapter, the sale ends
with 120 tickets sold, with 80, or with none. All example arithmetic was recomputed
with the protocol's own math library; none of it is rounded by hand.

## What this document is not

This whitepaper is not marketing and not advice. It describes unaudited, undeployed
software at one specific commit, including its limitations and failure modes. Where
a statement could not be verified against the code, it was left out; the companion
file `docs/whitepaper/FACT-CHECK.md` maps each significant claim to its source.
