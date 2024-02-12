// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultSimpleBorrowable} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseTest} from "../base/BaseTest.t.sol";

/// @title VaultSimpleBorrowable Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultSimpleBorrowableBeforeAfterHooks is BaseTest {
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
    }

    VaultSimpleBorrowableVars svbVars;

    function _svbBefore(address _vault) internal {
        VaultSimpleBorrowable svb = VaultSimpleBorrowable(_vault);
        svbVars.borrowCapBefore = svb.borrowCap();
        svbVars.totalBorrowedBefore = svb.totalBorrowed();
    }

    function _svbAfter(address _vault) internal {
        VaultSimpleBorrowable svb = VaultSimpleBorrowable(_vault);
        svbVars.borrowCapAfter = svb.borrowCap();
        svbVars.totalBorrowedAfter = svb.totalBorrowed();

        // VaultSimple Post Conditions

        assert_VaultSimpleBorrowable_PcA();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimpleBorrowable
        Post Condition A: 
    (borrowCapAfter != 0) && (totalBorrowedAfter >= totalBorrowedBefore) => borrowCapAfter >= totalBorrowedAfter
           

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
}
