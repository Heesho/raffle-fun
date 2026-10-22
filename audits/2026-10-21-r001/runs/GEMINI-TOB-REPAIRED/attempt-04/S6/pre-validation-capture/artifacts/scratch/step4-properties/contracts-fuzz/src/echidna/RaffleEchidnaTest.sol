// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Raffle} from "../Raffle.sol";
import {RaffleFactory} from "../RaffleFactory.sol";
import {IRaffle} from "../interfaces/IRaffle.sol";
import {IRaffleFactory} from "../interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "../libraries/RaffleConstants.sol";

contract EchidnaMockUSDC is IERC20 {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public constant decimals = 6;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        require(balanceOf[from] >= value, "insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

contract EchidnaMockPrizeNFT is ERC721 {
    constructor() ERC721("Prize NFT", "PRIZE") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract EchidnaMockLink {
    function name() external pure returns (string memory) {
        return "Chainlink";
    }
}

contract EchidnaMockVRFWrapper {
    address public immutable link;
    uint256 public nextRequestId = 1;
    uint256 public currentNativePrice = 0.01 ether;

    constructor(address link_) {
        link = link_;
    }

    function setNativePrice(uint256 price_) external {
        currentNativePrice = price_;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return currentNativePrice;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return currentNativePrice;
    }

    function requestRandomWordsInNative(
        uint32,
        uint16,
        uint32,
        bytes calldata
    ) external payable returns (uint256 requestId) {
        require(msg.value >= currentNativePrice, "insufficient VRF fee");
        requestId = nextRequestId++;
    }

    function requestRandomnessPayInNative(
        uint32,
        uint16,
        uint32,
        bytes calldata
    ) external payable returns (uint256 requestId) {
        require(msg.value >= currentNativePrice, "insufficient VRF fee");
        requestId = nextRequestId++;
    }

    function fulfill(address consumer, uint256 requestId, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        Raffle(payable(consumer)).rawFulfillRandomWords(requestId, words);
    }
}

contract EchidnaActor is IERC721Receiver {
    EchidnaMockUSDC public immutable usdc;

    constructor(EchidnaMockUSDC usdc_) {
        usdc = usdc_;
    }

    function approveRaffle(address raffle) external {
        usdc.approve(raffle, type(uint256).max);
    }

    function buy(IRaffle raffle, uint128 entries, address recipient) external returns (uint256) {
        return raffle.buyEntries(recipient, entries);
    }

    function transferTicket(ERC721 raffle, address to, uint256 ticketId) external {
        raffle.transferFrom(address(this), to, ticketId);
    }

    function redeem(IRaffle raffle, uint256 ticketId) external {
        raffle.redeemWinningTicket(ticketId);
    }

    function refund(IRaffle raffle, uint256[] calldata ticketIds) external returns (uint256) {
        return raffle.refundTickets(ticketIds);
    }

    function requestDraw(IRaffle raffle) external payable returns (uint256) {
        return raffle.requestDraw{value: msg.value}();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}

contract EchidnaRecipient is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}

contract RaffleEchidnaTest is IERC721Receiver {
    EchidnaMockUSDC public usdc;
    EchidnaMockPrizeNFT public prizeNft;
    EchidnaMockLink public linkToken;
    EchidnaMockVRFWrapper public vrfWrapper;
    EchidnaRecipient public protocolTreasury;
    EchidnaRecipient public sponsorRecipient;
    EchidnaActor public actor1;
    EchidnaActor public actor2;

    RaffleFactory public factory;
    Raffle public openRaffle;
    Raffle public highReserveRaffle;

    // Ghost accounting variables for openRaffle
    uint256 public ghostRefundedQuoteOpen;
    uint256 public ghostClaimedWinnerOpen;
    uint256 public ghostClaimedSponsorOpen;
    uint256 public ghostClaimedProtocolOpen;
    uint8 public ghostLastStatusOpen;
    bool public ghostStatusTransitionValidOpen = true;

    constructor() payable {
        usdc = new EchidnaMockUSDC();
        prizeNft = new EchidnaMockPrizeNFT();
        linkToken = new EchidnaMockLink();
        vrfWrapper = new EchidnaMockVRFWrapper(address(linkToken));
        protocolTreasury = new EchidnaRecipient();
        sponsorRecipient = new EchidnaRecipient();
        actor1 = new EchidnaActor(usdc);
        actor2 = new EchidnaActor(usdc);

        factory = new RaffleFactory(
            address(usdc),
            address(vrfWrapper),
            address(protocolTreasury)
        );

        // Mint prizes to this sponsor harness and approve factory
        prizeNft.mint(address(this), 1);
        prizeNft.mint(address(this), 2);
        prizeNft.setApprovalForAll(address(factory), true);

        // Create openRaffle (raffleId = 1, reserveEntries = 3 -> easily reaches NftWon or CashWon)
        address r1 = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: 1,
                reserveEntries: 3,
                endTime: uint64(block.timestamp + 2 hours),
                sponsorRecipient: address(sponsorRecipient)
            })
        );
        openRaffle = Raffle(payable(r1));
        ghostLastStatusOpen = uint8(openRaffle.status());

        // Create highReserveRaffle (raffleId = 2, reserveEntries = 50 -> exercises CashWon path)
        address r2 = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: 2,
                reserveEntries: 50,
                endTime: uint64(block.timestamp + 2 hours),
                sponsorRecipient: address(sponsorRecipient)
            })
        );
        highReserveRaffle = Raffle(payable(r2));

        // Fund actors with USDC and approve both raffles
        usdc.mint(address(actor1), 10_000_000 * 1e6);
        usdc.mint(address(actor2), 10_000_000 * 1e6);
        actor1.approveRaffle(address(openRaffle));
        actor1.approveRaffle(address(highReserveRaffle));
        actor2.approveRaffle(address(openRaffle));
        actor2.approveRaffle(address(highReserveRaffle));
    }

    function _isResolved(IRaffle.Status s) internal pure returns (bool) {
        return s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon;
    }

    function _recordStatusTransition() internal {
        uint8 current = uint8(openRaffle.status());
        uint8 prev = ghostLastStatusOpen;
        if (current != prev) {
            bool valid = (prev == uint8(IRaffle.Status.AwaitingPrize) &&
                (current == uint8(IRaffle.Status.Active) || current == uint8(IRaffle.Status.Refunding))) ||
                (prev == uint8(IRaffle.Status.Active) &&
                    (current == uint8(IRaffle.Status.Drawing) || current == uint8(IRaffle.Status.Refunding))) ||
                (prev == uint8(IRaffle.Status.Drawing) &&
                    (current == uint8(IRaffle.Status.NftWon) ||
                        current == uint8(IRaffle.Status.CashWon) ||
                        current == uint8(IRaffle.Status.Refunding)));
            if (!valid) {
                ghostStatusTransitionValidOpen = false;
            }
            ghostLastStatusOpen = current;
        }
    }

    // --- Fuzzer Actions on openRaffle ---

    function action_buyActor1(uint256 rawEntries) external {
        uint128 entries = uint128((rawEntries % 5) + 1);
        actor1.buy(openRaffle, entries, address(actor1));
        _recordStatusTransition();
    }

    function action_buyActor2(uint256 rawEntries) external {
        uint128 entries = uint128((rawEntries % 5) + 1);
        actor2.buy(openRaffle, entries, address(actor2));
        _recordStatusTransition();
    }

    function action_transferTicket1To2(uint256 rawTicketId) external {
        uint256 count = openRaffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (rawTicketId % count) + 1;
        if (openRaffle.ownerOf(ticketId) == address(actor1)) {
            actor1.transferTicket(openRaffle, address(actor2), ticketId);
        }
        _recordStatusTransition();
    }

    function action_requestDraw() external payable {
        uint256 fee = vrfWrapper.currentNativePrice();
        if (address(this).balance >= fee) {
            openRaffle.requestDraw{value: fee}();
            _recordStatusTransition();
        }
    }

    function action_fulfillDraw(uint256 randomWord) external {
        uint256 reqId = openRaffle.vrfRequestId();
        if (reqId != 0) {
            vrfWrapper.fulfill(address(openRaffle), reqId, randomWord);
            _recordStatusTransition();
        }
    }

    function action_settleWinningTicket(uint256 rawTicketId) external {
        uint256 count = openRaffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (rawTicketId % count) + 1;
        openRaffle.settleWinningTicket(ticketId);
        _recordStatusTransition();
    }

    function action_settleWinningTicketExact() external {
        if (!_isResolved(openRaffle.status()) || openRaffle.settlementComplete()) return;
        uint256 winEntry = openRaffle.winningEntry();
        uint256 count = openRaffle.ticketCount();
        for (uint256 id = 1; id <= count; ++id) {
            (uint256 startEntry, uint256 endEntry) = openRaffle.ticketRange(id);
            if (winEntry >= startEntry && winEntry <= endEntry) {
                openRaffle.settleWinningTicket(id);
                _recordStatusTransition();
                return;
            }
        }
    }

    function action_redeemWinningTicket() external {
        if (!_isResolved(openRaffle.status())) return;
        uint256 winEntry = openRaffle.winningEntry();
        uint256 count = openRaffle.ticketCount();
        for (uint256 id = 1; id <= count; ++id) {
            (uint256 startEntry, uint256 endEntry) = openRaffle.ticketRange(id);
            if (winEntry >= startEntry && winEntry <= endEntry) {
                address owner = openRaffle.ownerOf(id);
                uint256 balBefore = usdc.balanceOf(owner);
                if (owner == address(actor1)) {
                    actor1.redeem(openRaffle, id);
                } else if (owner == address(actor2)) {
                    actor2.redeem(openRaffle, id);
                }
                uint256 balAfter = usdc.balanceOf(owner);
                ghostClaimedWinnerOpen += (balAfter - balBefore);
                _recordStatusTransition();
                return;
            }
        }
    }

    function action_enableRefunds() external {
        openRaffle.enableRefunds();
        _recordStatusTransition();
    }

    function action_refundTicket(uint256 rawTicketId) external {
        if (openRaffle.status() != IRaffle.Status.Refunding) return;
        uint256 count = openRaffle.ticketCount();
        if (count == 0) return;
        uint256 ticketId = (rawTicketId % count) + 1;
        uint256[] memory ids = new uint256[](1);
        ids[0] = ticketId;
        address owner = openRaffle.ownerOf(ticketId);
        uint256 refunded;
        if (owner == address(actor1)) {
            refunded = actor1.refund(openRaffle, ids);
        } else if (owner == address(actor2)) {
            refunded = actor2.refund(openRaffle, ids);
        }
        ghostRefundedQuoteOpen += refunded;
        _recordStatusTransition();
    }

    function action_releaseSponsorProceeds() external {
        uint256 beforeBal = usdc.balanceOf(address(sponsorRecipient));
        openRaffle.releaseSponsorProceeds();
        uint256 afterBal = usdc.balanceOf(address(sponsorRecipient));
        ghostClaimedSponsorOpen += (afterBal - beforeBal);
    }

    function action_releaseProtocolFees() external {
        uint256 beforeBal = usdc.balanceOf(address(protocolTreasury));
        openRaffle.releaseProtocolFees();
        uint256 afterBal = usdc.balanceOf(address(protocolTreasury));
        ghostClaimedProtocolOpen += (afterBal - beforeBal);
    }

    function action_releaseSponsorPrize() external {
        openRaffle.releaseSponsorPrize();
    }

    // --- Echidna Invariant Properties ---

    function echidna_quote_solvency() public view returns (bool) {
        uint256 accounted1 = openRaffle.accountedQuoteBalance();
        uint256 sum1 = openRaffle.unsettledPot() +
            openRaffle.remainingRefundLiability() +
            openRaffle.winnerProceeds() +
            openRaffle.sponsorProceeds() +
            openRaffle.protocolFees();
        uint256 actual1 = usdc.balanceOf(address(openRaffle));

        uint256 accounted2 = highReserveRaffle.accountedQuoteBalance();
        uint256 actual2 = usdc.balanceOf(address(highReserveRaffle));

        return (accounted1 == sum1) && (actual1 >= accounted1) && (actual2 >= accounted2);
    }

    function echidna_entry_accounting() public view returns (bool) {
        IRaffle.Status s = openRaffle.status();
        uint256 expectedGross = openRaffle.totalEntries() * openRaffle.ENTRY_PRICE();
        if (openRaffle.grossSales() != expectedGross) return false;
        if (s == IRaffle.Status.AwaitingPrize || s == IRaffle.Status.Active || s == IRaffle.Status.Drawing) {
            return openRaffle.unsettledPot() == expectedGross && openRaffle.remainingRefundLiability() == 0;
        }
        return true;
    }

    function echidna_settlement_conservation() public view returns (bool) {
        if (_isResolved(openRaffle.status()) && openRaffle.settlementComplete()) {
            if (openRaffle.unsettledPot() != 0 || openRaffle.remainingRefundLiability() != 0) {
                return false;
            }
            uint256 totalAllocated = openRaffle.winnerProceeds() +
                openRaffle.sponsorProceeds() +
                openRaffle.protocolFees() +
                ghostClaimedWinnerOpen +
                ghostClaimedSponsorOpen +
                ghostClaimedProtocolOpen;
            return totalAllocated == openRaffle.grossSales();
        }
        return true;
    }

    function echidna_refund_liability_conservation() public view returns (bool) {
        if (openRaffle.status() == IRaffle.Status.Refunding) {
            return
                openRaffle.unsettledPot() == 0 &&
                (openRaffle.remainingRefundLiability() + ghostRefundedQuoteOpen == openRaffle.grossSales());
        }
        return openRaffle.remainingRefundLiability() == 0;
    }

    function echidna_status_transitions_valid() public view returns (bool) {
        return ghostStatusTransitionValidOpen && uint8(openRaffle.status()) <= uint8(IRaffle.Status.Refunding);
    }

    function echidna_ticket_ranges_contiguous() public view returns (bool) {
        uint256 count = openRaffle.ticketCount();
        uint256 total = openRaffle.totalEntries();
        if (count == 0) {
            return total == 0;
        }
        uint256 expectedStart = 1;
        for (uint256 id = 1; id <= count; ++id) {
            (uint256 startEntry, uint256 endEntry) = openRaffle.ticketRange(id);
            if (startEntry != expectedStart || endEntry < startEntry) {
                return false;
            }
            expectedStart = endEntry + 1;
        }
        return expectedStart == total + 1;
    }

    function echidna_winning_ticket_bounds() public view returns (bool) {
        if (openRaffle.settlementComplete()) {
            uint256 winId = openRaffle.winningTicketId();
            if (winId == 0 || winId > openRaffle.ticketCount()) return false;
            (uint256 startEntry, uint256 endEntry) = openRaffle.ticketRange(winId);
            uint256 winEntry = openRaffle.winningEntry();
            return winEntry >= startEntry && winEntry <= endEntry;
        }
        return true;
    }

    function echidna_prize_custody_consistency() public view returns (bool) {
        IRaffle.Status s = openRaffle.status();
        address owner = prizeNft.ownerOf(1);
        if (s == IRaffle.Status.Active || s == IRaffle.Status.Drawing) {
            return owner == address(openRaffle) && !openRaffle.prizeClaimed();
        }
        if (openRaffle.prizeClaimed()) {
            return
                (s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon || s == IRaffle.Status.Refunding) &&
                owner != address(openRaffle);
        }
        return true;
    }

    function echidna_no_protocol_destination_holds_tickets() public view returns (bool) {
        return
            openRaffle.balanceOf(address(factory)) == 0 &&
            openRaffle.balanceOf(factory.raffleImplementation()) == 0 &&
            openRaffle.balanceOf(address(openRaffle)) == 0 &&
            openRaffle.balanceOf(address(usdc)) == 0 &&
            openRaffle.balanceOf(address(vrfWrapper)) == 0;
    }

    function echidna_factory_registry_bijection() public view returns (bool) {
        uint256 count = factory.raffleCount();
        for (uint256 id = 1; id <= count; ++id) {
            address r = factory.raffleById(id);
            if (r == address(0) || !factory.isRaffle(r) || factory.idByRaffle(r) != id) {
                return false;
            }
        }
        return true;
    }

    function echidna_implementation_locked() public view returns (bool) {
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        return impl.initialized() && impl.status() == IRaffle.Status.Refunding;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
