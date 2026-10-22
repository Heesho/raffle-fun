// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import {Raffle} from "../../../src/Raffle.sol";
import {RaffleFactory} from "../../../src/RaffleFactory.sol";
import {IRaffle} from "../../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../../src/interfaces/IRaffleFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
interface SymVm { function assume(bool) external; function prank(address) external; function warp(uint256) external; }
contract SymQuote {
    uint8 public constant decimals=6;
    mapping(address=>uint256) public balanceOf;
    mapping(address=>mapping(address=>uint256)) public allowance;
    function mint(address a,uint256 n) external { balanceOf[a]+=n; }
    function approve(address a,uint256 n) external returns(bool){allowance[msg.sender][a]=n;return true;}
    function transfer(address a,uint256 n) external returns(bool){require(balanceOf[msg.sender]>=n);balanceOf[msg.sender]-=n;balanceOf[a]+=n;return true;}
    function transferFrom(address a,address b,uint256 n) external returns(bool){require(balanceOf[a]>=n&&allowance[a][msg.sender]>=n);allowance[a][msg.sender]-=n;balanceOf[a]-=n;balanceOf[b]+=n;return true;}
}
contract SymPrize is ERC721 {
    constructor() ERC721("fresh symbolic prize","FSP"){}
    function mint(address a,uint256 i) external {_mint(a,i);}
}
contract SymWrapper {
    function link() external pure returns(address){return address(0x1234);}
    function calculateRequestPriceNative(uint32,uint32) external pure returns(uint256){return 0;}
    function requestRandomWordsInNative(uint32,uint16,uint32,bytes calldata) external payable returns(uint256){return 1;}
    function deliver(Raffle r,uint256 id,uint256 word) external {uint256[] memory w=new uint256[](1);w[0]=word;r.rawFulfillRandomWords(id,w);}
}
contract SupplementarySymbolic {
    SymVm constant vm=SymVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant A=address(0x1111);address constant B=address(0x2222);address constant C=address(0x3333);
    address constant SP=address(0xCAFE);address constant TR=address(0xFEE);
    uint256 constant FUNDS=100_000_000;uint64 constant END=1_800_000_100;
    SymQuote q;SymPrize prize;SymWrapper w;RaffleFactory f;
    function setUp() public {
        vm.warp(1_800_000_000);
        q=new SymQuote();prize=new SymPrize();w=new SymWrapper();f=new RaffleFactory(address(q),address(w),TR);
        q.mint(A,FUNDS);q.mint(B,FUNDS);
    }
    function fresh(uint128 reserve) internal returns(Raffle r){
        prize.mint(address(this),1);prize.approve(address(f),1);
        r=Raffle(payable(f.createRaffle(IRaffleFactory.CreateRaffleParams(SP,address(prize),1,reserve,END))));
        assert(f.isRaffle(address(r)));assert(f.raffleById(1)==address(r));assert(prize.ownerOf(1)==address(r));
    }
    function purchases(Raffle r,uint8 a,uint8 b) internal {
        vm.assume(a>0&&a<=16);vm.assume(b>0&&b<=16);
        vm.prank(A);q.approve(address(r),FUNDS);vm.prank(A);r.buyEntries(A,a);
        vm.prank(B);q.approve(address(r),FUNDS);vm.prank(B);r.buyEntries(B,b);
        uint256 gross=(uint256(a)+uint256(b))*1_000_000;
        assert(r.totalEntries()==uint128(uint256(a)+uint256(b)));assert(r.ticketCount()==2);
        assert(q.balanceOf(address(r))==gross);assert(r.accountedQuoteBalance()==gross);
        (uint128 lo1,uint128 hi1)=r.ticketRange(1);(uint128 lo2,uint128 hi2)=r.ticketRange(2);
        assert(lo1==1&&hi1==a&&lo2==uint128(a)+1&&hi2==uint128(a)+uint128(b));
    }
    function invariantBalance(Raffle r) internal view {assert(q.balanceOf(address(r))==r.accountedQuoteBalance());}
    function refundOne(Raffle r,address actor,uint256 id) internal {uint256[] memory ids=new uint256[](1);ids[0]=id;vm.prank(actor);r.refundTickets(ids);invariantBalance(r);}
    function check_refund_two_actors(uint8 a,uint8 b,bool reverse) public {
        Raffle r=fresh(33);purchases(r,a,b);vm.warp(uint256(END)+2 days);r.enableRefunds();
        uint256 before=r.remainingRefundLiability();uint256[] memory ids=new uint256[](1);ids[0]=1;
        vm.prank(C);(bool ok,)=address(r).call(abi.encodeCall(IRaffle.refundTickets,(ids)));
        assert(!ok);assert(r.remainingRefundLiability()==before);assert(r.ownerOf(1)==A);invariantBalance(r);
        if(reverse){refundOne(r,B,2);refundOne(r,A,1);}else{refundOne(r,A,1);refundOne(r,B,2);}
        assert(q.balanceOf(A)==FUNDS&&q.balanceOf(B)==FUNDS);assert(r.remainingRefundLiability()==0);
        assert(r.sponsorProceeds()==0&&r.protocolFees()==0&&r.accountedQuoteBalance()==0);
        r.releaseSponsorPrize();assert(prize.ownerOf(1)==SP);
    }
    function resolve(Raffle r,uint8 a,uint8 b,uint8 pick) internal returns(uint256 ticket,address winner,address loser){
        purchases(r,a,b);vm.assume(uint256(pick)<uint256(a)+uint256(b));
        vm.warp(END);r.requestDraw();w.deliver(r,1,pick);
        assert(r.winningEntry()==uint128(pick)+1);
        ticket=pick<a?1:2;winner=pick<a?A:B;loser=pick<a?B:A;
        r.settleWinningTicket(ticket);invariantBalance(r);
        vm.prank(loser);(bool ok,)=address(r).call(abi.encodeCall(IRaffle.redeemWinningTicket,(ticket)));
        assert(!ok);assert(!r.winnerRedeemed());assert(r.ownerOf(ticket)==winner);invariantBalance(r);
    }
    function check_cash_two_actors(uint8 a,uint8 b,uint8 pick,bool sponsorFirst) public {
        Raffle r=fresh(33);(uint256 ticket,address winner,)=resolve(r,a,b,pick);
        assert(r.status()==IRaffle.Status.CashWon);
        uint256 gross=(uint256(a)+uint256(b))*1_000_000;
        assert(r.winnerProceeds()==gross*80/100&&r.sponsorProceeds()==gross*15/100&&r.protocolFees()==gross*5/100);
        if(sponsorFirst){r.releaseSponsorProceeds();invariantBalance(r);}
        vm.prank(winner);r.redeemWinningTicket(ticket);invariantBalance(r);
        if(!sponsorFirst){r.releaseSponsorProceeds();invariantBalance(r);}
        r.releaseProtocolFees();invariantBalance(r);r.releaseSponsorPrize();
        assert(q.balanceOf(SP)==gross*15/100&&q.balanceOf(TR)==gross*5/100);
        assert(q.balanceOf(A)+q.balanceOf(B)+q.balanceOf(SP)+q.balanceOf(TR)==2*FUNDS);
        assert(r.accountedQuoteBalance()==0&&r.winnerRedeemed()&&prize.ownerOf(1)==SP);
    }
    function check_nft_two_actors(uint8 a,uint8 b,uint8 pick) public {
        Raffle r=fresh(1);(uint256 ticket,address winner,)=resolve(r,a,b,pick);
        assert(r.status()==IRaffle.Status.NftWon&&r.winnerProceeds()==0);
        uint256 gross=(uint256(a)+uint256(b))*1_000_000;
        r.releaseProtocolFees();invariantBalance(r);r.releaseSponsorProceeds();invariantBalance(r);
        vm.prank(winner);r.redeemWinningTicket(ticket);invariantBalance(r);
        assert(prize.ownerOf(1)==winner&&r.winnerRedeemed()&&r.prizeClaimed());
        assert(q.balanceOf(SP)==gross*95/100&&q.balanceOf(TR)==gross*5/100&&r.accountedQuoteBalance()==0);
        assert(q.balanceOf(A)+q.balanceOf(B)+q.balanceOf(SP)+q.balanceOf(TR)==2*FUNDS);
    }
    function check_initializer_and_callback_denial(uint8 a,uint8 b,uint8 pick) public {
        Raffle r=fresh(33);purchases(r,a,b);
        IRaffle.RaffleInitParams memory p=IRaffle.RaffleInitParams(A,A,TR,address(prize),1,1,1,END);
        vm.prank(C);(bool ok,)=address(r).call(abi.encodeCall(IRaffle.initialize,(p)));assert(!ok);
        vm.prank(C);(ok,)=f.raffleImplementation().call(abi.encodeCall(IRaffle.initialize,(p)));assert(!ok);
        vm.warp(END);r.requestDraw();uint256[] memory words=new uint256[](1);words[0]=pick;
        vm.prank(C);(ok,)=address(r).call(abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])",1,words));
        assert(!ok&&r.status()==IRaffle.Status.Drawing&&r.winningEntry()==0);
        w.deliver(r,2,pick);assert(r.status()==IRaffle.Status.Drawing&&r.winningEntry()==0);invariantBalance(r);
        assert(r.sponsor()==address(this)&&r.endTime()==END&&r.reserveEntries()==33&&r.initialized());
    }
}
