# Independent supplemental lifecycle source review

## Provenance and scope

This is an independent supplemental reasoning pass, not a Gebal native automatic specialist stage. The sole assessed-source authority was `audit/context.json`. No target checkout, test sources, audit history, scanner output, reports, or peer findings were read. The parent was instructed to preserve its own first pass before reading this response; findings were not sent in messages.

Requested configuration: `gpt-6-astra`, reasoning `ultra`, fallback disabled. Provider-returned model identity, enforced reasoning setting, token use, and cost were not available to this reviewer and remain unknown. This statement records the requested configuration, not an independently verified model attestation.

The protocol resources `audit/resources/START_HERE.md`, `audit/resources/agents/REVIEW.md`, and `audit/resources/agents/response.schema.json` were read in full. Shell/Python operations only extracted pinned source text and wrote inert review evidence. No compiler, test runner, analyzer, prover, assessed setup script, exploit, transaction, or browser was used.

## Assumptions recorded before conclusions

1. The clean design specification embedded in the context supplies the intended economics and lifecycle. Contract comments are implementation evidence, not authority to narrow those requirements silently.
2. The canonical quote token is trusted to have six decimals, standard fee-free and non-rebasing transfer behavior, and correct transfer results. Canonical Chainlink wrapper authentication, randomness and request behavior are trusted. Deployment addresses and live-chain availability are not independently verified.
3. Arbitrary prize contracts and ticket recipients can call back into exposed methods, revert, return malformed data, or retain assets. A distinction is necessary between treating an ERC721 as untrusted for call ordering and trusting it to report actual ownership. ERC165 and ownerOf answers alone cannot establish honesty of an arbitrary contract.
4. Redemption authority belongs to the current ticket owner, including after settlement; ordinary ERC721 approval grants transfer authority but is not direct redemption authority. Owner-controlled forwarding of a ticket is allowed.
5. EVM transaction atomicity is assumed: a revert propagating from delivery, ownership verification or safe mint unwinds the entire call and its descendant effects. External calls do not survive an outer revert.
6. The required request interval is [endTime, endTime + 2 days), callback acceptance is strictly before drawRequestedAt + 2 days, and refunds become available at the respective deadline. The separately documented empty-raffle cancellation path is treated as intended.
7. Settlement is permissionless and must remain independent of recipient behavior and ticket ownership. Sponsor and treasury quote claims are independent after settlement. Outcome finality is not assumed to imply guaranteed delivery by a malicious prize contract.
8. The phrase “Never move assets between raffle clones” is ambiguous between one canonical factory and every deployment of this code. The second observation is conditional on the broader interpretation and is not asserted as an unauthorized theft.
9. Analysis is limited to source reasoning. “Reviewed” and “supported” below mean manually traced source behavior, not measured test coverage, proof, successful compilation, or a security certificate.

## Original conclusions

No source-supported unauthorized initialization, duplicate claim, callback deadline bypass, owner-only redemption bypass, or reentrancy-driven accounting corruption was identified within the canonical dependency assumptions. Two narrowly framed observations remain for human disposition. Neither is presented as an executed exploit or final accepted finding.

### L-01 — Prize trust requirement is broader than the implemented escrow evidence

Severity: informational. Confidence: high for the trust-boundary discrepancy; no claim that arbitrary NFT honesty is generally enforceable by a generic interface check.

The clean specification calls arbitrary prize contracts untrusted, while `packages/contracts/src/interfaces/IRaffle.sol:12-15` explicitly limits supported prizes to honest, standards-compliant ERC721s. Creation accepts an arbitrary deployed address that reports ERC721 support (`packages/contracts/src/RaffleFactory.sol:154-178`). The prize contract itself supplies the receiver callback and the ownerOf answer used to consider escrow complete (`RaffleFactory.sol:127-134`; `Raffle.sol:416-430`). Delivery similarly relies on that same contract's transferFrom and ownerOf (`Raffle.sol:329-337`, `395-405`). These checks detect inconsistent or reverting token behavior, but cannot independently establish the truth of ownership reports supplied by a dishonest token.

The consequence is bounded and explicit: a token may appear escrowed under its own answers but later refuse a winner's transfer, or give an ownership answer without meaningful delivery. After NftWon, refund activation is unavailable (`Raffle.sol:276-299`), and successful permissionless settlement allocates sponsor and treasury proceeds without consulting the prize (`Raffle.sol:533-557`), as separately required. A reverting prize transfer preserves the winner's ticket and redemption state, but does not make the prize transferable or restore funds already claimed by independent beneficiaries.

