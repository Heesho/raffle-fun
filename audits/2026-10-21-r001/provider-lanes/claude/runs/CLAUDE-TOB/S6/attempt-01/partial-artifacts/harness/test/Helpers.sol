// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";

import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";

/// @notice Ticket recipient that tries to re-enter every guarded raffle entry point from the mint callback.
contract ReentrantRecipient is IERC721Receiver {
    IRaffle public target;
    bytes4[] public errors;

    function arm(IRaffle raffle) external {
        target = raffle;
    }

    function errorCount() external view returns (uint256) {
        return errors.length;
    }

    function _rec(bytes memory reason) internal {
        bytes4 sel;
        assembly ("memory-safe") {
            sel := mload(add(reason, 0x20))
        }
        errors.push(sel);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        if (address(target) != address(0) && msg.sender == address(target)) {
            uint256[] memory ids = new uint256[](1);
            ids[0] = tokenId;
            try target.buyEntries(address(this), 1) { } catch (bytes memory e) { _rec(e); }
            try target.requestDraw() { } catch (bytes memory e) { _rec(e); }
            try target.enableRefunds() { } catch (bytes memory e) { _rec(e); }
            try target.settleWinningTicket(tokenId) { } catch (bytes memory e) { _rec(e); }
            try target.redeemWinningTicket(tokenId) { } catch (bytes memory e) { _rec(e); }
            try target.refundTickets(ids) { } catch (bytes memory e) { _rec(e); }
            try target.releaseSponsorProceeds() { } catch (bytes memory e) { _rec(e); }
            try target.releaseProtocolFees() { } catch (bytes memory e) { _rec(e); }
            try target.releaseSponsorPrize() { } catch (bytes memory e) { _rec(e); }
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Untrusted prize whose transferFrom re-enters the raffle while the raffle is delivering the prize.
contract ReentrantPrizeNFT is MockPrizeNFT {
    IRaffle public hookTarget;
    bytes4[] public errors;

    function armHook(IRaffle raffle) external {
        hookTarget = raffle;
    }

    function errorCount() external view returns (uint256) {
        return errors.length;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (address(hookTarget) != address(0) && from == address(hookTarget)) {
            uint256[] memory ids = new uint256[](1);
            ids[0] = 1;
            try hookTarget.refundTickets(ids) { } catch (bytes memory e) { errors.push(bytes4(e)); }
            try hookTarget.releaseSponsorProceeds() { } catch (bytes memory e) { errors.push(bytes4(e)); }
            try hookTarget.releaseProtocolFees() { } catch (bytes memory e) { errors.push(bytes4(e)); }
            try hookTarget.redeemWinningTicket(1) { } catch (bytes memory e) { errors.push(bytes4(e)); }
            try hookTarget.releaseSponsorPrize() { } catch (bytes memory e) { errors.push(bytes4(e)); }
        }
        super.transferFrom(from, to, tokenId);
    }
}

/// @notice Contract caller that rejects native refunds.
contract EthRejecter {
    function callRequestDraw(IRaffle raffle) external payable returns (uint256) {
        return raffle.requestDraw{ value: msg.value }();
    }

    receive() external payable {
        revert("no ETH");
    }
}

/// @notice Minimal fixed-price NFT marketplace (models an OpenSea/Blur listing of a raffle ticket).
contract FixedPriceMarket {
    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    function list(IERC721 collection, uint256 tokenId, uint256 price) external {
        require(collection.ownerOf(tokenId) == msg.sender, "not owner");
        listings[address(collection)][tokenId] = Listing(msg.sender, price);
    }

    function buy(IERC721 collection, uint256 tokenId) external payable {
        Listing memory l = listings[address(collection)][tokenId];
        require(l.seller != address(0) && msg.value == l.price, "bad listing");
        delete listings[address(collection)][tokenId];
        collection.transferFrom(l.seller, msg.sender, tokenId);
        (bool ok,) = l.seller.call{ value: msg.value }("");
        require(ok, "pay seller");
    }
}

/// @notice Force-sends ETH with SELFDESTRUCT (EIP-6780: code survives, balance still moves).
contract ForceSender {
    constructor() payable { }

    function boom(address payable to) external {
        selfdestruct(to);
    }
}
