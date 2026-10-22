# Independent supplementary accounting review — original response

## Provenance and assumptions recorded before conclusions

This is an independent supplementary source review of `audit/context.json`, not a Gebal native automatic specialist stage. The only project source used is the content embedded in that context. The review instructions read in full were `audit/resources/START_HERE.md`, `audit/resources/agents/REVIEW.md`, and `audit/resources/agents/response.schema.json`. No assessed repository, target files outside the context, peer output, scanner result, audit history, or generated report was consulted. No compiler, tests, prover, exploit, transaction, browser, or assessed-project script was run. Local operations were restricted to reading the provided inert data and authoring/hashing review artifacts.

The operator requested `gpt-6-astra`, reasoning `ultra`, fallback disabled. Provider-returned model identity is unknown; this review cannot independently attest to model identity, settings, usage, or cost. This response reports no execution or measured coverage.

Snapshot: `50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e`.

Context: `2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142`.

The following assumptions precede and qualify every conclusion:

1. The exported clean specification is the requested behavior: 1,000,000 quote units per entry, one contiguous inclusive range per ticket, 95/5 NFT-result allocation or 80/15/5 cash-result allocation, 100% refunds, owner-only atomic redemption, permissionless storage-only settlement, separate sponsor/treasury claims, immutable implementation/configuration, and no asset transfers between raffle clones.
2. The quote token and wrapper are the correctly selected canonical trusted contracts, as the requirements stipulate. For accounting, quote transfers debit and credit the exact amount without rebasing, transfer fees, or fabricated success. Six-decimal metadata alone does not establish that trust. Their live implementations and deployed addresses are absent.
3. Ordinary EVM transaction rollback and CREATE semantics apply; timestamps are normal Ethereum timestamps representable in uint64. Addresses without code are not guaranteed to remain without code. In particular, a future factory CREATE address can subsequently become a registered clone without changing an earlier raffle's stored recipient.
4. Arbitrary prize contracts and ticket recipients are untrusted. ERC165 support and `ownerOf` are claims made by the prize contract. The interface's additional statement that supported prizes are honest, standards-compliant ERC721s (`IRaffle.sol:10-15`) is a narrower model than the clean requirements. Universal future NFT delivery is therefore not assumed. Any safety conclusion based on correct ERC721 behavior is expressly conditional.
5. Bounded refund liveness means each holder can submit a finite bounded ticket batch without iterating over all buyers or waiting for another recipient's asset transfer. It does not mean the system can force an arbitrary external token or an unreachable owner to act.
6. The specification's isolation rule applies at least to canonical clones from the same factory. The observation below requires only that narrower interpretation. No assumption that all factories share a global registry is made.
7. A sponsor can choose a recipient they do not control; no proof of recipient ownership is required in the supplied source. User configuration can therefore affect the user's own claim liveness. Severity below reflects this rather than claiming theft from unrelated raffles.

## Observation A1: A recipient accepted before deployment can later be a raffle clone, stranding sponsor assets

Severity: **medium**. Confidence: **high** in the source-level behavior; practical frequency is unknown. Human disposition: needs review.

The sponsor recipient is screened only against the current factory registry when the raffle is created (`packages/contracts/src/RaffleFactory.sol:154-169`), and again during initialization (`packages/contracts/src/Raffle.sol:187-205`). The helper explicitly does not query code-less destinations (`Raffle.sol:593-604`). A code-less address that later becomes another same-factory raffle is consequently a possible immutable recipient of an already existing raffle. `Clones.clone` uses CREATE (`packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:32-62`), and the factory registers each newly created address (`RaffleFactory.sol:105-125`); the source does not reserve future addresses against existing recipients.

In a cash or refund outcome, `releaseSponsorPrize` reads this earlier accepted recipient and calls the prize token's ordinary `transferFrom` without rechecking the current destination (`Raffle.sol:395-406`). For an ordinary ERC721 this can transfer the first raffle's escrowed prize to the second raffle even though the specification prohibits assets moving between clones. A successful `ownerOf` check then marks the first raffle's prize as claimed. The receiving raffle has no generic NFT recovery function and only releases its own configured prize, so the extra prize is outside its claims. The receiver hook cannot prevent this ordinary transfer; the source itself describes unrelated NFTs sent by unsafe transfer as unrecoverable (`Raffle.sol:409-411`), and the dependency interface warns about this distinction (`IERC721.sol:75-91`).

