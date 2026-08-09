// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../Raffle.sol";

/// @title ReentrantTicketReceiver
/// @notice Adversarial receiver that attempts nested purchases and prize claims from ERC721 callbacks.
contract ReentrantTicketReceiver is IERC721Receiver {
    /// @notice Raffle targeted by callback reentry attempts.
    Raffle public raffle;
    /// @notice Whether a ticket-mint callback should attempt a nested purchase.
    bool public attackMint;
    /// @notice Whether a prize-receipt callback should attempt a second prize claim.
    bool public attackPrize;
    /// @notice Whether the most recent attempted nested call was rejected.
    bool public reentryBlocked;

    /// @notice Configures the target and callback attack modes.
    /// @param raffle_ Target raffle.
    /// @param attackMint_ Enables purchase reentry.
    /// @param attackPrize_ Enables prize-claim reentry.
    function configure(Raffle raffle_, bool attackMint_, bool attackPrize_) external {
        raffle = raffle_;
        attackMint = attackMint_;
        attackPrize = attackPrize_;
        reentryBlocked = false;
    }

    /// @notice Approves the target raffle to spend this receiver's quote balance.
    /// @param quote Quote token.
    function approveQuote(IERC20 quote) external {
        quote.approve(address(raffle), type(uint256).max);
    }

    /// @notice Purchases one ticket owned by this receiver.
    function buyTicket() external {
        raffle.buyTickets(address(this), 1);
    }

    /// @notice Executes the receiver's authorized prize claim.
    function executePrizeClaim() external {
        raffle.redeemWinningTicket(address(this));
    }

    /// @notice Attempts the configured nested action and always remains able to receive the NFT.
    /// @param tokenId Received token ID.
    /// @return selector ERC721 receiver selector.
    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4 selector)
    {
        if (msg.sender == address(raffle) && attackMint) {
            attackMint = false;
            try raffle.buyTickets(address(this), 1) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        } else if (msg.sender == address(raffle.prizeToken()) && tokenId == raffle.prizeTokenId() && attackPrize) {
            attackPrize = false;
            try raffle.redeemWinningTicket(address(this)) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
        selector = IERC721Receiver.onERC721Received.selector;
    }
}
