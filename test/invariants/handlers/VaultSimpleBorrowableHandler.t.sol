// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler, VaultSimpleBorrowable} from "../base/BaseHandler.t.sol";

/// @title VaultSimpleBorrowableHandler
/// @notice Handler test contract for the VaultSimpleBorrowable actions
contract VaultSimpleBorrowableHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /* 
    
    E.g. num of active pools
    uint256 public activePools;

     */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrow(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.borrow.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);
        }
    }

    function borrowTo(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.borrow.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);
        }
    }

    function repay(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.repay.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);
        }
    }

    function repayTo(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.repay.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);
        }
    }

    function pullDebt(uint256 i, uint256 assets) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimpleBorrowable.pullDebt.selector, from, assets));

        if (success) {
            _svAfter(vaultAddress);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setBorrowCap(uint256 newBorrowCap) external {
        address vaultAddress = _getRandomSupportedVault(VaultType.SimpleBorrowable);

        VaultSimpleBorrowable vault = VaultSimpleBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        vault.setBorrowCap(newBorrowCap);
        _svAfter(vaultAddress);

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