The quote branch has the related liveness consequence: `releaseSponsorProceeds` ultimately reruns `_isProtocolDestination` (`Raffle.sol:375-381,564-566,593-604`), so once the immutable recipient becomes a registered clone, sponsor proceeds revert on every claim and there is no alternate recipient or configuration update. This is not quote-accounting inflation or unauthorized extraction; the claim remains recorded because the failing call rolls back. It is an immutable-recipient validation gap with an NFT isolation breach and a cash exit failure.

Assumptions specific to A1: the sponsor chooses an initially code-less address later occupied by a canonical clone; that clone is created before the affected sponsor asset is released; the original prize follows ordinary ERC721 `transferFrom` and truthful ownership behavior; the destination clone's own configured prize differs from the extra prize. No malicious quote token or prize behavior is needed. No exploit code, transactions, deployment addresses, or execution evidence were constructed.

Defensive property for owner review: every protocol-initiated prize delivery must apply the current destination-isolation policy, and an immutable recipient that later becomes disallowed must not render an otherwise valid sponsor claim permanently unreachable. A design decision is needed for the latter property because simply adding a check to prize release prevents the transfer but leaves the immutable claim blocked.

## Per-file and per-property source coverage

These are manual source checks, not measured test or proof coverage.

### `packages/contracts/src/Raffle.sol` — all 614 non-final-empty lines reviewed

- **Fixed-price accounting and entry coverage, lines 209-237, 468-475:** successful purchases transfer `entryCount * 1_000_000` before increasing `unsettledPot`; the transaction reverts if mint acceptance fails. Positive counts and the total-entry capacity check give disjoint contiguous ranges starting at 1. Since each ticket represents at least one entry, `ticketCount <= totalEntries <= uint128.max`, so the ticket counter cannot overflow on a purchase whose entry capacity check succeeds. Gross quote value is below 2^148, well inside uint256.
- **Conservation and rounding, lines 533-557:** settlement takes the recorded pot, computes aggregate floor fees, allocates cash only in CashWon, assigns the complete remainder to the sponsor, and zeroes the pot once. Under the quote assumption, NFT allocation sums to gross and cash allocation sums to gross. Because every purchase contributes a multiple of 1,000,000, the current 500 and 8,000 bps allocations divide exactly; the remainder formula also conserves value for arbitrary gross values. Direct unsolicited token transfers do not increase liabilities or fees.
- **Refund partition, lines 276-301, 349-371:** a state transition moves the whole unsettled pot into refund liability without asset calls. Batches contain 1–100 tickets, read the current owner, compute inclusive range length, burn each ticket, and subtract exactly that many entry prices. Duplicate or nonexistent IDs fail `ownerOf`, reverting the batch. Burned range history cannot be used twice because ownership no longer exists. A single-ticket refund does not depend on the population of all entrants.
- **Winner ownership and atomicity, lines 309-345:** settlement may be bundled, but current ownership is checked before burn. Approved operators cannot directly redeem. Redemption marks state and burns before the external delivery. Reverting token delivery or an incorrect reported NFT owner reverts the burn, flags, and any bundled settlement. Cash liabilities are cleared before transfer, with transaction rollback on failure. The winning claim can be transferred before redemption because settlement records the ticket rather than a fixed winner address.
- **Independent claims, lines 304-306, 375-406:** settlement does not deliver an asset, so sponsor and treasury allocations are independent of successful winner delivery. Sponsor/treasury balances are separately zeroed and separately transferred. Refunds do not wait for prize return. Prize return is available in CashWon or Refunding without consuming cash claims. A1 qualifies recipient safety and liveness.
- **Deadline boundaries, lines 240-300, 458-464, 509-523:** draws require `endTime <= now < endTime + 2 days`; callbacks require Drawing, matching persisted request, one word, no in-flight request, and `now < drawRequestedAt + 2 days`. Refund transitions become available at the complementary deadline. Drawing requires nonzero total entries, so accepted modulo selection has a nonzero divisor and produces [1,totalEntries]. Resolved states cannot later switch to refunds. No population-dependent loop occurs in callback or settlement.
- **Native fee handling, lines 240-272:** only the request path accepts ordinary native payments. The inherited helper pays its quoted amount; the function checks the actual paid price against msg.value and returns only excess from that call. A failure to return excess reverts the whole request. Another caller can request, or the caller can submit an exact fee. Forced native balances have no withdrawal path, but are not taken into raffle quote accounting.
- **Initialization and clone state, lines 151-205:** the implementation locks its own initialization; clone storage is separate and initialized once by the immutable factory. Mutable-looking per-raffle fields have no later setter. The constructor's factory and quote immutables are embedded in the shared implementation. Deadline/reserve input checks are supplied by the sole caller, the factory.
- **Receiver and adversarial callbacks, lines 416-430, 497-523:** prize activation is restricted to the exact configured token/id/from/operator and AwaitingPrize state. Ticket transfers pass the protocol-destination filter. Mint callbacks run after range and pot state are established while guarded lifecycle operations remain nonreentrant. Inherited ticket transfers may occur inside the recipient callback; this does not itself duplicate entries or liabilities. Authenticated malformed-length/late/wrong-request callbacks are ignored. Callback ABI decoding can still revert before the handler, as documented.
- **External token limits, lines 329-342, 395-406, 564-566:** SafeERC20 protects against call-level failures but cannot establish truthful balances for an untrusted quote token, which is outside the stated quote trust model. An untrusted prize can refuse delivery or falsely report ownership. Atomic rollback is enforced for detectable delivery failure; ultimate NFT delivery is not established.

