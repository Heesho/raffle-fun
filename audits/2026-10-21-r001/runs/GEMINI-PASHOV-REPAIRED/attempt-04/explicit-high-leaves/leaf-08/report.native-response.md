LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: asymmetric-destination-check | group_key: Raffle | _isProtocolDestination | asymmetric-destination-check
code_smells: _isProtocolDestination checks isRaffle only after createRaffle deploys code at the deterministic CREATE address of a clone. _transferQuote repeats _isProtocolDestination at payout time, but releaseSponsorPrize and redeemWinningTicket transfer prizeToken without that check.
description: A caller can pass a future clone address before deployment, so _transferQuote reverts after deployment. We did not find a path against another user.

LEAD | contract: Raffle | function: initialize | bug_class: asymmetric-input-validation | group_key: Raffle | initialize | asymmetric-input-validation
code_smells: _validateCreateParams checks only prizeToken and sponsorRecipient, while initialize also runs _isProtocolDestination on sponsor even though sponsor receives no payout.
description: The initialize function applies _isProtocolDestination to sponsor and rejects a prizeToken contract as sponsor. We did not find a path that harms active raffles.
