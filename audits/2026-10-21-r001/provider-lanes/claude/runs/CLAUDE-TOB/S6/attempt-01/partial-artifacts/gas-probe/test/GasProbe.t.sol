// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Raffle } from "raffle/Raffle.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";

interface VmCool {
    function cool(address) external;
    function warp(uint256) external;
    function prank(address) external;
    function deal(address, uint256) external;
}

/// @notice Measures the VRF callback with the raffle's account and storage marked cold (worst case per tx).
contract GasProbeTest {
    VmCool constant vm = VmCool(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    event log_named_uint(string key, uint256 val);

    function test_callbackGasCold() public {
        vm.warp(1_700_000_000);
        MockUSDC usdc = new MockUSDC();
        MockVRFV2PlusWrapper wrapper = new MockVRFV2PlusWrapper();
        MockPrizeNFT nft = new MockPrizeNFT();
        RaffleFactory factory = new RaffleFactory(address(usdc), address(wrapper), address(0x7EA5));
        nft.mint(address(this), 1);
        nft.approve(address(factory), 1);
        Raffle r = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: address(0x5EC1), prizeToken: address(nft), prizeTokenId: 1, reserveEntries: 5,
            endTime: uint64(block.timestamp + 1 days)
        }))));
        usdc.mint(address(this), 10e6);
        usdc.approve(address(r), 10e6);
        r.buyEntries(address(0xA11CE), 10);
        vm.warp(block.timestamp + 1 days);
        vm.deal(address(this), 1 ether);
        uint256 id = r.requestDraw{ value: wrapper.priceNative() }();
        vm.cool(address(r));
        uint256[] memory w = new uint256[](1);
        w[0] = 12345;
        (bool ok, uint256 gasUsed) = wrapper.fulfill(id, w);
        require(ok && r.winningEntry() != 0, "resolved");
        emit log_named_uint("fulfill callback gas, raffle account+storage cold", gasUsed);
        require(gasUsed < 300_000, "within callbackGasLimit");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable { }
}
