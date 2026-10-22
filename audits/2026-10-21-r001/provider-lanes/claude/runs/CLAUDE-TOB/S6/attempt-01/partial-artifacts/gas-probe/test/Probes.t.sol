// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Raffle } from "raffle/Raffle.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";

interface VmP {
    function warp(uint256) external;
    function prank(address) external;
    function deal(address, uint256) external;
    function expectRevert(bytes calldata) external;
    function getNonce(address) external view returns (uint64);
}

/// @notice Prize whose transferFrom "succeeds" without moving the token once armed.
contract NoOpTransferNFT is MockPrizeNFT {
    bool public noop;

    function arm() external {
        noop = true;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (noop) return;
        super.transferFrom(from, to, tokenId);
    }
}

contract NoErc165 {
    function ownerOf(uint256) external pure returns (address) {
        return address(0);
    }
}

contract Erc165False {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

/// @notice Remaining defensive paths and one deployment-configuration probe.
contract ProbesTest {
    VmP constant vm = VmP(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    MockUSDC usdc;
    MockVRFV2PlusWrapper wrapper;
    address constant ALICE = address(0xA11CE);

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC();
        wrapper = new MockVRFV2PlusWrapper();
        vm.deal(address(this), 10 ether);
    }

    function _createAddr(address deployer, uint256 nonce) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce)))))));
    }

    function _params(address prize, uint256 id, uint128 reserve) internal view returns (IRaffleFactory.CreateRaffleParams memory) {
        return IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: address(0x5EC1),
            prizeToken: prize,
            prizeTokenId: id,
            reserveEntries: reserve,
            endTime: uint64(block.timestamp + 1 days)
        });
    }

    /// Deployment probe: a protocolTreasury equal to the factory's first clone address passes the constructor checks,
    /// but every createRaffle then deploys the clone at that address and its initialize() rejects
    /// protocolTreasury == address(this). The CREATE is rolled back, the nonce is not consumed, so the factory is
    /// permanently unusable.
    function test_P1_treasuryAtFutureCloneAddressBricksFactory() public {
        address futureFactory = _createAddr(address(this), vm.getNonce(address(this)));
        address firstClone = _createAddr(futureFactory, 2); // nonce 1 = implementation
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), firstClone);
        require(address(f) == futureFactory, "factory address prediction");
        MockPrizeNFT nft = new MockPrizeNFT();
        for (uint256 i = 1; i <= 3; ++i) {
            nft.mint(address(this), i);
            nft.approve(address(f), i);
            vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, firstClone));
            f.createRaffle(_params(address(nft), i, 1));
        }
        require(f.raffleCount() == 0 && vm.getNonce(address(f)) == 2, "nonce never advances: factory bricked");
    }

    /// Delivery verification: a prize whose transferFrom silently does nothing cannot be "delivered".
    function test_P2_silentNoOpTransferIsCaughtByOwnerOfCheck() public {
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), address(0x7EA5));
        NoOpTransferNFT nft = new NoOpTransferNFT();
        nft.mint(address(this), 1);
        nft.approve(address(f), 1);
        Raffle r = Raffle(payable(f.createRaffle(_params(address(nft), 1, 1))));
        usdc.mint(address(this), 3e6);
        usdc.approve(address(r), 3e6);
        r.buyEntries(ALICE, 3);
        vm.warp(r.endTime());
        uint256 id = r.requestDraw{ value: wrapper.priceNative() }();
        uint256[] memory w = new uint256[](1);
        wrapper.fulfill(id, w);
        nft.arm();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.PrizeDeliveryVerificationFailed.selector, ALICE));
        vm.prank(ALICE);
        r.redeemWinningTicket(1);
    }

    function test_P3_prizeWithoutOrFailingErc165IsRejected() public {
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), address(0x7EA5));
        NoErc165 a = new NoErc165();
        Erc165False b = new Erc165False();
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, address(a)));
        f.createRaffle(_params(address(a), 1, 1));
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, address(b)));
        f.createRaffle(_params(address(b), 1, 1));
    }

    function test_P4_emptyRaffleNonSponsorMustWaitForEndTime() public {
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), address(0x7EA5));
        MockPrizeNFT nft = new MockPrizeNFT();
        nft.mint(address(this), 1);
        nft.approve(address(f), 1);
        Raffle r = Raffle(payable(f.createRaffle(_params(address(nft), 1, 1))));
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, uint256(r.endTime()), block.timestamp));
        vm.prank(ALICE);
        r.enableRefunds();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable { }
}
