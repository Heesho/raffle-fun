# TOOL-HALMOS targeted symbolic campaign

Completed 2026-10-21 UTC, independently after the sealed SUP-S1 first pass. This campaign did not modify or overwrite SUP-S1. Three targeted Halmos attempts were made; no further retries were made after the third. Actual frozen RaffleFactory/Raffle code was executed through deployed EIP1167 clones, using independently written dependency mocks. This was not a pure formula checker or a concrete regression labeled symbolic.

## Outcome

**PARTIAL: two targeted authorization properties passed; full accounting/settlement verification remains incomplete. No counterexample model was produced. Timeout is not a pass.**

| Property | Actual execution and symbolic scope | Result |
|---|---|---|
| check_aa_uninitialized_clone_denies_stranger(address) | Deploy actual factory and implementation, deploy additional real Clones.clone pointing to it; symbolic caller over all addresses except canonical factory; attempt actual initialize; assert revert, initialized=false, sponsor=0 | PASS, 2 paths, 0 bounded loops, 0.26s |
| check_initializer_and_callback_denial(uint8,uint8,uint8) | Real factory creation/prize escrow, two owners each buying symbolic a,b in[1,16], actual cloned purchase accounting and range assertions; outsider clone/implementation reinitialization, outsider rawFulfill and authenticated wrong-ID callback; assert denial plus unchanged draw/config/accounted balance | PASS, 7 paths, 0 bounded loops, 2.50s |
| check_refund_two_actors(uint8,uint8,bool) | Two positive symbolic quantities[1,16], two buyers, symbolic refund order; actual enableRefunds, wrong-owner low-level call, both burns/refunds, per-step actual token balance==accountedQuoteBalance, buyers restored, liability zero, prize returned | TIMEOUT, 19 paths, 0 bounded loops, 10.07s; unresolved SMT queries retained |
| check_cash_two_actors(uint8,uint8,uint8,bool) | Actual request, authenticated resolution, winning-range proof, wrong-owner denial, symbolic winner entry and sponsor-release ordering, terminal release/redemption conservation | INCOMPLETE: first process hit180s while cash solver queries were active; no test-completion result |
| check_nft_two_actors(uint8,uint8,uint8) | Actual reserve-met resolution, correct current owner, independent releases, NFT delivery/burn and final USDC conservation | NOT REACHED/UNPROVEN in first process; not selected in final narrowed campaign |

Passing authorization tests include successful actual symbolic purchases with balance/range assertions as setup preconditions. They do not establish terminal refund or settlement solvency beyond those exact tested sequences. Wrong-owner redemption is present in cash/NFT paths but is not claimed proved because those paths did not complete. Wrong-owner refund is present in the timed-out refund property but is likewise not claimed proved independently.

## Attempts and exact evidence

- `help/attempt-01`: recorded Halmos --help through the parent run-command helper, used to select supported CLI flags.
- `targeted/attempt-01`: original four-property harness (`HARNESS-attempt-01.sol`); build succeeded with Solidity0.8.36; process cap180s; Z3, loop3, branching100ms, assertion10s, solver threads2. INCOMPLETE on process timeout, exit143. No complete JSON result was emitted. The shutdown solver-executor error is a timeout consequence, not a contract counterexample.
- `targeted/attempt-02`: added full-address symbolic fresh-clone authorization property (`HARNESS-attempt-02.sol`); process cap120s; Z3, loop3, branching100ms, assertion2s, threads4. INCOMPLETE, exit1: anchored test regex ended at the function name, but Halmos matches signatures including arguments, so no tests selected. This is a recorded invocation/setup failure, never a pass.
- `targeted/attempt-03`: corrected selection prefix and put the fresh-clone property first (`HARNESS-attempt-03.sol`); process cap180s; Z3, loop3, branching100ms, assertion2s, threads4, PYTHONUNBUFFERED=1. Completed tool execution in17.37s, overall exit1: two PASS and one solver TIMEOUT. `halmos-attempt-03.json` gives exact per-test results. The overall campaign is therefore incomplete even though two properties passed.

