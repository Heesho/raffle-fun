// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Raffle} from "./Raffle.sol";
import {RaffleFactory} from "./RaffleFactory.sol";
import {IRaffle} from "./interfaces/IRaffle.sol";
import {IRaffleFactory} from "./interfaces/IRaffleFactory.sol";

contract EchidnaMockUSDC is IERC20, IERC20Metadata {
    string public constant override name = "USD Coin";
    string public constant override symbol = "USDC";
    uint8 public constant override decimals = 6;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "ERC20: insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = currentAllowance - value;
        }
        require(balanceOf[from] >= value, "ERC20: insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        return true;
    }
}

contract EchidnaMockPrizeNFT is ERC721 {
    constructor() ERC721("MockPrize", "PRIZE") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract EchidnaMockVRFWrapper {
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
}

contract RaffleEchidnaProperties {
    EchidnaMockUSDC public usdc;
    EchidnaMockUSDC public mockLink;
    EchidnaMockPrizeNFT public prizeNft;
    EchidnaMockVRFWrapper public vrfWrapper;
    RaffleFactory public factory;
    Raffle public raffle;

    address public constant SPONSOR = address(0x1001);
    address public constant TREASURY = address(0x1002);
    address public constant USER_A = address(0x2001);
    address public constant USER_B = address(0x2002);

    constructor() {
        usdc = new EchidnaMockUSDC();
        mockLink = new EchidnaMockUSDC();
        prizeNft = new EchidnaMockPrizeNFT();
        vrfWrapper = new EchidnaMockVRFWrapper(address(mockLink));
        factory = new RaffleFactory(address(usdc), address(vrfWrapper), TREASURY);

        prizeNft.mint(address(this), 1);
        prizeNft.approve(address(factory), 1);

        address raffleAddr = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prizeNft),
                prizeTokenId: 1,
                sponsorRecipient: SPONSOR,
                reserveEntries: 10,
                endTime: uint64(block.timestamp + 7 days)
            })
        );
        raffle = Raffle(payable(raffleAddr));

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(raffle), type(uint256).max);
    }

    function action_buyEntriesA(uint8 rawCount) external {
        uint128 count = uint128((uint256(rawCount) % 10) + 1);
        if (raffle.status() == IRaffle.Status.Active && block.timestamp < raffle.endTime()) {
            raffle.buyEntries(USER_A, count);
        }
    }

    function action_buyEntriesB(uint8 rawCount) external {
        uint128 count = uint128((uint256(rawCount) % 10) + 1);
        if (raffle.status() == IRaffle.Status.Active && block.timestamp < raffle.endTime()) {
            raffle.buyEntries(USER_B, count);
        }
    }

    // Echidna Property 1: ERC721 interface & metadata conformity
    function echidna_erc721_interfaces_supported() public view returns (bool) {
        return
            raffle.supportsInterface(type(IERC165).interfaceId) &&
            raffle.supportsInterface(type(IERC721).interfaceId) &&
            raffle.supportsInterface(type(IERC721Metadata).interfaceId) &&
            !raffle.supportsInterface(0xffffffff);
    }

    // Echidna Property 2: Quote token balance conservation (standard ERC20 without direct transfers)
    function echidna_quote_balance_conservation() public view returns (bool) {
        return raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle));
    }

    // Echidna Property 3: Protocol destination addresses never own Raffle ERC721 tickets
    function echidna_no_protocol_destination_ticket_owner() public view returns (bool) {
        return
            raffle.balanceOf(address(raffle)) == 0 &&
            raffle.balanceOf(address(factory)) == 0 &&
            raffle.balanceOf(factory.raffleImplementation()) == 0 &&
            raffle.balanceOf(address(usdc)) == 0 &&
            raffle.balanceOf(address(vrfWrapper)) == 0 &&
            raffle.balanceOf(address(prizeNft)) == 0;
    }

    // Echidna Property 4: Gross sales equals totalEntries * ENTRY_PRICE
    function echidna_gross_sales_consistency() public view returns (bool) {
        return raffle.grossSales() == uint256(raffle.totalEntries()) * raffle.ENTRY_PRICE();
    }

    // Echidna Property 5: Ticket count matches User A + User B ERC721 balances
    function echidna_erc721_balance_sum_matches_ticket_count() public view returns (bool) {
        return raffle.balanceOf(USER_A) + raffle.balanceOf(USER_B) == raffle.ticketCount();
    }
}
