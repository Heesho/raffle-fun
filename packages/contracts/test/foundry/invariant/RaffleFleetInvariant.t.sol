// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";
import { MultiActorRaffleHandler } from "./MultiActorRaffleHandler.sol";

contract RaffleFleetCrossHandler is Test {
    MockEntropyV2 public immutable entropy;
    RaffleFactory public immutable factory;
    Raffle[3] public raffles;

    address public immutable alternateTreasuryOne = address(0xF101);
    address public immutable alternateTreasuryTwo = address(0xF102);
    bool public siblingTransferSucceeded;

    constructor(MockEntropyV2 entropy_, RaffleFactory factory_, Raffle[3] memory raffles_) {
        entropy = entropy_;
        factory = factory_;
        raffles = raffles_;
    }

    function acceptFactoryOwnership() external {
        if (factory.pendingOwner() == address(this)) factory.acceptOwnership();
    }

    function attemptSiblingTransfer(uint256 sourceSeed, uint256 destinationSeed, uint256 ticketSeed) external {
        uint256 sourceIndex = sourceSeed % raffles.length;
        uint256 destinationIndex = destinationSeed % raffles.length;
        if (sourceIndex == destinationIndex) destinationIndex = (destinationIndex + 1) % raffles.length;

        Raffle source = raffles[sourceIndex];
        if (source.totalTickets() == 0) return;
        uint256 ticketId = bound(ticketSeed, 1, source.totalTickets());
        try source.ownerOf(ticketId) returns (address owner) {
            vm.prank(owner);
            try source.transferFrom(owner, address(raffles[destinationIndex]), ticketId) {
                siblingTransferSucceeded = true;
            } catch { }
        } catch { }
    }

    function churnFactoryPolicy(uint256 treasurySeed, bool paused) external {
        address nextTreasury = treasurySeed % 2 == 0 ? alternateTreasuryOne : alternateTreasuryTwo;
        try factory.setProtocolTreasury(nextTreasury) { } catch { }
        try factory.setCreationPaused(paused) { } catch { }
    }

    function attemptRegisteredRaffleAsTreasury(uint256 raffleSeed) external {
        try factory.setProtocolTreasury(address(raffles[raffleSeed % raffles.length])) { } catch { }
    }

    function varySharedEntropyFee(uint128 feeSeed) external {
        entropy.setFee(uint128(bound(uint256(feeSeed), 0, 10 ether)));
    }
}

