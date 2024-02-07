// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Helpers
import {Pretty, Strings} from "../utils/Pretty.sol";

// Contracts
import {VaultSimple} from "test/invariants/Setup.t.sol";

// Test Contracts
import {BaseTest} from "../base/BaseTest.t.sol";

/// @title VaultSimple Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract VaultSimpleBeforeAfterHooks is BaseTest {
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
        bytes snapshotBefore;
        bytes snapshotAfter;
        // VaultSimple
        uint256 totalAssetsBefore;
        uint256 totalAssetsAfter;
        uint256 supplyCapBefore;
        uint256 supplyCapAfter;
    }

    VaultSimpleVars svVars;

    function _svBefore(address _vault) internal {
        VaultSimple sv = VaultSimple(_vault);
        svVars.totalSupplyBefore = sv.totalSupply();
        svVars.reentrancyLockBefore = sv.getReentrancyLock();
        svVars.snapshotBefore = sv.getSnapshot();
        svVars.totalAssetsBefore = sv.totalAssets();
        svVars.supplyCapBefore = sv.supplyCap();
    }

    function _svAfter(address _vault) internal {
        VaultSimple sv = VaultSimple(_vault);
        svVars.totalSupplyAfter = sv.totalSupply();
        svVars.reentrancyLockAfter = sv.getReentrancyLock();
        svVars.snapshotAfter = sv.getSnapshot();
        svVars.totalAssetsAfter = sv.totalAssets();
        svVars.supplyCapAfter = sv.supplyCap();
    }
}
