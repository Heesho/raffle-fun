# Incident-response runbook

Existing raffles are immutable and have no administrator. An incident response can
pause only future creation, disable product surfaces, help users exercise existing
permissionless paths, and migrate new activity to a separately reviewed factory. It
cannot upgrade, seize, redirect, or rewrite an existing raffle.

## Roles and authority

Assign named primary and backup people before launch:

- incident commander: severity, decisions, timeline, and closure;
- chain lead: independent RPC verification, traces, affected-set and loss analysis;
- Safe operator: proposes the pre-reviewed pause transaction; never acts from a single
  chat message;
- product lead: disables writes and preserves read/recovery access;
- communications/legal lead: user notices, regulator/counterparty coordination, and
  disclosure timing.

Store the call tree, Safe signer contacts, RPC/monitor credentials, frontend kill
switch, status-page access, and Chainlink/Circle escalation routes outside this public
repository. Test access quarterly.

## Severity

- **P0:** active exploitation, quote insolvency, counterfeit canonical raffle,
  compromised owner Safe, or a production-state violation that can affect assets.
- **P1:** credible unexploited vulnerability, broken dependency/oracle/token control,
  owner/treasury drift, or widespread inability to complete recovery paths.
- **P2:** isolated liveness, indexer, RPC, or UI fault with onchain safety properties
  intact.

## First 15 minutes

1. Open a timestamped incident log and assign the roles above.
2. Verify chain ID, block hash, addresses, state, and transactions through two
   independent RPCs. Treat screenshots and the subgraph as supporting evidence only.
3. Identify the exact factory, implementation, raffle set, source commit, dependency
   lock, first suspicious block, and whether the issue affects existing raffles or only
   future creation.
4. For P0/P1, have the Safe operator propose `setCreationPaused(true)`. A second person
   must decode the chain, target, selector, and argument before the Safe threshold signs.
5. Disable new-raffle and purchase writes in the frontend. Keep direct read, claim,
   redemption, and refund instructions available unless the affected call itself is
   unsafe.
6. Preserve RPC responses, receipts, logs, traces, bytecode, runtime hashes, monitor
   alerts, and relevant application logs. Do not rotate or destroy evidence before it
   is copied.

Never ask users to send assets to a rescue wallet, disclose seed phrases, or approve a
new contract during initial containment.

## Analysis and user protection

Classify each canonical raffle by lifecycle and exposure. Reconcile its actual USDC
balance against `accountedQuoteBalance()` and the four recorded liabilities. Identify
all deadlines and entitlement holders from chain state.

- For missed request, callback timeout, or NFT-delivery timeout, sponsor the ordinary
  permissionless transition only when its documented boundary is reached.
- For claims/redemptions, publish exact verified addresses and calldata-generation
  instructions; do not introduce an unreviewed relayer or asset custodian.
- For an owner compromise, creation pause/treasury controls affect future raffles only.
  Assume every owner action needs independent decoding and Safe recovery review.
- Escalate Chainlink liveness/authentication issues to Chainlink and USDC
  pause/freeze/proxy issues to Circle, while continuing independent chain verification.

## Recovery and migration

A replacement factory is a new release. It requires a new implementation, independent
review, Sepolia validation, source verification, Safe acceptance, monitoring, and
signed deployment record. Never label it a hotfix while skipping release gates.

Resume creation only after the incident commander records root cause, affected scope,
why remaining raffles are safe to interact with, completed fixes, independent review
where required, monitoring changes, and the exact Safe transaction approving resume.
The frontend must not silently route an old factory page to a new contract.

## Communications and closure

The first public notice should state confirmed facts, affected addresses/chains,
temporarily disabled actions, safe actions, and the next update time. Avoid claims of
fund recovery or safety before reconciliation. Coordinate private vulnerability
disclosure under `SECURITY.md`.

Close only after the affected set and liabilities reconcile, users have durable
recovery instructions, alerts and tests cover the root cause, external obligations are
handled, and a blameless postmortem with exact blocks/transactions is published or
retained under counsel as appropriate.
