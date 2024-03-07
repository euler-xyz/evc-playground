// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {BaseHandler, VaultSimpleBorrowable} from "../base/BaseHandler.t.sol";

/// @title VaultSimpleBorrowableHandler
/// @notice Handler test contract for the VaultSimpleBorrowable actions
contract VaultSimpleBorrowableHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrowTo(uint256 assets, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        bool isAccountHealthyBefore = isAccountHealthy(vaultAddress, receiver);

        _before(vaultAddress, VaultType.SimpleBorrowable);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.borrow.selector, assets, receiver));

        if (!isAccountHealthyBefore) {
            // VaultSimpleBorrowable_invariantD
            assert(!success);
        } else {
            if (success) {
                _after(vaultAddress, VaultType.SimpleBorrowable);
            }
        }
    }

    function repayTo(uint256 assets, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        (uint256 liabilityValueBefore, uint256 collateralValueBefore) = vault.getAccountLiabilityStatus(receiver);

        _before(vaultAddress, VaultType.SimpleBorrowable);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.repay.selector, assets, receiver));

        if (success) {
            _after(vaultAddress, VaultType.SimpleBorrowable);

            (uint256 liabilityValueAfter, uint256 collateralValueAfter) = vault.getAccountLiabilityStatus(receiver);

            // VaultSimpleBorrowable_invariantC
            assertLe(liabilityValueAfter, liabilityValueBefore, "Liability value must decrease");
        }
    }

    function pullDebt(uint256 i, uint256 j, uint256 assets) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        _before(vaultAddress, VaultType.SimpleBorrowable);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.pullDebt.selector, from, assets));

        if (success) {
            _after(vaultAddress, VaultType.SimpleBorrowable);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setBorrowCap(uint256 j, uint256 newBorrowCap) external {
        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _before(vaultAddress, VaultType.SimpleBorrowable);
        vault.setBorrowCap(newBorrowCap);
        _after(vaultAddress, VaultType.SimpleBorrowable);

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
