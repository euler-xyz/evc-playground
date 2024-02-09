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
        Invariant A: totalAssets == sum of all balances
        Invariant B: totalSupply == sum of all minted shares
        Invariant C: balanceOf(actor) == sum of all shares owned by address
        Invariant D: totalSupply == sum of balanceOf(actors)

    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimple_invariantA(address _vault) internal {//TODO: implement balance changes
        uint256 totalAssets = VaultSimple(_vault).totalAssets();

        assertEq(totalAssets, ghost_sumBalances[_vault], string.concat("VaultSimple_invariantA: ", vaultNames[_vault]));
    }

    function assert_VaultSimple_invariantB(address _vault) internal {
        uint256 totalSupply = VaultSimple(_vault).totalSupply();

        assertEq(totalSupply, ghost_sumBalances[_vault], string.concat("VaultSimple_invariantB: ", vaultNames[_vault]));
    }

    function assert_VaultSimple_invariantC(address _vault, address _account) internal returns (uint256 balanceOf) {
        balanceOf = VaultSimple(_vault).balanceOf(_account);

        assertEq(
            balanceOf,
            ghost_sumSharesBalancesPerUser[_vault][_account],
            string.concat("VaultSimple_invariantC: ", vaultNames[_vault])
        );
    }

    function assert_VaultSimple_invariantD(address _vault, uint256 _sumBalances) internal {
        uint256 totalSupply = VaultSimple(_vault).totalSupply();

        assertEq(totalSupply, _sumBalances, string.concat("VaultSimple_invariantD: ", vaultNames[_vault]));
    }
}
