// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Base Contracts
import {VaultSimpleBorrowable} from "test/invariants/Setup.t.sol";
import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title VaultSimpleBorrowableInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract VaultSimpleBorrowableInvariants is HandlerAggregator {
    /*//////////////////////////////////////////////////////////////////////////////////////////////
    //                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimpleBorrowable
        Invariant A: totalBorrowed >= any account owed balance
        Invariant B: totalBorrowed == sum of all user debt
        Invariant C: User liability should always decrease after repayment (Implemented in the handler)
        Invariant D: Unhealthy users can not borrow (Implemented in the handler)
        Invariant E: If theres at least one borrow, the asset.balanceOf(vault) > 0
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimpleBorrowable_invariantA(
        address _vault,
        address _borrower
    ) internal monotonicTimestamp(_vault) {
        assertGe(
            VaultSimpleBorrowable(_vault).totalBorrowed(),
            VaultSimpleBorrowable(_vault).getOwed(_borrower),
            string.concat("VaultSimpleBorrowable_invariantA: ", vaultNames[_vault])
        );
    }

    function assert_VaultSimpleBorrowable_invariantB(address _vault) internal monotonicTimestamp(_vault) {
        //@audit-issue CRIT-1: broken invariant totalDebt > sum of total Borrowed -> rounding error on totalBorrowed
        uint256 totalDebt;
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            totalDebt += VaultSimpleBorrowable(_vault).debtOf(address(actorAddresses[i]));
        }

        assertApproxEqAbs(
            VaultSimpleBorrowable(_vault).totalBorrowed(),
            totalDebt,
            1,
            string.concat("VaultSimpleBorrowable_invariantB: ", vaultNames[_vault])
        );
    }

    function assert_VaultSimpleBorrowable_invariantE(address _vault) internal monotonicTimestamp(_vault) {
        if (VaultSimpleBorrowable(_vault).totalBorrowed() > 0) {
            assertGt(
                ERC20(address(VaultSimpleBorrowable(_vault).asset())).balanceOf(_vault),
                0,
                string.concat("VaultSimpleBorrowable_invariantE: ", vaultNames[_vault])
            );
        }
    }
}
