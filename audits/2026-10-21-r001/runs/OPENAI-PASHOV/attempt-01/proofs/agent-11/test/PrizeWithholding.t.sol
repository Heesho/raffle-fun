// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import {RaffleFactory} from "../snapshot/target/packages/contracts/src/RaffleFactory.sol";
import {Raffle} from "../snapshot/target/packages/contracts/src/Raffle.sol";
import {IRaffle} from "../snapshot/target/packages/contracts/src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../snapshot/target/packages/contracts/src/interfaces/IRaffleFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function deal(address,uint256) external;
}
contract Quote {
    uint8 public constant decimals = 6;
    mapping(address=>uint256) public balanceOf;
    mapping(address=>mapping(address=>uint256)) public allowance;
    function mint(address to,uint256 v) external { balanceOf[to] += v; }
    function approve(address to,uint256 v) external returns(bool) { allowance[msg.sender][to]=v; return true; }
    function transfer(address to,uint256 v) external returns(bool) { balanceOf[msg.sender]-=v; balanceOf[to]+=v; return true; }
    function transferFrom(address from,address to,uint256 v) external returns(bool) {
        allowance[from][msg.sender]-=v; balanceOf[from]-=v; balanceOf[to]+=v; return true;
    }
}
contract Wrapper {
    address public constant link = address(0x1234);
    uint256 public constant FEE = 1;
    function calculateRequestPriceNative(uint32,uint32) external pure returns(uint256) { return FEE; }
    function requestRandomWordsInNative(uint32,uint16,uint32,bytes calldata) external payable returns(uint256) {
        require(msg.value==FEE); return 1;
    }
    function fulfill(Raffle raffle) external {
        uint256[] memory words = new uint256[](1); words[0]=0;
        raffle.rawFulfillRandomWords(1,words);
    }
}
contract RestrictablePrize is ERC721 {
    address public immutable controller;
    bool public frozen;
    constructor() ERC721("Prize","PRIZE") { controller=msg.sender; _mint(msg.sender,1); }
    function freeze() external { require(msg.sender==controller); frozen=true; }
    function transferFrom(address from,address to,uint256 id) public override {
        require(!frozen,"PRIZE_FROZEN"); super.transferFrom(from,to,id);
    }
}
contract PrizeWithholdingTest {
    Vm constant vm=Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event Demonstrated(uint256 sponsorReceives,uint256 buyerRefund,uint256 nftOwnerPrizeBlocked);
    function testSponsorWithdrawsBeforePrizeDelivery() external {
        vm.warp(1_000_000);
        Quote quote=new Quote(); Wrapper wrapper=new Wrapper();
        RaffleFactory factory=new RaffleFactory(address(quote),address(wrapper),address(0xBEEF));
        RestrictablePrize prize=new RestrictablePrize();
        prize.approve(address(factory),1);
        Raffle raffle=Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient:address(this), prizeToken:address(prize), prizeTokenId:1,
            reserveEntries:100,endTime:uint64(block.timestamp+1)
        }))));
        require(prize.ownerOf(1)==address(raffle),"escrow must be real");
        address buyer=address(0xB0B);
        quote.mint(buyer,100_000_000);
        vm.prank(buyer); quote.approve(address(raffle),100_000_000);
        vm.prank(buyer); raffle.buyEntries(buyer,100);
        prize.freeze();
        vm.warp(block.timestamp+1); vm.deal(address(this),1);
        raffle.requestDraw{value:1}(); wrapper.fulfill(raffle);
        require(raffle.status()==IRaffle.Status.NftWon);
        raffle.settleWinningTicket(1);
        raffle.releaseSponsorProceeds(); raffle.releaseProtocolFees();
        require(quote.balanceOf(address(this))==95_000_000,"sponsor received 95 USDC");
        require(quote.balanceOf(address(0xBEEF))==5_000_000,"treasury received 5 USDC");
        vm.prank(buyer);
        (bool redeemed,)=address(raffle).call(abi.encodeCall(Raffle.redeemWinningTicket,(1)));
        require(!redeemed,"redemption must fail");
        require(raffle.ownerOf(1)==buyer,"failed delivery preserves ticket");
        require(!raffle.winnerRedeemed(),"failed delivery preserves state");
        require(prize.ownerOf(1)==address(raffle),"prize remains blocked");
        (bool refunds,)=address(raffle).call(abi.encodeCall(Raffle.enableRefunds,()));
        require(!refunds,"NFT result disallows refunds");
        require(quote.balanceOf(buyer)==0 && quote.balanceOf(address(raffle))==0);
        emit Demonstrated(95_000_000,0,1);
    }
}
