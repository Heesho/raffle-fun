# Clean Context — Malicious ERC-721 Can Forge Prize Escrow and Steal Raffle Proceeds

## Description

`RaffleFactory.createRaffle` accepts a sponsor-selected ERC-721 contract and treats calls to that contract as proof that the advertised NFT was escrowed. This allows a malicious sponsor to supply an ERC-721-like contract that fabricates every signal used by the factory to validate custody.

The malicious token can self-report ERC-165/ERC-721 support, invoke the raffle's receiver callback with the expected arguments, and make `ownerOf` report the raffle as the owner without transferring an enforceable asset. The factory consequently registers the raffle as canonical and observes it in the `Active` state even though no redeemable prize is held.

Victims can then purchase entries using the canonical USDC asset. If the raffle resolves with `NftWon`, settlement can allocate 95% of the pot to the attacker's sponsor recipient, and those proceeds can be released even though the winner cannot redeem the advertised NFT.

## Deep Dive

The vulnerability is at the post-transfer validation in `packages/contracts/src/RaffleFactory.sol:129`. The custody check asks the same untrusted `prizeToken` contract whether the transfer succeeded:

```solidity
IERC721(params.prizeToken).safeTransferFrom(...);
// The attacker-controlled token supplies the custody attestation.
IERC721(params.prizeToken).ownerOf(params.prizeTokenId) == raffle;
```

All validations leading to this check can be forged by the malicious token:

1. The token has deployed bytecode, satisfying the code-presence requirement.
2. Its `supportsInterface` function returns `true` for the ERC-721 interface ID, satisfying the checks at `RaffleFactory.sol:155-177`.
3. When the factory invokes `safeTransferFrom`, the token directly calls `Raffle.onERC721Received` using the factory as `operator`, the sponsor as `from`, and the configured token ID.
4. Because `msg.sender` is the configured prize token and the callback arguments match the raffle configuration, the callback passes the checks at `Raffle.sol:416-430` and changes the raffle status to `Active`.
5. The token's `ownerOf` function returns the clone address, satisfying the factory's custody comparison at `RaffleFactory.sol:129`.
6. The following status check also succeeds because the malicious token itself caused the transition to `Active`.

The two post-transfer signals are therefore circular rather than independent: both are entirely controlled by the contract whose behavior is being validated. ERC-165 only reports which interface a contract claims to support; it does not establish honest ERC-721 semantics or real custody.

The factory initializes and registers the clone before initiating this interaction (`RaffleFactory.sol:105-128`). Once the forged checks pass, the raffle remains a canonical registered raffle and accepts USDC entries through `Raffle.sol:209-236`.

When the reserve is met and VRF resolution produces `NftWon`, settlement at `Raffle.sol:518-555` allocates 95% of the pot to the sponsor without first delivering or independently revalidating the prize. `releaseSponsorProceeds` then transfers those funds to the attacker-controlled sponsor recipient (`Raffle.sol:375-381`). Prize delivery occurs separately through `redeemWinningTicket` (`Raffle.sol:329-337`), where the malicious token can revert or otherwise refuse to deliver anything.

## Exploitation

A malicious sponsor can deploy a `Fake721` contract with the following behavior:

- `supportsInterface(0x80ac58cd)` returns `true`.
- `ownerOf(1)` initially reports the attacker as owner and later reports an address selected by the attacker.
- `safeTransferFrom(attacker, raffle, 1)` records the raffle address and calls `raffle.onERC721Received(factory, attacker, 1, "")`, but does not transfer any enforceable NFT.
- A later transfer attempted by `redeemWinningTicket` reverts.

The attacker then performs the following sequence:

1. Call `createRaffle` with `prizeToken` set to `Fake721`, token ID `1`, `sponsorRecipient` set to the attacker, and a reachable reserve such as one entry.
2. Allow the factory's transfer call to trigger the forged receiver callback, changing the raffle to `Active`.
3. Return the raffle address from `ownerOf(1)`, causing the factory's custody check to pass.
4. Attract victims to the canonically registered raffle and have them purchase entries with USDC.
5. After resolution produces `NftWon`, settle the winning ticket. This allocates 95% of the pot as sponsor proceeds without transferring the prize.
6. Call `releaseSponsorProceeds` to receive the allocated USDC.
7. Reject the winner's subsequent redemption attempt from within `Fake721`.

The winner is left without the advertised NFT, while the raffle has no path that refunds their entry payments because prize redemption failed.

## Impact

A malicious sponsor can create an apparently valid, active, and canonically registered raffle backed by no enforceable prize. Entrants may transfer real USDC based on that false escrow state.

Following a successful `NftWon` resolution, the attacker can withdraw 95% of the raffle pot while preventing delivery of the advertised NFT. The winner receives neither the prize nor a refund, and the protocol's factory registration and `Active` status provide a misleading custody assurance.

## Recommendation

Do not accept arbitrary sponsor-controlled token implementations as escrowable prizes. Restrict `prizeToken` to an explicit allowlist of reviewed, trusted ERC-721 collections or trusted adapters. The allowlist must be enforced before clone initialization, registration, or any prize-transfer callback can activate the raffle.

For defense in depth:

- Register and expose a raffle as active only after the trusted collection's deposit flow completes.
- Separate a provisional deposit-observed state from the final `Active` state, with only the factory able to finalize activation.
- Prevent sponsor proceeds from becoming releasable until prize delivery succeeds, or hold sufficient sponsor collateral to refund entrants if delivery fails.
- Add a terminal failure path that refunds participants when the prize cannot be delivered within a defined period.

Reordering the existing transfer and registration operations, repeating `ownerOf`, or adding further ERC-165 checks is not sufficient on its own: an attacker-controlled token can fabricate all of those responses.