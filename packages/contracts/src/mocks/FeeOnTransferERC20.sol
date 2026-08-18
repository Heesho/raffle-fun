// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title FeeOnTransferERC20
/// @notice Adversarial quote token that burns one percent of ordinary transfers.
contract FeeOnTransferERC20 is ERC20 {
    /// @notice Creates the adversarial test token.
    constructor() ERC20("Fee Token", "FEE") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Mints adversarial test balances.
    /// @param to Recipient.
    /// @param amount Amount.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev Mint and burn paths remain conventional while transfers deliver less than requested.
    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = Math.mulDiv(value, 100, 10_000);
        super._update(from, to, value - fee);
        if (fee != 0) super._update(from, address(0), fee);
    }
}
