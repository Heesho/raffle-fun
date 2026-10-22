// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice GENERATED SCRATCH MODEL (S6 attempt-02), not production code.
/// @dev Solidity model of the ERC-1167 runtime emitted by OpenZeppelin Clones.clone
///      (363d3d373d3d3d363d73<impl>5af43d82803e903d91602b57fd5bf3): no storage slots, no selectors,
///      every call (including empty-calldata value transfers) is DELEGATECALLed to one fixed implementation.
///      The implementation address is an immutable here (code, not storage), matching the bytecode-embedded address.
contract MinimalProxyModel {
    address private immutable _implementation;

    constructor(address implementation_) {
        _implementation = implementation_;
    }

    fallback() external payable {
        address impl = _implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
