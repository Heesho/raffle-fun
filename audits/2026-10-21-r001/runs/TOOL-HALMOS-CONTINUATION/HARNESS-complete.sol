// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import { SupplementarySymbolic } from "./SupplementarySymbolic.t.sol";
/// @notice Same input domains and original assertions, with successful execution also required.
contract CompleteSymbolic is SupplementarySymbolic {
    function check_complete_refund(uint8 a,uint8 b,bool reverse) public {
        vm.assume(a>0&&a<=16&&b>0&&b<=16);
        (bool ok,)=address(this).call(abi.encodeCall(this.check_refund_two_actors,(a,b,reverse)));
        assert(ok);
    }
    function check_complete_cash(uint8 a,uint8 b,uint8 pick,bool sponsorFirst) public {
        vm.assume(a>0&&a<=16&&b>0&&b<=16);
        vm.assume(uint256(pick)<uint256(a)+uint256(b));
        (bool ok,)=address(this).call(abi.encodeCall(this.check_cash_two_actors,(a,b,pick,sponsorFirst)));
        assert(ok);
    }
    function check_complete_nft(uint8 a,uint8 b,uint8 pick) public {
        vm.assume(a>0&&a<=16&&b>0&&b<=16);
        vm.assume(uint256(pick)<uint256(a)+uint256(b));
        (bool ok,)=address(this).call(abi.encodeCall(this.check_nft_two_actors,(a,b,pick)));
        assert(ok);
    }
}
