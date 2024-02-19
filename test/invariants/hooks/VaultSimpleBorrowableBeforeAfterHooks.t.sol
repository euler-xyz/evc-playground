// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultSimpleBorrowable} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title VaultSimpleBorrowable Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultSimpleBorrowableBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct VaultSimpleBorrowableVars {
        // VaultSimpleBorrowable
        uint256 borrowCapBefore;
        uint256 borrowCapAfter;
        uint256 totalBorrowedBefore;
        uint256 totalBorrowedAfter;
        bool controllerEnabledBefore;
        bool controllerEnabledAfter;
        uint256 userDebtBefore;
        uint256 userDebtAfter;
    }

    VaultSimpleBorrowableVars svbVars;

    function _svbBefore(address _vault) internal {
        VaultSimpleBorrowable svb = VaultSimpleBorrowable(_vault);
        svbVars.borrowCapBefore = svb.borrowCap();
        svbVars.totalBorrowedBefore = svb.totalBorrowed();
        svbVars.controllerEnabledBefore = evc.isControllerEnabled(address(actor), _vault);
        svbVars.userDebtBefore = svb.debtOf(address(actor));
    }

    function _svbAfter(address _vault) internal {
        VaultSimpleBorrowable svb = VaultSimpleBorrowable(_vault);
        svbVars.borrowCapAfter = svb.borrowCap();
        svbVars.totalBorrowedAfter = svb.totalBorrowed();
        svbVars.controllerEnabledAfter = evc.isControllerEnabled(address(actor), _vault);
        svbVars.userDebtAfter = svb.debtOf(address(actor));

        // VaultSimple Post Conditions
        assert_VaultSimpleBorrowable_PcA();
        assert_VaultSimpleBorrowable_PcB();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimpleBorrowable
        Post Condition A: (borrowCapAfter != 0) && (totalBorrowedAfter >= totalBorrowedBefore) 
            => borrowCapAfter >= totalBorrowedAfter
        Post Condition B: Controller cannot be disabled if there is any liability  
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimpleBorrowable_PcA() internal {
        assertTrue(
            (svbVars.totalBorrowedAfter > svbVars.totalBorrowedBefore && svbVars.borrowCapAfter != 0)
                ? (svbVars.borrowCapAfter >= svbVars.totalBorrowedAfter)
                : true,
            "(totalBorrowedAfter > totalBorrowedBefore)"
        );
    }

    function assert_VaultSimpleBorrowable_PcB() internal {
        if (svbVars.userDebtBefore > 0) {
            assertEq(svbVars.controllerEnabledAfter, true, "Controller cannot be disabled if there is any liability");
        }
    }
}
