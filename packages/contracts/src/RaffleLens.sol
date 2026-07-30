// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { IRaffleLens } from "./interfaces/IRaffleLens.sol";

/// @title RaffleLens
/// @notice Stateless read-only aggregator that accepts only factory-registered raffle clones.
contract RaffleLens is IRaffleLens {
    /// @notice Maximum raffle count accepted by one aggregate view call.
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @notice Canonical factory used for registration checks and identifiers.
    IRaffleFactory public immutable factory;

    /// @notice Binds this lens to one factory version.
    /// @param factory_ Canonical deployed factory with runtime code.
    constructor(address factory_) {
        if (factory_ == address(0) || factory_.code.length == 0) revert InvalidFactory(factory_);
        factory = IRaffleFactory(factory_);
    }

    /// @inheritdoc IRaffleLens
    function getRaffleState(address raffle, address account)
        external
        view
        override
        returns (RaffleView memory raffleView)
    {
        raffleView = _getRaffleState(raffle, account);
    }

    /// @inheritdoc IRaffleLens
    function getRaffleStates(address[] calldata raffles, address account)
        external
        view
        override
        returns (RaffleView[] memory raffleViews)
    {
        uint256 length = raffles.length;
        if (length > MAX_BATCH_SIZE) revert BatchTooLarge(length, MAX_BATCH_SIZE);

        raffleViews = new RaffleView[](length);
        for (uint256 i; i < length; ++i) {
            raffleViews[i] = _getRaffleState(raffles[i], account);
        }
    }

    /// @dev Registration is checked before any untrusted external read, preventing arbitrary custody-like forwarding.
    function _getRaffleState(address raffleAddress, address account) internal view returns (RaffleView memory view_) {
        if (!factory.isRaffle(raffleAddress)) revert UnregisteredRaffle(raffleAddress);
        IRaffle raffle = IRaffle(raffleAddress);

        IRaffle.RaffleState raffleState = raffle.state();
        address claimant = raffle.prizeClaimant();
        uint256 quoteClaim = account == address(0) ? 0 : raffle.claimableQuote(account);

        view_ = RaffleView({
            factoryId: factory.idByRaffle(raffleAddress),
            registered: true,
            raffle: raffleAddress,
            state: raffleState,
            outcome: raffle.outcome(),
            sponsor: raffle.sponsor(),
            protocolTreasury: raffle.protocolTreasury(),
            quoteToken: address(raffle.quoteToken()),
            prizeToken: address(raffle.prizeToken()),
            prizeTokenId: raffle.prizeTokenId(),
            ticketPrice: raffle.ticketPrice(),
            minimumTickets: raffle.minimumTickets(),
            startTime: raffle.startTime(),
            endTime: raffle.endTime(),
            totalTickets: raffle.totalTickets(),
            grossSales: raffle.grossSales(),
            netPot: raffle.netPot(),
            winningTicketId: raffle.winningTicketId(),
            winner: raffle.winner(),
            accountTicketBalance: account == address(0) ? 0 : IERC721(raffleAddress).balanceOf(account),
            accountQuoteClaim: quoteClaim,
            accountIsPrizeClaimant: account != address(0) && account == claimant,
            entropyFee: raffle.getEntropyFee(),
            canBuy: raffle.isOpen(),
            canDraw: raffle.canRequestDraw(),
            canClaimQuote: quoteClaim != 0,
            canClaimPrize: account != address(0) && account == claimant && !raffle.prizeClaimed()
                && (raffleState == IRaffle.RaffleState.Resolved || raffleState == IRaffle.RaffleState.Cancelled)
        });
    }
}
