// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VaultSimpleBeforeAfterHooks} from "../../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title PriceOracleHandler
/// @notice Handler test contract for the  PriceOracle actions
contract PriceOracleHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
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

    /// @notice This function simulates changes in the interest rate model
    function setQuote(uint256 i, uint256 _j, uint256 price) external {
        address baseAsset = _getRandomBaseAsset(i);

        oracle.setQuote(baseAsset, address(referenceAsset), price);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
