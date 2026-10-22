// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Raffle} from "./Raffle.sol";
import {RaffleFactory} from "./RaffleFactory.sol";
import {IRaffle} from "./interfaces/IRaffle.sol";
import {IRaffleFactory} from "./interfaces/IRaffleFactory.sol";

contract EchidnaMockUSDC is IERC20, IERC20Metadata {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
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
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract EchidnaMockNFT is ERC721 {
    constructor() ERC721("Prize", "PRZ") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract EchidnaMockVRF {
    address public constant link = address(0x1111);
    uint256 public lastRequestId;

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
        requestId = ++lastRequestId;
    }

    function fulfill(address raffle, uint256 requestId, uint256 word) external {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        Raffle(payable(raffle)).rawFulfillRandomWords(requestId, words);
    }
}

contract EchidnaRaffleHarness {
    EchidnaMockUSDC public usdc;
    EchidnaMockNFT public nft;
    EchidnaMockVRF public vrf;
    RaffleFactory public factory;
    IRaffle public raffle;

    address public constant TREASURY = address(0x9001);
    address public constant SPONSOR_RECIPIENT = address(0x9002);

    constructor() {
        usdc = new EchidnaMockUSDC();
        nft = new EchidnaMockNFT();
        vrf = new EchidnaMockVRF();
        factory = new RaffleFactory(address(usdc), address(vrf), TREASURY);

        nft.mint(address(this), 1);
        nft.approve(address(factory), 1);

        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 1,
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 3600),
                sponsorRecipient: SPONSOR_RECIPIENT
            })
        );
        raffle = IRaffle(raffleAddr);

        usdc.mint(address(this), 1_000_000_000e6);
        usdc.approve(raffleAddr, type(uint256).max);
    }

    function action_buyEntries(uint8 rawCount) external {
        uint128 count = uint128((uint256(rawCount) % 20) + 1);
        raffle.buyEntries(address(this), count);
    }

    function action_requestDraw() external {
        raffle.requestDraw();
    }

    function action_fulfill(uint256 randomWord) external {
        vrf.fulfill(address(raffle), raffle.vrfRequestId(), randomWord);
    }

    function action_enableRefunds() external {
        raffle.enableRefunds();
    }

    function action_settle(uint8 rawTicketId) external {
        uint256 count = raffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (uint256(rawTicketId) % count) + 1;
        raffle.settleWinningTicket(ticketId);
    }

    function action_redeem(uint8 rawTicketId) external {
        uint256 count = raffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (uint256(rawTicketId) % count) + 1;
        raffle.redeemWinningTicket(ticketId);
    }

    function action_refundSingle(uint8 rawTicketId) external {
        uint256 count = raffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (uint256(rawTicketId) % count) + 1;
        uint256[] memory ids = new uint256[](1);
        ids[0] = ticketId;
        raffle.refundTickets(ids);
    }

    function action_releaseSponsorProceeds() external {
        raffle.releaseSponsorProceeds();
    }

    function action_releaseProtocolFees() external {
        raffle.releaseProtocolFees();
    }

    function action_releaseSponsorPrize() external {
        raffle.releaseSponsorPrize();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function echidna_quote_conservation() public view returns (bool) {
        return raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle));
    }

    function echidna_prize_custody_valid() public view returns (bool) {
        address owner = nft.ownerOf(1);
        if (!raffle.prizeClaimed()) {
            return owner == address(raffle);
        }
        return owner == address(this) || owner == SPONSOR_RECIPIENT;
    }

    function echidna_settlement_mutually_exclusive_with_refunding() public view returns (bool) {
        if (raffle.status() == IRaffle.Status.Refunding) {
            return !raffle.settlementComplete() && !raffle.winnerRedeemed() && raffle.unsettledPot() == 0;
        }
        return true;
    }
}
