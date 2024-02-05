// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//Import Contracts and Interfaces

import {BaseInvariants} from "./BaseInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in BaseInvariants
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants that inherits HandlerAggregator
abstract contract Invariants is BaseInvariants {
    /*  

    E.g. of an invariant wrapper recognized by Echidna and Medusa

    function echidna_invariant_Area1_A() public returns (bool) {
        assert_invariant_Area1_A(pool.owner());
        return true;
    } 
    */
}