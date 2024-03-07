// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultSimple} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title VaultSimple Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultSimpleBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct VaultSimpleVars {
        // ERC4626
        uint256 totalSupplyBefore;
        uint256 totalSupplyAfter;
        // VaultBase
        uint256 reentrancyLockBefore;
        uint256 reentrancyLockAfter;
        uint256 snapshotLengthBefore;
        uint256 snapshotLengthAfter;
        // VaultSimple
        uint256 totalAssetsBefore;
        uint256 totalAssetsAfter;
        uint256 supplyCapBefore;
        uint256 supplyCapAfter;
    }

    VaultSimpleVars svVars;

    function _svBefore(address _vault) internal {
        // ERC4626
        VaultSimple sv = VaultSimple(_vault);
        svVars.totalSupplyBefore = sv.totalSupply();
        // VaultBase
        svVars.reentrancyLockBefore = sv.getReentrancyLock();
        svVars.snapshotLengthBefore = sv.getSnapshotLength();
        // VaultSimple
        svVars.totalAssetsBefore = sv.totalAssets();
        svVars.supplyCapBefore = sv.supplyCap();
    }

    function _svAfter(address _vault) internal {
        // ERC4626
        VaultSimple sv = VaultSimple(_vault);
        svVars.totalSupplyAfter = sv.totalSupply();
        // VaultBase
        svVars.reentrancyLockAfter = sv.getReentrancyLock();
        svVars.snapshotLengthAfter = sv.getSnapshotLength();
        // VaultSimple
        svVars.totalAssetsAfter = sv.totalAssets();
        svVars.supplyCapAfter = sv.supplyCap();

        // VaultSimple Post Conditions
        assert_VaultSimple_PcA();
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POST CONDITIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimple
        Post Condition A: 
            (supplyCapAfter != 0) && (totalSupplyAfter >= totalSupplyBefore) => supplyCapAfter >= totalSupplyAfter
            
        */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function assert_VaultSimple_PcA() internal {
        assertTrue(
            (svVars.totalSupplyAfter > svVars.totalSupplyBefore && svVars.supplyCapAfter != 0)
                ? (svVars.supplyCapAfter >= svVars.totalSupplyAfter)
                : true,
            "(totalSupplyAfter > totalSupplyBefore)"
        );
    }
}
