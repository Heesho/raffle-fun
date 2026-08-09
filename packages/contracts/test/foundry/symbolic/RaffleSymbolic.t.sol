// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

/// @notice Focused Halmos checks over a concrete one-ticket production raffle and symbolic randomness.
contract RaffleSymbolicTest is Test, IERC721Receiver {
    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;
    address internal treasury = address(0x5151);

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        entropy.setFee(0);
        prize.mint(address(this), 1);
        raffle = new Raffle(
            IRaffle.RaffleParams({
                factory: address(this),
                sponsor: address(this),
                sponsorPrizeRecoveryRecipient: address(0xBEEF),
                protocolTreasury: treasury,
                quoteToken: address(quote),
                entropy: address(entropy),
                prizeToken: address(prize),
                prizeTokenId: 1,
                raffleId: 1,
                ticketPrice: 1e6,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1,
                callbackGasLimit: 300_000,
                metadataURI: "ipfs://symbolic"
            })
        );
        prize.safeTransferFrom(address(this), address(raffle), 1);
        quote.mint(address(this), 1e6);
        quote.approve(address(raffle), 1e6);
        raffle.buyTickets(address(this), 1);
    }

    function check_oneTicketAlwaysSelected(bytes32 randomNumber) public {
        uint64 sequence = _request();
        entropy.fulfill(sequence, randomNumber);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.winningTicketId(), 1);
    }

    function check_resolutionExcludesTimeout(bytes32 randomNumber) public {
        uint64 sequence = _request();
        entropy.fulfill(sequence, randomNumber);
        vm.warp(raffle.callbackDeadline());
        (bool success,) = address(raffle).call(abi.encodeCall(IRaffle.enableRefunds, ()));
        assertFalse(success);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.claimableQuote(treasury), 50_000);
        assertEq(raffle.remainingRefundLiability(), 0);
    }

    function check_timeoutExcludesLateCallback(bytes32 randomNumber) public {
        uint64 sequence = _request();
        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();
        entropy.fulfill(sequence, randomNumber);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        assertEq(raffle.winningTicketId(), 0);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.remainingRefundLiability(), 1e6);
    }

    function check_winnerCredentialConsumesAtMostOnce(bytes32 randomNumber) public {
        uint64 sequence = _request();
        entropy.fulfill(sequence, randomNumber);
        raffle.redeemWinningTicket(address(this));
        (bool success,) = address(raffle).call(abi.encodeCall(IRaffle.redeemWinningTicket, (address(this))));
        assertFalse(success);
        assertTrue(raffle.prizeClaimed());
        assertEq(prize.ownerOf(1), address(this));
    }

    function check_refundCredentialConsumesAtMostOnce() public {
        vm.warp(raffle.requestGraceDeadline());
        raffle.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        raffle.redeemRefundTickets(ids, address(this));
        (bool success,) = address(raffle).call(abi.encodeCall(IRaffle.redeemRefundTickets, (ids, address(this))));
        assertFalse(success);
        assertEq(raffle.remainingRefundLiability(), 0);
        assertEq(raffle.accountedQuoteBalance(), 0);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _request() internal returns (uint64 sequence) {
        vm.warp(raffle.endTime());
        sequence = raffle.requestDraw();
    }
}
