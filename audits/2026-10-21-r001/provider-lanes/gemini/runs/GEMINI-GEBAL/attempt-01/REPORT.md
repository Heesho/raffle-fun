# Gebal assessment

Run: 9b66bccf-5138-42e3-911d-48da23cf375d

**Outcome: succeeded**

An empty findings list is not a security certificate\. Completed checks establish only their stated coverage\.

**Source-only run: no compiler, static analyzer or executable test coverage.**

Snapshot: 4d791fd1b91c282a49b1db1ec34fc406e11a75d7cb7fe4fea8a93c9b81d22ecb

## Incomplete checks

All planned tasks completed. Coverage remains limited to the checks below.

## Scope and requirements

raffle\.fun non-upgradeable ERC-721 prize raffle protocol \(Raffle\.sol, RaffleFactory\.sol, IRaffle\.sol, IRaffleFactory\.sol, RaffleConstants\.sol\)\. Requirements: \(1\) Never move assets between raffle clones or lock assets in protocol sinks; \(2\) Escrowed prizeToken must be verified and isolated per raffle; \(3\) Ticket entries are fixed 1 USDC \(6 decimals\), sequential 1-indexed contiguous ranges \[startEntry, endEntry\], transferable via ERC-721; \(4\) Chainlink VRF v2\.5 Direct Funding native wrapper draw within \[endTime, endTime \+ 2 days\) and callback within \[requestedAt, requestedAt \+ 2 days\); \(5\) Settlement is permissionless and storage-only, splitting 95% sponsor / 5% treasury on NftWon \(totalEntries \>= reserveEntries\) or 80% winner / 15% sponsor / 5% treasury on CashWon \(totalEntries \< reserveEntries\); \(6\) Pull-claim isolation for winner redemption, sponsor proceeds, sponsor prize reclaim, protocol fees, and ticket refunds\.

Authorized: packages/contracts/src, packages/contracts/foundry\.toml, packages/contracts/remappings\.txt

Project path: packages/contracts

Explicit dependency paths: none

Execution policy: Only profile\.default is selected; other profiles, RPC endpoints and formatting configuration are not loaded\. Controller overrides output/cache/script paths, denies FFI/filesystem/RPC and dependency downloads, and disables automatic remappings\. Configured fuzz/invariant campaigns are replaced by the disclosed fixed seed and bounded campaign\. Tests requiring denied capabilities cannot be validated\. Source-only intake does not establish compiler, test, property or security coverage\.

Excluded/absent: 

## Check evidence

- intake: succeeded. Recorded 7 authorized files\. Build configuration unsupported; see diagnosis\.
  Evidence: 6a2f6ee5a51c355f1ec00e670901ccba6a13b8ebb37bfa86341429701eb81378

## Findings requiring human review

### Predictable CREATE clone addresses bypass \_isProtocolDestination before deployment, locking quote payouts and allowing cross-clone prize transfers

Severity: medium; confidence: high; evidence: model; disposition: accept

RaffleFactory\.createRaffle deploys clones with Clones\.clone\(raffleImplementation\) \(EVM CREATE opcode\), making every future clone address deterministic from \(address\(factory\), nonce\)\. Before a future clone R\_future is deployed, R\_future\.code\.length == 0 and canonicalFactory\.isRaffle\(R\_future\) == false\. Consequently, R\_future passes RaffleFactory\.\_validateCreateParams and Raffle\.\_isProtocolDestination during Raffle\.initialize \(as sponsorRecipient\) and Raffle\.\_update \(as a ticket recipient in buyEntries or transferFrom\), and bypasses ERC721Utils\.checkOnERC721Received\. Once R\_future is deployed by a subsequent createRaffle call, isRaffle\[R\_future\] becomes true and R\_future\.code\.length == 45: \(1\) Raffle\.releaseSponsorProceeds calls \_transferQuote\(R\_future, amount\), which re-checks \_isProtocolDestination and permanently reverts with InvalidQuoteDestination\(R\_future\), locking sponsorProceeds; \(2\) Raffle\.releaseSponsorPrize and Raffle\.redeemWinningTicket \(in Status\.NftWon\) omit \_isProtocolDestination and call prizeToken\.transferFrom\(address\(this\), R\_future, prizeTokenId\), moving the prize NFT into clone R\_future in violation of the cross-clone asset isolation invariant and stranding the NFT permanently; \(3\) any ticket owned by R\_future can never be redeemed or refunded because Raffle has no outbound call to redeemWinningTicket or refundTickets; \(4\) if protocolTreasury is configured to a future clone CREATE address R\_k in the RaffleFactory constructor, createRaffle permanently reverts at raffle k with UnsafeProtocolDestination\. Assumptions: A caller or sponsor specifies a precomputed future CREATE address of RaffleFactory before that clone index is deployed\.; At least one subsequent createRaffle call occurs to deploy the clone at that predicted address\.