Each recorded attempt contains command, timestamps, process timeout, stdout, stderr, and freeze-integrity results. Halmos invokes Forge's build of the isolated project (initial74 files, later1 changed file); only the named fresh symbolic contract/properties were selected for execution. Existing test files were not used to design this harness; build diagnostics may reference other files compiled by Forge.

The parent helper was initially invoked without arguments while checking usage and raised IndexError before creating a run or executing a tool. Subsequent operational calls used its required SLOT/TIMEOUT/CWD/CMD schema. That preflight failure does not count as a symbolic result.

## Models, bounds and exclusions

- Mock quote contract: six decimals; standard mapping-based allowance and exact fee-free transfers; each of two fixed EOAs starts with100USDC. This models the stated trusted canonical-token semantics, not USDC administration/blacklisting/rebasing or fee tokens.
- Mock prize: actual OZ ERC721 with externally callable test mint; exact factory escrow callback and transfer behavior. No malicious prize-token behavior, transfer pause, reentrant prize callback or false ownerOf response was modeled.
- Mock wrapper: link getter, zero native quote, request ID1, external delivery helper. Production rawFulfill wrapper authentication still executes. This tests callback caller and request-ID gates, not actual cryptographic randomness, pricing, native refunds, confirmation delays or service availability.
- a,b are full uint8 symbolic inputs constrained1..16; nonzero total2..32. Cash reserve33 and NFT reserve1 select intended branch. `pick` is uint8, constrained below a+b for cash/NFT so every possible winning entry in that bounded sale is representable; full256-bit randomness/modulo uniformity is not proved. Refund order and sponsor-release order are symbolic booleans. Initializer caller is a full symbolic160-bit address except immutable factory.
- Fixed actor addresses A=0x1111, B=0x2222, outsider C=0x3333, sponsor recipient0xCAFE, treasury0xFEE. Timestamp fixed1,800,000,000 initially; sale end1,800,000,100; refund transition at end+2days. Arbitrary timing/deadline races are not explored.
- No stateful invariant-depth campaign was run; these are fixed bounded transaction sequences. Loop bound3 was configured; all final selected tests reported0 bounded loops. No proof claim extends to100-ticket batches, arbitrary actor counts, uint128 maxima, cross-clone donation, rejected transfer rollback, native refunds, malicious dependencies or arbitrary transaction order.
- `timeout-smt-queries/11.smt2` and `12.smt2` preserve the refund assertion queries reported unresolved. No attempt was made to reclassify them as safe after the3-attempt limit.

## SMTChecker applicability

No SMTChecker proof is claimed or run. A standalone `solc` executable was not found on PATH, although Forge successfully supplied Solidity0.8.36 compilation. More importantly, a source-level CHC/BMC experiment over these cross-contract factory/clone/token flows requires explicit handling of CREATE, delegatecall and arbitrary external token calls; replacing them with percentage equations would not test the requested actual execution and would duplicate the rejected formula-only approach. A useful separate experiment would target actual Raffle.initialize with a constrained immutable factory and assert storage remains unchanged for non-factory senders, then report compiler unsupported-operation/modeling warnings rather than treating abstraction as a full clone proof. The successful Halmos fresh-clone property supplies the direct bytecode test for that obligation here. SMTChecker accounting/delegatecall applicability remains unverified, not silently covered.

## Integrity and reproducibility

`integrity-isolated-before.json` records SHA256 for the five production files and four package/compiler/remapping configs, each compared with frozen clean-context bytes before execution. `integrity-isolated-after.json` confirms exact equality after the campaign. Parent-helper before/after files additionally verify its frozen repository/snapshot/dependency boundaries. Only the fresh symbolic harness and local build outputs changed in the isolated Halmos directory; no production source/config remediation occurred. Harness versions and timeout queries are copied into this output directory. `MANIFEST.json` records artifact hashes and a UTC completion timestamp.
