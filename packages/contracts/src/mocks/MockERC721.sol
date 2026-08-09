// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockERC721
/// @notice Minimal standards-compliant prize NFT used by local deployments and tests.
contract MockERC721 is ERC721 {
    /// @notice Creates the local prize collection.
    constructor() ERC721("Mock Prize", "MPRIZE") { }

    /// @notice Mints a chosen test prize.
    /// @param to Recipient.
    /// @param tokenId Token ID.
    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
