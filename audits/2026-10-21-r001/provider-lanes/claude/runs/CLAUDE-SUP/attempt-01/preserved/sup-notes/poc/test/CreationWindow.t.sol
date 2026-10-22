// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract EvilSponsor {
    function go(RaffleFactory f, address prize, uint256 id, address rcpt, uint64 end) external returns (address) {
        return f.createRaffle(IRaffleFactory.CreateRaffleParams(rcpt, prize, id, 1, end));
    }

    function cancel(Raffle r) external {
        r.enableRefunds();
    }
}

/// Lying prize: fakes the receiver callback, drives the clone to Refunding + prize release via the sponsor
/// contract during createRaffle, then restores ownerOf()==clone so only the factory's status check remains.
contract LyingPrize {
    EvilSponsor internal s;
    mapping(uint256 => address) internal owner_;

    function setSponsor(EvilSponsor s_) external {
        s = s_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function ownerOf(uint256 id) external view returns (address) {
        return owner_[id];
    }

    function transferFrom(address, address to, uint256 id) external {
        owner_[id] = to;
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        owner_[id] = to;
        IERC721Receiver(to).onERC721Received(msg.sender, from, id, "");
        s.cancel(Raffle(payable(to))); // sponsor early-close of the still-empty clone -> Refunding
        Raffle(payable(to)).releaseSponsorPrize(); // "returns" prize
        owner_[id] = to; // lie again so the factory's ownerOf check passes
    }
}

contract CreationWindowTest is Base {
    function test_factoryStatusCheckCatchesForcedTransition() public {
        LyingPrize p = new LyingPrize();
        EvilSponsor s = new EvilSponsor();
        p.setSponsor(s);
        address predicted = _computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.PrizeEscrowVerificationFailed.selector, predicted, address(p), 7)
        );
        s.go(factory, address(p), 7, recipient, uint64(T0 + 1 days));
        require(factory.raffleCount() == 0 && !factory.isRaffle(predicted), "nothing registered");
    }
}
