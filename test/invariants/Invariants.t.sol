// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";
import {VaultSimpleInvariants} from "./invariants/VaultSimpleInvariants.t.sol";
import {VaultSimpleBorrowableInvariants} from "./invariants/VaultSimpleBorrowableInvariants.t.sol";
import {VaultRegularBorrowableInvariants} from "./invariants/VaultRegularBorrowableInvariants.t.sol";
import {VaultBorrowableWETHInvariants} from "./invariants/VaultBorrowableWETHInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in BaseInvariants
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants that inherits HandlerAggregator
abstract contract Invariants is
    BaseInvariants,
    VaultSimpleInvariants,
    VaultSimpleBorrowableInvariants,
    VaultRegularBorrowableInvariants,
    VaultBorrowableWETHInvariants
{
    uint256 private constant REENTRANCY_UNLOCKED = 1;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BASE INVARIANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*  
    E.g. of an invariant wrapper recognized by Echidna and Medusa

    function echidna_invariant_Area1_A() public returns (bool) {
        assert_invariant_Area1_A(pool.owner());
        return true;
    } 
    */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 VAULT SIMPLE INVARIANTS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            VAULT SIMPLE BORROWABLE INVARIANTS                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           VAULT REGULAR BORROWABLE INVARIANTS                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            VAULT BORROWABLE WETH INVARIANTS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
