[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `RaffleFactory.createRaffle`: the sponsor gives one prize collectible and receives an active raffle; the raffle count rises by one and the ID/address registry gains one binding.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.initialize`: no asset moves; the factory records the sponsor, beneficiaries, prize, reserve, and timing, then marks the raffle as waiting for its prize.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.onERC721Received`: the configured prize is expected to arrive from its sponsor, and the raffle becomes active; quote-token totals remain zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.buyEntries`: the buyer gives `entryCount * 1,000,000` quote units, the recipient gets one range ticket, and sold entries, ticket count, and the unallocated pot increase correspondingly.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle._update`: a holder gives the bearer ticket to another holder; the ticket owner changes but its represented entries and all quote liabilities remain unchanged.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.requestDraw`: the requester gives native currency, Chainlink receives the current fee, excess returns to the requester, and the raffle records one pending draw and its time.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.fulfillRandomWords`: nobody gives or receives an asset; one sold entry becomes the winner and the result becomes either NFT-won or cash-won.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.enableRefunds`: no asset moves; the entire unallocated pot is reclassified as the amount owed to refundable tickets.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle._settleWinningTicket`: no asset moves; the unallocated pot becomes winner, sponsor, and treasury claims whose sum remains exact.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.redeemWinningTicket`: the current winner gives up and burns the winning ticket, receiving either the prize NFT or the complete cash-winner claim.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.refundTickets`: the owner burns selected tickets, receives exactly one USDC per represented entry, and the aggregate refund amount falls by the same value.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseSponsorProceeds`: the immutable sponsor recipient receives its complete quote-token claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseProtocolFees`: the immutable treasury receives its complete fee claim and that claim becomes zero.

[Model: gpt-daybreak-blue-latest (runner-selected label; provider identity not asserted)] `Raffle.releaseSponsorPrize`: after a cash or refund result, the sponsor recipient receives the configured prize and the one-prize claim is closed.

[Why: RaffleFactory.sol:129] Why is the prize contract’s current ownership report treated as proof of durable escrow? The implicit belief is that an arbitrary ERC-721 cannot later revoke custody or lie about it, despite that contract being untrusted.

[Why: Raffle.sol:254] Why is an in-flight request flagged before calling the wrapper? The request identifier is not recorded until the wrapper returns, so accepting a synchronous callback would validate randomness against incomplete state.

[Why: Raffle.sol:498] Why may holder-to-holder transfers continue while the draw is pending? The design assumes transferability remains information-neutral, but a pending fulfillment can reveal the winner to the transaction-ordering layer before the state transition lands.

[Why: Raffle.sol:512] Why is a callback rejected exactly at its deadline? This makes callback acceptance and refund availability mutually exclusive at the boundary.

[Why: Raffle.sol:538] Why does settlement not inspect ticket ownership? Settlement only allocates liabilities; ownership is deliberately deferred until redemption so the bearer claim follows the ticket.

[Why: Raffle.sol:378] Why may sponsor proceeds leave before successful NFT delivery? The implementation assumes the escrowed prize remains durably transferable; an untrusted prize contract invalidates that assumption.

[Defeat: Raffle.initialize] (1) An EOA calling a fresh clone fails because only the immutable factory is accepted. (2) A caller targeting the implementation fails because it is already initialized. (3) A malicious prize callback attempting reinitialization fails because clone initialization already completed atomically.

[Defeat: RaffleFactory.createRaffle] (1) An unrelated address invoking the receiver callback fails the configured-token check. (2) A token callback with the wrong ID, sponsor, or operator fails. (3) A sponsor-controlled ERC-721 can genuinely deposit, pass every check, and later seize the prize through a privileged transfer; this succeeds and is reported below.

[Defeat: Raffle.buyEntries] (1) A purchase at `endTime` fails. (2) A zero-entry purchase fails. (3) A recipient callback trying to buy again is blocked and rolls back, but removal of the prize by its own contract is not checked before payment.

[Defeat: Raffle.requestDraw] (1) A frontrunner may pay the fee and request first, but cannot choose the VRF result or receive protocol value. (2) Buying entries in the same block at `timestamp == endTime` fails. (3) A request at `endTime + 2 days` fails while refunds become available.

[Defeat: Raffle.fulfillRandomWords] (1) A direct callback from a non-wrapper address fails inherited authentication. (2) A wrong request ID or wrong word count is ignored. (3) A genuine pending fulfillment can be simulated and ordered around an already-authorized ticket transfer; callback authentication does not bind ticket ownership.

[Defeat: Raffle._update] (1) An attacker without ownership or approval cannot transfer ticket 42. (2) An approved transfer to the factory or a registered same-factory raffle fails. (3) A marketplace executing the owner’s valid fixed-price order can transfer ticket 42 to a searcher while status is `Drawing`; this succeeds and is reported below.

[Defeat: Raffle.enableRefunds] (1) A sold raffle cannot enter refunds before the request deadline. (2) A valid callback landing before its deadline changes status and makes the refund transaction fail. (3) At the exact deadline, the callback is rejected and refunds succeed, so there is no ambiguous timestamp.

[Defeat: Raffle._settleWinningTicket] (1) A ticket outside the winning range fails. (2) Frontrunning settlement with the correct ticket cannot redirect its claim. (3) Repeating settlement fails, although settlement still permits sponsor funds to leave before an untrusted prize is delivered.

[Defeat: release paths] (1) Frontrunning sponsor release still pays the immutable sponsor recipient. (2) Frontrunning fee release still pays the immutable treasury. (3) A second prize release fails, but an already-seized prize can make winner delivery fail after sponsor and treasury quote claims have left.

[LastOut: create / escrow] With an honest prize, exactly one NFT enters and remains for one terminal recipient. With a sponsor-seizable prize, the eventual NFT winner is last out and receives zero of the one NFT owed: the raffle is short exactly one prize.

[LastOut: buy / transfer] For 100 one-entry tickets, the clone receives exactly `100,000,000` quote units and records the same unallocated pot. Ticket transfers do not alter this balance; no quote shortfall appears.

[LastOut: successful draw] The callback moves no asset and creates no additional liability. The full pot and one prize remain available, although pending-result ordering can change which economic cohort owns the winning ticket.

[LastOut: settle / redeem NFT] From a `100,000,000`-unit pot, sponsor and treasury claims are `95,000,000` and `5,000,000`; either can be paid last in full. With honest custody, the winning owner also receives one NFT. Under the revocable-prize path, the winner receives no NFT and holds the entire one-prize shortfall.

[LastOut: settle / redeem cash] From a `100,000,000`-unit pot, winner, sponsor, and treasury receive `80,000,000`, `15,000,000`, and `5,000,000`. In every release order, the last claimant is paid in full and the remaining quote liability reaches zero.

[LastOut: timeout / refund] For tickets representing 40, 35, and 25 entries, sequential refunds pay `40,000,000`, `35,000,000`, and `25,000,000`. The final holder receives all `25,000,000`; the clone is short by zero.

[LastOut: empty raffle] No quote claim exists. With an honest prize, the sponsor recipient is the only claimant and receives the one escrowed NFT in full.

[LastOut: independent releases] Winner, sponsor, treasury, and sponsor-prize releases debit distinct claims. Reordering them creates no quote deficit; only loss of external prize custody breaks the final-claimant result.

[Saturation: ticket-transfer-ordering] Checked minting at `Raffle.sol:235`, inherited approvals and transfers through `Raffle.sol:497-502`, burns at `Raffle.sol:325` and `Raffle.sol:364`, current-owner selection at `Raffle.sol:320`, and every `Drawing`, `NftWon`, `CashWon`, and `Refunding` branch. NFT- and cash-winner sniping share the same missing lifecycle transfer lock and are one finding.

[Saturation: prize-custody] Checked interface admission at `RaffleFactory.sol:172`, initial transfer and ownership verification at `RaffleFactory.sol:128-132`, receipt at `Raffle.sol:416-430`, winner delivery at `Raffle.sol:334-336`, sponsor return at `Raffle.sol:404-405`, and all settlement/release paths. Every check ultimately trusts the same prize contract, so fake escrow, later seizure, and false delivery reports share one admission defect and mitigation.

[Saturation: totals-and-ordering] Checked every write to sold entries, ticket count, unallocated pot, refund liability, winner proceeds, sponsor proceeds, fees, raffle count, registry state, winning entry, settlement flags, and prize flags. Initialization, sale, request, callback/refund boundary, rounding, duplicate claims, and release ordering produced no additional surviving candidate.

FINDING | contract: Raffle | function: _update | bug_class: vrf-reveal-front-running | group_key: Raffle | _update | vrf-reveal-front-running
root_cause: Raffle.sol:498 checks only whether the destination is protocol plumbing and omits a lifecycle transfer lock, so holder-to-holder transfers remain executable while the authenticated fulfillment revealing the winning entry is pending and after it lands.
internal_pre: The raffle is Drawing with 100 one-entry tickets, reserveEntries is 100, and ticket 42 is approved to a marketplace.
external_pre: Ticket 42 has an executable fixed-price signed order for 100 USDC, and a searcher or block builder can observe or simulate the pending VRF fulfillment before ordering transactions.
path:
  1. One hundred buyers pay 100,000,000 raw USDC in total for a raffle whose prize has a 10,000 USDC market value; Alice owns ticket 42 and lists it for 100,000,000 raw USDC before resolution.
  2. A requester starts the draw, leaving the raffle in Drawing while Alice’s order remains executable.
  3. The pending authenticated fulfillment yields random word 41, so `(41 % 100) + 1` reveals that entry and ticket 42 will win.
  4. A searcher orders a marketplace fill before the fulfillment, pays Alice 100 USDC plus gas, and receives ticket 42 because `_update` has no Drawing-state restriction.
  5. The fulfillment records entry 42 as the winner; the searcher settles and redeems ticket 42 for the 10,000 USDC NFT.
impact: Alice, the stale-order seller, loses 9,900 USDC of revealed winning-claim value; the searcher captures approximately 9,900 USDC minus gas even though Alice had no opportunity to react to the pending fulfillment.
mitigation: In `_update`, reject holder-to-holder transfers while status is Drawing, NftWon, or CashWon, while continuing to permit protocol burns.

FINDING | contract: RaffleFactory | function: _validateCreateParams | bug_class: revocable-prize-custody | group_key: RaffleFactory | _validateCreateParams | revocable-prize-custody
root_cause: RaffleFactory.sol:172 accepts a sponsor-selected prize solely from its self-reported ERC-721 interface support; the missing trusted-token or irrevocable-custody admission check lets a token with privileged seizure pass the one-time ownership check at RaffleFactory.sol:129 and later remove the prize.
internal_pre: An Active raffle has reserveEntries of 10,000, 9,999 entries have sold, and the attacker is both the prize-token administrator and sponsor recipient.
external_pre: The configured ERC-721 exposes a sponsor-controlled privileged transfer or upgrade that can move an escrowed token without raffle approval; draw and transaction costs are below the 9,500 USDC sponsor allocation.
path:
  1. The attacker genuinely deposits a 20,000 USDC NFT from an ERC-721 that reports interface support and truthful ownership, so creation and the one-time custody check succeed.
  2. Buyers purchase 9,999 entries for 9,999,000,000 raw USDC; Alice broadcasts a final one-entry purchase that would meet the 10,000-entry reserve.
  3. The attacker frontruns Alice with the token’s privileged transfer, moving the NFT from the raffle back to itself while the raffle remains Active.
  4. Alice’s purchase still transfers 1,000,000 raw USDC because `buyEntries` never detects the lost prize; the pot becomes 10,000,000,000 raw USDC and the reserve is met.
  5. The attacker funds the draw, the result becomes NftWon, and settlement allocates 9,500,000,000 raw USDC to the attacker’s sponsor recipient and 500,000,000 to the treasury; both amounts can be released.
  6. The winning buyer calls `redeemWinningTicket`, but prize transfer reverts because the raffle no longer owns the NFT, leaving the ticket permanently unredeemable with no refund transition.
impact: Entrants collectively lose 10,000 USDC, of which the attacker captures 9,500 USDC while retaining the 20,000 USDC prize; the winning-ticket owner is left holding an unbacked claim and the treasury holds the remaining 500 USDC.
mitigation: Add an immutable trusted-prize registry check in `_validateCreateParams` and admit only vetted, non-upgradeable ERC-721 contracts without privileged seizure; self-reported interface and ownership answers cannot establish this property.

[Coverage: files] `Raffle.sol`—all asset movements, ticket ownership paths, totals, deadlines, callback, settlement, refunds, and releases; `RaffleFactory.sol`—constructor trust, atomic clone initialization, registry ordering, prize admission, and escrow; `IRaffle.sol`—all lifecycle, ownership, accounting, timing, event, and error promises; `IRaffleFactory.sol`—creation parameters and registry guarantees; `RaffleConstants.sol`—entry price, fee splits, limits, timeouts, and VRF configuration; `DESIGN.md`—all stated custody, transferability, deadline, and independent-claim properties.

[Coverage: properties] Quote solvency and rounding, ticket-range continuity, initialization races, sale and deadline ordering, VRF authentication and reveal ordering, cancellation grief, last-user-out for every terminal branch, one-shot settlement, current-owner redemption, untrusted prize custody, protocol-destination filtering, cross-clone movement, native-fee pass-through, and absence of swaps, price oracles, signatures, shares, or cross-chain accounting were covered.