contract RaffleFleetInvariantTest is StdInvariant, Test {
    uint256 internal constant USDC = 1e6;

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    RaffleFactory internal factory;
    Raffle[3] internal raffles;
    MultiActorRaffleHandler[3] internal handlers;
    RaffleFleetCrossHandler internal crossHandler;

    address internal sponsor = address(0xD001);
    address internal recovery = address(0xD002);
    address internal initialTreasury = address(0xD003);

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        factory = new RaffleFactory(address(quote), address(entropy), initialTreasury, 300_000, address(this));

        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        uint256[3] memory minimumTickets = [uint256(1), uint256(3), uint256(50)];
        for (uint256 index; index < raffles.length; ++index) {
            prize.mint(sponsor, index + 1);
            vm.prank(sponsor);
            raffles[index] = Raffle(
                payable(factory.createRaffle(
                        IRaffleFactory.CreateRaffleParams({
                            prizeToken: address(prize),
                            prizeTokenId: index + 1,
                            sponsorPrizeRecoveryRecipient: recovery,
                            ticketPrice: USDC,
                            minimumTickets: minimumTickets[index],
                            startTime: block.timestamp,
                            endTime: block.timestamp + 7 days,
                            metadataURI: "ipfs://fleet"
                        })
                    ))
            );
            handlers[index] = new MultiActorRaffleHandler(
                quote, prize, entropy, factory, raffles[index], sponsor, recovery, initialTreasury
            );
            for (uint256 buyerIndex; buyerIndex < 3; ++buyerIndex) {
                address account = handlers[index].buyers(buyerIndex);
                quote.mint(account, 1_000_000 * USDC);
                vm.prank(account);
                quote.approve(address(raffles[index]), type(uint256).max);
            }
            targetContract(address(handlers[index]));
        }

        crossHandler = new RaffleFleetCrossHandler(entropy, factory, raffles);
        factory.transferOwnership(address(crossHandler));
        crossHandler.acceptFactoryOwnership();
        targetContract(address(crossHandler));
    }

    function invariantFleetRegistryAndCapturedConfigurationNeverDrift() public view {
        assertEq(factory.raffleCount(), raffles.length);
        for (uint256 index; index < raffles.length; ++index) {
            Raffle raffle = raffles[index];
            assertEq(raffle.raffleId(), index + 1);
            assertEq(factory.raffleById(index + 1), address(raffle));
            assertEq(factory.idByRaffle(address(raffle)), index + 1);
            assertTrue(factory.isRaffle(address(raffle)));
            assertEq(raffle.factory(), address(factory));
            assertEq(address(raffle.quoteToken()), address(quote));
            assertEq(address(raffle.entropy()), address(entropy));
            assertEq(raffle.protocolTreasury(), initialTreasury);
        }
        assertFalse(crossHandler.siblingTransferSucceeded());
        assertFalse(factory.isRaffle(factory.protocolTreasury()));
    }

    function invariantFleetAccountingIsLocallyExactAndGloballySolvent() public view {
        uint256 totalActualBalance;
        uint256 totalAccountedBalance;
        for (uint256 index; index < raffles.length; ++index) {
            Raffle raffle = raffles[index];
            uint256 accounted = raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.winnerCashLiability()
                + raffle.totalClaimableQuote();
            uint256 actual = quote.balanceOf(address(raffle));
            assertEq(raffle.accountedQuoteBalance(), accounted);
            assertGe(actual, accounted);
            assertEq(raffle.grossSales(), raffle.totalTickets() * raffle.ticketPrice());
            totalActualBalance += actual;
            totalAccountedBalance += accounted;
        }
        assertGe(totalActualBalance, totalAccountedBalance);
    }

    function invariantFleetTicketsStayInsideTheirOwnLifecycleAndKnownOwners() public view {
        address[6] memory accounts =
            [address(0xB001), address(0xB002), address(0xB003), address(0xC001), address(0xC002), address(0xC003)];

        for (uint256 raffleIndex; raffleIndex < raffles.length; ++raffleIndex) {
            Raffle raffle = raffles[raffleIndex];
            uint256 liveTickets;
            for (uint256 ticketId = 1; ticketId <= raffle.totalTickets(); ++ticketId) {
                try raffle.ownerOf(ticketId) returns (address owner) {
                    ++liveTickets;
                    for (uint256 siblingIndex; siblingIndex < raffles.length; ++siblingIndex) {
                        assertNotEq(owner, address(raffles[siblingIndex]));
                    }
                } catch { }
            }

            uint256 summedBalances;
            for (uint256 accountIndex; accountIndex < accounts.length; ++accountIndex) {
                summedBalances += raffle.balanceOf(accounts[accountIndex]);
            }
            assertEq(liveTickets, summedBalances);

            uint256 winner = raffle.winningTicketId();
            if (winner == 0) {
                IRaffle.Status current = raffle.status();
                assertTrue(
                    current == IRaffle.Status.Active || current == IRaffle.Status.Drawing
                        || current == IRaffle.Status.Refunding || current == IRaffle.Status.Closed
                );
            } else {
                assertGe(winner, 1);
                assertLe(winner, raffle.totalTickets());
            }
        }
    }

    function invariantFleetStatusAndPrizeEscrowsAreIndependent() public view {
        for (uint256 index; index < raffles.length; ++index) {
            Raffle raffle = raffles[index];
            assertFalse(handlers[index].statusWentBackward());
            if (!raffle.prizeClaimed()) assertEq(prize.ownerOf(index + 1), address(raffle));
            else assertEq(prize.ownerOf(index + 1), handlers[index].prizeReceiver());

            for (uint256 siblingIndex; siblingIndex < raffles.length; ++siblingIndex) {
                if (siblingIndex != index) assertNotEq(prize.ownerOf(index + 1), address(raffles[siblingIndex]));
            }
        }
    }
}