### `packages/contracts/src/RaffleFactory.sol` — all 186 non-final-empty lines reviewed

- **Immutability, lines 25-54,65-92:** quote, wrapper, treasury, implementation, callback gas, and confirmations have no mutation entrypoint. No owner, upgrade, rescue, fee setter, or external arbitrary-call function appears in this production file. The implementation is created directly and fixed.
- **Dependency screening, lines 65-90:** token and wrapper require code; quote token requires six-decimal metadata. These checks do not authenticate canonical identity. The wrapper constructor calls `link()` through the included Chainlink base.
- **Atomic creation, lines 97-147:** parameter validation, clone creation, initialization, registry writes, prize transfer, final reported ownership, and Active state checks all belong to one transaction. A detectable failure rolls back registration and the count. Registration precedes the external prize transfer, so current destination checks can recognize the newly deployed clone. The factory is nonreentrant, including during the untrusted prize's transfer. Prize code can still make calls into other contracts; no global exclusion is inferred.
- **Parameters, lines 154-178:** reserve must be positive, end time is strictly future and at most 30 days, selected destinations avoid current known protocol sinks, and the prize reports ERC721 support. A1 records the later-address-change gap. ERC165 and `ownerOf` checks are not a proof of an honest future prize contract.

### `packages/contracts/src/interfaces/IRaffle.sol` — all 521 non-final-empty lines reviewed

- Checked statuses, initialization inputs, events, error definitions, and all declared functions/getters against implementation.
- Accounting and ownership semantics at lines 10-15,64-79,115-128,147-171,326-355,383-390,450-480 match the code under the stated token assumptions.
- Request and callback boundaries at lines 316-324,375-381 match the implementation; refunds explicitly allow an empty raffle to close early for its sponsor.
- The declared honest-prize restriction at lines 14-15 is narrower than the requirement's untrusted-prize wording. This conflict is recorded as a gap rather than silently treating comments as authoritative or claiming universal NFT liveness.

### `packages/contracts/src/interfaces/IRaffleFactory.sol` — all 150 non-final-empty lines reviewed

