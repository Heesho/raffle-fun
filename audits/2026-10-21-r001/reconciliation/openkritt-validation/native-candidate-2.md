# clean-context + Predictable Future Clone Address Bypasses Sponsor-Recipient Validation

## Description

`RaffleFactory.createRaffle` attempts to prevent a canonical raffle from being selected as another raffle's `sponsorRecipient`. However, the validation at `packages/contracts/src/RaffleFactory.sol:163-168` only checks the current value of `isRaffle[sponsorRecipient]`.

Because `Clones.clone` deploys with `CREATE`, future clone addresses can be calculated from the factory address and nonce. A sponsor can therefore configure raffle A with the address of the next-but-one clone B before B exists. The factory and `Raffle.initialize` accept the address because it has no code and is not yet registered. Once B is deployed and added to `isRaffle`, A retains B as its immutable sponsor recipient.

This is a time-of-check/time-of-use bypass: the predicate is true when the recipient is configured but becomes false before the recipient is used.

## Deep Dive

Suppose `n` is the factory's next `CREATE` nonce. The sponsor calculates the clone address produced at nonce `n + 1` and supplies that address as A's `sponsorRecipient` at `RaffleFactory.sol:97`.

During A's creation:

1. B has not been deployed and `isRaffle[B]` is false.
2. The check at `RaffleFactory.sol:163-168` therefore accepts B.
3. The factory deploys and initializes A at `RaffleFactory.sol:105-121`; the corresponding initialization validation in `Raffle.sol` also sees B as unregistered.
4. A subsequent successful `createRaffle` deploys the next clone at B.
5. The factory then records B as a canonical raffle at `RaffleFactory.sol:123-125`.

A is now permanently configured to send sponsor assets to protocol plumbing. In the `Refunding` or `CashWon` state, `releaseSponsorPrize` at `Raffle.sol:395-405` uses plain ERC-721 `transferFrom`. That operation does not require the destination to implement an ERC-721 receiver callback, so the NFT can be transferred into B even though B has no method for recovering arbitrary NFTs.

The analogous proceeds path fails differently. When sponsor proceeds are released, the runtime quote-token transfer guard observes that B is now registered as a raffle and reverts. Since A's recipient cannot be replaced, those proceeds remain permanently unclaimable.

## Exploitation

A sponsor-controlled EOA or helper contract can execute the following sequence:

1. Own and approve two standard ERC-721 tokens, IDs 1 and 2, for the factory/raffle flow.
2. Determine the factory's next `CREATE` nonce `n` and calculate `B = CREATE(factory, n + 1)`.
3. Create raffle A using token ID 1, `sponsorRecipient = B`, `reserveEntries = 1`, and a valid future end time. B passes validation because it does not yet exist.
4. Immediately create a second raffle using token ID 2 and a benign recipient. This consumes the next nonce, deploying the second clone at B and registering it in `isRaffle`.
5. With no entries sold in A, call `A.enableRefunds()` to move A into `Refunding`.
6. Call `A.releaseSponsorPrize()`. The call transfers token ID 1 to B.

After the final step, `ownerOf(1)` is B, but B exposes no arbitrary-NFT rescue operation. The NFT is therefore permanently stranded. Performing the two factory calls atomically prevents another transaction from consuming the expected deployment nonce.

## Impact

The bypass defeats the factory's intended isolation between canonical raffle clones and allows assets belonging to one raffle to be sent into another canonical raffle.

For an ERC-721 sponsor prize, the result is an irreversible transfer into a contract that cannot recover the token. For sponsor proceeds, the result is a permanently reverting release path and indefinitely locked funds. The directly exposed value is limited to the prize or proceeds supplied by the malicious sponsor; this sequence does not by itself steal assets from unrelated users. Nevertheless, it violates a protocol-enforced destination invariant and leaves canonical raffle instances holding unrecoverable foreign assets.

## Recommendation

Enforce the recipient restriction when assets are released, not only when the raffle is initialized, and provide a recovery path when an initially valid recipient later becomes invalid.

Before either the NFT prize or quote-token proceeds are transferred, query the factory's current registry state. If the configured recipient is now a raffle, allow the original sponsor to nominate a replacement nonzero, non-raffle recipient, or return the asset directly to the authenticated sponsor. Apply the same policy consistently to both release paths.

A pull-based design in which the sponsor selects or confirms the destination at withdrawal time would avoid relying on a permanent snapshot of a mutable registry. Merely changing `transferFrom` to `safeTransferFrom` is insufficient: it may stop the NFT from entering B, but without recipient replacement or a fallback withdrawal it only changes permanent asset lockup into a permanently reverting release.