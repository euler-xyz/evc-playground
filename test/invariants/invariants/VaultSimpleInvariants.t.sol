// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Base Contracts
import {VaultSimple} from "../base/BaseStorage.t.sol";
import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title VaultSimpleInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract VaultSimpleInvariants is HandlerAggregator {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimple
    Invariant A: totalAssets = sum of all balances
    Invariant B: totalSupply = sum of all minted shares

    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimple_invariantA(address _vault) internal {
        uint256 totalAssets = VaultSimple(_vault).totalAssets();

        assertEq(totalAssets, ghost_sumBalances[_vault], vaultNames[_vault]);
    }

    function assert_VaultSimple_invariantB(address _vault) internal {
        uint256 totalSupply = VaultSimple(_vault).totalSupply();

        assertEq(totalSupply, ghost_sumBalances[_vault], vaultNames[_vault]);
    }
}
