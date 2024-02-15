// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimpleBorrowable_invariantA(address _vault, address _borrower) internal {
        if (block.timestamp >= VaultSimpleBorrowable(_vault).getLastInterestUpdate()) {
            assertGe(
                VaultSimpleBorrowable(_vault).totalBorrowed(),
                VaultSimpleBorrowable(_vault).getOwed(_borrower),
                string.concat("VaultSimpleBorrowable_invariantA: ", vaultNames[_vault])
            );
        }
    }

    function assert_VaultSimpleBorrowable_invariantB(address _vault) internal {
        uint256 totalDebt;
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            totalDebt += VaultSimpleBorrowable(_vault).debtOf(address(actorAddresses[i]));
        }
        assertEq(
            VaultSimpleBorrowable(_vault).totalBorrowed(),
            totalDebt,
            string.concat("VaultSimpleBorrowable_invariantB: ", vaultNames[_vault])
        );
    }
}
