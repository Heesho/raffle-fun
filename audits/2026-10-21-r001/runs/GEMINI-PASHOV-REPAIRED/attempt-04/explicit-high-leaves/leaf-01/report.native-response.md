LEAD | contract: RaffleFactory | function: _validateCreateParams | bug_class: unbounded-reserve-entries | group_key: RaffleFactory | _validateCreateParams | unbounded-reserve-entries
code_smells: The function _validateCreateParams checks that params.reserveEntries is more than zero, but it sets no upper limit on params.reserveEntries even when reserveEntries * ENTRY_PRICE exceeds quoteToken.totalSupply().
description: A sponsor can set reserveEntries above the quoteToken supply to force CashWon, but we did not verify that a buyer accepts this reserve.

LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: unregistered-future-clone-destination | group_key: Raffle | _isProtocolDestination | unregistered-future-clone-destination
code_smells: The function _isProtocolDestination skips canonicalFactory.isRaffle when destination.code.length is zero, so a deterministic future Clones.clone address passes validation at initialization or transfer and later reverts in _transferQuote.
description: A caller can pass a future clone address as a recipient before deployment, but we did not find a path that harms another user.
