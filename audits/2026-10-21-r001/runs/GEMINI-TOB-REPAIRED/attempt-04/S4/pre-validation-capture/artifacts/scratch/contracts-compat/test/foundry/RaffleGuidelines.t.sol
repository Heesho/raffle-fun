// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleFactory} from "../../src/RaffleFactory.sol";
import {IRaffle} from "../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../src/interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "../../src/libraries/RaffleConstants.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function deal(address who, uint256 newBalance) external;
    function expectRevert() external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertSelector) external;
}

contract MockUSDC is IERC20, IERC20Metadata {
    string public constant name = "USD Coin";
    string public constant symbol = "USDC";
    uint8 public decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public blacklisted;

    error Blacklisted(address account);

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setBlacklisted(address account, bool status) external {
        blacklisted[account] = status;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (blacklisted[msg.sender]) revert Blacklisted(msg.sender);
        if (blacklisted[to]) revert Blacklisted(to);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (blacklisted[from]) revert Blacklisted(from);
        if (blacklisted[to]) revert Blacklisted(to);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockPrizeNFT is ERC721 {
    constructor() ERC721("MockPrize", "MPRZ") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockVRFWrapper {
    address public link;
    uint256 public quotedPrice = 0.005 ether;
    uint256 public actualPrice = 0.005 ether;
    uint256 public lastRequestId;

    constructor(address link_) {
        link = link_;
    }

    function setPrices(uint256 quotedPrice_, uint256 actualPrice_) external {
        quotedPrice = quotedPrice_;
        actualPrice = actualPrice_;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return quotedPrice;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return actualPrice;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata)
        external
        payable
        returns (uint256 requestId)
    {
        require(msg.value >= actualPrice, "insufficient fee");
        requestId = ++lastRequestId;
    }

    function fulfill(address raffle, uint256 requestId, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        Raffle(payable(raffle)).rawFulfillRandomWords(requestId, words);
    }

    function fulfillWithWords(address raffle, uint256 requestId, uint256[] memory words) external {
        Raffle(payable(raffle)).rawFulfillRandomWords(requestId, words);
    }
}

contract ReturnBombCaller {
    function callRequestDraw(IRaffle raffle) external payable returns (uint256) {
        return raffle.requestDraw{value: msg.value}();
    }

    receive() external payable {
        assembly {
            mstore(0x00, 0x1234)
            return(0x00, 0x10000) // 64 KB return payload
        }
    }
}

contract RaffleGuidelinesTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockUSDC internal usdc;
    MockPrizeNFT internal prizeNft;
    MockVRFWrapper internal vrf;
    RaffleFactory internal factory;

    address internal treasury = address(0xBEEF);
    address internal sponsor = address(0xA11CE);
    address internal sponsorRecipient = address(0xA11CF);
    address internal buyer1 = address(0xB0B1);
    address internal buyer2 = address(0xB0B2);
    address internal buyer3 = address(0xB0B3);

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(6);
        prizeNft = new MockPrizeNFT();
        vrf = new MockVRFWrapper(address(0x1111));
        factory = new RaffleFactory(address(usdc), address(vrf), treasury);

        usdc.mint(buyer1, 1_000_000e6);
        usdc.mint(buyer2, 1_000_000e6);
        usdc.mint(buyer3, 1_000_000e6);

        vm.prank(buyer1);
        usdc.approve(address(factory), type(uint256).max);
    }

    function _createStandardRaffle(uint256 tokenId, uint128 reserveEntries, uint64 duration)
        internal
        returns (IRaffle raffle)
    {
        prizeNft.mint(sponsor, tokenId);
        vm.startPrank(sponsor);
        prizeNft.approve(address(factory), tokenId);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: tokenId,
                reserveEntries: reserveEntries,
                endTime: uint64(block.timestamp) + duration,
                sponsorRecipient: sponsorRecipient
            })
        );
        vm.stopPrank();
        raffle = IRaffle(raffleAddr);

        vm.prank(buyer1);
        usdc.approve(raffleAddr, type(uint256).max);
        vm.prank(buyer2);
        usdc.approve(raffleAddr, type(uint256).max);
        vm.prank(buyer3);
        usdc.approve(raffleAddr, type(uint256).max);
    }

    function test_ImplementationIsLockedAndRefundMode() public {
        IRaffle impl = IRaffle(factory.raffleImplementation());
        require(impl.initialized(), "impl must be initialized");
        require(impl.status() == IRaffle.Status.Refunding, "impl must be Refunding");

        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        impl.initialize(
            IRaffle.RaffleInitParams({
                sponsor: sponsor,
                sponsorRecipient: sponsorRecipient,
                protocolTreasury: treasury,
                prizeToken: address(prizeNft),
                prizeTokenId: 1,
                raffleId: 1,
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 100)
            })
        );
    }

    function test_FullNftWonLifecycleAndAccounting() public {
        IRaffle raffle = _createStandardRaffle(1, 10, 1 days);
        require(raffle.status() == IRaffle.Status.Active, "must be Active");
        require(prizeNft.ownerOf(1) == address(raffle), "prize must be escrowed");

        vm.prank(buyer1);
        uint256 t1 = raffle.buyEntries(buyer1, 6);
        vm.prank(buyer2);
        uint256 t2 = raffle.buyEntries(buyer2, 4);

        require(t1 == 1 && t2 == 2, "sequential ticket IDs");
        require(raffle.totalEntries() == 10, "10 total entries");
        require(raffle.unsettledPot() == 10e6, "10 USDC pot");
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "balance invariant");

        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        require(buyer1.balance == 1 ether - 0.005 ether, "excess native refunded");
        require(raffle.status() == IRaffle.Status.Drawing, "Drawing state");

        // Winning entry = (7 % 10) + 1 = 8 -> inside ticket 2 [7..10]
        vrf.fulfill(address(raffle), reqId, 7);
        require(raffle.status() == IRaffle.Status.NftWon, "NftWon state");
        require(raffle.winningEntry() == 8, "winningEntry == 8");

        // Ticket 1 does not contain entry 8
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, uint256(1), uint128(8))
        );
        raffle.settleWinningTicket(1);

        // Settle ticket 2
        uint256 cashProceeds = raffle.settleWinningTicket(2);
        require(cashProceeds == 0, "no cash proceeds on NftWon");
        require(raffle.settlementComplete(), "settlement complete");
        require(raffle.protocolFees() == 0.5e6, "5% protocol fee");
        require(raffle.sponsorProceeds() == 9.5e6, "95% sponsor proceeds");
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "balance invariant");

        // Redeem winning ticket 2 by buyer2
        vm.prank(buyer2);
        raffle.redeemWinningTicket(2);
        require(prizeNft.ownerOf(1) == buyer2, "winner received NFT");
        require(raffle.prizeClaimed() && raffle.winnerRedeemed(), "flags updated");

        // Release sponsor proceeds & protocol fees
        raffle.releaseSponsorProceeds();
        raffle.releaseProtocolFees();
        require(usdc.balanceOf(sponsorRecipient) == 9.5e6, "sponsor paid");
        require(usdc.balanceOf(treasury) == 0.5e6, "treasury paid");
        require(raffle.accountedQuoteBalance() == 0 && usdc.balanceOf(address(raffle)) == 0, "zero balance");
    }

    function test_FullCashWonLifecycleAndSponsorPrizeReturn() public {
        IRaffle raffle = _createStandardRaffle(2, 20, 1 days);

        vm.prank(buyer1);
        raffle.buyEntries(buyer1, 3);
        vm.prank(buyer2);
        raffle.buyEntries(buyer2, 7);

        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer2, 1 ether);
        vm.prank(buyer2);
        uint256 reqId = raffle.requestDraw{value: 0.005 ether}();

        // Winning entry = (2 % 10) + 1 = 3 -> inside ticket 1 [1..3]
        vrf.fulfill(address(raffle), reqId, 2);
        require(raffle.status() == IRaffle.Status.CashWon, "CashWon state");
        require(raffle.winningEntry() == 3, "winningEntry == 3");

        // Redeem directly (settles + redeems in one call)
        vm.prank(buyer1);
        uint256 cashWon = raffle.redeemWinningTicket(1);
        require(cashWon == 8e6, "80% cash winner share");
        require(raffle.sponsorProceeds() == 1.5e6, "15% sponsor share");
        require(raffle.protocolFees() == 0.5e6, "5% protocol fee");

        raffle.releaseSponsorPrize();
        require(prizeNft.ownerOf(2) == sponsorRecipient, "sponsor received returned NFT");

        raffle.releaseSponsorProceeds();
        raffle.releaseProtocolFees();
        require(raffle.accountedQuoteBalance() == 0 && usdc.balanceOf(address(raffle)) == 0, "zero balance");
    }

    function test_RefundPathsAndBatching() public {
        // 1. Sponsor early cancel when 0 entries sold
        IRaffle r1 = _createStandardRaffle(10, 5, 1 days);
        vm.prank(buyer1);
        vm.expectRevert();
        r1.enableRefunds(); // non-sponsor cannot cancel before endTime

        vm.prank(sponsor);
        r1.enableRefunds();
        require(r1.status() == IRaffle.Status.Refunding, "r1 Refunding");
        r1.releaseSponsorPrize();
        require(prizeNft.ownerOf(10) == sponsorRecipient, "r1 NFT returned");

        // 2. Callback timeout refund after Drawing
        IRaffle r2 = _createStandardRaffle(11, 5, 1 days);
        vm.prank(buyer1);
        uint256 t1 = r2.buyEntries(buyer1, 2);
        vm.prank(buyer1);
        uint256 t2 = r2.buyEntries(buyer1, 3);

        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = r2.requestDraw{value: 0.005 ether}();

        // Late VRF callback after callbackDeadline (DRAW_CALLBACK_TIMEOUT = 2 days) is ignored (no-op)
        vm.warp(block.timestamp + 2 days);
        vrf.fulfill(address(r2), reqId, 42);
        require(r2.status() == IRaffle.Status.Drawing, "late callback must be ignored");

        r2.enableRefunds();
        require(r2.status() == IRaffle.Status.Refunding, "r2 Refunding");
        require(r2.remainingRefundLiability() == 5e6, "5 USDC refund liability");

        uint256[] memory ids = new uint256[](2);
        ids[0] = t1;
        ids[1] = t2;
        uint256 balBefore = usdc.balanceOf(buyer1);
        vm.prank(buyer1);
        uint256 refunded = r2.refundTickets(ids);
        require(refunded == 5e6, "refunded 5 USDC");
        require(usdc.balanceOf(buyer1) - balBefore == 5e6, "buyer1 balance restored");
        require(r2.accountedQuoteBalance() == 0, "0 accounted balance");
    }

    function test_ReturnBombCallerRefundSucceeds() public {
        IRaffle raffle = _createStandardRaffle(20, 5, 1 days);
        vm.prank(buyer1);
        raffle.buyEntries(buyer1, 5);
        vm.warp(block.timestamp + 1 days);

        ReturnBombCaller bomber = new ReturnBombCaller();
        vm.deal(address(bomber), 1 ether);
        bomber.callRequestDraw{value: 0.01 ether}(raffle);
        require(raffle.status() == IRaffle.Status.Drawing, "Drawing despite 64KB returnbomb");
    }

    function test_BlacklistedSponsorRecipientLocksSponsorProceedsOnly() public {
        IRaffle raffle = _createStandardRaffle(30, 5, 1 days);
        vm.prank(buyer1);
        raffle.buyEntries(buyer1, 5);
        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.005 ether}();
        vrf.fulfill(address(raffle), reqId, 0);

        // Blacklist sponsorRecipient in USDC
        usdc.setBlacklisted(sponsorRecipient, true);

        // Winner can still redeem NFT and protocol can still collect fees
        vm.prank(buyer1);
        raffle.redeemWinningTicket(1);
        require(prizeNft.ownerOf(30) == buyer1, "winner still receives NFT");
        raffle.releaseProtocolFees();
        require(usdc.balanceOf(treasury) > 0, "treasury still receives fees");

        // Sponsor proceeds are permanently locked because sponsorRecipient cannot be updated
        vm.expectRevert(abi.encodeWithSelector(MockUSDC.Blacklisted.selector, sponsorRecipient));
        raffle.releaseSponsorProceeds();
    }

    function test_TicketTransferAfterResolutionChangesWinnerRecipient() public {
        IRaffle raffle = _createStandardRaffle(40, 5, 1 days);
        vm.prank(buyer1);
        raffle.buyEntries(buyer1, 5);
        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.005 ether}();
        vrf.fulfill(address(raffle), reqId, 0);

        // Ticket 1 is transferred from buyer1 to buyer3 AFTER RaffleResolved
        vm.prank(buyer1);
        ERC721(address(raffle)).transferFrom(buyer1, buyer3, 1);

        // buyer3 is now the current owner and claims the prize
        vm.prank(buyer3);
        raffle.redeemWinningTicket(1);
        require(prizeNft.ownerOf(40) == buyer3, "new ticket holder receives prize");
        require(raffle.winnerRecipient() == buyer3, "winnerRecipient recorded as buyer3");
    }

    function testFuzz_SettlementConservationAndSelection(
        uint32 e1,
        uint32 e2,
        uint32 e3,
        uint32 reserveRaw,
        uint256 randomWord
    ) public {
        uint128 c1 = uint128((uint256(e1) % 500) + 1);
        uint128 c2 = uint128((uint256(e2) % 500) + 1);
        uint128 c3 = uint128((uint256(e3) % 500) + 1);
        uint128 reserve = uint128((uint256(reserveRaw) % 2000) + 1);

        IRaffle raffle = _createStandardRaffle(100, reserve, 1 days);

        vm.prank(buyer1);
        raffle.buyEntries(buyer1, c1);
        vm.prank(buyer2);
        raffle.buyEntries(buyer2, c2);
        vm.prank(buyer3);
        raffle.buyEntries(buyer3, c3);

        uint128 total = c1 + c2 + c3;
        require(raffle.totalEntries() == total, "totalEntries matches");
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "pre-draw conservation");

        vm.warp(block.timestamp + 1 days);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.005 ether}();
        vrf.fulfill(address(raffle), reqId, randomWord);

        uint128 winningEntry = raffle.winningEntry();
        require(winningEntry >= 1 && winningEntry <= total, "winningEntry in [1, total]");

        uint256 winningTicket = winningEntry <= c1 ? 1 : (winningEntry <= c1 + c2 ? 2 : 3);
        address expectedWinner = winningTicket == 1 ? buyer1 : (winningTicket == 2 ? buyer2 : buyer3);

        vm.prank(expectedWinner);
        raffle.redeemWinningTicket(winningTicket);

        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "post-redeem conservation");

        if (total >= reserve) {
            require(raffle.status() == IRaffle.Status.NftWon, "NftWon when total >= reserve");
            require(prizeNft.ownerOf(100) == expectedWinner, "NFT delivered to winner");
        } else {
            require(raffle.status() == IRaffle.Status.CashWon, "CashWon when total < reserve");
            raffle.releaseSponsorPrize();
            require(prizeNft.ownerOf(100) == sponsorRecipient, "NFT returned to sponsor");
        }

        raffle.releaseSponsorProceeds();
        raffle.releaseProtocolFees();

        require(raffle.accountedQuoteBalance() == 0, "final accounted balance == 0");
        require(usdc.balanceOf(address(raffle)) == 0, "final actual balance == 0");
    }
}