- Checked initialization inputs, canonical getters, register/count mapping semantics, no administration entrypoints, and documented constructor metadata limits at lines 7-9.
- The creation event and final checks correspond for compliant prizes. The `isRaffle` notice at lines 136-139 concerns successful completed creations; intermediate reads during an untrusted prize call can see the pre-transfer registration, with the whole transaction reverting on detectable failure. Frontend discovery is therefore advisory as required, but frontend transaction decisions are not present in scope.

### `packages/contracts/src/libraries/RaffleConstants.sol` — all 43 non-final-empty lines reviewed

- Lines 12-24 set BPS=10,000, fee=500, winner=8,000, price=1,000,000, decimals=6.
- Lines 27-42 set maximum refund batch=100, sale duration=30 days, both liveness windows=2 days, callback gas=300,000, confirmations=30.
- Constants agree with the supplied arithmetic and timing requirements. Actual callback gas sufficiency and chain-specific wrapper parameter acceptance were not measured.

## Pertinent dependency behavior checked

- OpenZeppelin `ERC721.sol`, complete: current ownership, approvals, `_update`, mint and burn, safe-receiver calls, and rollback-compatible flow. `_burn` has no caller check itself, so the raffle's explicit owner checks are material. All externally reachable transfer/mint/burn paths dispatch through the raffle override. Name/symbol are overridden in the raffle and do not depend on clone constructor storage.
- `ERC721Utils.sol`, complete: safe mint/transfer checks only deployed code and reverts on recipient refusal. Ordinary prize `transferFrom` does not invoke this helper.
- `IERC721.sol`, `IERC721Receiver.sol`, `IERC20.sol`, `IERC20Metadata.sol`, complete: the relevant APIs and safe versus ordinary transfer semantics.
- `SafeERC20.sol`, complete: `safeTransfer`/`safeTransferFrom` propagate reverts and reject false returns, while permitting no-return calls to contracts. The raffle does not use approval-changing or ERC1363 helper functions.
- `ReentrancyGuard.sol`, complete, with `StorageSlot.sol:1-106`: the clone's initial zero guard slot is accepted because only ENTERED=2 is rejected; first entry sets 2 and exit sets 1. Constructor nonexecution on clones therefore does not disable the guard or lock the first call. The guard's dedicated slot is separate for each delegatecall context.
- `Clones.sol:1-90`: the called clone function and CREATE assembly embed a fixed implementation. Remaining deterministic/immutable-args variants are not called and were not reviewed in depth.
- `Math.sol:1-52,190-300`: `mulDiv` floors; the relevant product is already below uint256 under total-entry bounds, so the simple division branch is sufficient for these allocations. Other general-purpose Math APIs and unused branches are not independently audited.
- Chainlink `VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`, complete: native request pricing/payment, direct request ID return, immutable wrapper authorization for `rawFulfillRandomWords`, and native extra-args encoding. The wrapper implementation, coordinator, billing state, and live config are absent. LINK requests are inherited internal helpers unused by the raffle's public flow.
- OpenZeppelin `Context.sol` and `ERC165.sol`, complete: msg.sender identity and standard interface reporting. Other dependency resources are inventoried as supplied, not claimed fully audited.
- `foundry.toml`, `package.json`, and `remappings.txt`, complete: compiler 0.8.36, Cancun, optimization, and package pins inspected as inert data. Relevant `pnpm-lock.yaml` importer and package entries were inspected and show direct OpenZeppelin 5.6.1 and Chainlink 1.5.0 pins. No package script or configuration was executed.

## Remaining gaps and limits

