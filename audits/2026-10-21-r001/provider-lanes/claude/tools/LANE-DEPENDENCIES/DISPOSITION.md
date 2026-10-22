# Dependency / supply-chain disposition (lane validation copy)
- Install: pnpm 11.18.0 / node 22.23.2, `pnpm install --frozen-lockfile` (lockfile integrity sha512 verified by pnpm; "Lockfile passes
  supply-chain policies"); isolated store. The 31 reachable dependency files match dependency-hashes.json (31/31).
- Production compile inputs: @openzeppelin/contracts 5.6.1 (remapping `@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/`)
  and @chainlink/contracts 1.5.0 VRF v2.5 wrapper consumer files (VRFV2PlusWrapperConsumerBase, IVRFV2PlusWrapper, VRFV2PlusClient,
  LinkTokenInterface). None of the imported Chainlink files import OpenZeppelin.
- `pnpm audit --prod` (packages/contracts): every @openzeppelin advisory resolves to 4.7.3 / 4.8.3 copies reached only through
  `@chainlink/contracts > @arbitrum/nitro-contracts (> @offchainlabs/upgrade-executor)`, which production sources never compile.
  Disposition: NOT_APPLICABLE to production bytecode; it is hygiene debt in the npm tree. The remaining advisories (next, sharp,
  source-map-js) affect apps/web, and (ws, tmp, js-yaml, brace-expansion, braces, elliptic) are JS tooling deps, all outside
  the contract scope.
- No known advisory applies to OpenZeppelin 5.6.1 in the audit output.