contract RaffleInvariantHandler {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockUSDC public usdc;
    MockPrizeNFT public prizeNft;
    MockVRFWrapper public vrf;
    RaffleFactory public factory;
    IRaffle public raffle;

    address public sponsor = address(0xA11CE);
    address public sponsorRecipient = address(0xA11CF);
    address public treasury = address(0xBEEF);
    address[3] public buyers = [address(0xB0B1), address(0xB0B2), address(0xB0B3)];

    constructor(
        MockUSDC usdc_,
        MockPrizeNFT prizeNft_,
        MockVRFWrapper vrf_,
        RaffleFactory factory_,
        IRaffle raffle_
    ) {
        usdc = usdc_;
        prizeNft = prizeNft_;
        vrf = vrf_;
        factory = factory_;
        raffle = raffle_;
    }

    function buyEntries(uint8 buyerSeed, uint8 countSeed) external {
        if (raffle.status() != IRaffle.Status.Active) return;
        if (block.timestamp >= raffle.endTime()) return;
        address buyer = buyers[buyerSeed % 3];
        uint128 count = uint128((uint256(countSeed) % 25) + 1);
        vm.prank(buyer);
        raffle.buyEntries(buyer, count);
    }

    function warpTime(uint32 deltaSeed) external {
        uint256 delta = (uint256(deltaSeed) % (12 hours)) + 1;
        vm.warp(block.timestamp + delta);
    }

    function requestDraw() external {
        if (raffle.status() != IRaffle.Status.Active) return;
        if (block.timestamp < raffle.endTime()) return;
        if (block.timestamp >= raffle.drawRequestDeadline()) return;
        if (raffle.totalEntries() == 0) return;
        vm.deal(buyers[0], 1 ether);
        vm.prank(buyers[0]);
        raffle.requestDraw{value: 0.01 ether}();
    }

    function fulfillDraw(uint256 word) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        vrf.fulfill(address(raffle), raffle.vrfRequestId(), word);
    }

    function enableRefunds(bool asSponsor) external {
        IRaffle.Status st = raffle.status();
        if (st == IRaffle.Status.Active) {
            if (raffle.totalEntries() == 0) {
                if (block.timestamp < raffle.endTime() && !asSponsor) return;
            } else {
                if (block.timestamp < raffle.drawRequestDeadline()) return;
            }
        } else if (st == IRaffle.Status.Drawing) {
            if (block.timestamp < raffle.callbackDeadline()) return;
        } else {
            return;
        }
        vm.prank(asSponsor ? sponsor : buyers[0]);
        raffle.enableRefunds();
    }

    function redeemOrRefundAll() external {
        IRaffle.Status st = raffle.status();
        uint256 count = raffle.ticketCount();
        if (st == IRaffle.Status.NftWon || st == IRaffle.Status.CashWon) {
            if (raffle.winnerRedeemed()) return;
            uint128 winEntry = raffle.winningEntry();
            for (uint256 i = 1; i <= count; ++i) {
                (uint128 firstE, uint128 lastE) = raffle.ticketRange(i);
                if (winEntry >= firstE && winEntry <= lastE) {
                    address owner = ERC721(address(raffle)).ownerOf(i);
                    vm.prank(owner);
                    raffle.redeemWinningTicket(i);
                    break;
                }
            }
        } else if (st == IRaffle.Status.Refunding) {
            for (uint256 i = 1; i <= count; ++i) {
                try ERC721(address(raffle)).ownerOf(i) returns (address owner) {
                    uint256[] memory ids = new uint256[](1);
                    ids[0] = i;
                    vm.prank(owner);
                    raffle.refundTickets(ids);
                } catch {}
            }
        }
    }

    function releaseClaims() external {
        if (raffle.sponsorProceeds() > 0) {
            raffle.releaseSponsorProceeds();
        }
        if (raffle.protocolFees() > 0) {
            raffle.releaseProtocolFees();
        }
        IRaffle.Status st = raffle.status();
        if ((st == IRaffle.Status.CashWon || st == IRaffle.Status.Refunding) && !raffle.prizeClaimed()) {
            raffle.releaseSponsorPrize();
        }
    }
}

