// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {DefaultBeforeAfterHooks} from "../hooks/DefaultBeforeAfterHooks.t.sol";
import {BaseHandler, VaultSimple} from "../base/BaseHandler.t.sol";

/// @title VaultSimpleHandler
/// @notice Handler test contract for the VaultSimple actions
contract VaultSimpleHandler is BaseHandler, DefaultBeforeAfterHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /* 
    
    E.g. num of active pools
    uint256 public activePools;

     */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 assets, address receiver) external setup {
        //TODO make reciever one of the actors
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.deposit.selector, assets, receiver));

        if (success) {
            ghost_sumBalances[vaultAddress] += assets;
            ghost_sumBalancesPerUser[vaultAddress][address(actor)] += assets;
        }
    }

    function mint(uint256 shares, address receiver) external setup {
        //TODO make reciever one of the actors
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.mint.selector, shares, receiver));

        uint256 assets = abi.decode(returnData, (uint256));

        if (success) {
            ghost_sumBalances[vaultAddress] += assets;
            ghost_sumBalancesPerUser[vaultAddress][address(actor)] += assets;
        }
    }

    function withdraw(uint256 assets, address receiver) external setup {
        //TODO make reciever one of the actors
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.withdraw.selector, assets, receiver));

        if (success) {
            ghost_sumBalances[vaultAddress] -= assets;
            ghost_sumBalancesPerUser[vaultAddress][address(actor)] -= assets;
        }
    }

    function redeem(uint256 shares, address receiver) external setup {
        //TODO make reciever one of the actors
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.withdraw.selector, shares, receiver));

        uint256 assets = abi.decode(returnData, (uint256));

        if (success) {
            ghost_sumBalances[vaultAddress] -= assets;
            ghost_sumBalancesPerUser[vaultAddress][address(actor)] -= assets;
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
