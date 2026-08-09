:::part id="part-vii" no="Part VII" title="User Guides"
Step-by-step walkthroughs for sponsors, buyers, and winners, and the checklists that keep them safe.
- 35|Sponsor Walkthrough
- 36|Ticket Buyer Walkthrough
- 37|Winner Walkthrough
- 38|Safety Checklists
:::

# Chapter 35 | Sponsor Walkthrough

You have an NFT and want to raffle it. Here is the whole journey, in order.

**1. Verify you are in the right place.** Confirm the application's domain
carefully and, for meaningful amounts, cross-check the factory address the site
uses against an independent source (the official announcement, the block explorer's
verified-contract page). Everything else you do flows through that address.

**2. Choose the prize and understand the approval.** Pick the NFT. Your wallet will
first ask you to approve the factory to transfer that specific token. Prefer
single-token approval over collection-wide approval when the interface offers the
choice.

**3. Choose the payment token.** The interface lists only tokens the factory
currently admits. Pick the one your audience actually holds; a raffle priced in an
obscure token is a raffle with fewer buyers.

**4. Set the price and the minimum honestly.** Price times minimum is the gross
interest you are asking the market to show. Set the minimum at the level below
which you would genuinely rather keep the NFT, because that is exactly what the
contract will enforce. Remember the cash branch: if the minimum is missed, the
winner takes 76 percent of whatever pot exists and you receive 19 percent plus the
prize back.

**5. Set the dates.** Sales may start now or up to 7 days out, and run at most 30
days. Shorter windows concentrate attention; longer windows suit larger audiences.
The 3-day draw window and 2-day callback timeout after closing are fixed and not
yours to change.

**6. Set the recovery address deliberately.** This is where the prize returns in
every ending except an outright win, and it cannot be changed later. A hardware or
vault wallet you control is the robust choice; leaving it as your active wallet is
the default.

**7. Create, and check the result.** One transaction does everything. Afterward,
verify on the explorer that the new raffle owns your NFT and that its parameters
read back as you intended. The interface will show the raffle's permanent address;
share that address, not a screenshot.

**8. During the sale.** You have no dials to turn, which is the point and the
pitch. You may buy tickets in your own raffle like anyone else, publicly. If nobody
has bought yet and you regret the setup, you can cancel and reclaim the prize; the
first sale removes that option permanently.

**9. After the close.** Anyone can request the draw; do not assume someone else
will. If the raffle resolves, claim your proceeds with claimQuote; if the minimum
was missed, your recovery address also reclaims the prize via claimPrize. If the
draw fails entirely, expect refunds to be credited (anyone can do it, including
you) and your recovery address to reclaim the prize. Claims never expire, but there
is no reason to wait.

:::callout kind="sponsor"
The one decision that deserves the most thought is the minimum. It is your public
statement of reserve value, it decides which branch is likely, and it is the number
sophisticated buyers will judge you by.
:::

# Chapter 36 | Ticket Buyer Walkthrough

**1. Judge the prize before the raffle.** The contract guarantees custody, not
authenticity. Open the prize's collection on a block explorer or marketplace you
trust: is it the canonical contract for that artwork or collectible, or a
same-named copy? Does the collection have an owner or upgrade powers that could
alter tokens? A minute of diligence here dominates everything else.

**2. Judge the sponsor.** Pseudonymous is normal onchain; unverifiable is a
warning. A sponsor whose address has history, whose socials link to the raffle
address, and who answers questions is offering you more than a fresh wallet with a
stock image.

**3. Read the raffle's terms.** Fixed price, minimum, closing time, payment token:
all onchain, all shown by the app, all checkable on the explorer. Note especially
the minimum versus tickets already sold: it tells you which branch you are likely
buying into, the NFT draw or the 76 percent cash draw.

**4. Understand your odds, live.** Odds are tickets-held over tickets-sold, and
tickets keep selling until the close. Ten percent odds now can be five percent
tomorrow; the pot grows correspondingly. The app shows both continuously.

**5. Approve and buy.** Your wallet approves the raffle to spend the exact
purchase amount of the payment token, then the purchase mints your numbered
tickets. Wallets with batching support show one confirmation; others show two.
Verify the amount before signing; the contract will take exactly the advertised
price and nothing else.

**6. Optionally, move tickets.** Tickets are yours: transfer them to a friend, a
cold wallet, wherever, any time before a draw request succeeds. Whoever holds a
ticket when the draw lands, or when a refund is credited, receives what that ticket
earns.

**7. Wait for settlement.** After the close, someone (possibly you) requests the
draw within 3 days; the result usually follows quickly. If instead the deadlines
lapse, the raffle flips to refunds with no action needed from you except the final
withdrawal.

**8. Claim.** If you won, Chapter 37 is yours. If the raffle refunded, your balance
appears once your tickets are credited; withdraw it with claimQuote whenever you
like. Losing tickets in a resolved raffle earn nothing; they remain as souvenirs.

:::callout kind="holder"
Spend only what you can afford to lose to chance. This is a raffle: the expected
outcome of buying a ticket is losing the ticket price. The protocol makes the odds
honest; it does not make them good.
:::

# Chapter 37 | Winner Walkthrough

There are three ways to "win" and each ends differently.

**You hold the winning ticket and the minimum was met.** You are the recorded
winner and prize claimant. Call claimPrize with the address where you want the NFT
delivered (your everyday wallet, a vault, anywhere safe; not a contract that
rejects NFTs, though if delivery fails the claim survives and you retry). A helper
can alternatively push the prize straight to your recorded address using
claimPrizeFor; nobody, helper or otherwise, can send it anywhere but to you.

**You hold the winning ticket and the minimum was missed.** You are the recorded
winner of the cash prize: 80 percent of the post-fee pot. Call claimQuote with your
chosen destination and the tokens transfer immediately. The NFT is not yours in
this branch; it returns to the sponsor's recovery address.

**The raffle failed and you held tickets.** Not a win, but money back: once your
tickets are credited (anyone can run the crediting; the app surfaces it), your full
purchase price per held ticket is withdrawable via claimQuote, forever.

In every case: there is no deadline, no expiry, and no queue. Your claim is a row
in the contract's storage that only your withdrawal (or a push to exactly you) can
consume.

# Chapter 38 | Safety Checklists

:::html
<div class="two-col">
<div class="check-card">
<div class="check-title">Sponsor checklist</div>
<ul>
<li>Domain and factory address verified against an independent source</li>
<li>NFT approval granted for the single token, not the whole collection</li>
<li>Payment token is one your audience actually holds</li>
<li>Minimum set at your true reserve level; cash-branch split understood</li>
<li>Sale window fits your audience; deadlines after close understood</li>
<li>Recovery address is a wallet you control and will still control next month</li>
<li>Raffle address verified on the explorer after creation; prize inside</li>
<li>Plan for who requests the draw after closing</li>
</ul>
</div>
<div class="check-card">
<div class="check-title">Buyer checklist</div>
<ul>
<li>Prize collection verified as canonical, not a same-named copy</li>
<li>Collection checked for owner or upgrade powers over tokens</li>
<li>Sponsor has history and answers questions</li>
<li>Raffle address reached from a source you trust, not a random link</li>
<li>Price, minimum, tickets sold, and closing time read and understood</li>
<li>Which branch is likely (NFT or cash) and what the cash prize would be</li>
<li>Approval amount matches the purchase exactly</li>
<li>Only discretionary money spent; a ticket is a chance, not an investment</li>
</ul>
</div>
</div>
:::
