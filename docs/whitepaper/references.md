# Whitepaper primary references

Last checked: August 10, 2026.

## Repository sources

- reviewed repository and contract commit:
  `6539e0c2b7e1a112dae70215f299dbd6ef48c4b3`;
- production Solidity under `packages/contracts/src/`;
- Foundry and Hardhat tests under `packages/contracts/test/`;
- generated Hardhat artifacts and synchronized SDK/subgraph ABIs;
- internal review evidence under `packages/contracts/audit/`;
- `SECURITY.md`, `README.md`, and `docs/SECURITY-INVARIANTS.md`;
- architecture, state, randomness, threat, deployment, SDK, subgraph, and frontend
  sources named in `FACT-CHECK.md`.

## External primary sources

- Solidity documentation: <https://docs.soliditylang.org/en/latest/>
- Solidity security considerations:
  <https://docs.soliditylang.org/en/latest/security-considerations.html>
- ERC-20: <https://eips.ethereum.org/EIPS/eip-20>
- ERC-165: <https://eips.ethereum.org/EIPS/eip-165>
- ERC-721: <https://eips.ethereum.org/EIPS/eip-721>
- OpenZeppelin Contracts 5.x: <https://docs.openzeppelin.com/contracts/5.x/>
- OpenZeppelin ERC-721 API:
  <https://docs.openzeppelin.com/contracts/5.x/api/token/erc721>
- OpenZeppelin access API:
  <https://docs.openzeppelin.com/contracts/5.x/api/access>
- Pyth Entropy: <https://docs.pyth.network/entropy>
- Pyth EVM integration:
  <https://docs.pyth.network/entropy/generate-random-numbers-evm>
- Pyth request variants:
  <https://docs.pyth.network/entropy/request-callback-variants>
- Pyth custom callback gas:
  <https://docs.pyth.network/entropy/set-custom-gas-limits>
- Pyth chain list: <https://docs.pyth.network/entropy/chainlist>
- Base protocol overview:
  <https://docs.base.org/base-chain/specs/protocol/overview>
- Base transaction troubleshooting:
  <https://docs.base.org/base-chain/network-information/troubleshooting-transactions>

External sources explain standards and dependencies. They do not endorse raffle.fun,
verify a deployment, or convert the internal review into an independent audit.
