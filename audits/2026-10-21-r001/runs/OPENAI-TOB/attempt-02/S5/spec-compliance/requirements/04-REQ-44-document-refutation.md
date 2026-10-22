## REQ-44 — Documentary refutation review: reread chain state

> "Frontend discovery is advisory; transaction decisions must reread current chain state."
> — `target/DESIGN.md:L2`

**Verdict:** absent · confidence: high, confined to the supplied source

**Refutation result:** Not refuted. No correction or revised verdict.

Reviewed the exact supplied analysis at `audit/S5/spec-compliance/requirements/04-REQ-44.md`. This is the requested document-reading challenge to that finding, not a new discovery pass or an independent replay of all contract paths in that analysis.

---

**What this demands of an implementation:** The sentence "Frontend discovery is advisory; transaction decisions must reread current chain state." (`target/DESIGN.md:L2`) distinguishes discovery from the reads used for transaction decisions. In this frontend context, "advisory" qualifies discovery; it does not weaken "must reread" into a recommendation. The original finding's request for a frontend decision path using renewed chain reads is supported by the complete sentence.

The entire design document was read (`target/DESIGN.md:L1-L4`). Its heading is "# Clean design specification" (`L1`), and its closing paragraph says, "Source, not design prose, determines actual behavior." (`L4`). That statement distinguishes actual behavior from the specification; it does not retract the quoted obligation at `L2`. No earlier definition, example, roadmap qualification, or later exception to that obligation was found in these four lines.

The API comment says, "Native-token wei currently quoted by the wrapper; the value may change before request inclusion." (`target/packages/contracts/src/interfaces/IRaffle.sol:L360`). This qualifies the stability of a fee quote, not the obligation to reread. Neither this qualification nor the original finding requires a read to guarantee unchanged state at transaction inclusion.

---

**Where enforcement lives:** No frontend decision/submission implementation was located by the inventories and searches below. The contract evidence cited by the original finding was checked directly:

```solidity
// target/packages/contracts/src/Raffle.sol:L249-L250
uint256 quotedFee = getVrfRequestPrice();
if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

// target/packages/contracts/src/Raffle.sol:L436-L438
function getVrfRequestPrice() public view override returns (uint256 fee) {
    fee = i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1);
}
```

The fee read occurs inside the external payable `requestDraw` function (`target/packages/contracts/src/Raffle.sol:L240-L250`), and the getter calls the wrapper (`L436-L438`). Those lines establish execution-time querying; they do not establish a frontend read before deciding to submit. The interface describes the getter as "Returns the wrapper's current native direct-funding price for the configured callback." (`target/packages/contracts/src/interfaces/IRaffle.sol:L359`). Providing that API does not establish its use by a frontend.

---

**Paths walked:**

- Document context: the complete specification, `target/DESIGN.md:L1-L4`, including the sentence before the requirement and the closing paragraph. No textual exemption was found.
- API context: draw-request comments and signature (`target/packages/contracts/src/interfaces/IRaffle.sol:L316-L320`), price-query comments and signatures (`L359-L366`), and historical-range comments (`L368-L373`). The relevant price-stability qualification is quoted above.
- Source correspondence: read `requestDraw` (`target/packages/contracts/src/Raffle.sol:L240-L273`) and the price getter (`L436-L438`) to locate the quoted query relative to the transaction entrypoint. This review does not claim independent validation of all dependencies or transaction paths.
- Alternative application location: read `target/packages/contracts/hardhat.config.ts:L1-L59`; it exports plugin, path, compiler, and network configuration. No transaction-decision routine occurs there.

---

**Searched:** All commands were local source/specification reads or text searches. No tests, compilers, analyzers, scanners, fuzzers, chain calls, network research, or behavior-generating tools were used.

1. **Project inventory:** `rg --files --hidden --no-ignore target -g '!.git/**' -g '!**/.git/**' -g '!**/test/**' -g '!**/tests/**' -g '!**/node_modules/**'` returned `DESIGN.md`, five project Solidity files, `hardhat.config.ts`, and build/dependency files. No frontend application or submission script appeared.
2. **Application-source inventory:** `rg --files --hidden --no-ignore target -g '!**/.git/**' -g '!**/test/**' -g '!**/tests/**' -g '!**/node_modules/**' -g '*.{ts,tsx,js,jsx,mjs,cjs,vue,svelte,html,py,go,rs,sol}'` returned exactly `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`, and `hardhat.config.ts`, all under `target/packages/contracts/`.
3. **Document vocabulary:** `rg -n -i 'frontend|discovery|advisory|reread|re-read|refresh|refetch|cache|stale|indexer|subgraph' target/DESIGN.md target/packages/contracts/src` returned exactly two lines: the requirement at `target/DESIGN.md:L2` and the historical-range comment at `target/packages/contracts/src/Raffle.sol:L138`.
4. **Broader documentary context:** the same locations were searched with the additional alternatives `off.?chain|client|transaction|current|historical`. Relevant matches included the fee-query comments at `target/packages/contracts/src/interfaces/IRaffle.sol:L359-L360`; other matches were the `VRFV2PlusClient` symbol, lifecycle/ownership/liability descriptions, and the closing design paragraph. No frontend-specific exception to the reread requirement was found.
5. **Client/refresh implementation sweep:** `rg -n -i --hidden --no-ignore -g '!**/.git/**' -g '!**/test/**' -g '!**/tests/**' -g '*.{sol,ts,tsx,js,jsx,mjs,cjs,vue,svelte,html,py,go,rs}' '\b(frontend|discovery|advisory|reread|refresh|refetch|stale|indexer|subgraph)\b|re-read|readContract|readContracts|writeContract|simulateContract|sendTransaction|eth_call|eth_sendTransaction|useReadContract|useWriteContract|publicClient|walletClient|blockTag|getLogs|queryFilter' target` returned **0 matching lines**, including vendored source. This whole-word pattern does not match the plural "indexers" at `Raffle.sol:L138`; search 3 covers that comment.
6. **Transaction callers:** using the same hidden/ignored-source inclusion and test exclusions, searched `(createRaffle|buyEntries|requestDraw|enableRefunds|settleWinningTicket|redeemWinningTicket|refundTickets|releaseSponsorProceeds|releaseProtocolFees|releaseSponsorPrize)\s*\(`. Returned **23 lines**: contract/interface declarations and the private settlement helper with its two internal calls (`target/packages/contracts/src/Raffle.sol:L305,L315,L533`). No frontend caller was found.

---

**How the verdict was reached:** The complete sentence explicitly requires rereading: "Frontend discovery is advisory; transaction decisions must reread current chain state." (`target/DESIGN.md:L2`). The documentary qualifications examined do not excuse this behavior. The original finding already limits **absent** to the supplied implementation and expressly disclaims an observed stale-read path or a claim about an external frontend.

The source inventory and caller searches support that limited absence. The execution-time fee query (`target/packages/contracts/src/Raffle.sol:L249-L250,L436-L438`) does not establish frontend decision ordering, so it does not justify **implemented** or **partial**. No incompatible frontend path was found to justify **contradicted**. The quoted obligation is checkable in a frontend implementation; no documentary ambiguity was found that requires changing the category to **undecidable**. The claimed divergence therefore survives this document-reading challenge without correction.

---

**Open questions:** Whether any separately maintained frontend rereads chain state before making transaction decisions cannot be established from this supplied target. No frontend stale-read execution or resulting harm was established. Neither uncertainty expands the scoped absence into a claim about an external implementation.
