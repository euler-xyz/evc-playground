// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultRegularBorrowable} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title VaultRegularBorrowable Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultRegularBorrowableBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct VaultRegularBorrowableBeforeAfterHooksVars {
        // VaultRegularBorrowable
        uint256 interestAccumulatorBefore;
        uint256 interestAccumulatorAfter;
        uint256 liabilityValueBefore;
        uint256 liabilityValueAfter;
        uint256 collateralValueBefore;
        uint256 collateralValueAfter;
    }

    VaultRegularBorrowableBeforeAfterHooksVars rvbVars;

    function _rvbBefore(address _vault) internal {
        VaultRegularBorrowable rvb = VaultRegularBorrowable(_vault);
        rvbVars.interestAccumulatorBefore = rvb.getInterestAccumulator();
        (rvbVars.liabilityValueBefore, rvbVars.collateralValueBefore) = rvb.getAccountLiabilityStatus(address(actor));
    }

    function _rvbAfter(address _vault) internal {
        VaultRegularBorrowable rvb = VaultRegularBorrowable(_vault);
        rvbVars.interestAccumulatorAfter = rvb.getInterestAccumulator();
        (rvbVars.liabilityValueAfter, rvbVars.collateralValueAfter) = rvb.getAccountLiabilityStatus(address(actor));

        // VaultSimple Post Conditions
        assert_rvbPostConditionA();
        assert_rvbPostConditionB();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultRegularBorrowable
        Post Condition A: Interest rate monotonically increases
        Post Condition B: A healthy account cant never be left unhealthy after a transaction

    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_rvbPostConditionA() internal {
        assertGe(
            rvbVars.interestAccumulatorAfter,
            rvbVars.interestAccumulatorBefore,
            "Interest rate must monotonically increase"
        );
    }

    function assert_rvbPostConditionB() internal {
        if (isAccountHealthy(rvbVars.liabilityValueBefore, rvbVars.collateralValueBefore)) {
            assertTrue(
                isAccountHealthy(rvbVars.liabilityValueAfter, rvbVars.collateralValueAfter),
                "Account cannot be left unhealthy"
            );
        }
    }
}
