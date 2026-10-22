// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Standards-compliant ERC-721 prize whose admin can freeze transfers (models pausable / transfer-validator
///         collections such as ERC721-C, or an admin-controlled collection chosen by a malicious sponsor).
contract MockPrizeNFT is ERC721 {
    bool public frozen;

    constructor() ERC721("Prize", "PRZ") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setFrozen(bool isFrozen) external {
        frozen = isFrozen;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        require(!frozen || _ownerOf(tokenId) == address(0), "PRZ: frozen");
        return super._update(to, tokenId, auth);
    }
}
