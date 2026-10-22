// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { FactoryDeployer } from "../FactoryDeployer.sol";
import { RaffleHandler } from "../RaffleHandler.sol";
import { MockPrizeNFT } from "../mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../mocks/MockVRFV2PlusWrapper.sol";

// Pre-deployed by Echidna `deployContracts` (see echidna/echidna.yaml).
MockUSDC constant E_USDC = MockUSDC(address(0x10000000));
MockVRFV2PlusWrapper constant E_WRAPPER = MockVRFV2PlusWrapper(address(0x20000000));
MockPrizeNFT constant E_NFT = MockPrizeNFT(address(0x30000000));
FactoryDeployer constant E_DEPLOYER = FactoryDeployer(address(0x40000000));

/// @notice Echidna property harness. Properties must hold for every reachable sequence.
contract EchidnaRaffle is RaffleHandler {
    constructor() payable RaffleHandler(E_USDC, E_WRAPPER, E_NFT, E_DEPLOYER) { }

    /// @dev Every action's success/revert matched the specification model and every post-state check passed.
    function echidna_no_spec_violation() external view returns (bool) {
        return violations == 0;
    }

    /// @dev Global accounting, custody, lifecycle, partition, registry and isolation invariants (I1-I12).
    function echidna_global_invariants() external view returns (bool) {
        (bool ok,) = checkInvariants();
        return ok;
    }
}

/// @notice Reachability canaries: each property is EXPECTED to be falsified, proving the campaign reaches that state.
contract EchidnaRaffleCanaries is RaffleHandler {
    constructor() payable RaffleHandler(E_USDC, E_WRAPPER, E_NFT, E_DEPLOYER) { }

    function echidna_canary_resolve_nft() external view returns (bool) {
        return hits["resolveNft"] == 0;
    }

    function echidna_canary_resolve_cash() external view returns (bool) {
        return hits["resolveCash"] == 0;
    }

    function echidna_canary_nft_redeemed() external view returns (bool) {
        return hits["redeemNft"] == 0;
    }

    function echidna_canary_cash_redeemed() external view returns (bool) {
        return hits["redeemCash"] == 0;
    }

    function echidna_canary_refund_paid() external view returns (bool) {
        return hits["refund"] == 0;
    }

    function echidna_canary_refunds_after_drawing_timeout() external view returns (bool) {
        return hits["refundsAfterDrawing"] == 0;
    }

    function echidna_canary_late_callback_ignored() external view returns (bool) {
        return hits["fulfillIgnored"] == 0;
    }

    function echidna_canary_sponsor_early_cancel() external view returns (bool) {
        return hits["sponsorEarlyCancel"] == 0;
    }

    function echidna_canary_prize_returned() external view returns (bool) {
        return hits["releasePrize"] == 0;
    }

    function echidna_canary_fees_released() external view returns (bool) {
        return hits["releaseFees"] == 0;
    }

    function echidna_canary_three_raffles() external view returns (bool) {
        return raffles.length < 3;
    }
}
