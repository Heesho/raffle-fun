# Step 5 — manual review (privacy, front-running, cryptography, DeFi)

Pattern searches over the original sources: `00-step5-source-searches.txt` (224 lines; recorded commands and matches).
Executable demonstrations run against UNMODIFIED production code in the generated harness:
`../04-properties/33-forge-test-all-final.stdout.txt` (20/20 pass) and `10-forge-test-F5-economics.stdout.txt`.

## 5.1 Privacy

| Question (skill) | Search / analysis | Conclusion |
|---|---|---|
| Secrets stored on-chain? | No `secret/password/seed/salt/commit/reveal` identifiers; `private` state is `_ticketRanges` (also exposed via `ticketRange()`) and `_requestInFlight` (transient flag). | None. All raffle state (buyers, ranges, owners, pot) is public by design. |
| Commit–reveal needed? | Randomness comes from Chainlink VRF (cryptographic commit by the oracle, proof verified on-chain by the coordinator). No user-supplied secret influences the outcome. | Not needed for randomness. **However** the VRF result is public in the fulfillment transaction before inclusion → see S6-F1 (front-running). |
| Privacy assumptions documented? | DESIGN.md: "Frontend discovery is advisory". | Add explicit user-facing note that ticket ownership/entries are public and that the outcome becomes knowable one block early (S6-F1). |

## 5.2 Front-running / ordering / MEV

