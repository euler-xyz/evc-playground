// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";

// Testing contracts
import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler, EnumerableSet} from "../base/BaseHandler.t.sol";

/// @title EVCHandler
/// @notice Handler test contract for the EVC actions
contract EVCHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
    using EnumerableSet for EnumerableSet.AddressSet;

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

    // TODO:
    // - setNonce
    // - setOperator

    function setAccountOperator(uint256 i, uint256 j, bool authorised) external setup {
        bool success;
        bytes memory returnData;

        // TODO: extend not only for actors
        address account = _getRandomActor(i);

        address operator = _getRandomActor(j);

        (success, returnData) = actor.proxy(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.setAccountOperator.selector, account, operator, authorised)
        );

        if (success) {
            assert(true);
        }
    }

    // COLLATERAL

    function enableCollateral(uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        (success, returnData) = actor.proxy(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.enableCollateral.selector, account, vaultAddress)
        );

        if (success) {
            ghost_accountCollaterals[address(actor)].add(vaultAddress);
            assert(true);
        }
    }

    function disableCollateral(uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        (success, returnData) = actor.proxy(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.disableCollateral.selector, account, vaultAddress)
        );

        if (success) {
            ghost_accountCollaterals[address(actor)].remove(vaultAddress);
            assert(true);
        }
    }

    function reorderCollaterals(uint256 i, uint256 j, uint8 index1, uint8 index2) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        (success, returnData) = actor.proxy(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.reorderCollaterals.selector, account, index1, index2)
        );

        if (success) {
            assert(true);
        }
    }

    // CONTROLLER

    function enableController(uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.SimpleBorrowable);

        (success, returnData) = actor.proxy(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.enableController.selector, account, vaultAddress)
        );

        if (success) {
            assert(true);
        }
    }

    function disableController(uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        (success, returnData) = actor.proxy(
            address(evc), abi.encodeWithSelector(EthereumVaultConnector.disableController.selector, account)
        );

        if (success) {
            assert(true);
        }
    }

    function requireAccountStatusCheck(uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address account = _getRandomActor(i);

        evc.call(
            address(evc),
            address(0),
            0,
            abi.encodeWithSelector(EthereumVaultConnector.requireAccountStatusCheck.selector, account)
        );
    }

    //TODO:
    // - batch
    // - batchRevert
    // - forgiveAccountStatusCheck
    // - requireVaultStatusCheck

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
