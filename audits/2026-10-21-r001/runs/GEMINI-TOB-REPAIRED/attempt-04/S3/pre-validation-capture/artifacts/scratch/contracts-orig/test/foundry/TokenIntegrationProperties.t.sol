// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Raffle} from "../../src/Raffle.sol";
import {RaffleFactory} from "../../src/RaffleFactory.sol";
import {IRaffle} from "../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../src/interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "../../src/libraries/RaffleConstants.sol";

interface Vm {
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function warp(uint256 newTimestamp) external;
    function deal(address who, uint256 newBalance) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertSelector) external;
    function expectRevert() external;
}

contract MockUSDC is IERC20, IERC20Metadata {
    string public constant override name = "USD Coin";
    string public constant override symbol = "USDC";
    uint8 public immutable override decimals;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    uint256 public feeBps;
    mapping(address => bool) public blacklisted;

    error Blacklisted(address account);

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setFeeBps(uint256 feeBps_) external {
        feeBps = feeBps_;
    }

    function setBlacklisted(address account, bool isBlacklisted) external {
        blacklisted[account] = isBlacklisted;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = currentAllowance - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (blacklisted[from]) revert Blacklisted(from);
        if (blacklisted[to]) revert Blacklisted(to);
        require(balanceOf[from] >= value, "ERC20: insufficient balance");
        uint256 fee = (value * feeBps) / 10_000;
        uint256 received = value - fee;
        balanceOf[from] -= value;
        balanceOf[to] += received;
        if (fee > 0) {
            totalSupply -= fee;
        }
    }
}

contract MockPrizeNFT is ERC721 {
    bool public transferPaused;

    error PrizeTransferPaused();

    constructor() ERC721("MockPrize", "PRIZE") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setTransferPaused(bool paused) external {
        transferPaused = paused;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (transferPaused) revert PrizeTransferPaused();
        return super._update(to, tokenId, auth);
    }
}

contract MockVRFWrapper {
    address public immutable linkToken;
    uint256 public fixedPrice = 0.01 ether;
    uint256 public nextRequestId = 1;

    constructor(address linkToken_) {
        linkToken = linkToken_;
    }

    function link() external view returns (address) {
        return linkToken;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return fixedPrice;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return fixedPrice;
    }

    function requestRandomWordsInNative(
        uint32,
        uint16,
        uint32,
        bytes calldata
    ) external payable returns (uint256 requestId) {
        require(msg.value >= fixedPrice, "insufficient VRF fee");
        requestId = nextRequestId++;
    }

    function fulfill(address consumer, uint256 requestId, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        Raffle(payable(consumer)).rawFulfillRandomWords(requestId, words);
    }
}

contract NonERC721ReceiverContract {
    // Intentionally does NOT implement IERC721Receiver
}