This is primarily a requirement/trust-model reconciliation item, not a demonstrated failure with an honest standard ERC721. Clarify whether “untrusted” means hostile callbacks and failure handling while ownership semantics remain trusted. If dishonest ownership semantics are in scope, the current implementation does not satisfy the stronger escrow/delivery promise; solving that would require an explicit product trust or economic policy rather than assuming another ownerOf check can prove truth.

### L-02 — Clone destination screening is confined to one factory registry

Severity: low. Confidence: medium because the breadth of the isolation requirement needs confirmation.

`packages/contracts/src/Raffle.sol:593-604` asks only the immutable local factory's `isRaffle(destination)` mapping; the comments at lines 587-589 expressly describe same-factory plumbing. `packages/contracts/src/RaffleFactory.sol:154-168` likewise screens only its own mapping for configured prize tokens and sponsor recipients. The constructor's treasury exclusions are also local (`RaffleFactory.sol:65-91`). A clone created by a different deployment of this same immutable factory is not registered in the first factory's mapping. Under that condition, source checks do not categorically reject that clone as a configured quote recipient or another factory's raffle-ticket contract as a prize token.

Quote releases then transfer to the configured recipient (`Raffle.sol:375-391`, `564-567`); destination clones have no generic recovery method for excess external transfers. This can produce a transfer between clones or strand a voluntarily configured recipient claim, contrary to a literal global interpretation of the clean specification. It does not establish an attacker redirecting a correctly configured existing raffle, and it is not a defect if the specification means only clones registered by a single canonical factory.

The defensive property to clarify is whether asset destination isolation is intentionally local to a canonical deployment. If global isolation is intended, the present registry is insufficient evidence for that property.

## Per-file and property coverage

### packages/contracts/src/Raffle.sol — all 614 non-trailing source lines read

- Constructor and initialization (`151-206`): implementation is locked by initialized=true; factory and quote are bytecode immutables; clone initialization is one-time and factory-only. Assignments occur after destination/zero checks. A revert rolls back the early initialization flag. No configuration setter or upgrade route appears.
- ERC1167/reentrancy interaction (`176-206`, `209-237` with dependency ReentrancyGuard `88-114`): clones start with a zero guard slot, but the guard rejects only ENTERED=2, so first protected calls remain usable and set the normal idle value afterward. No constructor initialization requirement was incorrectly assumed for the clone guard.
- Purchase range and callback safety (`209-237`): only Active and pre-end purchases; positive uint128 entry count; total bound checked before addition. Quote collection precedes range/counter/pot writes, and all those writes precede _safeMint's untrusted recipient hook. All economic entry points use the same nonReentrant guard. An owner may transfer its freshly minted ticket during its receiver hook without changing its fixed range or adding unpaid entries. Hook failure rolls the whole purchase back. TicketCount cannot exceed totalEntries because every ticket requires at least one entry.
- Draw request (`240-273`): nonempty Active raffle; lower-inclusive and upper-exclusive interval; request state recorded before wrapper interaction; _requestInFlight excludes synchronous response before request ID persistence; ID persisted before clearing the flag. Native excess return failure rolls back the request transaction. Direct native transfers are rejected at `170-173`; forced excess native currency is not counted as USDC liability.
- Refund transition (`276-301`): nonempty Active at request deadline; Drawing at callback deadline; empty Active can close early only for sponsor and after end for anyone. Terminal states cannot move into refunds. Unsettled pot moves to refund liability exactly once.
- Settlement and current ownership (`303-346`, `533-558`, `579-585`): permissionless settlement checks only terminal state and inclusive historical range; terminal winningEntry is nonzero, so absent zero ranges cannot falsely pass. No ticket burns precede terminal winner settlement. Settlement locks its recorded ticket ID and allocates liabilities without ownership reads or external calls. Redemption authenticates current owner after optional settlement, then burns before delivery; failures unwind both optional settlement and redemption. Approvals are not accepted by the owner check. A previously settled ticket remains transferable until redemption.
- Refund claim (`349-372`): current owner only, 1..100 tickets, exact inclusive range amounts, all burns before quote transfer. Duplicate IDs fail ownerOf after the first burn and unwind the batch. No partial refund or double redemption path identified.
- Independent beneficiaries (`375-407`): sponsor and treasury amounts are zeroed independently before transfer and revert back on failure. Sponsor prize return is permitted only for CashWon or Refunding and is distinct from quote settlement. A failing prize transfer does not block independent quote claims; this also bounds what is guaranteed against an uncooperative prize.
- Prize receipt (`416-431`): exact configured token/id/from/operator and AwaitingPrize required; single successful callback activates the raffle. Factory verifies Active and reported ownership before creation returns. Factory nonReentrancy prevents recursive factory creation; callback-time clone calls cannot bypass their own state, payment, ownership, or reentrancy requirements. True ownership remains conditional on token honesty as L-01 explains.
- Transfer screening and callback (`497-524`, `593-604`): inherited ticket transfer paths call the overridden destination filter; burns allow zero destination. Wrapper authentication is inherited. Wrong request, in-flight, duplicate, wrong-length and deadline-or-later callbacks do not resolve. Accepted callback performs only bounded arithmetic, storage writes and event emission. One-based modulo result lies within totalEntries; Drawing cannot be reached with zero totalEntries through requestDraw. Callback makes no prize, recipient or quote call.
- Economics and limits (`458-475`, `533-558`): two fixed two-day deadlines; gross equals totalEntries * 1,000,000; aggregate protocol floor, cash floor and sponsor remainder sum to original unsettled pot. Values bounded by uint128 entries times fixed price fit uint256. Only a superficial secondary accounting pass was performed; the specialist focus was lifecycle/integration.

