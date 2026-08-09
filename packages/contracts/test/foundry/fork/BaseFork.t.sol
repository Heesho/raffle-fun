// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropyV2 } from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";

contract BaseForkTest is Test {
    address internal sponsor = makeAddr("fork-sponsor");
    address internal buyer = makeAddr("fork-buyer");
    address internal treasury = makeAddr("fork-treasury");

    function setUp() public {
        if (!vm.envOr("RUN_FORK_TESTS", false)) vm.skip(true);
    }

    function testBaseMainnetPythUsdcAndPrizeLifecycleAtPinnedBlock() public {
        _validateFork(
            vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")),
            49_752_968,
            8453,
            0x6E7D74FA7d5c90FEF9F0512987605a6d546181Bb,
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        );
    }

    function testBaseSepoliaPythUsdcAndPrizeLifecycleAtPinnedBlock() public {
        _validateFork(
            vm.envOr("BASE_SEPOLIA_RPC_URL", string("https://sepolia.base.org")),
            45_263_498,
            84_532,
            0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c,
            0x036CbD53842c5426634e7929541eC2318f3dCF7e
        );
    }

    function _validateFork(
        string memory rpcUrl,
        uint256 forkBlock,
        uint256 expectedChainId,
        address entropyAddress,
        address usdc
    ) internal {
        vm.createSelectFork(rpcUrl, forkBlock);
        assertEq(block.chainid, expectedChainId);
        assertGt(entropyAddress.code.length, 0);
        assertGt(usdc.code.length, 0);
        assertEq(IERC20Metadata(usdc).decimals(), 6);

        IEntropyV2 entropy = IEntropyV2(entropyAddress);
        assertNotEq(entropy.getDefaultProvider(), address(0));
        assertGt(entropy.getFeeV2(300_000), 0);

        MockERC721 prize = new MockERC721();
        RaffleFactory factory = new RaffleFactory(usdc, entropyAddress, treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);

        Raffle empty = _create(factory, prize, 1, block.timestamp + 1 days);
        vm.prank(sponsor);
        empty.closeEmptyRaffle();
        vm.prank(sponsor);
        empty.claimSponsorPrize(sponsor);
        assertEq(prize.ownerOf(1), sponsor);

        Raffle raffle = _create(factory, prize, 2, block.timestamp + 1);
        deal(usdc, buyer, 1e6, true);
        uint256 buyerBefore = IERC20(usdc).balanceOf(buyer);
        vm.startPrank(buyer);
        IERC20(usdc).approve(address(raffle), 1e6);
        raffle.buyTickets(buyer, 1);
        vm.stopPrank();
        assertEq(buyerBefore - IERC20(usdc).balanceOf(buyer), 1e6);
        assertEq(IERC20(usdc).balanceOf(address(raffle)), 1e6);

        vm.warp(raffle.endTime());
        uint256 fee = raffle.getEntropyFee();
        vm.deal(address(this), fee);
        uint64 sequence = raffle.requestDraw{ value: fee }();
        assertGt(sequence, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));

        address provider = entropy.getDefaultProvider();
        vm.expectRevert(bytes("Only Entropy can call this function"));
        IEntropyConsumer(address(raffle))._entropyCallback(sequence, provider, bytes32(uint256(1)));
    }

    function _create(RaffleFactory factory, MockERC721 prize, uint256 tokenId, uint256 endTime)
        internal
        returns (Raffle raffle)
    {
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: 1e6,
                        minimumTickets: 2,
                        startTime: block.timestamp,
                        endTime: endTime,
                        metadataURI: "ipfs://fork"
                    })
                )
            )
        );
    }
}
