# raffle.fun at a glance

raffle.fun is an Ethereum raffle for one NFT. The sponsor picks a reserve price and a
deadline up to 30 days out. Every raffle number costs exactly 1 USDC. Selling starts the
moment the NFT is locked in, which happens in the same transaction that creates the
raffle.

## One purchase, one NFT ticket

A buyer chooses how many numbers to buy:

- 1 USDC mints one ticket containing one number;
- 20 USDC mints one ticket containing 20 consecutive numbers;
- any positive amount still mints only one ticket.

The ticket is an ERC-721 bearer claim and can move in any raffle state, including
after winner settlement, until successful owner redemption or a refund burns it.

![One ticket per purchase, each holding a contiguous block of numbers. The draw picks a number, not a ticket — so finding the winner is a single lookup no matter how many entries sold.](../figures/entry-ranges.svg)

## Two successful outcomes

![Both endings pay the sponsor and the protocol. The reserve only decides who ends up with the NFT, and whether the drawn ticket is paid in cash.](../figures/outcome-split.svg)

If a sponsor sets a 2,000,000-entry reserve, there is no separate protocol cap. The
raffle does not sell out: it accepts entries until the deadline, and equality meets
the reserve.

If the reserve is missed, the sponsor receives the NFT back plus 15% of gross sales.
The randomly selected ticket receives 80% of gross sales, and the protocol receives
the remaining 5%. Anyone can settle a finished raffle, which records the winning ticket
and locks in these entitlements without reading its owner or burning it. The current
owner then atomically burns the ticket while receiving its NFT or cash; sponsor and
protocol assets remain independently releasable.

## Verifiable and bounded

After the deadline, anyone may pay Chainlink VRF v2.5's ETH fee to request one random
word. The contract selects one entry from `1..totalEntries`. Because each ticket
stores its own first and last number, proving the winner takes constant work—there is
no search through all buyers.

The permissionless draw request is available for two days after sale end. If no
request is accepted by that hard deadline, anyone can open full, fee-free refunds. An
accepted request gets its own two-day callback window; Chainlink callbacks at or after
that deadline are ignored and refunds become available. Each ticket refunds its
number of entries at 1 USDC each. A request made in the final second can make the
maximum nominal path just under four days.

![The two draw windows run back to back rather than overlapping, so a raffle started at the last permitted second still finishes within roughly four days of the sale ending.](../figures/lifecycle-timeline.svg)

## What the operator cannot do

Every raffle is a fixed, non-upgradeable ERC-1167 clone with no owner or rescue key.
The factory is also ownerless and cannot be paused or reconfigured. No administrator
can change a running raffle, choose a winner, redirect a prize, or seize its pot.

The same immutability cuts the other way: nothing can be fixed after the fact either.

## Know before you buy

Refunds exist only until a result arrives. Once the draw resolves, that result is
final — there is no refund afterwards. So if the prize collection is later paused,
upgraded, or otherwise stops allowing transfers, the winner's NFT can stay stuck, even
though the sponsor and protocol USDC still pay out normally. **The collection behind a
raffle is the risk you are taking. Check it before you buy.**

This candidate v1 is not deployed or independently audited. Chainlink, Ethereum,
USDC issuer controls, the NFT collection, wallet safety, and applicable gambling or
promotional-law requirements remain external risks.
