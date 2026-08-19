# Current audit threat model

This file fixes the adversary and trust assumptions used for review of the committed
Ethereum v1 audit candidate. The maintained public explanation is
`docs/THREAT-MODEL.md`; the code is authoritative.

## Security objective

For an honest standards-compliant ERC-721 prize and available exact-transfer official
USDC, no unauthorized party can select the winner, seize or duplicate a supported
asset, create an unfunded liability, redirect a fixed recipient's balance, or make work
scale with total entries. Sold raffles have a bounded two-day request window followed,
if a request succeeds, by a bounded two-day callback window. Each has an exact full-
refund recovery boundary, subject to external asset and chain availability.

## In-scope adversaries

- malicious sponsor, buyer, ticket recipient, ticket operator, draw requester,
  refund caller, winner, and public finalizer;
- compromised factory owner after deployment;
- reentrant or rejecting ERC-721 receivers;
- false-returning, fee-on-transfer, over-crediting, under-crediting, or reentrant quote
  tokens at the contract boundary;
- prizes that revert, no-op, reenter, or report unexpected ownership;
- unauthorized or undecodable VRF calls; wrapper-authenticated ABI-decodable wrong-ID,
  synchronous, duplicate, wrong-word-count, stale, deadline-expired, or missing VRF
  callbacks;
- transaction ordering, censorship, and reorganization at every sale, request,
  callback, settlement, and timeout boundary;
- duplicated, foreign, malformed, maximum-range, or maximum-batch ticket inputs;
- protocol-destination and cross-raffle credential sinks;
- stale or malicious indexer/frontend data.

## Trusted or externally assumed

- Ethereum consensus and sufficient transaction inclusion;
- the release-day official Chainlink VRF v2.5 wrapper/coordinator and its security,
  pricing, and availability model;
- the release-day official USDC deployment and its issuer/proxy controls;
- honest ERC-721 interface and ownership behavior for a supported prize;
- secure factory-owner and treasury wallets;
- users retain control of ticket-owner accounts or deploy contracts capable of the
  owner-only refund action;
- independently reviewed deployment configuration and verified bytecode.

The contract has timeout recovery both when no request is included before
`drawRequestDeadline()` and when an accepted request receives no valid callback before
`callbackDeadline()`. Requests/callbacks require `block.timestamp` strictly below their
cutoff and refunds open at the cutoff. A valid earlier result is final and the prize must
remain within the supported ERC-721 trust boundary. A request at the last valid second
can place the final nominal boundary almost four days after sale end.

## Authority review

The factory owner can pause or unpause future creation and transfer factory ownership
through `Ownable2Step`. It cannot change the immutable implementation, quote token,
wrapper, treasury, constants, or an existing raffle. A raffle has no owner, upgrade,
arbitrary-call, cancellation, rescue, or emergency-settlement selector.

The sponsor controls the initial prize, reserve, and end time. After atomic creation it
cannot cancel a sold raffle, choose randomness, move tickets, take the cash-result pot,
or bypass the lifecycle. Anyone can release its NFT only after `CashWon` or `Refunding`,
always to the immutable `sponsorRecipient`. Sponsor quote proceeds are recorded only
during winning-ticket settlement and can likewise be released only to that recipient.

## Required attack surfaces

Review and test must cover:

1. clone implementation locking, one-time initialization, registry ordering, storage
   isolation, and atomic prize escrow;
2. sequential ticket creation, stored-range arithmetic, `uint128` overflow, ERC-721
   hooks, and bearer transfers across lifecycle boundaries;
3. wrapper fee quoting, the exact `[endTime, drawRequestDeadline())` request window,
   sold-`Active` refunds at the request deadline, native value flow, request reentrancy,
   callback authentication, ABI-decodability, request matching, malformed words, gas
   boundedness, callbacks strictly before `callbackDeadline()`, refunds at the callback
   deadline, and the last-valid-second request path;
4. reserve equality, callback-only resolution, constant-time winner proof, fixed
   current-owner settlement, immutable sponsor/treasury destinations, and prize postconditions;
5. NFT-branch 5/95, cash-branch 80/5/15 gross, and full-refund conservation;
   fixed-recipient releases, exact token deltas, burns,
   rollback, reentrancy, donations, and partial refund ordering;
6. known protocol destinations, future-code destinations, contract ticket owners,
   and unsupported asset behavior;
7. ABI, status ordinal, `bigint`, event, subgraph, deployment-record, and frontend
   agreement with the exact Solidity candidate.

## Explicitly out of scope for correctness claims

Legal compliance, market demand, NFT valuation/authenticity, wallet compromise, RPC or
website availability, malicious tokens that lie consistently, malicious consensus,
Chainlink cryptographic compromise, and future issuer/provider governance are not
solved by this code. They remain launch and operational risks in
`CURRENT-RESIDUAL-RISKS.md`.

Because both deadlines are hard inclusion cutoffs, censorship or a reorganization that
removes an otherwise valid request or callback after its cutoff prevents replay and can
force the refund outcome. This is a residual chain-liveness risk, not an equality race.
