# IRaffle requirement extraction

Source: `target/packages/contracts/src/interfaces/IRaffle.sol`, lines 1–521, supplied frozen target for requested commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.

This is the native requirement-extraction stage. The schema-bound response contains the requirement catalogue: stable IDs, verbatim quotations, source locations, kinds, documentary force, and concrete checkability notes. No implementation-compliance verdict is asserted, and no per-requirement compliance analysis was requested in this stage.

## Evidence and method

Read the entire specified interface using `nl -ba target/packages/contracts/src/interfaces/IRaffle.sol`. No additional searches were needed. No other source, previous analysis, sibling output, or external evidence was consulted. No tests, compilers, analyzers, scanners, fuzzers, or runtime behavior tools were run. The target was not modified.

The extraction covers the overview and trust assumptions (L10–L15), lifecycle definitions (L20–L33), configuration semantics (L36–L44), events and their payloads (L58–L179), errors and their payloads (L184–L301), state-changing APIs (L305–L355), view APIs (L359–L390), and generated getters (L394–L520). Imports, licensing, authorship, version metadata, and section labels are not behavioral requirements.

Independent clauses are separated. Repeated descriptions of the same property need not create additional requirements; event payloads and query results remain independently checkable API behavior. Quotes retain the document's wording; NatSpec delimiters, indentation, and line wrapping are presentation syntax. Locations identify the relevant symbol when a quoted clause is a sentence fragment. Descriptive prose and descriptions of permissions remain descriptive; the explicit “must contain” condition is mandatory. A stated permission does not make its implementation optional.

## Documentation limits retained in the catalogue

- “one autonomous NFT raffle” (L10): the document does not define an operational criterion for autonomy.
- “honest” (L14): honesty is an external prize-token trust assumption without a precise behavioral definition. ERC-721 standards compliance is a separate stated assumption (L15).
- “known protocol destination that could strand the claim” (L225): this interface does not enumerate the rejected quote destinations or define the stranding criterion.
- “known protocol plumbing” (L266): this interface does not enumerate the destinations rejected during initialization and ticket transfers.
- “rounded down from gross sales” (L120) and “The cash-winner allocation is rounded down” (L328): rounding direction is specified, but this interface does not specify the underlying allocation percentages. No percentage or unstated winner-selection formula is inferred.
- “canonical” factory and USDC identities (L36, L306, L407, L422–L423): deployment identity is an external assumption; the interface alone supplies no canonical addresses.

The returned requirements describe what an implementation would have to satisfy. They do not report that any implementation satisfies or violates those properties.
