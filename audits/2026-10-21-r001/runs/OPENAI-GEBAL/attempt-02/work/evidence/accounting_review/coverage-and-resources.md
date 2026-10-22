# Cold specialist coverage and resources

Source authority: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/OPENAI-GEBAL-attempt-02/context.json`.

The initial assignment named `work/context.json`; that file did not exist. Root corrected the authorized native export path to `context.json`. Only that native export supplied assessed source. Files under the assessed repository were never read directly. No peer, root-review, historical, scanner, or test-result artifact was read. Source comments were treated as evidence of stated assumptions, not authority to override the clean requirements.

Context file SHA256: `501efc5686810f59dc190014cd069440aaddaf5c40d48212757a171950254423`.
Native snapshotHash: `d0b726edfae0c24ed708c5c0f1908c40f4ab85da8d1708de38fe437a384dcc0a`.
Native contextHash: `c5b7124850800b51b1a5b5346ac3abe133da1f07d34f2d0764eab305fbb6947d`.

All listed source hashes are the native context's hashes, not claims about current files outside the export. All source spans are inclusive and 1-based. A broad first read of physical JSON lines 1–180 was truncated; it exposed incidental dependency excerpts and is not credited as complete source coverage. Subsequent bounded extractions supplied the full relied-upon production text. The complete path/hash/line-count inventory and top-level requirements, scope, compiler and EVM metadata were read, but this does not imply every inventory file's content was reviewed.

## Production sources, all explicitly reviewed in full

| Native source path | SHA256 | Read span |
| --- | --- | --- |
| packages/contracts/src/Raffle.sol | 6e4c977922c3e39fafaa8c4c4fb74a971f1817eca9b6552eb8a540969f968617 | 1–615 |
| packages/contracts/src/RaffleFactory.sol | d0e62b34faa42513fd968f915262728fe66a15c4b9af13a3c66f496704142ace | 1–187 |
| packages/contracts/src/libraries/RaffleConstants.sol | 0893f1a70ac03ad557e0b4c8bdf6a2f73d317f8417d1b4a3c1a571b893ed54b6 | 1–44 |
| packages/contracts/src/interfaces/IRaffle.sol | a43ede9e8802d636a566fb225ed65bdf70f06d17f4734a1632a0a9f84aa5b2dd | 1–522 |
| packages/contracts/src/interfaces/IRaffleFactory.sol | 747d238e4c7dc5b517f91c796dec87d9ddbfec9c626d1ff21467c60d780d03cf | 1–151 |

## Targeted dependency and metadata reads from the same native context

| Native source path | SHA256 | Read span |
| --- | --- | --- |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | ef8e2398c78851bd2ec12bc48d923058c557889d5a3d5ee4919c17ff0fb3517e | 1–434 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol | b48e95db8c85866c1d88af8e82f346e0d22d24b5aac5b936079d958c72e13b9f | 1–51 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol | c2394cb2a327f234711da34884947f4aa0f6dd2791d1d6303a0c7acfaf81bca3 | 1–281 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol | 94e409e8f6e3184236651a6cc2b1a6a3ea0f0a25eb85b71e524ad5791bb2fbc8 | 1–120 |
| packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol | 06c768a2b794ea59dd6d6c1bfe33cf5098a4a8921aec14cf066576a2bffafce6 | 1–85 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol | bdfdbe133991c0c78042957ff5cd97167926fcaf6d15664f3835a076cb066457 | 185–285 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | 8cf045f295b8c6035d14012a9bc2e8ab2b5ce24749a199ca0190519c4bf2dcc0 | 1–119 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol | a48aaaeaed60e65f04f6c8772e5673dda663dcfa7913fdadd14b412300b9d5f1 | 1–84 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol | f3b89bb466c2a79b10c1816d342fbfbec49fe82695cba92bd46e7d31af698011 | 1–28 |
| packages/contracts/foundry.toml | 0fdce809ea1675dac422cff420a3402b2f28aabed0631595e43823033fa8ef50 | 1–49 |
| packages/contracts/package.json | 2f46b8f46ed3de275a3a6d097c86a888fece719151bdf4e171495dc12e6802ad | 1–45 |
| packages/contracts/remappings.txt | cbf6730be9c6b6daa1855953ba581d96f14e2dbc3bc95ca3bc2d92cfd231acaa | 1–3 |
| pnpm-lock.yaml | 3c277879a07bda9a4bd9788b810a000b3cb58873fc84d515e4661e0a4ed422c4 | Inventory metadata only; content not reviewed |

The incidental first context read also displayed the complete LinkTokenInterface text and some other dependencies before/after truncation. Those excerpts are not relied upon to assert additional dependency review coverage. The three bounded Chainlink rereads above remove any uncertainty for the VRF paths actually used in reasoning.

## Harness resources, read fully

Root: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/gebal/`.

