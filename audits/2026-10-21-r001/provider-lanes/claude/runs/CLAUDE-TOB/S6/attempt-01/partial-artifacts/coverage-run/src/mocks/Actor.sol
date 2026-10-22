// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice Generic user proxy so the harness can act as many distinct msg.senders (accepts ERC-721 and ETH).
contract Actor is IERC721Receiver {
    function exec(address target, bytes calldata data) external payable returns (bool ok, bytes memory ret) {
        (ok, ret) = target.call{ value: msg.value }(data);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function sweep(address payable to) external {
        (bool ok,) = to.call{ value: address(this).balance }("");
        require(ok, "sweep");
    }

    receive() external payable { }
}