1. No compilation, tests, invariant execution, gas measurement, static analyzer, bytecode comparison, deployment inspection, or formal proof. Source checks are not a security certificate.
2. The actual canonical quote token and wrapper implementations, chain addresses, blocklisting/pause behavior, wrapper configuration, callback gas demand, and official deployment identity are absent or unverified. Metadata and interfaces cannot establish them.
3. An arbitrary prize contract can refuse later transfer or fabricate both escrow and delivery ownership reports. In the NftWon state a detectable failed delivery rolls back, preserving the ticket, but `enableRefunds` cannot open from that final state. Sponsor/treasury claims remain independent of delivery by design. Whether a terminal fallback for permanently undeliverable prizes is required is unresolved; the clean specification's untrusted-prize model and IRaffle's honest-prize support statement must be reconciled. This is not elevated into a separate unconditional defect because the requested behavior explicitly requires rollback on delivery failure without defining such a fallback.
4. Claims depend on owners being able to act and on token transfers succeeding. Arbitrary recipient contracts may lack the ability to redeem or transfer their tickets, and fixed treasury/sponsor recipients may be unsuitable. A1 identifies a protocol-specific change in destination classification; generic misconfigured recipients are not presented as unrelated-asset theft.
5. Frontend discovery and rereading state before transactions cannot be assessed: no frontend source is supplied. Indexer event handling and wallet UX are likewise outside this review.
6. Dependency review concentrated on reachable behavior. The full lockfile dependency graph and unused general utility routines were not audited; every embedded resource is listed below with its supplied hash to distinguish availability from semantic coverage.
7. Timestamp edge cases beyond ordinary Ethereum ranges, source-to-deployed-bytecode identity, and future compiler/runtime changes are unverified. No external source was consulted.

The original schema response below contains one candidate observation and these limitations. Findings remain unaccepted and require human review. No substantive conclusions were transmitted to peer reviewers before saving and sealing this response.


## Artifact timestamp and complete loaded-resource inventory

Original response finalized at 2026-10-21T08:05:34.570281+00:00. All embedded resources were loaded as part of parsing the authoritative context; semantic review depth is specified above. This inventory does not imply all dependencies were audited.

