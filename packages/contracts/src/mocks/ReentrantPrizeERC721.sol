// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { IRaffle } from "../interfaces/IRaffle.sol";
import { IRaffleFactory } from "../interfaces/IRaffleFactory.sol";

/// @title ReentrantPrizeERC721
/// @notice Adversarial prize that attempts nested factory creation or winning-ticket redemption.
contract ReentrantPrizeERC721 is ERC721, IERC721Receiver {
    enum AttackKind {
        None,
        FactoryCreation,
        WinnerTransfer,
        SponsorSafeTransfer
    }

    /// @notice Factory targeted by the nested creation attempt.
    IRaffleFactory public factory;
    /// @notice Whether the next factory-operated transfer should attack.
    bool public attackEnabled;
    /// @notice Whether factory reentrancy protection rejected the nested creation.
    bool public reentryBlocked;
    /// @notice Secondary token used by the nested creation attempt.
    uint256 public nestedPrizeTokenId;
    /// @notice Active attack path.
    AttackKind public attackKind;
    /// @notice Raffle targeted by a redemption reentry attempt.
    IRaffle public targetRaffle;
    /// @notice Ticket supplied to a nested winning-ticket redemption attempt.
    uint256 public targetTicketId;
    /// @notice Current ticket owner used as the only allowed third-party destination.
    address public targetWinner;
    /// @notice Number of nested redemption calls attempted.
    uint256 public reentryAttempts;
    /// @notice Number of nested calls rejected by the target.
    uint256 public reentryBlocks;
    /// @notice Selector returned by the most recent nested-call revert.
    bytes4 public reentrySelector;

    /// @notice Creates the adversarial prize collection.
    constructor() ERC721("Reentrant Prize", "RPRIZE") { }

    /// @notice Mints a chosen test token.
    /// @param to Recipient.
    /// @param tokenId Token ID.
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /// @notice Arms a nested creation attempt funded by a token owned by this contract.
    /// @param factory_ Target factory.
    /// @param tokenId Secondary prize token ID.
    function arm(IRaffleFactory factory_, uint256 tokenId) external {
        factory = factory_;
        nestedPrizeTokenId = tokenId;
        _mint(address(this), tokenId);
        _setApprovalForAll(address(this), address(factory_), true);
        attackKind = AttackKind.FactoryCreation;
        attackEnabled = true;
        reentryBlocked = false;
    }

    /// @notice Arms reentry from the winner-prize release `transferFrom` hook.
    function armWinnerTransfer(IRaffle raffle_, uint256 ticketId_, address winner_) external {
        _armSettlement(AttackKind.WinnerTransfer, raffle_, ticketId_, winner_);
    }

    /// @notice Arms reentry from both sponsor `safeTransferFrom` and its receiver callback.
    function armSponsorSafeTransfer(IRaffle raffle_, uint256 ticketId_, address winner_) external {
        _armSettlement(AttackKind.SponsorSafeTransfer, raffle_, ticketId_, winner_);
    }

    /// @notice Attempts redemption reentry before a winner-prize delivery completes.
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (
            attackEnabled && (attackKind == AttackKind.WinnerTransfer || attackKind == AttackKind.SponsorSafeTransfer)
                && msg.sender == address(targetRaffle)
        ) {
            attackEnabled = false;
            _attemptRedemptionReentry();
        }
        super.transferFrom(from, to, tokenId);
    }

    /// @notice Attempts nested creation before completing the outer transfer.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (attackEnabled && attackKind == AttackKind.FactoryCreation && msg.sender == address(factory)) {
            attackEnabled = false;
            try factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: address(0xBEEF),
                    prizeToken: address(this),
                    prizeTokenId: nestedPrizeTokenId,
                    reserveEntries: 1,
                    endTime: uint64(block.timestamp + 1 days)
                })
            ) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        } else if (attackEnabled && attackKind == AttackKind.SponsorSafeTransfer && msg.sender == address(targetRaffle))
        {
            _attemptRedemptionReentry();
        }
        super.safeTransferFrom(from, to, tokenId, data);
        if (attackKind == AttackKind.SponsorSafeTransfer) attackEnabled = false;
    }

    /// @notice Attempts nested settlement from the sponsor delivery receiver callback.
    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        if (attackEnabled && attackKind == AttackKind.SponsorSafeTransfer) {
            _attemptRedemptionReentry();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function _armSettlement(AttackKind kind, IRaffle raffle_, uint256 ticketId_, address winner_) private {
        attackKind = kind;
        targetRaffle = raffle_;
        targetTicketId = ticketId_;
        targetWinner = winner_;
        attackEnabled = true;
        reentryBlocked = false;
        reentryAttempts = 0;
        reentryBlocks = 0;
        reentrySelector = bytes4(0);
    }

    function _attemptRedemptionReentry() private {
        ++reentryAttempts;
        try targetRaffle.redeemWinningTicket(targetTicketId) {
            reentryBlocked = false;
        } catch (bytes memory reason) {
            reentryBlocked = true;
            ++reentryBlocks;
            if (reason.length >= 4) {
                bytes4 selector;
                assembly ("memory-safe") {
                    selector := mload(add(reason, 0x20))
                }
                reentrySelector = selector;
            }
        }
    }
}
