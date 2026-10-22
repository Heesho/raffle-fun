Original review assumptions, before final candidate disposition

The clean DESIGN.md embedded in audit/context.json is the requirement authority. Code comments are observed implementation claims, not amendments to those requirements. In particular, the design calls arbitrary prize contracts and ticket recipients untrusted, while IRaffle.sol:13-15 narrows supported prizes to honest standards-compliant ERC721s. This difference must remain explicit.

Canonical USDC and the VRF wrapper are trusted as specified. USDC transfers are assumed to move the requested six-decimal amount without fees or rebasing; address identity, blacklist/pause state, and deployed wrapper configuration are not established by this source snapshot. A prize contract's ownerOf answer is its own assertion and cannot independently establish economic authenticity or future transferability.

Required accounting properties are conservation of outstanding liabilities, one million quote units per entry, contiguous non-overlapping ranges, aggregate 5% protocol and 80% cash-winner allocations with sponsor remainder, and full refunds only in the refund branch. Required authorization is factory-only one-time initialization, current-owner claims, authenticated VRF resolution, and no mutable administrator.

Required lifecycle properties are exclusive sale end, request eligibility in [end,end+2days), callback acceptance strictly before requestedAt+2days, refund availability at each applicable deadline, one-way terminal outcomes, storage-only settlement, and atomic claim rollback on delivery failure. Exits should remain independent and bounded; assets should not move from one raffle clone into another.

Source reasoning is not an executed test or formal proof. Timing uses ordinary EVM transaction atomicity and monotonically progressing block time. CREATE addresses can become deployed/registered later; current registry membership need not be stable across transactions. No deployment identity or chain state is assumed to have been verified.
