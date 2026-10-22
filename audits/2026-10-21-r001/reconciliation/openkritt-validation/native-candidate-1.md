# clean-context — Sponsor Can Withdraw Raffle Proceeds Before Prize Delivery

## Description

`Raffle` releases sponsor proceeds based on the raffle reaching `NftWon`, even if the winner has not received the escrowed NFT. This creates an unsafe lifecycle gap between financial settlement and prize delivery.

A sponsor can select an ERC-721 whose transfers the sponsor can pause. The token passes creation and escrow checks while transfers are enabled. After ticket sales, the sponsor pauses the token, lets the raffle resolve successfully, settles the winning ticket, and withdraws 95% of the pot. The winner's later attempt to claim the NFT reverts, while refunds are unavailable because the raffle is already in the terminal `NftWon` state.

## Deep Dive

`RaffleFactory.createRaffle` accepts a sponsor-selected token contract after checking that it contains code, reports ERC-721 support, and satisfies the configured address constraints. The factory then initializes the raffle and transfers the NFT into escrow. These checks establish present ownership and transferability but cannot guarantee that the token will remain transferable.

A sponsor-controlled pausable ERC-721 therefore passes the complete creation flow while unpaused:

1. The sponsor calls `RaffleFactory.createRaffle` with the pausable token and `reserveEntries = 1` (`packages/contracts/src/RaffleFactory.sol:97`).
2. Factory validation accepts the code-bearing contract after it reports `IERC721` support (`packages/contracts/src/RaffleFactory.sol:154`).
3. Initialization permanently stores the selected `prizeToken` (`packages/contracts/src/Raffle.sol:176`, assignment at line 200).
4. The factory's `safeTransferFrom` succeeds while transfers are enabled. `onERC721Received` changes the raffle to `Active`, and the subsequent `ownerOf` check confirms escrow (`packages/contracts/src/RaffleFactory.sol:127`, `packages/contracts/src/Raffle.sol:428`).

Once at least one ticket has been purchased, the sponsor can pause transfers through the prize contract. Because the reserve is one, the authenticated randomness callback resolves any nonempty raffle to `NftWon` (`packages/contracts/src/Raffle.sol:521`).

The critical sequencing error occurs during settlement. `settleWinningTicket` calls `_settleWinningTicket`, which credits `sponsorProceeds` with the pot minus the protocol fee without first transferring the NFT or proving that it was claimed (`packages/contracts/src/Raffle.sol:304`, credit at line 554). `releaseSponsorProceeds` then transfers those proceeds at line 380 without requiring `winnerRedeemed` or `prizeClaimed` (`packages/contracts/src/Raffle.sol:375`).

Prize delivery is deferred and independent from payout. When the winner later attempts the NFT `transferFrom`, the paused token reverts. The protocol cannot restore the entrants' funds through its refund path because `enableRefunds` rejects the terminal `NftWon` state. Consequently, the contract can reach the following inconsistent terminal outcome:

- the sponsor has received 95% of ticket sales;
- the prize remains trapped in the raffle;
- the winner cannot claim the prize; and
- entrants cannot obtain refunds.

## Exploitation

An attacker can execute the following sequence:

1. Deploy or control an ERC-721 contract with a sponsor-controlled transfer-pause role.
2. Mint token ID `1`, approve the raffle factory, and leave transfers enabled.
3. Create a raffle using approximately the following parameters:

```solidity
createRaffle({
    sponsorRecipient: attacker,
    prizeToken: pausableToken,
    prizeTokenId: 1,
    reserveEntries: 1,
    endTime: uint64(block.timestamp + 1 days)
});
```

4. Allow a victim to purchase ticket `1` through the entry function at `packages/contracts/src/Raffle.sol:209`.
5. Pause transfers on the prize contract.
6. Complete the draw. Since `totalEntries >= reserveEntries`, the VRF callback sets the raffle state to `NftWon`.
7. Call `settleWinningTicket(1)`. Settlement records the winner and credits 95% of the sales pot to `sponsorProceeds`, but does not deliver the NFT.
8. Call `releaseSponsorProceeds()`. The raffle transfers the credited USDC to the attacker's recipient despite the undelivered prize.
9. The victim's prize claim reverts because ERC-721 transfers remain paused. A refund cannot be enabled because the raffle has already reached `NftWon`.

## Impact

A malicious sponsor can collect 95% of all raffle sales without delivering the advertised prize. The winner loses their ticket payment and cannot receive the NFT, while every entrant is denied the protocol's refund mechanism. The escrowed NFT may also remain permanently trapped if the sponsor never unpauses transfers.

The issue breaks the raffle's central exchange invariant: sponsor compensation is finalized even though the corresponding prize obligation has not been fulfilled.

## Recommendation

Make sponsor proceeds releasable only after successful prize delivery. In particular:

- Do not credit or transfer `sponsorProceeds` merely because the raffle entered `NftWon` or the winning ticket was settled.
- Record successful NFT delivery in protocol state only after the token transfer completes, and require that state in `releaseSponsorProceeds`.
- Keep ticket funds escrowed until delivery is confirmed.
- If delivery fails or remains impossible past a bounded claim/delivery period, transition to a refund-capable state and return ticket payments instead of paying the sponsor.

Where practical, perform prize delivery and sponsor accounting atomically: attempt the NFT transfer first, then credit proceeds only after it succeeds. If the design retains winner-initiated claims, add an explicit delivery deadline and recovery path so that an uncooperative winner cannot indefinitely lock legitimate sponsor funds, while a nontransferable prize can never result in sponsor payout.