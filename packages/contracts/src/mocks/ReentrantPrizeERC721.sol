// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import { IRaffleFactory } from "../interfaces/IRaffleFactory.sol";

/// @title ReentrantPrizeERC721
/// @notice Adversarial prize contract that attempts nested factory creation during escrow transfer.
contract ReentrantPrizeERC721 is ERC721 {
    /// @notice Factory targeted by the nested creation attempt.
    IRaffleFactory public factory;
    /// @notice Whether the next factory-operated transfer should attack.
    bool public attackEnabled;
    /// @notice Whether factory reentrancy protection rejected the nested creation.
    bool public reentryBlocked;
    /// @notice Secondary token used by the nested creation attempt.
    uint256 public nestedPrizeTokenId;

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
        attackEnabled = true;
        reentryBlocked = false;
    }

    /// @notice Attempts nested creation before completing the outer transfer.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (attackEnabled && msg.sender == address(factory)) {
            attackEnabled = false;
            try factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    prizeToken: address(this),
                    prizeTokenId: nestedPrizeTokenId,
                    quoteToken: factory.verifiedQuoteTokenAt(0),
                    sponsorPrizeRecoveryRecipient: address(0),
                    ticketPrice: 1e6,
                    minimumTickets: 1,
                    startTime: block.timestamp,
                    endTime: block.timestamp + 1 days,
                    metadataURI: "ipfs://nested"
                })
            ) {
                reentryBlocked = false;
            } catch {
                reentryBlocked = true;
            }
        }
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
