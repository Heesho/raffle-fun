LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: across-tx-clone-destination-bypass | group_key: Raffle | _isProtocolDestination | across-tx-clone-destination-bypass
code_smells: `Raffle._isProtocolDestination` checks `destination.code.length != 0` and `canonicalFactory.isRaffle(destination)`, so a future clone address from `Clones.clone` passes validation before `createRaffle` deploys that clone. Once `createRaffle` deploys the clone at that address, `releaseSponsorProceeds` reverts with `InvalidQuoteDestination`, and `releaseSponsorPrize` sends the prize token to that clone.
description: A caller can supply a future clone address before deployment to lock payouts, and a path that forces a victim remains unproven.

LEAD | contract: Raffle | function: enableRefunds | bug_class: operation-interleaving-cancellation-block | group_key: Raffle | enableRefunds | operation-interleaving-cancellation-block
code_smells: `Raffle.enableRefunds` lets `sponsor` cancel a raffle before `endTime` only when `totalEntries == 0`. A buyer who calls `buyEntries` for one entry sets `totalEntries = 1`, so `enableRefunds` reverts until `drawRequestDeadline` and `refundTickets` returns the payment.
description: An attacker can buy one entry before the sponsor cancels an empty raffle to lock the prize, and profit for the attacker remains unproven.
