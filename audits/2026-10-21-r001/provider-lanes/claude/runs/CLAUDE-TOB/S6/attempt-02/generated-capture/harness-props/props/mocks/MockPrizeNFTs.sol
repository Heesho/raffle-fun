// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice GENERATED SCRATCH MOCK (S6 attempt-02): honest, standards-compliant ERC-721 prize collection.
contract MockPrizeNFT is ERC721 {
    constructor() ERC721("Mock Prize", "PRIZE") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

/// @notice GENERATED SCRATCH MOCK: ERC-721 whose collection owner can freeze transfers at any time (a common real-world
///         pattern: pausable / operator-filtered / admin-controlled collections). Used to show that the protocol's
///         sponsor payout is independent from prize deliverability.
contract PausablePrizeNFT is ERC721 {
    address public immutable collectionOwner;
    bool public paused;

    constructor() ERC721("Pausable Prize", "PPRIZE") {
        collectionOwner = msg.sender;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setPaused(bool value) external {
        require(msg.sender == collectionOwner, "not collection owner");
        paused = value;
    }

    function adminTransfer(address from, address to, uint256 tokenId) external {
        require(msg.sender == collectionOwner, "not collection owner");
        _transfer(from, to, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        require(!paused || auth == address(0), "transfers paused");
        return super._update(to, tokenId, auth);
    }
}

/// @notice GENERATED SCRATCH MOCK: dishonest ERC-721 that "escrows" nothing. safeTransferFrom only invokes the
///         receiver hook with the expected operator/from/tokenId and ownerOf lies, so the factory's escrow
///         verification passes without any token moving.
contract LyingPrizeNFT {
    mapping(uint256 tokenId => address owner) public realOwner;
    mapping(uint256 tokenId => address claimed) public claimedOwner;

    function mint(address to, uint256 tokenId) external {
        realOwner[tokenId] = to;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd || interfaceId == 0x01ffc9a7;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address c = claimedOwner[tokenId];
        return c == address(0) ? realOwner[tokenId] : c;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        // No ownership change; only claims it.
        claimedOwner[tokenId] = to;
        require(
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "")
                == IERC721Receiver.onERC721Received.selector,
            "rejected"
        );
    }

    function transferFrom(address, address to, uint256 tokenId) external {
        claimedOwner[tokenId] = to;
    }
}
