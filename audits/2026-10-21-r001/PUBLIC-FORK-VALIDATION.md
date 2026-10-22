# Pinned public-dependency fork validation

Both maintained fork tests completed: **2 passed, 0 failed, 0 skipped**, on a fresh isolated copy using the frozen Solidity source and build inputs. The earlier release setup skip remains a historical skipped attempt; it is not relabeled as a pass.

| Network | Pinned block | Block hash |
|---|---:|---|
|Ethereum mainnet|26242794|`0x8fdbd950a706924ce62a5904c1b6b575b51f27f72ec968cb83ccd24c6a2dd7ac`|
|Ethereum Sepolia|11964220|`0xc9cd9fb1482946d20622e8ea7749f3d06b6f83f2484f079d4a93de82f906585e`|

The existing EthereumFork.t.sol tests verify the chain, quote/wrapper code presence, USDC decimals, positive native fee quote, factory configuration, empty-raffle prize return, actual quote-token approval/purchase and range receipt, successful local request to the real wrapper, and unauthorized callback rejection. They use a mock prize, storage-cheatcode-funded buyers and local fork deployment. They do not produce a real offchain VRF proof or validate a live deployed candidate.

Endpoints came from [PublicNode's Ethereum gateway](https://ethereum.publicnode.com/). The quote addresses are listed by [Circle](https://developers.circle.com/stablecoins/usdc-contract-addresses); wrapper documentation was checked against [Chainlink supported networks](https://docs.chain.link/vrf/v2-5/supported-networks.md). Downloaded documents and SHA256 metadata are retained in the attempt's external-evidence directory. These sources corroborate address selection; successful fork execution supplies the behavioral evidence. No blanket future availability or administrator guarantee follows.

Exact command, source integrity checks and raw results: `runs/TOOL-PUBLIC-FORK/attempt-01/`. Configuration, pinned block responses and command are in `public-fork-plan.json`. RPC discovery first failed because the default Python user agent received403; explicit audit client identification succeeded. Those original probe failures remain under TOOL-PUBLIC-RPC-PROBE. All remote operations were read-only. All contract creation, token balance funding and request state writes occurred only in the local fork; no transaction was signed or broadcast to a public chain.
