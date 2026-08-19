# Ethereum Sepolia soak plan

Mainnet is blocked until the exact v1 release candidate completes this plan. The
candidate factory must use official Sepolia USDC and the official Chainlink VRF v2.5
native direct-funding wrapper with the fixed 300,000 callback gas and 30 confirmations.

Adversarial wrapper, ERC-20, or ERC-721 drills belong to separate staging factories
that must never enter deployment records or the public application.

## Entry gate

- clean source commit and frozen lockfile;
- every repository validation gate green from a clean checkout;
- independent audit scope fixed to that commit and deployment configuration;
- verified factory and implementation source;
- finalized deployment record passes transaction, runtime, ownership, USDC, wrapper,
  fixed-constant, and implementation-lock checks;
- two-step ownership accepted by the reviewed contract wallet;
- monitoring, keepers, incident roles, and legal review staffed.

## Duration and volume

Run for at least 14 consecutive days and exercise the real two-day callback timeout
without changing production constants. Require at least 25 successful
official-wrapper draws across at least ten wallets and five standards-compliant NFT
collections. Keep every prize and entry value deliberately low.

## Required scenarios

| Scenario                | Required evidence                                                                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Range purchase          | sequential IDs and stored 1-entry/multi-entry ranges are exact and contiguous; cost is exactly 1 USDC per entry                                                                       |
| Bearer transfer         | ticket transfers work before close, while drawing, and after resolution; successful settlement burns the ticket exactly once                                                          |
| NFT result              | equality meets reserve; settlement snapshots winner and records 5%/95%; winner NFT and both quote claims release independently                                                        |
| Cash result             | below-reserve settlement records 80%/5%/15%; winner cash, sponsor cash, protocol fee, and sponsor NFT release independently                                                           |
| Empty raffle            | sponsor enters zero-liability `Refunding` before end and anyone can do so at/after end                                                                                                |
| Request boundary        | request at `drawRequestDeadline() - 1` succeeds; request at the deadline fails; a sold `Active` raffle can enter refunds at the deadline                                              |
| Callback absence        | staging wrapper accepts but does not fulfill; refunds open exactly at `callbackDeadline()`                                                                                            |
| Callback rejection      | staging wrapper sends synchronous, wrong-ID, duplicate, stale, and deadline-expired ABI-decodable callbacks without unsafe mutation; unauthorized or undecodable calls revert earlier |
| NFT transfer failure    | adversarial collection reverts or lies on release; winner NFT remains pending while settlement and both quote claims remain usable                                                    |
| Callback boundary       | matching callback at `callbackDeadline() - 1` resolves; at the deadline it is ignored and refunds are available                                                                       |
| Outgoing failure        | adversarial quote token proves a failed winner/sponsor/protocol release restores only that claim and leaves all other claims usable                                                   |
| Operational controls    | contract wallet pauses/resumes future creation; frontend write kill switch and keeper actions are rehearsed                                                                           |
| Degraded infrastructure | direct chain reads and calldata instructions remain usable while subgraph or one RPC is unavailable                                                                                   |

For every scenario retain chain ID, block and transaction hashes, addresses, decoded
events, before/after state, actual balances and liabilities, ticket ranges, monitor
alert/acknowledgement, and expected versus observed behavior.

The official-wrapper candidate cannot manufacture absence, wrong-word-count callbacks,
or undecodable callback calldata. Those behaviors are demonstrated on source-identical
staging clones whose only difference is the adversarial dependency; the live candidate
is separately monitored for real request/fulfillment correlation.

## Exit gate

The soak passes only with:

- no unexplained runtime, configuration, state, range, or accounting mismatch;
- no unresolved P0/P1 incident or missed acknowledgement objective;
- every official draw correlated to Chainlink request and fulfillment evidence;
- no callback gas failure and approved headroom for the exact release bytecode;
- the empty path, exact request and callback boundaries, the last-valid-second request,
  both refund origins, and both successful outcomes exercised;
- complete monitoring reconciliation, contract-wallet pause, UI-disable, and incident
  drills by the people who will operate mainnet;
- every code or configuration change independently reviewed and its soak impact
  documented.

The last-valid-second request gives the wrapper a fresh two-day callback window, so the
last nominal callback/refund boundary is almost four days after sale end. Evidence must
also cover the operational consequence of censorship or a reorganization removing a
request or callback after its cutoff: it cannot be replayed and the supported recovery
outcome is refunds.

Changing Solidity, compiler, dependencies, wrapper, USDC, implementation, constants,
owner/treasury, ABI generation, or deployment procedure invalidates affected evidence
and requires a documented restart decision.
