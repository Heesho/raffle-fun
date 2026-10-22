// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";

import { S6TestBase } from "./S6TestBase.sol";
import { HonestPrize, MockQuoteToken, MockVrfWrapper } from "./S6Mocks.sol";

contract S6PurchaseHandler is IERC721Receiver {
    MockQuoteToken public immutable quote;
    Raffle public immutable raffle;
    uint256 public calls;

    constructor(MockQuoteToken quote_, Raffle raffle_) {
        quote = quote_;
        raffle = raffle_;
        quote_.approve(address(raffle_), type(uint256).max);
    }

    function buy(uint128 rawEntries) external {
        uint128 entries = uint128(uint256(rawEntries) % 1_000 + 1);
        raffle.buyEntries(address(this), entries);
        ++calls;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract S6InvariantTest is S6TestBase {
    uint256 internal constant ENTRY_PRICE = 1_000_000;
    address internal constant SPONSOR_RECIPIENT = address(0x6200);
    address internal constant TREASURY = address(0x6300);

    MockQuoteToken internal quote;
    MockVrfWrapper internal wrapper;
    RaffleFactory internal factory;
    HonestPrize internal prize;
    Raffle internal raffle;
    S6PurchaseHandler internal handler;
    address[] private _targetedContracts;

    function setUp() public {
        quote = new MockQuoteToken();
        wrapper = new MockVrfWrapper(address(quote));
        factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        prize = new HonestPrize();
        prize.mint(address(this), 1);
        prize.approve(address(factory), 1);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: SPONSOR_RECIPIENT,
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        reserveEntries: type(uint128).max,
                        endTime: uint64(block.timestamp + 30 days)
                    })
                )
            )
        );
        handler = new S6PurchaseHandler(quote, raffle);
        quote.mint(address(handler), uint256(type(uint128).max) * ENTRY_PRICE);
        _targetedContracts.push(address(handler));
    }

    function targetContracts() external view returns (address[] memory) {
        return _targetedContracts;
    }

    function invariant_RangesRemainAContiguousPartition() public view {
        uint256 tickets = raffle.ticketCount();
        uint256 expectedFirst = 1;
        for (uint256 ticketId = 1; ticketId <= tickets; ++ticketId) {
            (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(ticketId);
            assertEq(firstEntry, expectedFirst, "range begins after predecessor");
            assertTrue(lastEntry >= firstEntry, "range nonempty");
            assertEq(raffle.ownerOf(ticketId), address(handler), "handler owns live ticket");
            expectedFirst = uint256(lastEntry) + 1;
        }
        assertEq(expectedFirst - 1, raffle.totalEntries(), "partition ends at totalEntries");
        assertEq(tickets, handler.calls(), "one ticket per successful action");
    }

    function invariant_ActiveSalesAccountingMatchesCustodyAndGross() public view {
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active), "sales remain active");
        assertEq(raffle.unsettledPot(), raffle.grossSales(), "unsettled equals lifetime sales");
        assertEq(raffle.accountedQuoteBalance(), raffle.grossSales(), "liability equals lifetime sales");
        assertEq(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance(), "custody covers liability");
        assertTrue(raffle.ticketCount() <= raffle.totalEntries(), "each ticket represents at least one entry");
    }

    function invariant_NoTerminalLiabilitiesDuringActiveSales() public view {
        assertEq(raffle.remainingRefundLiability(), 0, "no refunds allocated");
        assertEq(raffle.winnerProceeds(), 0, "no winner allocated");
        assertEq(raffle.sponsorProceeds(), 0, "no sponsor allocated");
        assertEq(raffle.protocolFees(), 0, "no protocol allocated");
        assertFalse(raffle.settlementComplete(), "not settled");
        assertFalse(raffle.winnerRedeemed(), "not redeemed");
        assertFalse(raffle.prizeClaimed(), "prize remains escrowed");
    }
}
