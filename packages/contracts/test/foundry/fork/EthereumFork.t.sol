// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IChainlinkVRFV2PlusWrapper } from "../../../src/interfaces/IChainlinkVRFV2PlusWrapper.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";

contract EthereumForkTest is Test {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_VRF_WRAPPER = 0x02aae1A04f9828517b3007f83f6181900CaD910c;
    address internal constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address internal constant SEPOLIA_VRF_WRAPPER = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;

    address internal sponsor = makeAddr("fork-sponsor");
    address internal buyer = makeAddr("fork-buyer");
    address internal treasury = makeAddr("fork-treasury");

    function setUp() public {
        if (!vm.envOr("RUN_LATEST_FORK_TESTS", false)) vm.skip(true);
    }

    function testEthereumMainnetChainlinkVrfUsdcAndRangeReceipt() public {
        _validateFork(
            vm.envString("ETHEREUM_RPC_URL"),
            vm.envOr("ETHEREUM_FORK_BLOCK", uint256(0)),
            1,
            MAINNET_VRF_WRAPPER,
            MAINNET_USDC
        );
    }

    function testEthereumSepoliaChainlinkVrfUsdcAndRangeReceipt() public {
        _validateFork(
            vm.envString("SEPOLIA_RPC_URL"),
            vm.envOr("SEPOLIA_FORK_BLOCK", uint256(0)),
            11_155_111,
            SEPOLIA_VRF_WRAPPER,
            SEPOLIA_USDC
        );
    }

    function _validateFork(
        string memory rpcUrl,
        uint256 forkBlock,
        uint256 expectedChainId,
        address wrapperAddress,
        address usdc
    ) internal {
        if (forkBlock == 0) vm.createSelectFork(rpcUrl);
        else vm.createSelectFork(rpcUrl, forkBlock);
        vm.txGasPrice(1 gwei);

        assertEq(block.chainid, expectedChainId);
        assertGt(wrapperAddress.code.length, 0);
        assertGt(usdc.code.length, 0);
        assertEq(IERC20Metadata(usdc).decimals(), 6);
        assertGt(IChainlinkVRFV2PlusWrapper(wrapperAddress).calculateRequestPriceNative(300_000, 1), 0);

        MockERC721 prize = new MockERC721();
        RaffleFactory factory = new RaffleFactory(usdc, wrapperAddress, treasury, address(this));
        assertEq(factory.callbackGasLimit(), 300_000);
        assertEq(factory.requestConfirmations(), 30);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);

        Raffle empty = _create(factory, prize, 1, 1, uint64(block.timestamp + 1 days));
        vm.prank(sponsor);
        empty.enableRefunds();
        vm.prank(sponsor);
        empty.releaseSponsorPrize();
        assertEq(prize.ownerOf(1), sponsor);

        Raffle raffle = _create(factory, prize, 2, 3, uint64(block.timestamp + 1));
        deal(usdc, buyer, 2e6, true);
        uint256 buyerBefore = IERC20(usdc).balanceOf(buyer);
        vm.startPrank(buyer);
        IERC20(usdc).approve(address(raffle), 2e6);
        uint256 receiptId = raffle.buyEntries(buyer, 2);
        vm.stopPrank();

        (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(receiptId);
        assertEq(firstEntry, 1);
        assertEq(lastEntry, 2);
        assertEq(raffle.ticketCount(), 1);
        assertEq(raffle.totalEntries(), 2);
        assertEq(buyerBefore - IERC20(usdc).balanceOf(buyer), 2e6);

        vm.warp(raffle.endTime());
        uint256 fee = raffle.getVrfRequestPrice();
        vm.deal(address(this), fee);
        uint256 requestId = raffle.requestDraw{ value: fee }();
        assertGt(requestId, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;
        vm.expectPartialRevert(IRaffle.OnlyVRFWrapperCanFulfill.selector);
        raffle.rawFulfillRandomWords(requestId, randomWords);
    }

    function _create(RaffleFactory factory, MockERC721 prize, uint256 tokenId, uint128 reserveEntries, uint64 endTime)
        internal
        returns (Raffle raffle)
    {
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        reserveEntries: reserveEntries,
                        endTime: endTime
                    })
                ))
        );
    }
}
