# S6 per-file source coverage

Every row below was included in the full numbered source capture. All 36 Solidity files compiled under Solidity 0.8.36 during the actual Slither scan; the reachable production graph compiled again in Forge and Echidna. “Runtime” identifies direct behavioral execution by the stage-created harness. “Manual” identifies source-level control/data-flow review. Dependency files are not claimed to have independent exhaustive unit coverage when only a subset of their APIs is reachable.

## Five production files

| File (lines) | S6 coverage and result |
|---|---|
| `src/Raffle.sol` (614) | Full manual review; Slither detectors and three printers; ERC-721 static check; direct Foundry unit/fuzz/invariant and Echidna runtime execution. Forge coverage: 87.04% lines (215/247), 83.22% statements, 34.48% branches, 87.10% functions. Findings S6-01 through S6-05 intersect its external-call, custody, delivery, and destination logic. |
| `src/RaffleFactory.sol` (186) | Full manual review; Slither/printers; direct creation, validation, clone registry, malicious prize, cross-factory, timing, and integration execution. Forge coverage: 78.69% lines (48/61), 81.48% statements, 16.67% branches, 100% functions. Findings S6-01, S6-03, S6-04, S6-05. |
| `src/interfaces/IRaffle.sol` (521) | Full ABI/error/event/trust-assumption review; compiled and used throughout both controllers; included in Slither ERC-721 check. The “honest prize” comment conflicts with DESIGN.md’s untrusted arbitrary-prize boundary and cannot serve as enforcement. |
| `src/interfaces/IRaffleFactory.sol` (150) | Full creation/registry ABI, events, errors, and deployment-responsibility review; compiled and exercised by all factory harnesses. |
| `src/libraries/RaffleConstants.sol` (43) | Full economics/timing/bounds review; constants exercised across sale, draw, callback, refund, batch, and fee tests; fee fuzzing covered both result branches. |

## Thirty-one dependency files

