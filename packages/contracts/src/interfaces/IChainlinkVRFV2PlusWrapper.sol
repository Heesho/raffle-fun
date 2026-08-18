// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice Minimal native-payment surface used from Chainlink's VRF v2.5 direct-funding wrapper.
/// @dev Selectors match `IVRFV2PlusWrapper` from Chainlink Contracts 1.5.0. LINK-payment and wrapper-administration
///      functions are intentionally excluded from the production import surface.
interface IChainlinkVRFV2PlusWrapper {
    function calculateRequestPriceNative(uint32 callbackGasLimit, uint32 numWords)
        external
        view
        returns (uint256 requestPrice);

    function estimateRequestPriceNative(uint32 callbackGasLimit, uint32 numWords, uint256 requestGasPriceWei)
        external
        view
        returns (uint256 requestPrice);

    function requestRandomWordsInNative(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes calldata extraArgs
    ) external payable returns (uint256 requestId);
}
