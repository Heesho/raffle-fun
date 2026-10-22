# Requirements and assumptions fixed before judgment

The native context's clean design specification is authoritative. Required properties considered were atomic single-prize escrow; immutable configuration and fixed clone target; isolated clone assets; fixed price and inclusive transferable ranges; complete conservation of the stated outcome allocations; strict request and callback windows; bounded refund batches; storage-only callback and settlement; current-owner claims; rollback on failed delivery; and independent sponsor and treasury quote releases.

USDC and the Chainlink wrapper are trusted canonical dependencies. Arbitrary prize contracts and ticket recipients are untrusted. External deployment correctness, callback availability, and a permanently transferable prize are not established facts. The source interface's honest-prize restriction conflicts with the broader exported trust statement and is explicitly preserved as uncertainty in the raw review. No independent assertion that arbitrary prize semantics can be authenticated from ownerOf is made.

# Source coverage

All five production files were explicitly reviewed in full from context.json: Raffle.sol (1-615), RaffleFactory.sol (1-187), RaffleConstants.sol (1-44), IRaffle.sol (1-522), and IRaffleFactory.sol (1-151). Review covered public state, generated getter declarations, inherited ticket behavior relevant to transfers and burns, errors, events, and interface promise/implementation correspondence.

- Factory and clone lifecycle: constructor code and decimals checks; immutable implementation deployment; initialization authority and lock; clone storage isolation; same-factory destinations; registration ordering; exact prize receiver parameters; final ownership and Active checks; creation rollback.
- Sales and recipients: Active/end-time gating; zero and overflow checks; transfer-before-record sequencing under trusted USDC; contiguous nonzero ranges; ticket counter bound; receiver callback and allowed bearer transfer; inability of operator approval alone to redeem or refund.
- Draw and deadlines: permissionless funding; [end,end+2 days) request boundary; asynchronous trusted wrapper call; request-in-flight flag; excess refund rollback; wrapper authentication; wrong IDs, lengths, duplicate and late callbacks; callback result-only transitions; both full-refund deadlines.
- Terminal states: nonzero selected range; single settlement; no asset transfer in settlement; outcome percentages and remainder allocation; current owner at redemption; burned claim rollback on external failure; bounded atomic refund batches; independent quote claims; prize release state and delivery checks.
- Untrusted prize behavior: interface assertions are not semantic proof; callback spoofing is constrained to the configured prize but cannot prove honesty; initial escrow can succeed while later delivery fails; recipient classification can change after initialization; unsafe sponsor-prize delivery bypasses recipient acceptance.

# Limits and acquisition record

The first attempted path, work/context.json, did not exist. The parent corrected it to context.json at the same authorized cell root. No directory enumeration or unrelated file inspection was used to locate it.

The first whole-context display was truncated and is not treated as comprehensive reading. Complete/overlapping targeted extracts subsequently covered every production source line. Dependency reads were limited to the spans listed in resources.json; no complete dependency audit is claimed. Native context metadata, requirements, scope, compiler/EVM declarations, and limitations were read. The lockfile was not comprehensively reviewed. foundry.toml was read as inert metadata only.

Only inert source extraction, file hashing, and review artifact creation were performed. No assessed repository code or configuration was executed, and no tests, exploits, commands for reproduction, deployment lookups, or transactions were generated. No peer finding, other audit output, history, or raw target repository source was read. All source evidence came from the native context. The original JSON response remains preserved independently of later reconciliation.

This source review is not a certificate of safety, measured coverage, or proof of runtime behavior. Candidates remain unaccepted pending human disposition.