Source: packages/contracts/src/Raffle\.sol:334-337, packages/contracts/src/Raffle\.sol:395-407, packages/contracts/src/Raffle\.sol:497-502, packages/contracts/src/Raffle\.sol:564-567, packages/contracts/src/Raffle\.sol:593-605, packages/contracts/src/RaffleFactory\.sol:106-127, packages/contracts/src/RaffleFactory\.sol:159-168

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7

### Decoupled sponsorProceeds payout in Status\.NftWon allows sponsor to claim 95% of buyer USDC even when prizeToken delivery fails in redeemWinningTicket

Severity: medium; confidence: high; evidence: model; disposition: accept

In Status\.NftWon, \_settleWinningTicket allocates 95% of unsettledPot to sponsorProceeds and 5% to protocolFees in storage without transferring prizeToken or verifying that prizeToken remains transferable to the winning ticket owner\. Raffle\.releaseSponsorProceeds only checks sponsorProceeds \!= 0 and does not require prizeClaimed == true when status == Status\.NftWon\. If the arbitrary ERC-721 prizeToken is pausable, blacklist-enabled, expiring, soulbound-after-escrow, or sponsor-controlled and reverts \(or fails the post-transfer ownerOf check\) during redeemWinningTicket, the sponsor still extracts 95% of buyer USDC while the winner cannot receive the NFT and the raffle cannot transition from Status\.NftWon to Status\.Refunding\. Assumptions: The escrowed prizeToken is an arbitrary ERC-721 contract that succeeds during createRaffle safeTransferFrom but reverts or blocks transfer when redeemWinningTicket is called after settlement\.

Source: packages/contracts/src/Raffle\.sol:329-339, packages/contracts/src/Raffle\.sol:375-382, packages/contracts/src/Raffle\.sol:533-558, packages/contracts/src/RaffleFactory\.sol:171-177

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7

### Discontinuous payout cliff at reserveEntries and unrestricted single-buyer under-target draw enable sponsor self-purchase arbitrage and 20% fee extraction

Severity: low; confidence: high; evidence: model; disposition: accept

When totalEntries crosses reserveEntries, settlement switches discontinuously from Status\.CashWon \(80% winnerProceeds, 15% sponsorProceeds, 5% protocolFees, plus prize NFT returned to sponsor\) to Status\.NftWon \(0% winnerProceeds, 95% sponsorProceeds, 5% protocolFees\)\. Because neither sponsor nor sponsorRecipient is blocked in buyEntries, a sponsor receives a 95% rebate on every entry bought once totalEntries \>= reserveEntries \(paying $0\.05 net per $1\.00 entry\) and can buy the shortfall right before endTime to capture 80% of existing buyers' pot plus proportional probability of winning back the NFT\. Conversely, when totalEntries \< reserveEntries and only a single buyer \(or single ticket\) participated, requestDraw can still be called at endTime to force Status\.CashWon, extracting 15% sponsorProceeds \+ 5% protocolFees from the sole buyer while returning the NFT to the sponsor\. Assumptions: Economic mechanism treats sponsor entries identically to external buyer entries and permits draws when ticketCount == 1 below reserveEntries\.

Source: packages/contracts/src/Raffle\.sol:209-236, packages/contracts/src/Raffle\.sol:243-248, packages/contracts/src/Raffle\.sol:519-550, packages/contracts/src/RaffleFactory\.sol:178-179

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7

### Sponsor pre-endTime empty-raffle cancellation in enableRefunds can be front-run by a 1-USDC buyEntries transaction

Severity: low; confidence: high; evidence: model; disposition: accept

Raffle\.enableRefunds allows the sponsor to cancel an active raffle before endTime only when totalEntries == 0\. Because buyEntries is permissionless while block\.timestamp \< endTime, an observer in the public mempool can front-run the sponsor's enableRefunds\(\) call with buyEntries\(recipient, 1\) for 1 USDC \(1e6 quoteToken units\)\. This increments totalEntries to 1, causing the sponsor's enableRefunds\(\) transaction to take the totalEntries \!= 0 branch and revert with RefundsNotAvailable\(endTime \+ 2 days, block\.timestamp\), locking the prize NFT until at least endTime \(and winning the NFT for 1 USDC if reserveEntries == 1\)\. Assumptions: The sponsor broadcasts enableRefunds\(\) via a public mempool before endTime while totalEntries == 0\.

