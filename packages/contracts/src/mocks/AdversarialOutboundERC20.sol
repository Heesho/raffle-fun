// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title AdversarialOutboundERC20
/// @notice Test token that can become recipient-taxed or sender-taxed after accepting exact ticket payments.
contract AdversarialOutboundERC20 is ERC20 {
    enum TransferMode {
        Exact,
        RecipientFee,
        SenderTax
    }

    TransferMode public transferMode;

    constructor() ERC20("Adversarial Outbound Token", "AOUT") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setTransferMode(TransferMode mode) external {
        transferMode = mode;
    }

    function _update(address from, address to, uint256 value) internal override {
        TransferMode mode = transferMode;
        if (from == address(0) || to == address(0) || mode == TransferMode.Exact) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = Math.mulDiv(value, 100, 10_000);
        if (mode == TransferMode.RecipientFee) {
            super._update(from, to, value - fee);
            if (fee != 0) super._update(from, address(0), fee);
        } else {
            super._update(from, to, value);
            if (fee != 0) super._update(from, address(0), fee);
        }
    }
}