### packages/contracts/src/RaffleFactory.sol — all 186 non-trailing source lines read

- Constructor `65-92`: code checks for canonical token/wrapper, six-decimal quote metadata, immutable configuration, own locked implementation deployment, no mutable administrator. Metadata cannot establish canonical token identity, which is an explicit trusted deployment assumption.
- Creation `97-148`: validates duration and reserve, creates fixed-target clone, initializes in the same transaction, registers then transfers the exact prize, checks reported owner and Active status, emits after checks. Any failure reverts count, registry, clone deployment and token actions atomically. Registration before token call is transiently visible but no separate transaction can interleave; no demonstrated misuse of that visibility was found.
- Validation `154-185`: sponsor recipient, prize code/interface, reserve, and local plumbing exclusions inspected. Cross-factory limitation recorded as conditional L-02. Arbitrary ERC165 answers are not treated as proof of honesty.

### packages/contracts/src/interfaces/IRaffle.sol — all 521 non-trailing source lines read

- Enum and configuration `20-54`; all events/errors `56-301`; callable API `305-355`; timing/accounting views `357-390`; getters `392-520` compared against implementation.
- Current owner/burn/refund batch semantics, terminal result labels and exact exclusive deadlines are consistent with traced implementation.
- Honest-prize narrowing at `12-15` differs from the clean requirement's literal arbitrary-prize trust wording, recorded in L-01.
- A transfer or mint event recipient can cease to be current owner in the same transaction due to receiver-controlled transfer. Discovery remains advisory; current ownerOf governs claims. No frontend source was provided.

### packages/contracts/src/interfaces/IRaffleFactory.sol — all 150 non-trailing source lines read

- Constructor deployment assumptions `6-9`, create parameters `14-26`, event completion semantics `30-52`, validation errors `54-97`, and create/registry API `101-149` reconciled to implementation.
- Local registry describes canonical successful clones; it does not purport to enumerate clones created by other factories. Temporary registry reads inside creation do not themselves prove a persisted successful creation.

### packages/contracts/src/libraries/RaffleConstants.sol — all 43 non-trailing source lines read

- BPS=10,000; fee=500; cash=8,000; entry=1,000,000; decimals=6; batch=100; maximum sale=30 days; request/callback timeout=2 days each; callback gas=300,000; confirmations=30.
- Values match embedded specification where specified. No runtime gas adequacy measurement was performed.

## Dependency paths traced

