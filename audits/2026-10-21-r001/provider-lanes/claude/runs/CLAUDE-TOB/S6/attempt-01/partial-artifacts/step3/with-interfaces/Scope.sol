// SPDX-License-Identifier: MIT
// Analysis entry point only (outside packages/): imports exactly the five in-scope production files.
pragma solidity 0.8.36;

import "../../../packages/contracts/src/RaffleFactory.sol";
import "../../../packages/contracts/src/Raffle.sol";
import "../../../packages/contracts/src/interfaces/IRaffle.sol";
import "../../../packages/contracts/src/interfaces/IRaffleFactory.sol";
import "../../../packages/contracts/src/libraries/RaffleConstants.sol";
