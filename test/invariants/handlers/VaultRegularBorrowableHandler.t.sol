// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {VaultSimpleBorrowableBeforeAfterHooks} from "../hooks/VaultSimpleBorrowableBeforeAfterHooks.t.sol";
import {BaseHandler, VaultRegularBorrowable} from "../base/BaseHandler.t.sol";

/// @title VaultRegularBorrowableHandler
/// @notice Handler test contract for the VaultRegularBorrowable actions
contract VaultRegularBorrowableHandler is
    BaseHandler,
    VaultSimpleBeforeAfterHooks,
    VaultSimpleBorrowableBeforeAfterHooks
{
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

    /* 
    
    E.g. sum of all balances
    uint256 public ghost_sumBalances;

     */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function liquidate(uint256 repayAssets, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address collateral = _getRandomAccountCollateral(i + j, address(actor));

        address vaultAddress = _getRandomSupportedVault(j, VaultType.RegularBorrowable);

        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        _svbBefore(vaultAddress);
        (success, returnData) = actor.proxy(
            vaultAddress,
            abi.encodeWithSelector(VaultRegularBorrowable.liquidate.selector, receiver, collateral, repayAssets)
        );

        if (success) {
            assert(false);
            _svAfter(vaultAddress);
            _svbAfter(vaultAddress);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