- `audit/resources/START_HERE.md`: `a4391cdbafbea7c963dd7881ce0251e96ca44a08124b830e5698e1f2a5c3cb36` (review-protocol)
- `audit/resources/agents/REVIEW.md`: `6be0a96e138fbc86a9d3c80fbab38840b5ced20eddd2ec6aef087db937bda117` (review-protocol)
- `audit/resources/agents/response.schema.json`: `91bbbc126a265d37789ab4e54a64fa0d3845d28e979faebbe8ac8e5d3d8ff240` (review-protocol)
- `audit/context.json`: `be731d11b76a20f5f2c1f9bd16317f407e1b5488b0355e9b1ad53538b1e75952` (authoritative-context-container)
- `packages/contracts/foundry.toml`: `0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50` (embedded-source)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol`: `f81ec96e909daa2cd27536274a30d916b26d5fc91261bed8d7a6a3e157f3825c` (embedded-source)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol`: `a48aaaeaed60e65f04f6c8772e5673dda663dcfa7913fdadd14b412300b9d5f1` (embedded-source)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol`: `f3b89bb466c2a79b10c1816d342fbfbec49fe82695cba92bd46e7d31af698011` (embedded-source)
- `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`: `8cf045f295b8c6035d14012a9bc2e8ab2b5ce24749a199ca0190519c4bf2dcc0` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol`: `fa7068f56bc180571a6095be6eaef06d51dbe81e30cb128397d993c9599ecc30` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol`: `9c3a75a925a6dac9e88b03cddc58d42fe3131b0aaaad84408521f3f7af2f991b` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol`: `dfb3f56fa928a7c6cae41a7ce2c86b9210fa18d33fa26389099d66a0fa790368` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol`: `0158e2d3e0e28bedd99eec13dcf1a8aa3a70a5b7e4bb2ad709609c95fcc740d1` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol`: `06c768a2b794ea59dd6d6c1bfe33cf5098a4a8921aec14cf066576a2bffafce6` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol`: `0b7132f17d14d1d84b41b0bb429be62dafdff00fd3470f68724d8018eb07f57a` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol`: `01b6f5c4fa45fd38822b286ecef6daf983d27306dd6362496fa71b3e4600b72c` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol`: `c2394cb2a327f234711da34884947f4aa0f6dd2791d1d6303a0c7acfaf81bca3` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol`: `ef8e2398c78851bd2ec12bc48d923058c557889d5a3d5ee4919c17ff0fb3517e` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol`: `33223782ea652dca413702ce92f9f59d91d758a035065b24bbedb7dc60c63a78` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol`: `ff0eb9902bf0ac099205615fac90eacf34fae637571b05aab3ea35dea53d5f17` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol`: `eafee3ffdc7cb2fba4bf6bd16fb28f8e5b4679742e81c2ad42a1b1df5c179feb` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol`: `b48e95db8c85866c1d88af8e82f346e0d22d24b5aac5b936079d958c72e13b9f` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol`: `3ce9120a27934c75a074cb785d3a88868069ef6529dbe4dc6b845af0836f3c70` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol`: `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol`: `9623aa59745a23a72f313adc5adbf583968bf366a7cbf3fc43c1148d7d2c3c86` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol`: `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol`: `61a2b12c96857aaa35f48aeda67a4281637a42494c0b3795be0ae976aa7b3793` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol`: `9055c2994b37dea1a41b7b7926dcb510f05dbe2540b0aafc5fbee9558fffd0ca` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol`: `e128cbe9c6c406d5a42c26e4079c0a95b369ce552f2d0c3dfd2fcb836c5708f2` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol`: `bdfdbe133991c0c78042957ff5cd97167926fcaf6d15664f3835a076cb066457` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol`: `5779bc848bde39f1ad7bc02b4f708a0040888e0083b1a33f119cd94639350134` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol`: `1ed50b1056af886752f0fb48a0165d381e69bb4a4b18b893b066dc144a7e08d7` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol`: `270fc8401c1a13fae6a7a4a2dd6e381b95d658896701e51f0d3e2688acab3dec` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol`: `94e409e8f6e3184236651a6cc2b1a6a3ea0f0a25eb85b71e524ad5791bb2fbc8` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol`: `75704538dcb223239280c6726d9a31cf769a7816718517c997fc7d63bdb70778` (embedded-source)
- `packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol`: `e318709bbe73a7831d64c1351e8bdc43780b245f25191234e361e6ab9b98c67b` (embedded-source)
- `packages/contracts/package.json`: `2f46b8f46ed3de275a3a6d097c86a888fece719151bdf4e171495dc12e6802ad` (embedded-source)
- `packages/contracts/remappings.txt`: `cbf6730be9c6b6daa1855953ba581d96f14e2dbc3bc95ca3bc2d92cfd231acaa` (embedded-source)
- `packages/contracts/src/interfaces/IRaffle.sol`: `a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd` (embedded-source)
- `packages/contracts/src/interfaces/IRaffleFactory.sol`: `747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf` (embedded-source)
- `packages/contracts/src/libraries/RaffleConstants.sol`: `0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6` (embedded-source)
- `packages/contracts/src/Raffle.sol`: `6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617` (embedded-source)
- `packages/contracts/src/RaffleFactory.sol`: `d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace` (embedded-source)
- `pnpm-lock.yaml`: `3c277879a07bda9a4bd9788b810a000b3cb58873fc84d515e4661e0a4ed422c4` (embedded-source)

## Exact original schema response

```json
{
  "schemaVersion": 1,
  "snapshotHash": "50f9efb6b671450adc50c493c35692429d5dc4b5ded6d7b123a79df21361cc0e",
  "contextHash": "2df5cb1e4b5b8f0f3c0663ef5fb41a1a3a2d12ed2304560034c3a691cfa80142",
  "review": {
    "observations": [
      {
        "title": "A future raffle address can pass immutable recipient validation and later strand sponsor assets",
        "description": "Sponsor-recipient validation uses the current registry during creation and initialization. A recipient with no code can later become another same-factory clone: the helper skips registry lookup for code-less destinations, while the factory deploys clones using CREATE and registers them. In CashWon or Refunding, releaseSponsorPrize transfers the configured NFT to the immutable sponsorRecipient without rechecking its current protocol-destination status. For a compliant prize this allows the original raffle NFT to move into a later canonical clone, violating clone isolation and leaving an unrelated prize outside the receiving clone's configured claims with no rescue path. The original raffle then records the prize as claimed. Sponsor quote proceeds have a related exit failure because _transferQuote does recheck the now-registered recipient and always reverts; the recipient cannot be changed. The condition requires an initially accepted address later occupied by a canonical clone and affects that configured sponsor's own assets, not arbitrary balances of unrelated raffles. Defensive property: validate current destination isolation on every asset delivery and define a reachable claim path when an immutable recipient later becomes disallowed. Source-only reasoning; no exploit or execution evidence.",
        "severity": "medium",
        "confidence": "high",
        "source": [
          {
            "path": "packages/contracts/src/RaffleFactory.sol",
            "start": 105,
            "end": 125
          },
          {
            "path": "packages/contracts/src/RaffleFactory.sol",
            "start": 154,
            "end": 169
          },
          {
            "path": "packages/contracts/src/Raffle.sol",
            "start": 187,
            "end": 205
          },
          {
            "path": "packages/contracts/src/Raffle.sol",
            "start": 375,
            "end": 411
          },
          {
            "path": "packages/contracts/src/Raffle.sol",
            "start": 564,
            "end": 566
          },
          {
            "path": "packages/contracts/src/Raffle.sol",
            "start": 593,
            "end": 604
          },
          {
            "path": "packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol",
            "start": 32,
            "end": 62
          },
          {
            "path": "packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol",
            "start": 75,
            "end": 91
          }
        ],
        "assumptions": [
          "The requirement that assets never move between raffle clones includes canonical clones of the same factory.",
          "The sponsor selects an initially code-less recipient address that is later occupied by another canonical factory clone before the affected sponsor assets are released.",
          "The prize follows ordinary ERC721 transferFrom semantics and reports ownership truthfully; no malicious quote token or prize implementation is required.",
          "The destination clone has a different configured prize and cannot recover the unrelated NFT through its normal prize-release function.",
          "Severity reflects recipient-dependent loss of the configured sponsor assets; no theft of unrelated clone balances is claimed."
        ]
      }
    ],
    "gaps": [
      "Source-only independent supplementary review, not a Gebal native specialist stage. No assessed code, compiler, test, prover, analyzer, generated exploit, transaction, browser, or project script was executed. Manual per-file/property coverage is recorded in RAW.md and is not measured verification coverage.",
      "Only audit/context.json supplied project evidence. All five production files were reviewed; pertinent dependency behavior was inspected. Unused utility routines and the full lockfile graph were not audited.",
      "Canonical quote-token and wrapper implementation/deployment identity, runtime configurations, administrative restrictions, callback gas sufficiency, and source-to-bytecode correspondence are absent or unverified. Exact-value quote transfers and the trusted canonical wrapper are assumptions required by the supplied specification.",
      "The requirement treats arbitrary prizes as untrusted, while IRaffle.sol:10-15 restricts supported prizes to honest standards-compliant ERC721s. Arbitrary prizes can refuse future transfer or fabricate ownerOf reports. Detectable NFT delivery failure rolls back redemption, but there is no refund transition out of NftWon. Whether a terminal fallback is required remains unresolved because the specification expressly requires rollback on failed delivery without defining a fallback; this is recorded as a trust-model/liveness gap rather than an unconditional second defect.",
      "A ticket owner must be able to act, and the configured recipient/token must permit delivery. Generic inaccessible recipient contracts, quote-token pauses or restrictions, and accidental unsolicited assets can prevent recovery; no universal external-dependency liveness guarantee is established.",
      "Frontend discovery, current-state rereads before transactions, indexers, wallet behavior, and deployment tooling are not included in the supplied scope.",
      "Operator-requested model is gpt-6-astra with ultra reasoning and fallback disabled; provider-returned identity, usage, and cost are unknown and are not independently attested by this review.",
      "No peer output, historical finding, scanner result, or report was consulted. Candidate observations remain needs-review and are not human-accepted findings."
    ]
  }
}
```
