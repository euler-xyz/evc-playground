// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultRegularBorrowable} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseTest} from "../base/BaseTest.t.sol";

/// @title VaultRegularBorrowable Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultRegularBorrowableBeforeAfterHooks is BaseTest {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct VaultRegularBorrowableBeforeAfterHooksVars {
        // VaultRegularBorrowable
        uint256 interestAccumulatorBefore;
        uint256 interestAccumulatorAfter;
    }

    VaultRegularBorrowableBeforeAfterHooksVars rvbVars;

    function _rvbBefore(address _vault) internal {
        VaultRegularBorrowable rvb = VaultRegularBorrowable(_vault);
        rvbVars.interestAccumulatorBefore = rvb.getInterestAccumulator();
    }

    function _rvbAfter(address _vault) internal {
        VaultRegularBorrowable rvb = VaultRegularBorrowable(_vault);
        rvbVars.interestAccumulatorAfter = rvb.getInterestAccumulator();

        // VaultSimple Post Conditions
        assert_rvbPostConditionA();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultRegularBorrowable
        Post Condition A: Interest rate monotonically increases
           

    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_rvbPostConditionA() internal {
        assertGe(
            rvbVars.interestAccumulatorAfter,
            rvbVars.interestAccumulatorBefore,
            "Interest rate must monotonically increase"
        );
    }
}
