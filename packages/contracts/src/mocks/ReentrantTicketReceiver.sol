// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../Raffle.sol";

/// @title ReentrantTicketReceiver
/// @notice Adversarial receiver that attempts a nested purchase from a ticket-mint callback.
contract ReentrantTicketReceiver is IERC721Receiver {
    /// @notice Raffle targeted by callback reentry attempts.
    Raffle public raffle;
    /// @notice Whether a ticket-mint callback should attempt a nested purchase.
    bool public attackMint;
    /// @notice Whether the most recent attempted nested call was rejected.
    bool public reentryBlocked;

    /// @notice Configures the target and ticket-mint attack mode.
    /// @param raffle_ Target raffle.
    /// @param attackMint_ Enables purchase reentry.
    function configure(Raffle raffle_, bool attackMint_) external {
        raffle = raffle_;
        attackMint = attackMint_;
        reentryBlocked = false;
    }

    /// @notice Approves the target raffle to spend this receiver's quote balance.
    /// @param quote Quote token.
    function approveQuote(IERC20 quote) external {
        quote.approve(address(raffle), type(uint256).max);
    }

    /// @notice Purchases one entry ticket owned by this receiver.
    function buyTicket() external {
        raffle.buyEntries(address(this), 1);
    }

    /// @notice Attempts the configured nested action and always remains able to receive the NFT.
    /// @return selector ERC721 receiver selector.
    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4 selector) {
        if (msg.sender == address(raffle) && attackMint) {
            attackMint = false;
            try raffle.buyEntries(address(this), 1) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
        selector = IERC721Receiver.onERC721Received.selector;
    }
}
