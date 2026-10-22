// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { Vm, MockUSDC, MockVRFWrapper, MockNFT } from "../src/Mocks.sol";

abstract contract Base {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant T0 = 1_800_000_000;
    uint256 internal constant E = 1_000_000; // ENTRY_PRICE

    MockUSDC internal usdc;
    MockVRFWrapper internal wrapper;
    RaffleFactory internal factory;
    MockNFT internal nft;

    address internal treasury;
    address internal sponsor;
    address internal recipient;
    address internal alice;
    address internal bob;
    address internal carol;
    address internal keeper;

    function setUp() public virtual {
        vm.warp(T0);
        treasury = vm.addr(0xA001);
        sponsor = vm.addr(0xA002);
        recipient = vm.addr(0xA003);
        alice = vm.addr(0xA004);
        bob = vm.addr(0xA005);
        carol = vm.addr(0xA006);
        keeper = vm.addr(0xA007);
        usdc = new MockUSDC();
        wrapper = new MockVRFWrapper();
        factory = new RaffleFactory(address(usdc), address(wrapper), treasury);
        nft = new MockNFT();
    }

    // ---------------------------------------------------------------- helpers

    function _params(address rcpt, address prize, uint256 id, uint128 reserve, uint64 end)
        internal
        pure
        returns (IRaffleFactory.CreateRaffleParams memory p)
    {
        p = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: rcpt, prizeToken: prize, prizeTokenId: id, reserveEntries: reserve, endTime: end
        });
    }

    function _create(uint256 tokenId, uint128 reserve, uint64 end) internal returns (Raffle r) {
        r = _createFor(sponsor, recipient, tokenId, reserve, end);
    }

    function _createFor(address who, address rcpt, uint256 tokenId, uint128 reserve, uint64 end)
        internal
        returns (Raffle r)
    {
        nft.mint(who, tokenId);
        vm.prank(who);
        nft.approve(address(factory), tokenId);
        vm.prank(who);
        r = Raffle(payable(factory.createRaffle(_params(rcpt, address(nft), tokenId, reserve, end))));
    }

    function _buy(Raffle r, address who, uint128 n) internal returns (uint256 id) {
        usdc.mint(who, uint256(n) * E);
        vm.prank(who);
        usdc.approve(address(r), type(uint256).max);
        vm.prank(who);
        id = r.buyEntries(who, n);
    }

    function _request(Raffle r) internal returns (uint256 id) {
        uint256 fee = r.getVrfRequestPrice();
        vm.deal(keeper, fee + 1 ether);
        vm.prank(keeper);
        id = r.requestDraw{ value: fee + 0.5 ether }();
    }

    function _fulfill(Raffle r, uint256 word) internal returns (bool ok) {
        ok = wrapper.fulfillOne(r.vrfRequestId(), word);
    }

    /// @dev word such that winningEntry == target (1-based), given totalEntries.
    function _wordFor(Raffle r, uint128 target) internal view returns (uint256) {
        return uint256(target - 1) + uint256(r.totalEntries()) * 12_345;
    }

    function _computeCreateAddress(address deployer, uint256 nonce) internal pure returns (address) {
        bytes memory data;
        if (nonce == 0) data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        else if (nonce <= 0x7f) data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce));
        else if (nonce <= 0xff) data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }

    function _eq(uint256 a, uint256 b, string memory what) internal pure {
        if (a != b) revert(string.concat(what, ": ", _s(a), " != ", _s(b)));
    }

    function _s(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        bytes memory b;
        while (v != 0) {
            b = abi.encodePacked(bytes1(uint8(48 + (v % 10))), b);
            v /= 10;
        }
        return string(b);
    }

    function _st(Raffle r) internal view returns (uint8) {
        return uint8(r.status());
    }
}