contract TicketHolderContract is IERC721Receiver {
    // Implements IERC721Receiver ONLY for Raffle tickets, not for prizeToken
    address public immutable acceptedRaffle;

    constructor(address acceptedRaffle_) {
        acceptedRaffle = acceptedRaffle_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        require(msg.sender == acceptedRaffle, "Only accepts Raffle tickets via safeTransfer");
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract TokenIntegrationPropertiesTest {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MockUSDC internal usdc;
    MockPrizeNFT internal prizeNft;
    MockUSDC internal mockLink;
    MockVRFWrapper internal vrfWrapper;
    RaffleFactory internal factory;

    address internal sponsor = address(0x1001);
    address internal sponsorRecipient = address(0x1002);
    address internal treasury = address(0x1003);
    address internal buyer1 = address(0x2001);
    address internal buyer2 = address(0x2002);
    address internal buyer3 = address(0x2003);

    function setUp() public {
        usdc = new MockUSDC(6);
        mockLink = new MockUSDC(18);
        prizeNft = new MockPrizeNFT();
        vrfWrapper = new MockVRFWrapper(address(mockLink));
        factory = new RaffleFactory(address(usdc), address(vrfWrapper), treasury);

        usdc.mint(buyer1, 1_000_000e6);
        usdc.mint(buyer2, 1_000_000e6);
        usdc.mint(buyer3, 1_000_000e6);
    }

    function _createStandardRaffle(uint256 tokenId, uint128 reserveEntries) internal returns (Raffle raffle) {
        prizeNft.mint(sponsor, tokenId);
        vm.startPrank(sponsor);
        prizeNft.approve(address(factory), tokenId);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: tokenId,
                sponsorRecipient: sponsorRecipient,
                reserveEntries: reserveEntries,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        raffle = Raffle(payable(raffleAddr));
    }

    // =========================================================================
    // 1. ERC721 CONFORMITY PROPERTIES (Phase 2 / Category 9 & 10)
    // =========================================================================

    function testProperty_ERC721MetadataAndInterfaces() public {
        Raffle raffle = _createStandardRaffle(1, 10);

        require(
            keccak256(bytes(raffle.name())) == keccak256(bytes("raffle.fun Ticket")),
            "name mismatch"
        );
        require(
            keccak256(bytes(raffle.symbol())) == keccak256(bytes("RAFFLE")),
            "symbol mismatch"
        );
        require(raffle.supportsInterface(type(IERC165).interfaceId), "IERC165 not supported");
        require(raffle.supportsInterface(type(IERC721).interfaceId), "IERC721 not supported");
        require(raffle.supportsInterface(type(IERC721Metadata).interfaceId), "IERC721Metadata not supported");
        require(!raffle.supportsInterface(0xffffffff), "0xffffffff must be false");

        // Mint ticket 1 and check tokenURI
        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 5e6);
        uint256 ticketId = raffle.buyEntries(buyer1, 5);
        vm.stopPrank();

        // tokenURI returns empty string because _baseURI is ""
        require(keccak256(bytes(raffle.tokenURI(ticketId))) == keccak256(bytes("")), "tokenURI should be empty");
    }

    function testProperty_SequentialTicketsAndContiguousRanges(uint8 c1, uint8 c2, uint8 c3) public {
        uint128 e1 = uint128(uint256(c1) + 1);
        uint128 e2 = uint128(uint256(c2) + 1);
        uint128 e3 = uint128(uint256(c3) + 1);

        Raffle raffle = _createStandardRaffle(10, 50);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), uint256(e1) * 1e6);
        uint256 t1 = raffle.buyEntries(buyer1, e1);
        vm.stopPrank();

        vm.startPrank(buyer2);
        usdc.approve(address(raffle), uint256(e2) * 1e6);
        uint256 t2 = raffle.buyEntries(buyer2, e2);
        vm.stopPrank();

        vm.startPrank(buyer3);
        usdc.approve(address(raffle), uint256(e3) * 1e6);
        uint256 t3 = raffle.buyEntries(buyer3, e3);
        vm.stopPrank();

        require(t1 == 1 && t2 == 2 && t3 == 3, "non-sequential ticket IDs");
        require(raffle.ticketCount() == 3, "ticketCount mismatch");
        require(raffle.totalEntries() == e1 + e2 + e3, "totalEntries mismatch");

        (uint128 f1, uint128 l1) = raffle.ticketRange(t1);
        (uint128 f2, uint128 l2) = raffle.ticketRange(t2);
        (uint128 f3, uint128 l3) = raffle.ticketRange(t3);

        require(f1 == 1 && l1 == e1, "t1 range invalid");
        require(f2 == l1 + 1 && l2 == e1 + e2, "t2 range non-contiguous");
        require(f3 == l2 + 1 && l3 == e1 + e2 + e3, "t3 range non-contiguous");
    }

    function testProperty_ERC721ProtocolDestinationGuardsAndApprovalClearing() public {
        Raffle raffle = _createStandardRaffle(2, 10);
        Raffle siblingRaffle = _createStandardRaffle(3, 10);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 5e6);
        uint256 ticketId = raffle.buyEntries(buyer1, 5);

        // Approve buyer2, then transfer to buyer3 -> approval must clear
        raffle.approve(buyer2, ticketId);
        require(raffle.getApproved(ticketId) == buyer2, "approval not set");
        raffle.transferFrom(buyer1, buyer3, ticketId);
        vm.stopPrank();

        require(raffle.ownerOf(ticketId) == buyer3, "owner mismatch after transfer");
        require(raffle.getApproved(ticketId) == address(0), "approval not cleared on transfer");

        // Verify all protocol destinations are blocked in _update
        address[6] memory forbidden = [
            address(raffle),
            address(factory),
            factory.raffleImplementation(),
            address(usdc),
            address(vrfWrapper),
            address(prizeNft)
        ];

        vm.startPrank(buyer3);
        for (uint256 i = 0; i < forbidden.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, forbidden[i])
            );
            raffle.transferFrom(buyer3, forbidden[i], ticketId);
        }

        // Also sibling raffle clone is blocked via canonicalFactory.isRaffle(destination)
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(siblingRaffle))
        );
        raffle.transferFrom(buyer3, address(siblingRaffle), ticketId);
        vm.stopPrank();
    }

    // =========================================================================
    // 2. QUOTE TOKEN CONSERVATION & WEIRD ERC20 PROPERTIES (Categories 4, 5, 7, 8)
    // =========================================================================

    function testProperty_QuoteTokenConservation_NftWon(uint8 entries1, uint8 entries2, uint256 randomSeed) public {
        uint128 e1 = uint128((uint256(entries1) % 50) + 5);
        uint128 e2 = uint128((uint256(entries2) % 50) + 5);
        uint128 reserve = e1 + e2; // Ensure reserve is met

        Raffle raffle = _createStandardRaffle(100, reserve);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), uint256(e1) * 1e6);
        raffle.buyEntries(buyer1, e1);
        vm.stopPrank();

        vm.startPrank(buyer2);
        usdc.approve(address(raffle), uint256(e2) * 1e6);
        raffle.buyEntries(buyer2, e2);
        vm.stopPrank();

        // Active conservation
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "Active conservation violated");

        vm.warp(raffle.endTime() + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();

        vrfWrapper.fulfill(address(raffle), reqId, randomSeed);
        require(raffle.status() == IRaffle.Status.NftWon, "Expected NftWon");
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "NftWon pre-settle conservation violated");

        uint128 winEntry = raffle.winningEntry();
        (, uint128 l1) = raffle.ticketRange(1);
        uint256 winTicket = winEntry <= l1 ? 1 : 2;
        address winOwner = winTicket == 1 ? buyer1 : buyer2;

        raffle.settleWinningTicket(winTicket);
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "NftWon post-settle conservation violated");

        vm.prank(winOwner);
        raffle.redeemWinningTicket(winTicket);
        require(prizeNft.ownerOf(100) == winOwner, "Winner did not receive prize NFT");

        raffle.releaseSponsorProceeds();
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "Post-sponsor release conservation violated");

        raffle.releaseProtocolFees();
        require(raffle.accountedQuoteBalance() == 0, "Final accounted balance non-zero");
        require(usdc.balanceOf(address(raffle)) == 0, "Final token balance non-zero");
    }

    function testProperty_QuoteTokenConservation_CashWon(uint8 entries1, uint8 entries2, uint256 randomSeed) public {
        uint128 e1 = uint128((uint256(entries1) % 20) + 1);
        uint128 e2 = uint128((uint256(entries2) % 20) + 1);
        uint128 reserve = e1 + e2 + 10; // Under-reserve -> CashWon

        Raffle raffle = _createStandardRaffle(200, reserve);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), uint256(e1) * 1e6);
        raffle.buyEntries(buyer1, e1);
        vm.stopPrank();

        vm.startPrank(buyer2);
        usdc.approve(address(raffle), uint256(e2) * 1e6);
        raffle.buyEntries(buyer2, e2);
        vm.stopPrank();

        vm.warp(raffle.endTime() + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();

        vrfWrapper.fulfill(address(raffle), reqId, randomSeed);
        require(raffle.status() == IRaffle.Status.CashWon, "Expected CashWon");

        uint128 winEntry = raffle.winningEntry();
        (, uint128 l1) = raffle.ticketRange(1);
        uint256 winTicket = winEntry <= l1 ? 1 : 2;
        address winOwner = winTicket == 1 ? buyer1 : buyer2;

        vm.prank(winOwner);
        raffle.redeemWinningTicket(winTicket);
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "Post-winner redeem conservation violated");

        raffle.releaseSponsorProceeds();
        require(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)), "Post-sponsor release conservation violated");

        raffle.releaseProtocolFees();
        require(raffle.accountedQuoteBalance() == 0, "Final accounted balance non-zero");
        require(usdc.balanceOf(address(raffle)) == 0, "Final token balance non-zero");

        raffle.releaseSponsorPrize();
        require(prizeNft.ownerOf(200) == sponsorRecipient, "Sponsor did not recover prize");
    }

    function testProperty_FeeOnTransferQuoteTokenCreatesDeficit() public {
        Raffle raffle = _createStandardRaffle(300, 10);

        // Enable 1% fee on transfer on the 6-decimal quote token
        usdc.setFeeBps(100);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 5e6);
        raffle.buyEntries(buyer1, 5);
        vm.stopPrank();

        // Internal accounting assumes full 5e6 received, but actual balance is 4.95e6
        require(raffle.accountedQuoteBalance() == 5e6, "accountedQuoteBalance should be 5e6");
        require(usdc.balanceOf(address(raffle)) == 4_950_000, "actual balance should be 4.95e6");

        // Transition to Refunding after drawRequestDeadline and verify refund reverts due to token deficit
        vm.warp(raffle.drawRequestDeadline() + 1);
        vm.prank(sponsor);
        raffle.enableRefunds();

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 1;
        vm.prank(buyer1);
        vm.expectRevert();
        raffle.refundTickets(tickets);
    }

    function testProperty_BlacklistedWinnerCanTransferTicketWhileImmutableSponsorRecipientCannot() public {
        Raffle raffle = _createStandardRaffle(400, 10);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 5e6);
        uint256 ticketId = raffle.buyEntries(buyer1, 5);
        vm.stopPrank();

        vm.warp(raffle.endTime() + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        vrfWrapper.fulfill(address(raffle), reqId, 42);
        require(raffle.status() == IRaffle.Status.CashWon, "Expected CashWon");

        // Blacklist buyer1 in USDC
        usdc.setBlacklisted(buyer1, true);

        // Direct redemption by buyer1 reverts because USDC blocks transfer to buyer1
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(MockUSDC.Blacklisted.selector, buyer1));
        raffle.redeemWinningTicket(ticketId);

        // However, Raffle ERC721 allows ticket transfer in CashWon status to un-blacklisted buyer2!
        vm.prank(buyer1);
        raffle.transferFrom(buyer1, buyer2, ticketId);

        vm.prank(buyer2);
        raffle.redeemWinningTicket(ticketId);
        require(raffle.winnerRedeemed(), "buyer2 should successfully redeem");

        // Conversely, if sponsorRecipient is blacklisted in NftWon, sponsorProceeds cannot be redirected
        Raffle nftRaffle = _createStandardRaffle(401, 5);
        vm.startPrank(buyer2);
        usdc.approve(address(nftRaffle), 5e6);
        nftRaffle.buyEntries(buyer2, 5);
        vm.stopPrank();

        vm.warp(nftRaffle.endTime() + 1);
        vm.prank(buyer1);
        uint256 reqId2 = nftRaffle.requestDraw{value: 0.01 ether}();
        vrfWrapper.fulfill(address(nftRaffle), reqId2, 1);

        nftRaffle.settleWinningTicket(1);
        usdc.setBlacklisted(sponsorRecipient, true);

        // Protocol fees remain independently claimable even while sponsorRecipient is blacklisted
        nftRaffle.releaseProtocolFees();
        require(nftRaffle.protocolFees() == 0, "protocolFees should be claimed");

        // Sponsor proceeds are frozen because sponsorRecipient is immutable
        vm.expectRevert(abi.encodeWithSelector(MockUSDC.Blacklisted.selector, sponsorRecipient));
        nftRaffle.releaseSponsorProceeds();
    }

    // =========================================================================
    // 3. PRIZE TOKEN INTEGRATION PROPERTIES (Categories 8, 9, 10)
    // =========================================================================

    function testProperty_DecoupledSettlementAllowsSponsorProceedsWhenPrizeTokenPauses() public {
        Raffle raffle = _createStandardRaffle(500, 5);

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 5e6);
        raffle.buyEntries(buyer1, 5);
        vm.stopPrank();

        vm.warp(raffle.endTime() + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        vrfWrapper.fulfill(address(raffle), reqId, 7);
        require(raffle.status() == IRaffle.Status.NftWon, "Expected NftWon");

        // External prizeToken pauses transfers after NftWon resolution
        prizeNft.setTransferPaused(true);

        // Permissionless storage-only settlement still succeeds and unlocks sponsorProceeds
        raffle.settleWinningTicket(1);
        raffle.releaseSponsorProceeds();
        require(raffle.sponsorProceeds() == 0, "Sponsor claimed proceeds despite paused prizeToken");

        // Winner redemption reverts atomically (preserving ticket ownership) while prizeToken is paused
        vm.prank(buyer1);
        vm.expectRevert(MockPrizeNFT.PrizeTransferPaused.selector);
        raffle.redeemWinningTicket(1);
        require(raffle.ownerOf(1) == buyer1, "Winning ticket must not be burned on failed delivery");
    }

    function testProperty_PrizeDeliveryUsesTransferFromWithoutReceiverHook() public {
        NonERC721ReceiverContract nonReceiverSponsor = new NonERC721ReceiverContract();

        prizeNft.mint(sponsor, 600);
        vm.startPrank(sponsor);
        prizeNft.approve(address(factory), 600);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: 600,
                sponsorRecipient: address(nonReceiverSponsor),
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        Raffle raffle = Raffle(payable(raffleAddr));

        TicketHolderContract contractWinner = new TicketHolderContract(address(raffle));
        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 10e6);
        raffle.buyEntries(address(contractWinner), 10);
        vm.stopPrank();

        vm.warp(raffle.endTime() + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        vrfWrapper.fulfill(address(raffle), reqId, 1);

        // TicketHolderContract rejects prizeNft in onERC721Received, but redeemWinningTicket uses raw transferFrom
        vm.prank(address(contractWinner));
        raffle.redeemWinningTicket(1);
        require(prizeNft.ownerOf(600) == address(contractWinner), "Prize delivered via raw transferFrom");
    }
}