contract RaffleInvariantTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockUSDC internal usdc;
    MockPrizeNFT internal prizeNft;
    MockVRFWrapper internal vrf;
    RaffleFactory internal factory;
    IRaffle internal raffle;
    RaffleInvariantHandler internal handler;

    address internal treasury = address(0xBEEF);
    address internal sponsor = address(0xA11CE);
    address internal sponsorRecipient = address(0xA11CF);

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC(6);
        prizeNft = new MockPrizeNFT();
        vrf = new MockVRFWrapper(address(0x1111));
        factory = new RaffleFactory(address(usdc), address(vrf), treasury);

        prizeNft.mint(sponsor, 1);
        vm.startPrank(sponsor);
        prizeNft.approve(address(factory), 1);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: 1,
                reserveEntries: 25,
                endTime: uint64(block.timestamp + 1 days),
                sponsorRecipient: sponsorRecipient
            })
        );
        vm.stopPrank();
        raffle = IRaffle(raffleAddr);

        address[3] memory buyers = [address(0xB0B1), address(0xB0B2), address(0xB0B3)];
        for (uint256 i = 0; i < 3; ++i) {
            usdc.mint(buyers[i], 10_000_000e6);
            vm.prank(buyers[i]);
            usdc.approve(raffleAddr, type(uint256).max);
        }

        handler = new RaffleInvariantHandler(usdc, prizeNft, vrf, factory, raffle);
    }

    function invariant_QuoteBalanceConservation() public view {
        require(
            raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)),
            "accountedQuoteBalance must equal actual quoteToken balance"
        );
    }

    function invariant_PrizeCustodyAndClaims() public view {
        address nftOwner = prizeNft.ownerOf(1);
        if (!raffle.prizeClaimed()) {
            require(nftOwner == address(raffle), "unclaimed prize must remain in Raffle");
        } else {
            IRaffle.Status st = raffle.status();
            if (st == IRaffle.Status.NftWon) {
                require(nftOwner == raffle.winnerRecipient(), "NftWon prize must go to winnerRecipient");
            } else {
                require(nftOwner == sponsorRecipient, "CashWon/Refunding prize must go to sponsorRecipient");
            }
        }
    }

    function invariant_TerminalStateExclusivity() public view {
        IRaffle.Status st = raffle.status();
        if (st == IRaffle.Status.Refunding) {
            require(!raffle.settlementComplete(), "Refunding cannot have settlementComplete");
            require(!raffle.winnerRedeemed(), "Refunding cannot have winnerRedeemed");
            require(raffle.unsettledPot() == 0, "Refunding unsettledPot must be 0");
        }
        if (raffle.settlementComplete()) {
            require(
                st == IRaffle.Status.NftWon || st == IRaffle.Status.CashWon,
                "settlementComplete only in NftWon or CashWon"
            );
            require(raffle.unsettledPot() == 0, "settled unsettledPot must be 0");
        }
    }
}

