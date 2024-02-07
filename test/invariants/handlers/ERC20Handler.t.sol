// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Test Contracts
import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler} from "../base/BaseHandler.t.sol";

/// @title ERC20Handler
/// @notice Handler test contract for ERC20 contacts
contract ERC20Handler is BaseHandler, VaultSimpleBeforeAfterHooks {
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

    /*     function approve(address spender, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) =
            actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.approve.selector, spender, amount));

        if (success) {
            assert(true);
        }
    } */

    function approveTo(uint256 i, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address spender = _getRandomActor(i);

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) =
            actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.approve.selector, spender, amount));

        if (success) {
            assert(true);
        }
    }

    function transfer(address to, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) = actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.transfer.selector, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[erc20Address][address(actor)] -= amount;
            ghost_sumSharesBalancesPerUser[erc20Address][to] += amount;
        }
    }

    function transferTo(uint256 i, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address to = _getRandomActor(i);

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) = actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.transfer.selector, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[erc20Address][address(actor)] -= amount;
            ghost_sumSharesBalancesPerUser[erc20Address][to] += amount;
        }
    }

    function transferFrom(uint256 i, address to, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) =
            actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[erc20Address][from] -= amount;
            ghost_sumSharesBalancesPerUser[erc20Address][to] += amount;
        }
    }

    function transferFromTo(uint256 i, uint256 u, uint256 amount) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);
        // Get one of the three actors randomly
        address to = _getRandomActor(u);

        address erc20Address = _getRandomSupportedVault(VaultType.Simple);

        (success, returnData) =
            actor.proxy(erc20Address, abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[erc20Address][from] -= amount;
            ghost_sumSharesBalancesPerUser[erc20Address][to] += amount;
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
