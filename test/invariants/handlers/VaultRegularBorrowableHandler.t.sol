// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler} from "../base/BaseHandler.t.sol";

/// @title VaultRegularBorrowableHandler
/// @notice Handler test contract for the VaultRegularBorrowable actions
contract VaultRegularBorrowableHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
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

///////////////////////////////////////////////////////////////////////////////////////////////
//                                           HELPERS                                         //
///////////////////////////////////////////////////////////////////////////////////////////////
}
