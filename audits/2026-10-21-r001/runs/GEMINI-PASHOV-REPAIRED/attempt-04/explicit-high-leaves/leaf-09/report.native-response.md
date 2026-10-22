```
LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: future-clone-sink-bypass | group_key: Raffle | _isProtocolDestination | future-clone-sink-bypass
code_smells: The function _isProtocolDestination checks destination.code.length and isRaffle only at the time of the call, before Clones.clone deploys future raffles at predictable CREATE addresses.
description: A sponsor who sets sponsorRecipient to a future clone address causes releaseSponsorProceeds to revert after the factory deploys that clone. We did not find a way for an attacker to force a victim to use a future clone address.

LEAD | contract: RaffleFactory | function: constructor | bug_class: future-clone-treasury-collision | group_key: RaffleFactory | constructor | future-clone-treasury-collision
code_smells: The constructor checks protocolTreasury_ against address(this), quoteToken_, vrfWrapper_, and raffleImplementation, but it does not check future CREATE clone addresses of the factory.
description: A deployer who sets protocolTreasury_ to a future clone address makes createRaffle revert in initialize when the factory nonce reaches that address. This path requires a bad treasury address at deployment time.

LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: unsafe-erc721-prize-return | group_key: Raffle | releaseSponsorPrize | unsafe-erc721-prize-return
code_smells: The function releaseSponsorPrize calls prizeToken.transferFrom instead of safeTransferFrom, and initialize does not verify that a contract at sponsorRecipient can handle the NFT.
description: Any caller can trigger releaseSponsorPrize to send the NFT to a sponsorRecipient contract that does not run onERC721Received. This path affects only a sponsor who configures a contract without NFT withdrawal logic as sponsorRecipient.

LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: synchronous-vrf-callback-ignored | group_key: Raffle | fulfillRandomWords | synchronous-vrf-callback-ignored
code_smells: The function requestDraw sets _requestInFlight to true before requestRandomnessPayInNative, and fulfillRandomWords ignores any callback while _requestInFlight is true without a revert.
description: A VRF wrapper that calls rawFulfillRandomWords during requestRandomWordsInNative leaves the raffle in Status.Drawing with no second callback. The canonical Chainlink VRF v2.5 wrapper fulfills requests in a later block, so this path does not occur in production.
```
