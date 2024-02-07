// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title DonationAttackHandler
/// @notice Handler test contract for the  DonationAttack actions
contract DonationAttackHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
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

    /// @notice This function transfers any amount of assets to a contract in the system
    /// @dev Flashloan simulator
    function donate(uint256 amount) external {
        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        underlying.mint(address(this), amount);

        underlying.transfer(vaultAddress, amount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