| Surface | Analysis | Conclusion |
|---|---|---|
| Ticket trading while the VRF answer is pending | `_update` (Raffle.sol:497-502) has no lifecycle gate; `fulfillRandomWords` maps the word deterministically to an entry (Raffle.sol:518). The coordinator's fulfillment transaction reveals the word before inclusion. | **S6-F1 (Low)** — demonstrated by `test_F1_ticketsTradeableWhileDrawing_pendingWordDeterminesWinner`. |
| Reserve threshold flip at sale end | Outcome type = `totalEntries >= reserveEntries` (Raffle.sol:521); NftWon pays the sponsor 95% of gross INCLUDING its own purchases (Raffle.sol:543-544). A sponsor-controlled address can buy the shortfall immediately before `endTime` for a net cost of 5% of the shortfall. | **S6-F5 (Medium)** — quantified: baseline sponsor 135 USDC + NFT vs flipped 850 USDC net; buyers lose a 720 USDC cash prize (`test_F5_sponsorSybilCrossesReserve_flipsOutcome`). |
| Purchase slippage (odds dilution) | `buyEntries(recipient, entryCount)` (Raffle.sol:209) has no `maxTotalEntries` / outcome guard; price is constant, so there is no price slippage, only odds/outcome-type slippage. | Folded into S6-F5 recommendations (Informational on its own). |
| Sponsor cancel vs first buyer race | Sponsor may close an EMPTY raffle before endTime (Raffle.sol:280-284). Either order is safe: a cancelled raffle makes the purchase revert (no funds taken); a first purchase removes the sponsor's cancel right. | No issue — `test_emptyRaffle_sponsorCancel_only_while_no_entries`. |
| `requestDraw` / `settleWinningTicket` / releases front-running | Permissionless; outcome independent of caller; excess VRF fee refunded to whoever called. | No issue. |
| Timestamp manipulation | Day-scale windows on PoS Ethereum; boundaries disjoint and exact (symbolic + boundary tests). | No issue (Slither timestamp items triaged). |
| `createRaffle` approval front-running | Prize is always pulled from `msg.sender` (RaffleFactory.sol:128). | No issue — `test_factory_rejects_protocol_plumbing_and_bad_params` (Bob cannot raffle Alice's approved NFT). |

## 5.3 Cryptography

| Question | Analysis | Conclusion |
|---|---|---|
| Weak randomness (timestamp, blockhash, prevrandao)? | None used (search + custom Slither check C9). Randomness = Chainlink VRF v2.5 direct funding, native payment (`ExtraArgsV1{nativePayment:true}` validated by the mock exactly as the real wrapper's `checkPaymentMode`), 1 word, 30 confirmations, 300k callback gas. | Sound. Modulo bias `≤ totalEntries/2^256 ≤ 2^-128` (negligible). |
| Callback safety | Only the wrapper can call (`OnlyVRFWrapperCanFulfill`); wrong id / wrong length / late / duplicate / in-flight callbacks are ignored without reverting (custom check C5; fuzz; symbolic). | Sound. VRF failure → refunds after `drawRequestedAt + 2 days`. |
| Signatures / `ecrecover` / permits | None (search, C9). | N/A (verified). |
| Hash collisions (`abi.encodePacked`) | None in production code. | N/A (verified). |
| Address predictability | Clones use CREATE (factory nonce) → next clone address is predictable. Used to construct S6-F4. | **S6-F4 (Informational)**. |

## 5.4 DeFi interactions

| Question | Analysis | Conclusion |
|---|---|---|
| Oracle manipulation | No price oracle; only the VRF randomness oracle. `linkNativeFeed` exists only in the wrapper interface and is unused on the native-payment path. | N/A (verified). |
| Flash loans | Entries cannot be refunded before the deadline-gated `Refunding` state, so flash-borrowed capital cannot be repaid in the same transaction; no balance-dependent accounting (`balanceOf(address(this))` never read; fuzzed with unsolicited donations). | N/A (verified). |
| Protocol assumptions — USDC | Trusted canonical token (DESIGN.md), but upgradeable, pausable and blocklisting. Blocklisted winners/refunders can move their bearer ticket and claim from a clean address; a blocklisted `sponsorRecipient`/treasury strands only its own claim; a blocklisted raffle or a USDC pause freezes that raffle's USDC. | **S6-F8 (Informational)** — `test_blocklistedParties_liveness`. |
| Protocol assumptions — VRF wrapper | Trusted; if disabled/underfunded, `requestDraw` reverts or the callback never arrives → refunds after the 2-day timeouts (liveness preserved, prize returned). The requester pays the fee with no reimbursement. | Informational (S6-F8). |
| Protocol assumptions — prize contracts | DESIGN.md says untrusted; IRaffle NatSpec (IRaffle.sol:14-15) says "Supported prizes are honest". Escrow verification and delivery both depend on the prize contract; sponsor proceeds do not depend on delivery. | **S6-F2 (Medium)**, **S6-F3 (Low)**. |

## Findings (manual review)

| ID | Severity / difficulty | Title | Evidence |
|---|---|---|---|
| S6-F1 | Low / Medium | Tickets remain tradeable while a VRF fulfillment is pending; the pending word determines the winner one block early | Raffle.sol:497-502, 518; `test_F1_…` |
| S6-F2 | Medium / High | Sponsor proceeds are released independently of prize deliverability; a sponsor-controlled (pausable/admin/upgradeable) prize collection lets the sponsor collect 95% while the winner can never redeem | Raffle.sol:304-306, 329-337, 375-382, 533-558; `test_F2_…` |
| S6-F3 | Low / Medium | Escrow verification trusts the prize contract: a dishonest ERC-721 activates a raffle with no custody | RaffleFactory.sol:127-134; Raffle.sol:416-431; `test_F3_…` |
| S6-F4 | Informational / High | Registry screening skips code-less addresses: the predictable next clone address passes as `sponsorRecipient`; `releaseSponsorPrize` (no runtime re-screen) then moves the NFT into another clone, and USDC proceeds become unclaimable | Raffle.sol:395-407, 564-567, 593-605; `test_F4_…`, `test_F4b_…` |
| S6-F5 | Medium / Low | Reserve outcome can be flipped by a last-moment sponsor-controlled purchase at ~5% cost, converting buyers' cash prize into an NFT outcome | Raffle.sol:209-237, 521, 543-544; `test_F5_…` |
| S6-F6 | Informational | Unredeemed winning claims and stray assets are locked forever (no redemption deadline, no rescue path) | Raffle.sol:19-27, 309-346, 409-411 |
| S6-F7 | Informational | All ticket collections share `name`/`symbol` and have empty `tokenURI`; indistinguishable/spoofable on marketplaces | Raffle.sol:479-487 |
| S6-F8 | Informational | Liveness/trust dependencies: USDC pause/blocklist; VRF wrapper availability; requester-paid VRF fee | Raffle.sol:240-273, 564-567; `test_blocklistedParties_liveness` |
