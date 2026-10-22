# FIRST PASS — native Gebal source-only review

Sealed review timestamp (UTC): `2026-10-21T08:08:25Z`  
Target revision supplied by operator: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`  
Gebal reviewed replacement revision: `9ad24645f92a3821ae4539db5f1be52b48ed379e`  
Native run: `a9a573ab-b66c-4d87-8ca0-1e7a5d5bcf78`  
Snapshot hash: `50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e`  
Context hash: `2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142`

This is the original cold source conclusion, recorded before native import, scanner/tool findings, peers, reconciliation, or adjudication. The only project evidence used was the exact authoritative Gebal context above. The controller's accepted local selection was `gpt-daybreak-blue-latest`, access program `daybreak_blue`, effort `ultra`, fallback disabled. Provider-returned model identity was absent and is recorded as `unknown`; no identity is inferred from the alias or self-description.

## Original conclusions

### FP-01 — High — An untrusted prize contract can fabricate both escrow and delivery

The clean requirements treat arbitrary prize contracts as untrusted, but admission checks only that the contract reports ERC-721 interface support. During `createRaffle`, the prize contract controls `safeTransferFrom`: it can invoke the clone receiver with the expected caller-supplied arguments without maintaining real ownership, and the factory then asks that same untrusted contract whether the clone owns the token. This can activate a raffle with no genuine escrow. On an NFT-winning redemption, the same contract can make `transferFrom` a no-op and report the winner from `ownerOf`; the raffle then retains `winnerRedeemed`/`prizeClaimed` and the ticket burn while no genuine NFT was delivered. A sponsor controlling such a token can sell entries and receive the NFT-outcome sponsor allocation without contributing an enforceable prize.

Evidence: `RaffleFactory.sol:127-134`, `RaffleFactory.sol:154-177`, `Raffle.sol:416-430`, `Raffle.sol:329-337`. Confidence: high. Assumptions: the stated untrusted-prize threat model includes false ERC-721 implementations; entrants may buy from the raffle; the contract can return self-consistent false interface/ownership results.

### FP-02 — Low — Clone-isolation filtering recognizes only raffles from the current factory

Destination screening asks only the raffle's immutable factory whether an address is one of its registered clones. A clone from another `RaffleFactory` is accepted as a sponsor recipient and can also be configured as a treasury. In a cash/refund branch, `releaseSponsorPrize` uses `transferFrom` and can move the prize into that other clone; quote-token releases also pass the factory-local screen and become unaccounted balances in the recipient clone, which has no rescue path. This supplies a concrete cross-clone asset path contrary to the stated isolation requirement, although the party selecting the destination bears the direct loss.

Evidence: `RaffleFactory.sol:154-169`, `Raffle.sol:395-406`, `Raffle.sol:560-566`, `Raffle.sol:587-604`. Confidence: medium. Assumptions: multiple factory deployments are possible and the isolation requirement spans them; a sponsor/deployer selects another deployment's clone; the prize follows ordinary ERC-721 transfer semantics.

### Leads not promoted to findings

- Because `Clones.clone` uses sequential `CREATE`, a code-free future clone address can plausibly pass initialization screening and later become a same-factory registered raffle. Runtime quote screening would then block a sponsor claim, while `releaseSponsorPrize` does not repeat destination screening. This temporal variant was not executed and remains a lead rather than an additional finding.
- Forced native currency and unrelated token/NFT donations can remain unaccounted and unrecoverable. No source-supported path was found by which that behavior spends an accounted claimant's balance under the trusted quote-token assumption.
- Modulo selection has the usual negligible modulo bias for a uniform 256-bit VRF word; no practically exploitable source-supported manipulation path was identified.

## Per-property coverage

| Property | Source-only conclusion | Evidence/limit |
|---|---|---|
| Fixed entry price and contiguous inclusive ranges | Covered; arithmetic and range updates are internally consistent | `Raffle.sol:209-236`; no execution |
| Exactly one prize escrowed atomically | Not satisfied for an untrusted prize implementation | FP-01 |
| Reserve met: NFT + 95% sponsor / 5% treasury | Covered for trusted token semantics; allocations conserve gross pot | `Raffle.sol:533-557` |
| Reserve missed: 80% winner / 15% sponsor / 5% treasury | Covered; winner and protocol round down, sponsor receives remainder | `Raffle.sol:540-555`, `Math.sol:200-276` |
| Refunds: 100% per entry and prize return | Quote liability math covered; malicious prize and cross-clone destination caveats remain | `Raffle.sol:276-300`, `348-371`, `395-406` |
| Request window `[end,end+2 days)` | Covered by strict lower/upper checks | `Raffle.sol:240-247`, `458-460` |
| Callback accepted strictly before request + 2 days | Covered; late callback is ignored | `Raffle.sol:509-523`, `463-465` |
| Callback records result only | Covered; callback performs storage writes/event only | `Raffle.sol:509-523` |
| Permissionless storage-only settlement | Covered; winning range validation then allocation only | `Raffle.sol:303-306`, `533-558` |
| Redemption by current ticket owner, atomic burn/delivery | Covered against ordinary tokens and reentrancy; not against a lying prize contract | `Raffle.sol:309-345`; FP-01 |
| Independent sponsor and treasury claims | Covered; balances are separately zeroed and transferred | `Raffle.sol:374-392` |
| Rounding without loss | Covered algebraically in source: sponsor is residual | `Raffle.sol:539-555`; no property execution |
| Clone isolation | Same-factory existing clones are screened; global and temporal isolation is incomplete | FP-02 and retained lead |
| No administrator/mutable configuration/upgrade | Covered in the five first-party files; clone target and core addresses are immutable | Factory/raffle constructors and absence of privileged setters |
| Bounded exits | Refund batch is capped at 100 and repeatable; external-token refusal/lying and selected sink addresses can block delivery | `RaffleConstants.sol:26-27`; findings/assumptions above |
| Frontend discovery is advisory | Not an onchain-enforceable property | No frontend or chain state in scope |

## Per-file coverage

| File | SHA-256 | First-pass coverage |
|---|---|---|
| `packages/contracts/src/Raffle.sol` | `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` | Complete line-by-line semantic review of lifecycle, accounting, callbacks, settlement, redemption, refunds, transfers, and sink filtering |
| `packages/contracts/src/RaffleFactory.sol` | `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` | Complete line-by-line semantic review of immutable setup, clone creation/registration, prize validation, and atomic escrow |
| `packages/contracts/src/interfaces/IRaffle.sol` | `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` | Complete interface/status/error/event/function-contract review; compared to implementation and requirements |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` | Complete interface/error/event/getter review; compared to implementation |
| `packages/contracts/src/libraries/RaffleConstants.sol` | `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` | Complete constants/economics/timing/bound review |
| `packages/contracts/foundry.toml` | `0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50` | Configuration read; `gas_reports` made native diagnosis unsupported; no profile executed |
| `packages/contracts/remappings.txt` | `cbf6730be9c6b6daa1855953ba581d96f14e2dbc3bc95ca3bc2d92cfd231acaa` | Remapping identity checked |
| `packages/contracts/package.json` | `2f46b8f46ed3de275a3a6d097c86a888fece719151bdf4e171495dc12e6802ad` | Direct dependency versions and scripts inspected; scripts not executed |
| `pnpm-lock.yaml` | `3c277879a07bda9a4bd9788b810a000b3cb58873fc84d515e4661e0a4ed422c4` | Lock identity captured; selected Chainlink 1.5.0/OpenZeppelin 5.6.1 entries checked, not a line-by-line audit of unrelated lock entries |
| `.../@chainlink/.../LinkTokenInterface.sol` | `f81ec96e909daa2cd27536274a30d916b26d5fc91261bed8d7a6a3e157f3825c` | Full interface read; LINK request path is not used |
| `.../@chainlink/.../IVRFV2PlusWrapper.sol` | `a48aaaeaed60e65f04f6c8772e5673dda663dcfa7913fdadd14b412300b9d5f1` | Full wrapper interface read; native request/price methods reviewed |
| `.../@chainlink/.../VRFV2PlusClient.sol` | `f3b89bb466c2a79b10c1816d342fbfbec49fe82695cba92bd46e7d31af698011` | Full captured client library read; native-payment extra-argument encoding reviewed |
| `.../@chainlink/.../VRFV2PlusWrapperConsumerBase.sol` | `8cf045f295b8c6035d14012a9bc2e8ab2b5ce24749a199ca0190519c4bf2dcc0` | Full base read; wrapper-only callback and native request behavior reviewed |
| `.../@openzeppelin/.../Clones.sol` | `06c768a2b794ea59dd6d6c1bfe33cf5098a4a8921aec14cf066576a2bffafce6` | Reachable `clone`/CREATE implementation reviewed; deterministic helpers not independently analyzed |
| `.../@openzeppelin/.../SafeERC20.sol` | `c2394cb2a327f234711da34884947f4aa0f6dd2791d1d6303a0c7acfaf81bca3` | Reachable transfer and transferFrom behavior reviewed |
| `.../@openzeppelin/.../ERC721.sol` | `ef8e2398c78851bd2ec12bc48d923058c557889d5a3d5ee4919c17ff0fb3517e` | Reachable ownership/update/mint/burn/transfer behavior reviewed |
| `.../@openzeppelin/.../ERC721Utils.sol` | `b48e95db8c85866c1d88af8e82f346e0d22d24b5aac5b936079d958c72e13b9f` | Receiver check reviewed |
| `.../@openzeppelin/.../ReentrancyGuard.sol` | `94e409e8f6e3184236651a6cc2b1a6a3ea0f0a25eb85b71e524ad5791bb2fbc8` | Guard storage/modifier and clone-zero initialization behavior reviewed |
| `.../@openzeppelin/.../Math.sol` | `bdfdbe133991c0c78042957ff5cd97167926fcaf6d15664f3835a076cb066457` | Reachable floor `mulDiv` reviewed |
| `.../@openzeppelin/contracts/interfaces/draft-IERC6093.sol` | `fa7068f56bc180571a6095be6eaef06d51dbe81e30cb128397d993c9599ecc30` | Captured/import linkage; no independent semantic review beyond reachable error behavior |
| `.../@openzeppelin/contracts/interfaces/IERC1363.sol` | `9c3a75a925a6dac9e88b03cddc58d42fe3131b0aaaad84408521f3f7af2f991b` | Captured/import linkage only |
| `.../@openzeppelin/contracts/interfaces/IERC165.sol` | `dfb3f56fa928a7c6cae41a7ce2c86b9210fa18d33fa26389099d66a0fa790368` | Captured/import linkage only |
| `.../@openzeppelin/contracts/interfaces/IERC20.sol` | `0158e2d3e0e28bedd99eec13dcf1a8aa3a70a5b7e4bb2ad709609c95fcc740d1` | Captured/import linkage only |
| `.../@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` | `0b7132f17d14d1d84b41b0bb429be62dafdff00fd3470f68724d8018eb07f57a` | Decimals interface behavior reviewed |
| `.../@openzeppelin/contracts/token/ERC20/IERC20.sol` | `01b6f5c4fa45fd38822b286ecef6daf983d27306dd6362496fa71b3e4600b72c` | Interface behavior used by SafeERC20 reviewed |
| `.../@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` | `33223782ea652dca413702ce92f9f59d91d758a035065b24bbedb7dc60c63a78` | Captured/import linkage only |
| `.../@openzeppelin/contracts/token/ERC721/IERC721.sol` | `ff0eb9902bf0ac099205615fac90eacf34fae637571b05aab3ea35dea53d5f17` | Relevant ownership/transfer/interface contract reviewed |
| `.../@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` | `eafee3ffdc7cb2fba4bf6bd16fb28f8e5b4679742e81c2ad42a1b1df5c179feb` | Receiver selector/contract reviewed |
| `.../@openzeppelin/contracts/utils/Context.sol` | `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` | Captured/import linkage only |
| `.../@openzeppelin/contracts/utils/Errors.sol` | `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66` | Captured deployment-error linkage only |
| `.../@openzeppelin/contracts/utils/introspection/ERC165.sol` | `61a2b12c96857aaa35f48aeda67a4281637a42494c0b3795be0ae976aa7b3793` | Captured/import linkage only |
| `.../@openzeppelin/contracts/utils/introspection/IERC165.sol` | `9055c2994b37dea1a41b7b7926dcb510f05dbe2540b0aafc5fbee9558fffd0ca` | Relevant interface-ID query contract reviewed |
| `.../@openzeppelin/contracts/utils/StorageSlot.sol` | `75704538dcb223239280c6726d9a31cf769a7816718517c997fc7d63bdb70778` | Reentrancy-guard storage linkage reviewed |
| `.../@openzeppelin/contracts/utils/Bytes.sol` | `3ce9120a27934c75a074cb785d3a88868069ef6529dbe4dc6b845af0836f3c70` | Captured transitive helper; not independently semantically audited |
| `.../@openzeppelin/contracts/utils/Create2.sol` | `9623aa59745a23a72f313adc5adbf583968bf366a7cbf3fc43c1148d7d2c3c86` | Captured transitive helper; deterministic clone path unused |
| `.../@openzeppelin/contracts/utils/LowLevelCall.sol` | `e128cbe9c6c406d5a42c26e4079c0a95b369ce552f2d0c3dfd2fcb836c5708f2` | Captured transitive helper; not independently semantically audited |
| `.../@openzeppelin/contracts/utils/Panic.sol` | `270fc8401c1a13fae6a7a4a2dd6e381b95d658896701e51f0d3e2688acab3dec` | Reachable Math panic behavior noted |
| `.../@openzeppelin/contracts/utils/SafeCast.sol` | `5779bc848bde39f1ad7bc02b4f708a0040888e0083b1a33f119cd94639350134` | Captured transitive helper; relevant default-rounding path does not call it |
| `.../@openzeppelin/contracts/utils/SignedMath.sol` | `1ed50b1056af886752f0fb48a0165d381e69bb4a4b18b893b066dc144a7e08d7` | Captured transitive helper; not independently semantically audited |
| `.../@openzeppelin/contracts/utils/Strings.sol` | `e318709bbe73a7831d64c1351e8bdc43780b245f25191234e361e6ab9b98c67b` | Captured ERC-721 transitive helper; ticket URI is not overridden/used |

## Native and execution limits at seal time

- Gebal source-only intake: `SUCCEEDED`, 40 authorized files.
- Own-model source review: `COMPLETED` in the selected controller session; original inert JSON is `artifacts/reviews/original-review.controller.json`.
- Fresh exact-selection CLI specialist: `BLOCKED` before any response by sandbox DNS/network denial; raw JSONL/stderr preserved.
- Compiler, Foundry tests, fuzz/invariants, Slither, and other tool execution: `BLOCKED/NOT RUN`.
- Test-inclusive native plan: not created because Gebal doctor reported Docker unavailable and tool image not configured, exactly as the conditional workflow required.
- No target files were modified and no host project tools, live chain, deployment, transaction, publication, or service purchase was used.

The SHA-256 seal for this document, the original review JSON, and the authoritative context is recorded in `SEAL.json`. Any later correction or reconciliation must be append-only and must not alter this file or the sealed original JSON.