| # | Dependency (lines) | Reachability and review |
|---:|---|---|
| 1 | `@chainlink/.../shared/interfaces/LinkTokenInterface.sol` (31) | Full interface read; used by inherited base for `i_linkToken`/getter but LINK payment path is not selected. Constructor `link()` integration modeled by the wrapper mock. |
| 2 | `@chainlink/.../VRFV2PlusWrapperConsumerBase.sol` (118) | Full manual review; direct inherited runtime coverage of constructor wrapper binding, native request helper, `rawFulfillRandomWords` caller gate, getters, and internal dispatch. |
| 3 | `@chainlink/.../interfaces/IVRFV2PlusWrapper.sol` (83) | Full interface review; price, estimate, native request, request ID, and `link()` calls mapped. Actual wrapper implementation is absent and remains a limitation. |
| 4 | `@chainlink/.../libraries/VRFV2PlusClient.sol` (27) | Full read; direct runtime use of typed extra-args encoding for native payment. |
| 5 | `@openzeppelin/contracts/interfaces/IERC1363.sol` (86) | Full read; compiled through SafeERC20’s extended helpers, but ERC-1363 helpers are not called by production. |
| 6 | `@openzeppelin/contracts/interfaces/IERC165.sol` (6) | Full alias read; transitive interface dependency only. |
| 7 | `@openzeppelin/contracts/interfaces/IERC20.sol` (6) | Full alias read; transitive interface dependency only. |
| 8 | `@openzeppelin/contracts/interfaces/draft-IERC6093.sol` (162) | Full error-interface read; ERC-721 receiver/authorization errors reached in negative receiver and transfer tests. Unrelated error families are compiled but unreachable. |
| 9 | `@openzeppelin/contracts/proxy/Clones.sol` (294) | Full review of clone mechanisms; production directly executes nondeterministic `clone`. Deterministic/prediction/fetch/create2 variants are not selected. Fixed embedded implementation target supports the non-upgradeability conclusion. |
| 10 | `@openzeppelin/contracts/token/ERC20/IERC20.sol` (79) | Full interface review; transfer/transferFrom/approve/balance integration modeled with standard, false-return, callback, and fee-on-transfer mocks. |
| 11 | `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` (26) | Full read; factory `decimals()` validation executed, including its role in the conditional identity finding. |
| 12 | `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` (280) | Full review; production-selected `safeTransfer` and `safeTransferFrom` executed, including false-return rollback. Permit/ERC-1363 force-approve helpers are not selected. |
| 13 | `@openzeppelin/contracts/token/ERC721/ERC721.sol` (433) | Full inheritance/authorization/update review; direct runtime coverage of mint, burn, balance, ownership, approve, operator transfer, safe transfer, metadata, and interface support. |
| 14 | `@openzeppelin/contracts/token/ERC721/IERC721.sol` (135) | Full interface/event review; Slither ERC-721 conformance and runtime interface checks. |
| 15 | `@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` (28) | Full interface review; prize activation and ticket recipient callbacks executed with accepting, rejecting, reentrant, and incompatible recipients. |
| 16 | `@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` (27) | Full interface review; `name`, `symbol`, metadata interface ID, and inherited empty `tokenURI` behavior mapped; runtime checks cover name/symbol/interface. |
| 17 | `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` (50) | Full receiver-check review; direct execution of accept/reject/revert paths through safe mint/transfer and factory prize escrow. |
| 18 | `@openzeppelin/contracts/utils/Bytes.sol` (332) | Full source captured/read; transitive string/utility dependency. Production does not directly call its public library surface. |
| 19 | `@openzeppelin/contracts/utils/Context.sol` (28) | Full read; `_msgSender` reached through ERC-721 authorization paths. |
| 20 | `@openzeppelin/contracts/utils/Create2.sol` (91) | Full read; compiled through deterministic Clones helpers, but production uses `clone`/CREATE rather than CREATE2. |
| 21 | `@openzeppelin/contracts/utils/Errors.sol` (34) | Full read; compiled support for clone/low-level utilities; selected clone path reviewed. |
| 22 | `@openzeppelin/contracts/utils/LowLevelCall.sol` (127) | Full read; generic delegate/static/call helpers surfaced in manual danger search but are not invoked by first-party production paths. No upgrade delegatecall path exists. |
| 23 | `@openzeppelin/contracts/utils/Panic.sol` (57) | Full read; transitive utility for arithmetic/bytes helpers; no direct first-party call. |
| 24 | `@openzeppelin/contracts/utils/ReentrancyGuard.sol` (119) | Full namespaced-slot review; direct runtime reentrancy tests across purchase callbacks plus guarded lifecycle/claim calls. Clone zero-slot behavior was explicitly assessed. |
| 25 | `@openzeppelin/contracts/utils/StorageSlot.sol` (143) | Full read; transitive low-level utility only, with no first-party mutable implementation/admin slot. |
| 26 | `@openzeppelin/contracts/utils/Strings.sol` (532) | Full source captured/read; ERC-721 `tokenURI` transitive use and math/bytes helpers compiled. Fixed name/symbol do not depend on it. |
| 27 | `@openzeppelin/contracts/utils/introspection/ERC165.sol` (25) | Full read; direct inherited runtime checks for ERC-165, ERC-721, metadata, and invalid IDs. |
| 28 | `@openzeppelin/contracts/utils/introspection/IERC165.sol` (25) | Full interface review; factory queries sponsor-selected prize support; honest, false/non-callback, and lying implementations tested. |
| 29 | `@openzeppelin/contracts/utils/math/Math.sol` (763) | Full source captured/read; production-selected `mulDiv` reviewed and fuzzed 10,000 times across both economic branches. Other math helpers are not selected. |
| 30 | `@openzeppelin/contracts/utils/math/SafeCast.sol` (1,162) | Full source captured/read; compiled dependency with no direct first-party call. First-party timestamp casts were separately reviewed. |
| 31 | `@openzeppelin/contracts/utils/math/SignedMath.sol` (68) | Full read; transitive Strings helper only; no signed first-party arithmetic. |

The dependency and production numbered captures are preserved in `tool-output/00-dependencies-numbered-attempt-02.stdout` and `tool-output/00-source-and-design-numbered.stdout` respectively. The complete total is 6,891 Solidity source lines: 1,514 first-party lines and 5,377 dependency lines.