- `@openzeppelin/contracts/proxy/Clones.sol:1-62`: used create-based clone path embeds immutable implementation target; deployment failure reverts. Unused deterministic/immutable-argument helpers were not needed for conclusions.
- `@openzeppelin/contracts/token/ERC721/ERC721.sol:1-433`: ownerOf, approval/transfer authorization, mint/update/burn, acceptance callback ordering, and nonexistent-token behavior read. TransferFrom prohibits zero destination, while internal burn intentionally writes zero owner and clears approval.
- `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:1-50`: recipient code check, callback selector, failure propagation. Receiving untrusted code is an explicit external call after mint ownership is written.
- `@openzeppelin/contracts/token/ERC721/IERC721.sol:1-135` and `IERC721Receiver.sol:1-28`: ordinary versus safe transfer semantics and callback contract.
- `@openzeppelin/contracts/utils/ReentrancyGuard.sol:1-119`, `StorageSlot.sol:1-105`, and `Context.sol:1-28`: namespaced guard storage, zero clone slot behavior, sender identity, and atomic protected paths.
- `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:1-280`: relevant safeTransfer and safeTransferFrom return/error behavior, especially `29-47`, `176-244`. Other convenience functions are unused by production contracts.
- `@openzeppelin/contracts/utils/math/Math.sol:1-65,190-280`: mul512 and floor mulDiv path; bounded production values take the non-overflow path. Other mathematical routines were not audited.
- `@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:1-118`: immutable wrapper/link metadata, native request pricing and wrapper-only rawFulfillRandomWords gate.
- `@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:1-83` and `libraries/VRFV2PlusClient.sol:1-27`: request ABI, prices, returned request ID, and native-payment extraArgs.
- Package metadata and foundry configuration were read as inert text: Solidity 0.8.36, Cancun, optimizer enabled at 200 runs, via_ir=false in default profile, declared OpenZeppelin 5.6.1 and Chainlink 1.5.0. The whole lockfile and incidental transitive libraries were loaded by the context parser but not semantically audited. No package script was executed.

## Gaps and limits

- No compile, tests, mutation testing, fuzzing, formal proofs, bytecode comparison, deployment verification, or gas measurement. This is qualitative source coverage only.
- No actual USDC, wrapper implementation, coordinator, chain state, approved deployment addresses, arbitrary prize implementation, ticket recipient code, or frontend was supplied. Those integration properties remain conditional.
- Arbitrary malicious prize honesty cannot be established from ERC165/callback/ownerOf answers. Failure rollback is supported by source; eventual successful delivery is not guaranteed.
- Intended global versus single-factory clone isolation requires human clarification. L-02 is conditional and includes configuration-induced loss, not an established unauthorized drain.
- Safe delivery acceptance is not checked on prize release because ordinary transferFrom is used. The specification does not expressly require receiver acceptance and the current winner initiates redemption, so this was not elevated to a separate defect. Sponsor recipient compatibility is likewise an external integration assumption.
- Recipient-selected permanent loss (lost keys, an incapable contract, or deliberate transfer to an unrelated sink), forced NFT/USDC/native donations, and token-level pause/blacklist behavior are not solved by the no-rescue design; no unsupported protocol-wide theft claim was inferred from those facts.
- All embedded file hashes were inventoried. Files listed as loaded only were not semantically reviewed merely because Python parsed the context containing them. Relevant used dependency paths above were reviewed; unused library surfaces and the full 15,674-line lockfile were not.
- Candidate severities and assumptions require human review. No candidate is automatically accepted by this response.

## Context and resource inventory

Recorded at: 2026-10-21T08:05:07.080734+00:00

Snapshot hash: `50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e`

Context hash: `2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142`

Exact context-file SHA256: `be731d11b76a20f5f2c1f9bd16317f407e1b5488b0355e9b1ad53538b1e75952`

- `audit/resources/START_HERE.md` — SHA256 `a4391cdbafbea7c963dd7881ce0251e96ca44a08124b830e5698e1f2a5c3cb36`; protocol resource, read in full.
- `audit/resources/agents/REVIEW.md` — SHA256 `6be0a96e138fbc86a9d3c80fbab38840b5ced20eddd2ec6aef087db937bda117`; protocol resource, read in full.
- `audit/resources/agents/response.schema.json` — SHA256 `91bbbc126a265d37789ab4e54a64fa0d3845d28e979faebbe8ac8e5d3d8ff240`; protocol resource, read in full.

Every embedded context resource below was loaded by JSON parsing and its path/hash inventoried. Semantic read coverage is separately stated above.

