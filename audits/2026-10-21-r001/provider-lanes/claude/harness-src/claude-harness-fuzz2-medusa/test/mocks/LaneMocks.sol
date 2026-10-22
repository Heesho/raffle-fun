// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Lane-owned mocks (Anthropic lane, audit r001). Written from the clean source and the Chainlink
// interface only; the project's own mocks/tests were not consulted.

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract LaneUSDC is ERC20 {
    constructor() ERC20("Lane USD Coin", "USDC") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LanePrize is ERC721 {
    constructor() ERC721("Lane Prize", "PRZ") { }

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}

interface IRawFulfill {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

/// @dev Minimal VRF v2.5 native-payment wrapper stand-in. Callback is driven explicitly by the harness.
contract LaneVRFWrapper {
    uint256 public fee = 0.001 ether;
    uint256 public lastRequestId;
    mapping(uint256 => address) public consumerOf;
    address public link = address(0x1111);

    function setFee(uint256 f) external {
        fee = f;
    }

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) {
        return fee;
    }

    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) {
        return fee;
    }

    function calculateRequestPrice(uint32, uint32) external view returns (uint256) {
        return fee;
    }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata) external payable returns (uint256 id) {
        require(msg.value >= fee, "fee");
        id = ++lastRequestId;
        consumerOf[id] = msg.sender;
    }

    function fulfill(uint256 id, uint256 word) external {
        uint256[] memory w = new uint256[](1);
        w[0] = word;
        IRawFulfill(consumerOf[id]).rawFulfillRandomWords(id, w);
    }

    function fulfillRaw(address consumer, uint256 id, uint256[] memory words) external {
        IRawFulfill(consumer).rawFulfillRandomWords(id, words);
    }
}
