# SUP-S1 independent supplementary whole-system first pass

Review date: 2026-10-21 UTC. Scope: frozen clean-context only. This is a supplementary review and is not a named audit harness. Runner-selected model: gpt-6.1-sol, requested reasoning ultra; provider-returned model identity was not available and is not independently attested. The review was time-bounded to 15 minutes. No production source was modified. No repository tests, prior findings, scanner reports, historical artifacts, memory or deployment state were consulted.

## Result and confidence

No confirmed direct theft, double-claim, unauthorized initialization, VRF spoofing, ledger insolvency, or lifecycle escape was found under canonical USDC, canonical asynchronous Chainlink wrapper, and honest standards-compliant ERC721 prize assumptions. This is a limited manual first pass, not proof of absence. One concrete asset-trust/specification gap is recorded below because the provided clean design explicitly calls arbitrary prize contracts untrusted, whereas production interface documentation narrows supported prizes to honest ERC721s. It must not be represented as an unconditional exploit of an honest ERC721.

All five production Solidity files were examined, including every production-defined function. Key reachable dependency paths were examined for the actual semantics relied on by the implementation. No Solidity compilation, EVM execution, fuzzing, mainnet fork, gas measurement, or oracle integration test was performed in this supplementary pass. The included standalone Python checks verify independently derived arithmetic, partition and deadline properties only; they do not execute the contracts.

## SUP-S1-T1 — Arbitrary prize contracts can retain NFT-outcome proceeds while permanently blocking delivery

Classification: confirmed conditional trust gap against clean DESIGN.md line 2; high user-funds impact if arbitrary malicious prizes are in the supported threat model. This is a trust assumption rather than a contract bug if the honest-prize limitation in IRaffle.sol lines 12–15 is the intended authoritative boundary. Confidence in the execution sequence is high; acceptance as a protocol vulnerability requires resolution of that specification conflict. No deployed instance or user exposure was examined.

Affected source:

- RaffleFactory.sol lines 154–178: contract-code and self-reported ERC165 checks do not establish prize honesty or future transferability.
- RaffleFactory.sol lines 123–134: registry publication, safeTransferFrom and ownerOf/status checks establish only the token's current reported escrow state.
- Raffle.sol lines 416–430: the exact deposit callback activates sales.
- Raffle.sol lines 509–523: reserve-met callback irreversibly selects NftWon without a later delivery fallback.
- Raffle.sol lines 533–555 and 375–391: any caller can allocate and release 95% of gross sales to the sponsor and 5% to treasury before NFT redemption succeeds.
- Raffle.sol lines 309–337: failed NFT transfer or owner verification rolls back redemption, but cannot roll back previously completed settlement and sponsor release transactions.
- Raffle.sol lines 276–301: refunds are available only from Active/Drawing, not from NftWon.

Required attacker capability: sponsor controls or cooperates with the prize-contract administrator, can supply an ERC721-like contract that reports interface support, can deposit its configured token with a matching callback and ownerOf response, and can cause that token to reject outgoing transfers from the raffle after activation. The attacker does not control USDC, Chainlink, the victim ticket owners, or factory configuration.

Concrete sequence:

1. Deploy a prize contract that behaves normally during factory deposit and reports the raffle as owner; after deposit, disallow transferFrom when from equals the raffle. A static switch or administrator-controlled pause is sufficient. The malicious behavior need not reenter any raffle function.
2. Sponsor creates a raffle with reserveEntries=1, an ordinary sponsor recipient, and a future end time. Factory checks and exact receiver callback pass.
3. Victims buy N entries for N USDC. At sale end, any caller funds the normal VRF request; an authentic timely callback resolves NftWon.
4. Attacker or another caller supplies the actual winning range ticket to settleWinningTicket. The function is deliberately storage-only and allocates sponsorProceeds=0.95*N USDC and protocolFees=0.05*N USDC.
5. Anyone calls releaseSponsorProceeds, paying the attacker recipient. The winner's redeemWinningTicket call reverts at prizeToken.transferFrom; the ticket and winnerRedeemed remain intact, but the already-paid sponsor balance does not return. No NftWon refund or recovery path exists.

Impact: winner can be left with a permanently unredeemable ticket and no refund while sponsor keeps 95% of all entries. The same generic untrusted token can also lie about ownerOf; balance verification cannot prove external token semantics. Other raffles remain isolated and cash/refund liabilities do not become stealable through this behavior.

Recommended disposition: explicitly choose and document the supported prize trust boundary. If arbitrary adversarial contracts truly must be supported, collection validation/allowlisting and a delivery-failure economic design are required; an ownerOf check alone is insufficient. Do not treat moving sponsor release after winner redemption as a complete solution: it removes this payout ordering but still needs a defined fallback for a token that blocks delivery or lies. If honest prizes are a required precondition, mark this as a documented trust limitation and ensure discovery/creation flows convey it.

## Independently investigated and closed leads

