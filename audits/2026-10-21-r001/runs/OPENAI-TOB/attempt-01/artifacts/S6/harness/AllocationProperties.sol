// Audit-created arithmetic-only property harness; not an end-to-end raffle proof.
pragma solidity 0.8.36;
import {RaffleConstants} from "../../tool-copy/contracts/src/libraries/RaffleConstants.sol";
import {Math} from "../../tool-copy/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol";
contract AllocationProperties {
 uint128 public entries;
 function setEntries(uint128 n) public { entries=n; }
 function echidna_cash_conservation() public view returns(bool) {
 uint256 gross=uint256(entries)*RaffleConstants.ENTRY_PRICE;
 uint256 fee=Math.mulDiv(gross,RaffleConstants.PROTOCOL_FEE_BPS,RaffleConstants.BPS);
 uint256 winner=Math.mulDiv(gross,RaffleConstants.CASH_WINNER_BPS,RaffleConstants.BPS);
 uint256 sponsor=gross-fee-winner;
 return sponsor+fee+winner==gross; }
 function echidna_nft_conservation() public view returns(bool) {
 uint256 gross=uint256(entries)*RaffleConstants.ENTRY_PRICE;
 uint256 fee=Math.mulDiv(gross,RaffleConstants.PROTOCOL_FEE_BPS,RaffleConstants.BPS);
 return gross-fee+fee==gross; }
}
