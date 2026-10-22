// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Raffle } from "../../src/Raffle.sol";
import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";

interface Vm {
    function prank(address caller) external;
    function warp(uint256 timestamp) external;
}

interface IRawVrfConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

contract MockUsdc is IERC20Metadata {
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

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ALLOWANCE");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "ZERO_TO");
        require(balanceOf[from] >= amount, "BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

    contract MockVrfWrapper is IVRFV2PlusWrapper {
        uint256 public override lastRequestId;
        mapping(uint256 requestId => address consumer) public consumerByRequest;

        function calculateRequestPrice(uint32, uint32) external pure override returns (uint256) {
            return 0;
        }

        function calculateRequestPriceNative(uint32, uint32) external pure override returns (uint256) {
            return 0;
        }

        function estimateRequestPrice(uint32, uint32, uint256) external pure override returns (uint256) {
            return 0;
        }

        function estimateRequestPriceNative(uint32, uint32, uint256) external pure override returns (uint256) {
            return 0;
        }

        function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata)
            external
            payable
            override
            returns (uint256 requestId)
        {
            requestId = ++lastRequestId;
            consumerByRequest[requestId] = msg.sender;
        }

        function link() external view override returns (address) {
            return address(this);
        }

        function linkNativeFeed() external view override returns (address) {
            return address(this);
        }

        function fulfill(uint256 requestId, uint256 randomWord) external {
            address consumer = consumerByRequest[requestId];
            require(consumer != address(0), "UNKNOWN_REQUEST");
            uint256[] memory words = new uint256[](1);
            words[0] = randomWord;
            IRawVrfConsumer(consumer).rawFulfillRandomWords(requestId, words);
        }
    }

        contract SwitchablePrize is IERC721 {
            address public immutable controller;
            mapping(uint256 tokenId => address owner) private _ownerOf;
            mapping(address owner => uint256 balance) private _balanceOf;
            mapping(uint256 tokenId => address approved) private _tokenApproval;
            mapping(address owner => mapping(address operator => bool approved)) private _operatorApproval;
            mapping(address sender => bool blocked) public blockedFrom;

            constructor(address controller_) {
                controller = controller_;
            }

            function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
                return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId;
            }

            function mint(address to, uint256 tokenId) external {
                require(msg.sender == controller, "ONLY_CONTROLLER");
                require(to != address(0) && _ownerOf[tokenId] == address(0), "INVALID_MINT");
                _ownerOf[tokenId] = to;
                ++_balanceOf[to];
                emit Transfer(address(0), to, tokenId);
            }

            function setBlockedFrom(address from, bool blocked) external {
                require(msg.sender == controller, "ONLY_CONTROLLER");
                blockedFrom[from] = blocked;
            }

            function balanceOf(address owner) external view override returns (uint256) {
                require(owner != address(0), "ZERO_OWNER");
                return _balanceOf[owner];
            }

            function ownerOf(uint256 tokenId) public view override returns (address owner) {
                owner = _ownerOf[tokenId];
                require(owner != address(0), "NOT_MINTED");
            }

            function approve(address to, uint256 tokenId) external override {
                address owner = ownerOf(tokenId);
                require(msg.sender == owner || _operatorApproval[owner][msg.sender], "NOT_AUTHORIZED");
                _tokenApproval[tokenId] = to;
                emit Approval(owner, to, tokenId);
            }

            function getApproved(uint256 tokenId) external view override returns (address) {
                ownerOf(tokenId);
                return _tokenApproval[tokenId];
            }

            function setApprovalForAll(address operator, bool approved) external override {
                _operatorApproval[msg.sender][operator] = approved;
                emit ApprovalForAll(msg.sender, operator, approved);
            }

            function isApprovedForAll(address owner, address operator) external view override returns (bool) {
                return _operatorApproval[owner][operator];
            }

            function transferFrom(address from, address to, uint256 tokenId) public override {
                require(!blockedFrom[from], "BLOCKED_FROM");
                address owner = ownerOf(tokenId);
                require(owner == from && to != address(0), "INVALID_TRANSFER");
                require(
                    msg.sender == owner || _tokenApproval[tokenId] == msg.sender
                        || _operatorApproval[owner][msg.sender],
                    "NOT_AUTHORIZED"
                );
                delete _tokenApproval[tokenId];
                --_balanceOf[from];
                ++_balanceOf[to];
                _ownerOf[tokenId] = to;
                emit Transfer(from, to, tokenId);
            }

            function safeTransferFrom(address from, address to, uint256 tokenId) external override {
                safeTransferFrom(from, to, tokenId, "");
            }

            function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
                transferFrom(from, to, tokenId);
                if (to.code.length != 0) {
                    bytes4 selector = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data);
                    require(selector == IERC721Receiver.onERC721Received.selector, "UNSAFE_RECIPIENT");
                }
            }
        }

        contract CounterfeitPrize is IERC721 {
            mapping(uint256 tokenId => address reportedOwner) private _reportedOwner;

            function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
                return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId;
            }

            function balanceOf(address owner) external pure override returns (uint256) {
                require(owner != address(0), "ZERO_OWNER");
                return 0;
            }

            function ownerOf(uint256 tokenId) external view override returns (address owner) {
                owner = _reportedOwner[tokenId];
                require(owner != address(0), "NO_REPORT");
            }

            function approve(address, uint256) external pure override { }

            function getApproved(uint256) external pure override returns (address) {
                return address(0);
            }

            function setApprovalForAll(address, bool) external pure override { }

            function isApprovedForAll(address, address) external pure override returns (bool) {
                return false;
            }

            function transferFrom(address, address to, uint256 tokenId) public override {
                _reportedOwner[tokenId] = to;
                emit Transfer(address(0), to, tokenId);
            }

            function safeTransferFrom(address from, address to, uint256 tokenId) external override {
                safeTransferFrom(from, to, tokenId, "");
            }

            function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
                _reportedOwner[tokenId] = to;
                if (to.code.length != 0) {
                    bytes4 selector = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data);
                    require(selector == IERC721Receiver.onERC721Received.selector, "UNSAFE_RECIPIENT");
                }
                emit Transfer(from, to, tokenId);
            }

            function enforceableSupply() external pure returns (uint256) {
                return 0;
            }
        }

        contract TicketVault is IERC721Receiver {
            uint256 public receiverCalls;
            address public lastTokenContract;
            uint256 public lastTokenId;

            function onERC721Received(address, address, uint256 tokenId, bytes calldata)
                external
                override
                returns (bytes4)
            {
                ++receiverCalls;
                lastTokenContract = msg.sender;
                lastTokenId = tokenId;
                return IERC721Receiver.onERC721Received.selector;
            }

            function redeem(address raffle, uint256 ticketId) external {
                IRaffle(raffle).redeemWinningTicket(ticketId);
            }
        }

        contract DaybreakSimaoProofTest {
            Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

            address private constant SPONSOR = address(0x5100);
            address private constant ALICE = address(0xA11CE);
            address private constant BOB = address(0xB0B);
            address private constant CAROL = address(0xCA401);
            address private constant TREASURY = address(0x7EA5);

            uint256 private constant ONE_USDC = 1_000_000;
            uint256 private constant PRIZE_ID = 7;

            function test_counterfeitPrizeSelfAttestationActivatesAndPaysOut() external {
                (MockUsdc usdc, MockVrfWrapper wrapper, RaffleFactory factory) = _newProtocol();
                CounterfeitPrize prize = new CounterfeitPrize();

                vm.prank(SPONSOR);
                address raffleAddress = factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: SPONSOR,
                        prizeToken: address(prize),
                        prizeTokenId: PRIZE_ID,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 100)
                    })
                );
                Raffle raffle = Raffle(payable(raffleAddress));

                _assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active), "counterfeit did not activate");
                _assertEq(prize.balanceOf(raffleAddress), 0, "counterfeit unexpectedly has enforceable balance");
                _fundAndBuy(usdc, raffle, ALICE, 10, ALICE);
                _resolveNft(raffle, wrapper);

                vm.prank(ALICE);
                raffle.redeemWinningTicket(1);
                raffle.releaseSponsorProceeds();
                raffle.releaseProtocolFees();

                _assert(raffle.winnerRedeemed(), "winner not marked redeemed");
                _assert(raffle.prizeClaimed(), "phantom prize not marked claimed");
                _assertEq(prize.enforceableSupply(), 0, "counterfeit created enforceable supply");
                _assertEq(prize.balanceOf(ALICE), 0, "winner received an enforceable token");
                _assertEq(usdc.balanceOf(SPONSOR), 9_500_000, "sponsor payout mismatch");
                _assertEq(usdc.balanceOf(TREASURY), 500_000, "treasury payout mismatch");
                _assertEq(usdc.balanceOf(raffleAddress), 0, "raffle retained buyer funds");
            }

            function test_revocablePrizeDrainsClaimsWhileWinnerCannotRedeemOrRefund() external {
                (MockUsdc usdc, MockVrfWrapper wrapper, RaffleFactory factory) = _newProtocol();
                SwitchablePrize prize = new SwitchablePrize(SPONSOR);
                Raffle raffle = _createSwitchable(factory, prize, 100);

                _fundAndBuy(usdc, raffle, ALICE, 100, ALICE);
                _resolveNft(raffle, wrapper);

                vm.prank(SPONSOR);
                prize.setBlockedFrom(address(raffle), true);

                raffle.settleWinningTicket(1);
                _assertEq(raffle.sponsorProceeds(), 95_000_000, "sponsor claim mismatch");
                _assertEq(raffle.protocolFees(), 5_000_000, "protocol claim mismatch");

                raffle.releaseSponsorProceeds();
                raffle.releaseProtocolFees();

                vm.prank(ALICE);
                (bool redeemOk,) = address(raffle).call(abi.encodeCall(IRaffle.redeemWinningTicket, (1)));
                _assert(!redeemOk, "blocked prize redemption unexpectedly succeeded");

                (bool refundOk,) = address(raffle).call(abi.encodeWithSelector(IRaffle.enableRefunds.selector));
                _assert(!refundOk, "terminal NftWon unexpectedly entered refunds");

                _assertEq(usdc.balanceOf(SPONSOR), 95_000_000, "sponsor did not extract 95 percent");
                _assertEq(usdc.balanceOf(TREASURY), 5_000_000, "treasury did not extract 5 percent");
                _assertEq(usdc.balanceOf(address(raffle)), 0, "raffle still backs the winner");
                _assertEq(raffle.accountedQuoteBalance(), 0, "accounting still records buyer backing");
                _assertEq(raffle.ownerOf(1), ALICE, "failed redemption did not restore ticket");
                _assert(!raffle.winnerRedeemed(), "failed redemption persisted completion");
                _assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon), "raffle left terminal NftWon");
            }

            function test_ticketTransfersDuringDrawingAndAfterResolution() external {
                (MockUsdc usdc, MockVrfWrapper wrapper, RaffleFactory factory) = _newProtocol();
                SwitchablePrize prize = new SwitchablePrize(SPONSOR);
                Raffle raffle = _createSwitchable(factory, prize, 1);

                _fundAndBuy(usdc, raffle, ALICE, 1, ALICE);
                vm.warp(raffle.endTime());
                uint256 requestId = raffle.requestDraw();
                _assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing), "not drawing");

                vm.prank(ALICE);
                raffle.transferFrom(ALICE, BOB, 1);
                _assertEq(raffle.ownerOf(1), BOB, "drawing transfer blocked");

                wrapper.fulfill(requestId, 0);
                _assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon), "not resolved");

                vm.prank(BOB);
                raffle.transferFrom(BOB, CAROL, 1);
                _assertEq(raffle.ownerOf(1), CAROL, "post-resolution transfer blocked");
            }

            function test_contractWinnerReceivesPrizeWithoutAcknowledgement() external {
                (MockUsdc usdc, MockVrfWrapper wrapper, RaffleFactory factory) = _newProtocol();
                SwitchablePrize prize = new SwitchablePrize(SPONSOR);
                Raffle raffle = _createSwitchable(factory, prize, 1);
                TicketVault vault = new TicketVault();

                _fundAndBuy(usdc, raffle, ALICE, 1, address(vault));
                _assertEq(vault.receiverCalls(), 1, "ticket receipt hook missing");
                _assertEq(vault.lastTokenContract(), address(raffle), "wrong receipt token");
                _resolveNft(raffle, wrapper);

                vault.redeem(address(raffle), 1);

                _assertEq(prize.ownerOf(PRIZE_ID), address(vault), "nominal prize ownership missing");
                _assertEq(vault.receiverCalls(), 1, "prize unexpectedly invoked receiver hook");
                _assertEq(vault.lastTokenContract(), address(raffle), "prize replaced recorded ticket receipt");
                _assert(raffle.winnerRedeemed(), "contract winner redemption not finalized");
            }

            function _newProtocol() private returns (MockUsdc usdc, MockVrfWrapper wrapper, RaffleFactory factory) {
                usdc = new MockUsdc();
                wrapper = new MockVrfWrapper();
                factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
            }

            function _createSwitchable(RaffleFactory factory, SwitchablePrize prize, uint128 reserveEntries)
                private
                returns (Raffle raffle)
            {
                vm.prank(SPONSOR);
                prize.mint(SPONSOR, PRIZE_ID);
                vm.prank(SPONSOR);
                prize.approve(address(factory), PRIZE_ID);
                vm.prank(SPONSOR);
                address raffleAddress = factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: SPONSOR,
                        prizeToken: address(prize),
                        prizeTokenId: PRIZE_ID,
                        reserveEntries: reserveEntries,
                        endTime: uint64(block.timestamp + 100)
                    })
                );
                raffle = Raffle(payable(raffleAddress));
            }

            function _fundAndBuy(MockUsdc usdc, Raffle raffle, address payer, uint128 entries, address recipient)
                private
            {
                uint256 amount = uint256(entries) * ONE_USDC;
                usdc.mint(payer, amount);
                vm.prank(payer);
                usdc.approve(address(raffle), amount);
                vm.prank(payer);
                raffle.buyEntries(recipient, entries);
            }

            function _resolveNft(Raffle raffle, MockVrfWrapper wrapper) private {
                vm.warp(raffle.endTime());
                uint256 requestId = raffle.requestDraw();
                wrapper.fulfill(requestId, 0);
                _assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon), "not NftWon");
            }

            function _assert(bool condition, string memory message) private pure {
                require(condition, message);
            }

            function _assertEq(uint256 actual, uint256 expected, string memory message) private pure {
                require(actual == expected, message);
            }

            function _assertEq(address actual, address expected, string memory message) private pure {
                require(actual == expected, message);
            }
        }