| Relative path | SHA256 from local read | Read span |
| --- | --- | --- |
| START_HERE.md | a4391cdbafbea7c963dd7881ce0251e96ca44a08124b830e5698e1f2a5c3cb36 | 1–85 |
| agents/REVIEW.md | 6be0a96e138fbc86a9d3c80fbab38840b5ced20eddd2ec6aef087db937bda117 | 1–17 |
| agents/response.schema.json | 91bbbc126a265d37789ab4e54a64fa0d3845d28e979faebbe8ac8e5d3d8ff240 | 1–110 |

## Reasoned paths and limits

- Purchase and ranges: Raffle 209–237 transfers exactly entryCount times 1,000,000, advances totalEntries and ticketCount, records the inclusive next interval, and increases unsettledPot before safe mint. Positive entry count and totalEntries bounds make ticketCount no greater than totalEntries; total quote amount is below 2^148. The recipient callback may transfer its new ticket, but economic entrypoints are guarded and rejection reverts the payment and all minted state. TicketPurchased records the requested recipient, so latest ownership still requires a state read.
- Accounting and rounding: Raffle 533–558 allocates on the aggregate unsettled pot and clears it once. NFT branch assigns gross minus floor 5% to the sponsor. Cash branch assigns floor 80% to the winner and gross minus both allocations to the sponsor. The allocations sum to gross. In the actual fixed-price domain, every gross amount is a multiple of 1,000,000, so both percentage allocations are integral; there is no dust from sales. Math 199–277 provides floor mulDiv. Direct USDC donations do not enter sales or liabilities.
- Settlement and owner authorization: Raffle 579–584 checks an inclusive stored range. Unminted tickets have range [0,0] and cannot contain a positive winning entry. Settlement performs storage operations and arithmetic without reading owners or making token transfers. Redemption checks current owner, records recipient, marks redeemed and burns before delivery. Approved operators can transfer through ERC721 but cannot directly redeem without owning the ticket.
- Refunds: Raffle 349–372 checks one to 100 IDs, checks current owner per ID, sums each historical range and burns before the aggregate transfer. Repeated IDs fail ownerOf after the earlier burn, reverting the entire transaction. Disjoint sold ranges bound cumulative refunds by gross. SafeERC20 failure reverts burns and liability reduction.
- Claims: sponsor and treasury state is separately zeroed before token transfers, preserving independent claim access and preventing duplicate release. The whole call reverts on SafeERC20 failure. Winner NFT return uses transferFrom plus ownerOf reporting, so it cannot establish honest behavior of an arbitrary malicious prize. The two retained observations identify the trust mismatch and the sponsor-prize destination gap.
- Callbacks and lifecycle: VRF base authenticates the immutable wrapper. Raffle accepts exactly one random word only for its persisted request in Drawing and strictly before callbackDeadline; in-flight callbacks are ignored. Selection is within [1,totalEntries], and callback records only result state. Request deadline equality rejects requests; callback deadline equality rejects callbacks and permits refunds. Refunding and resolved outcomes do not transition back to drawing.
- Clone isolation and initialization: factory creation, initialization, registration, escrow, and final ownership/status checks are within one reverting transaction. Implementation constructor locks its own state; clones have isolated state and fixed implementation code/immutables. ReentrancyGuard rejects only ENTERED=2, so a fresh clone's zero guard slot is usable on its first call. Registry destination screening is dynamic for tickets and quote transfers, but not sponsor prize release.
- Interfaces/constants: all economic rates, durations, batch bound, getters, lifecycle values, and callable interface signatures were compared to implementation. The honest-prize NatSpec constraint differs from the broader clean context requirement; comments do not resolve that requirements conflict automatically.

These are manual source traces, not measured property coverage. No tests, compilation, analyzer, gas benchmark, proof, transaction, browsing, generated exploit, or target script was executed. JSON parsing, source display, file writing, and SHA256 sealing are evidence handling only.