1. **Clone guard starts at zero:** ReentrancyGuard.sol checks equality to ENTERED=2, not equality to NOT_ENTERED=1; clone-zero storage is safe on the first guarded call. It is set to 2 before any guarded body and restored to 1. No constructor-state inheritance assumption is required.
2. **Implementation takeover:** Raffle constructor stores initialized=true on implementation; clone storage remains zero, but initialize is restricted to immutable factory. Factory creates and initializes atomically with no intervening untrusted mutable call. No takeover found.
3. **Range/count overflow:** positive entries imply ticketCount<=totalEntries. The totalEntries cap therefore bounds both ++ticketCount and IDs. A price product is below 2^148; fee products below 2^161; uint256 is ample. firstEntry cannot overflow on a permitted positive purchase.
4. **Nonexistent winning ticket:** historical unknown ranges are [0,0], while authentic winningEntry is in [1,totalEntries]. Such a range cannot pass. Burns cannot occur in Drawing/NftWon/CashWon except the final winning burn; refund burns are restricted to Refunding. No stale burned ticket can settle a valid live draw.
5. **Double refund and duplicate batch IDs:** each iteration ownerOf checks before burning. A duplicate sees a nonexistent token on its next iteration and reverts the entire transaction. Failed final transfer also rolls back every burn and liability decrement.
6. **Inherited ERC721 reentrancy:** transfer/approve methods are not guarded, but transfers operate only under current owner/operator authorization and never change ranges, entry totals or monetary liabilities. A recipient may forward a newly minted ticket during onERC721Received. The guard blocks economic reentry. On winner redemption the winning ticket is already burned before external prize transfer. No unauthorized claim found.
7. **Synchronous, wrong, duplicate or late callbacks:** inherited rawFulfill authenticates msg.sender; in-flight gate ignores synchronous wrapper callbacks; status/id/length/deadline gates reject stale callbacks. Canonical asynchronous wrapper is required; if changed to synchronous-only, refunds remain the liveness escape rather than successful draw.
8. **Fee quote or native-refund failure:** request state, wrapper request and fee transfer are all in the same EVM transaction. Insufficient second quote or rejected excess refund reverts the complete request. An exact-value request avoids recipient refund requirements. A hostile requester can revert only its own request transaction.
9. **Fee/sponsor independence:** settlement makes no asset transfer and does not read ownerOf; broken sponsor/treasury/winner recipients cannot prevent other independent releases. The conditional malicious NFT issue above is distinct from reentrancy or accounting insolvency.
10. **Deadline races:** buys end at t=endTime; request opens at the same t and closes at t=end+2days; Active refunds open at that closure. Drawing callback closes strictly at requestedAt+2days and refunds open at that same t. No callback/refund overlap or dead interval exists.
11. **Same-factory sinks/cross-clone movement:** current same-factory clones and plumbing are screened for prize/recipient/ticket ownership. No function routes accounted quote balances between clones. Public quote donation or forced unrelated NFT/native transfer is outside liabilities and has no rescue path, as documented.
12. **Permissionless settlement proof theft:** anyone can supply the unique range, but no winner recipient is recorded until current owner explicitly redeems. Approved operators can transfer a ticket using standard ERC721 authority; they cannot directly call owner-only redemption or refund while another owner remains.

## Unresolved leads and explicit limits

- **Future/counterfactual protocol recipients (low-confidence security significance):** _isProtocolDestination, Raffle.sol lines 593–604, screens present code and current registry state. A user can mint/transfer a ticket to a predicted future clone address or choose such an address for sponsorRecipient while it has no code. Subsequent clone deployment can strand that ticket or cause _transferQuote to reject that sponsor recipient. The capability currently identified requires an owner/sponsor choosing an inaccessible destination; no involuntary victim or privilege-free way to transform an arbitrary victim EOA into a clone was found. Not elevated to a vulnerability. Deployment treasury set to its first future clone address can also make all creation revert at initialize; this is deployer misconfiguration rather than an attacker privilege.
- Canonical USDC blacklist, pause or upgrade behavior can block individual/all transfers. A blacklisted ticket owner may move the ticket to another usable owner when permitted by their wallet; immutable sponsor/treasury recipients cannot be changed. No alternate-recipient recovery exists. This is a dependency/recipient availability assumption, not a demonstrated adversarial USDC exploit.
- No actual wrapper configuration was provided: supported callback gas limit, request confirmations, native-payment support, service availability, network confirmation timing and callback gas consumption remain deployment checks. Refunds bound unresolved funds when the wrapper does not resolve.
- Modulo reduction introduces statistical bias when totalEntries does not divide 2^256, but with totalEntries<=2^128-1 its total-variation distance is bounded by totalEntries/(4*2^256)<2^-130, and no participant can choose authentic VRF output. No material exploitable bias was found.
- Third-party factory clones, arbitrary sink contracts and compromised participant wallets are not identified by the same-factory registry. Users selecting such recipients can strand their own bearer claims.
- Prize-token administration, external NFT value, UI discovery/indexer correctness and deployed bytecode/configuration were not audited.

## Deliverables

COVERAGE.md records file/function coverage and dependency depth. PROPERTIES.md states independent invariants and reasoning. ARCHITECTURE.md maps authority, state transitions, assets and external call boundaries. independent_checks.py and INDEPENDENT-CHECKS.json provide deterministic mathematical checks. SOURCE-HASHES.json binds the frozen source tree contents. SEAL.json binds all review artifacts with UTC timestamp and SHA256. A seal attests artifact integrity, not audit completeness or model provenance.