- `packages/contracts/foundry.toml` — `0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50`; exported lines 49.
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` — `f81ec96e909daa2cd27536274a30d916b26d5fc91261bed8d7a6a3e157f3825c`; exported lines 32.
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` — `a48aaaeaed60e65f04f6c8772e5673dda663dcfa7913fdadd14b412300b9d5f1`; exported lines 84.
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` — `f3b89bb466c2a79b10c1816d342fbfbec49fe82695cba92bd46e7d31af698011`; exported lines 28.
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` — `8cf045f295b8c6035d14012a9bc2e8ab2b5ce24749a199ca0190519c4bf2dcc0`; exported lines 119.
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol` — `fa7068f56bc180571a6095be6eaef06d51dbe81e30cb128397d993c9599ecc30`; exported lines 163.
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol` — `9c3a75a925a6dac9e88b03cddc58d42fe3131b0aaaad84408521f3f7af2f991b`; exported lines 87.
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol` — `dfb3f56fa928a7c6cae41a7ce2c86b9210fa18d33fa26389099d66a0fa790368`; exported lines 7.
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol` — `0158e2d3e0e28bedd99eec13dcf1a8aa3a70a5b7e4bb2ad709609c95fcc740d1`; exported lines 7.
- `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol` — `06c768a2b794ea59dd6d6c1bfe33cf5098a4a8921aec14cf066576a2bffafce6`; exported lines 295.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` — `0b7132f17d14d1d84b41b0bb429be62dafdff00fd3470f68724d8018eb07f57a`; exported lines 27.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol` — `01b6f5c4fa45fd38822b286ecef6daf983d27306dd6362496fa71b3e4600b72c`; exported lines 80.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` — `c2394cb2a327f234711da34884947f4aa0f6dd2791d1d6303a0c7acfaf81bca3`; exported lines 281.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` — `ef8e2398c78851bd2ec12bc48d923058c557889d5a3d5ee4919c17ff0fb3517e`; exported lines 434.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` — `33223782ea652dca413702ce92f9f59d91d758a035065b24bbedb7dc60c63a78`; exported lines 28.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol` — `ff0eb9902bf0ac099205615fac90eacf34fae637571b05aab3ea35dea53d5f17`; exported lines 136.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` — `eafee3ffdc7cb2fba4bf6bd16fb28f8e5b4679742e81c2ad42a1b1df5c179feb`; exported lines 29.
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` — `b48e95db8c85866c1d88af8e82f346e0d22d24b5aac5b936079d958c72e13b9f`; exported lines 51.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol` — `3ce9120a27934c75a074cb785d3a88868069ef6529dbe4dc6b845af0836f3c70`; exported lines 333.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol` — `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6`; exported lines 29.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol` — `9623aa59745a23a72f313adc5adbf583968bf366a7cbf3fc43c1148d7d2c3c86`; exported lines 92.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol` — `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66`; exported lines 35.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol` — `61a2b12c96857aaa35f48aeda67a4281637a42494c0b3795be0ae976aa7b3793`; exported lines 26.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol` — `9055c2994b37dea1a41b7b7926dcb510f05dbe2540b0aafc5fbee9558fffd0ca`; exported lines 26.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol` — `e128cbe9c6c406d5a42c26e4079c0a95b369ce552f2d0c3dfd2fcb836c5708f2`; exported lines 128.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol` — `bdfdbe133991c0c78042957ff5cd97167926fcaf6d15664f3835a076cb066457`; exported lines 764.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol` — `5779bc848bde39f1ad7bc02b4f708a0040888e0083b1a33f119cd94639350134`; exported lines 1163.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol` — `1ed50b1056af886752f0fb48a0165d381e69bb4a4b18b893b066dc144a7e08d7`; exported lines 69.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol` — `270fc8401c1a13fae6a7a4a2dd6e381b95d658896701e51f0d3e2688acab3dec`; exported lines 58.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` — `94e409e8f6e3184236651a6cc2b1a6a3ea0f0a25eb85b71e524ad5791bb2fbc8`; exported lines 120.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol` — `75704538dcb223239280c6726d9a31cf769a7816718517c997fc7d63bdb70778`; exported lines 144.
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol` — `e318709bbe73a7831d64c1351e8bdc43780b245f25191234e361e6ab9b98c67b`; exported lines 533.
- `packages/contracts/package.json` — `2f46b8f46ed3de275a3a6d097c86a888fece719151bdf4e171495dc12e6802ad`; exported lines 45.
- `packages/contracts/remappings.txt` — `cbf6730be9c6b6daa1855953ba581d96f14e2dbc3bc95ca3bc2d92cfd231acaa`; exported lines 3.
- `packages/contracts/src/interfaces/IRaffle.sol` — `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd`; exported lines 522.
- `packages/contracts/src/interfaces/IRaffleFactory.sol` — `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf`; exported lines 151.
- `packages/contracts/src/libraries/RaffleConstants.sol` — `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6`; exported lines 44.
- `packages/contracts/src/Raffle.sol` — `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617`; exported lines 615.
- `packages/contracts/src/RaffleFactory.sol` — `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace`; exported lines 187.
- `pnpm-lock.yaml` — `3c277879a07bda9a4bd9788b810a000b3cb58873fc84d515e4661e0a4ed422c4`; exported lines 15674.
