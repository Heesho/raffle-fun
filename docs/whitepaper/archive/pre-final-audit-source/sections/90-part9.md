:::part id="part-ix" no="Part IX" title="Conclusion"
What this design actually makes possible, and the handful of facts worth remembering.
- 39|What raffle.fun Makes Possible
- 40|Final Takeaways
:::

# Chapter 39 | What raffle.fun Makes Possible

Strip away the terminology, and raffle.fun does one specific thing: it lets a
stranger run a prize drawing that other strangers can join without anyone needing
to believe anyone. The prize is provably locked before the first ticket sells. The
rules are provably frozen before the first ticket sells. The odds are publicly
countable at every moment. The draw comes from a source none of the participants
control, exactly once. The payouts follow arithmetic that was published in advance,
and every failure the designers could bound is bounded: a raffle that cannot finish
returns everyone's money by rules, not by customer support.

That is a narrow claim, and the narrowness is deliberate. The protocol does not
judge prizes, guarantee value, replace law, or eliminate every dependency; Chapters
31 and 33 held that line honestly. What it eliminates is the specific, historically
well-earned need to trust a raffle operator with custody, rules, odds, drawing, and
settlement all at once. For sponsors, a credible raffle no longer requires a
reputation as collateral. For participants, "will I get paid?" is answered by code
you can read instead of a promise you cannot. For builders, raffle mechanics become
infrastructure: a primitive to compose with, audit once, and reuse.

Whether that primitive becomes widely used depends on things no whitepaper can
settle: audits, deployment, real communities, and law. What this document
establishes is what the software does, precisely, at one commit, so every later
conversation can start from facts.

# Chapter 40 | Final Takeaways

Seven sentences to keep:

1. The raffle contract, not any person, holds the prize and the money from creation
   to settlement, and its rules cannot be edited by anyone after creation.
2. Every ticket has equal odds, the count is public, and the minimum is an outcome
   threshold, never a sales cap.
3. One random result from Pyth Entropy decides the winner; equality with the
   minimum counts as met, the last ticket is eligible, and no draw can be redone.
4. Money flows are fixed: a 5 percent fee, then 100/0 or 80/20 of the rest by
   threshold; failed draws refund every ticket in full and charge nothing.
5. Everything is pull-based and permissionless where it matters: anyone can request
   the draw, finalize a failure, or help deliver a claim, and claims never expire.
6. The administrator's power stops at the door of every live raffle, structurally:
   the functions to interfere do not exist.
7. The honest limits remain: unaudited code, prize authenticity, token-issuer
   power, oracle fairness, your own keys, and your own jurisdiction's law.
