// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice GENERATED SCRATCH TEST CODE (S6 attempt-02): a distinct protocol user (buyer, sponsor, ticket holder)
///         driven by its deploying harness. Accepts ERC-721 tickets/prizes and native refunds.
contract Actor {
    address public immutable controller;

    constructor() {
        controller = msg.sender;
    }

    function exec(address target, bytes calldata data) external payable returns (bool ok, bytes memory ret) {
        require(msg.sender == controller, "Actor: not controller");
        (ok, ret) = target.call{ value: msg.value }(data);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable { }
}