Source: packages/contracts/src/Raffle\.sol:209-236, packages/contracts/src/Raffle\.sol:280-292

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7

### Untrusted prizeToken\.safeTransferFrom in createRaffle activates the Raffle clone before RaffleCreated is emitted and before post-transfer ownerOf verification

Severity: low; confidence: high; evidence: model; disposition: accept

In RaffleFactory\.createRaffle, prize\.safeTransferFrom\(msg\.sender, raffle, params\.prizeTokenId\) invokes Raffle\.onERC721Received, which transitions the clone from Status\.Initialized to Status\.Active and emits PrizeDeposited before safeTransferFrom returns to RaffleFactory\. Because Raffle's own ReentrancyGuard is not entered during createRaffle, a custom or hook-enabled prizeToken contract can call raffle\.buyEntries\(recipient, entryCount\) inside safeTransferFrom after onERC721Received returns, emitting Transfer and TicketPurchased events before RaffleFactory verifies prize\.ownerOf\(params\.prizeTokenId\) == raffle and before RaffleCreated is emitted\. Assumptions: The prizeToken contract executes an external call to the newly created Raffle clone inside safeTransferFrom after calling onERC721Received\.

Source: packages/contracts/src/RaffleFactory\.sol:128-147, packages/contracts/src/Raffle\.sol:416-431

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7

### Unbounded reserveEntries upper limit, unrestricted secondary ticket transfers during Status\.Drawing, and ERC-1167 ReentrancyGuard cold-slot gas overhead

Severity: informational; confidence: high; evidence: model; disposition: accept

Three defense-in-depth and gas hygiene issues exist across RaffleFactory and Raffle: \(1\) RaffleFactory\.\_validateCreateParams only checks reserveEntries \!= 0 and enforces no upper bound on uint128 reserveEntries, allowing raffles where reserveEntries exceeds total USDC supply so Status\.NftWon is unreachable; \(2\) Raffle\.\_update does not restrict ERC-721 ticket transfers during Status\.Drawing or after draw fulfillment, exposing open secondary-market orders or bids on tickets to mempool front-running once the VRF fulfillment transaction is visible; \(3\) Raffle inherits storage-backed ReentrancyGuard \(where \_status starts at 0 in uninitialized ERC-1167 clone storage rather than \_NOT\_ENTERED = 1\), charging the first buyEntries caller a 20,000-gas 0-to-1 SSTORE penalty, and hardcodes VRF\_CALLBACK\_GAS\_LIMIT = 300\_000 even though fulfillRandomWords only writes 4 storage slots\. Assumptions: Target EVM is cancun \(as configured in foundry\.toml\), where transient storage \(EIP-1153\) is available\.

Source: packages/contracts/src/RaffleFactory\.sol:178-179, packages/contracts/src/Raffle\.sol:252-266, packages/contracts/src/Raffle\.sol:497-502, packages/contracts/src/libraries/RaffleConstants\.sol:32-42

Artifacts: 9c6ca2adbc5e564b4ccf733989466f80dfe93189d8dfc38d69c31c8b2569a6d7


## Coverage gaps

- No semantic, test, or property coverage established by intake\.
- External agent provenance, token usage and spend are unknown\.
- Imported observations do not complete blocked local checks or establish any property\.
- Cold source-only review \(attempt-01\) excludes dynamic execution of Foundry tests, Slither, Aderyn, Echidna, and Halmos; dynamic verification is deferred to post-seal validation and attempt-02\.
- Chainlink VRF v2\.5 Direct Funding wrapper fee pricing and coordinator behavior are external to the five in-scope contracts\.

## Provenance and cost

Method: native-review-v1; adapter: 0.2.0

Tool image: unavailable; compiler: 0\.8\.36; EVM: cancun

Planned direct provider/model: none

External reviewers: gemini-4-argon \(Google Gemini 4 Argon High\). External provenance, usage and spend are unverified.

Recorded direct API tokens: 0; reserved: 0. Monetary cost: unknown. Local compute cost is not measured.

The JSON report retains manifests, settings, decisions, invocations, source hashes, timelines and coverage records. Artifact IDs resolve through the local store or CLI evidence command.
