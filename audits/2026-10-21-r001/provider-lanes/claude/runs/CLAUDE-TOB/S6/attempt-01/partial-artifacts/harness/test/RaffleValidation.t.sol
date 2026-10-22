// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Raffle } from "raffle/Raffle.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";

import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { Fixture } from "./RaffleUnit.t.sol";

contract SevenDecimals {
    function decimals() external pure returns (uint8) {
        return 7;
    }
}

contract NoDecimals { }

/// @notice "Prize" that supports ERC-165/721 detection but never moves anything: it calls the receiver hook itself and
///         reports whatever owner the raffle expects. Models a malicious prize contract chosen by a sponsor.
contract FakeEscrowNFT {
    mapping(uint256 => address) public fakeOwner;

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function mint(address to, uint256 id) external {
        fakeOwner[id] = to;
    }

    function approve(address, uint256) external { }

    function safeTransferFrom(address from, address to, uint256 id) external {
        require(
            IERC721Receiver(to).onERC721Received(msg.sender, from, id, "") == IERC721Receiver.onERC721Received.selector,
            "hook"
        );
        fakeOwner[id] = to; // bookkeeping only; nothing of value exists
    }

    function transferFrom(address, address to, uint256 id) external {
        fakeOwner[id] = to;
    }

    function ownerOf(uint256 id) external view returns (address) {
        return fakeOwner[id];
    }
}

/// @notice ERC-721 whose safeTransferFrom skips the receiver hook (non-compliant) - escrow must be rejected.
contract NoHookNFT is MockPrizeNFT {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) public override {
        transferFrom(from, to, tokenId);
    }
}

/// ===================================================================================================================
/// H. Validation paths not exercised by scenario tests (defensive reverts)
/// ===================================================================================================================
contract H_ValidationTest is Fixture {
    function test_H1_factoryConstructorValidation() public {
        SevenDecimals seven = new SevenDecimals();
        NoDecimals none = new NoDecimals();
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.InvalidQuoteTokenDecimals.selector, uint8(7), uint8(6)));
        new RaffleFactory(address(seven), address(wrapper), TREASURY);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedQuoteToken.selector, address(none)));
        new RaffleFactory(address(none), address(wrapper), TREASURY);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, address(0xbeef)));
        new RaffleFactory(address(0xbeef), address(wrapper), TREASURY);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(usdc)));
        new RaffleFactory(address(usdc), address(wrapper), address(usdc));
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(wrapper)));
        new RaffleFactory(address(usdc), address(wrapper), address(wrapper));
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        new RaffleFactory(address(usdc), address(wrapper), address(0));
    }

    function test_H2_prizeContractAsSponsorIsRejectedAtInitialize() public {
        uint256 id = 9;
        nft.mint(address(nft), id); // the prize contract itself owns the token and acts as sponsor
        vm.prank(address(nft));
        nft.setApprovalForAll(address(factory), true);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(nft)));
        vm.prank(address(nft));
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: sponsorRecipient,
                prizeToken: address(nft),
                prizeTokenId: id,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
    }

    function test_H3_unsolicitedSafeTransferToActiveRaffleRejected() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        nft.mint(alice, 555);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnexpectedPrize.selector, address(nft), 555, alice, alice));
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(r), 555);
    }

    function test_H4_nonCompliantPrizeWithoutHookCannotEscrow() public {
        NoHookNFT bad = new NoHookNFT();
        uint256 id = 1;
        bad.mint(sponsor, id);
        vm.prank(sponsor);
        bad.approve(address(factory), id);
        uint64 n = vm.getNonce(address(factory));
        address predicted = _createAddr(address(factory), n);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.PrizeEscrowVerificationFailed.selector, predicted, address(bad), id)
        );
        vm.prank(sponsor);
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: sponsorRecipient,
                prizeToken: address(bad),
                prizeTokenId: id,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
    }

    /// Root cause behind TOB-S6-3: escrow and delivery checks are self-reported by the prize contract. A lying prize
    /// passes creation, the raffle sells entries, the "winner" redeems nothing, and the sponsor collects 95%.
    function test_H5_PoC_lyingPrizeFakesEscrowAndDelivery() public {
        FakeEscrowNFT fake = new FakeEscrowNFT();
        fake.mint(sponsor, 1);
        vm.prank(sponsor);
        Raffle r = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsorRecipient,
                        prizeToken: address(fake),
                        prizeTokenId: 1,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                )
            )
        );
        assertTrue(r.status() == IRaffle.Status.Active, "fake escrow accepted");
        _buy(r, alice, alice, 100);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        vm.prank(alice);
        r.redeemWinningTicket(1); // "delivery" succeeds: ownerOf reports alice
        r.releaseSponsorProceeds();
        assertEq(usdc.balanceOf(sponsorRecipient), 95e6, "sponsor paid 95% for a prize that never existed");
    }

    function test_H6_doubleClaimsAndWrongStateClaimsRevert() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 2);
        vm.expectRevert(IRaffle.NoSponsorProceeds.selector);
        r.releaseSponsorProceeds();
        vm.expectRevert(IRaffle.NoProtocolFees.selector);
        r.releaseProtocolFees();
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SponsorPrizeUnavailable.selector, IRaffle.Status.NftWon));
        r.releaseSponsorPrize();
        r.settleWinningTicket(1);
        vm.expectRevert(IRaffle.SettlementAlreadyComplete.selector);
        r.settleWinningTicket(1);
        vm.prank(alice);
        r.redeemWinningTicket(1);
        vm.expectRevert(IRaffle.WinningTicketAlreadyRedeemed.selector);
        vm.prank(alice);
        r.redeemWinningTicket(1);
        Raffle c = _create(sponsor, sponsorRecipient, 10, 1 days);
        _buy(c, bob, bob, 1);
        vm.warp(c.endTime());
        _fulfill(_request(c), 0);
        c.releaseSponsorPrize();
        vm.expectRevert(IRaffle.PrizeAlreadyClaimed.selector);
        c.releaseSponsorPrize();
        assertEq(r.estimateVrfRequestPrice(7), wrapper.priceNative() + 7, "estimate passthrough");
        assertEq(address(r.vrfWrapper()), address(wrapper), "wrapper getter");
        assertTrue(keccak256(bytes(r.name())) == keccak256("raffle.fun Ticket") && keccak256(bytes(r.symbol())) == keccak256("RAFFLE"), "metadata");
    }
}
