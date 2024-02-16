// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {ERC4626} from "solmate/tokens/ERC4626.sol";

// Contracts
import {Actor} from "../utils/Actor.sol";
import {BaseHandler, VaultRegularBorrowable} from "../base/BaseHandler.t.sol";

/// @title VaultRegularBorrowableHandler
/// @notice Handler test contract for the VaultRegularBorrowable actions
contract VaultRegularBorrowableHandler is BaseHandler {
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
        address violator = _getRandomActor(i);

        address collateral = _getRandomAccountCollateral(i + j, address(actor));

        address vaultAddress = _getRandomSupportedVault(j, VaultType.RegularBorrowable);

        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);

        repayAssets = clampBetween(repayAssets, 0, vault.debtOf(violator));

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _before(vaultAddress, VaultType.RegularBorrowable);
        (success, returnData) = actor.proxy(
            vaultAddress,
            abi.encodeWithSelector(VaultRegularBorrowable.liquidate.selector, violator, collateral, repayAssets)
        );

        if (success) {
            assert(false);
            _after(vaultAddress, VaultType.RegularBorrowable);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //TODO: add owner actions:
    // - setIRM
    // - setReferenceAsset
    // - setOracle

    function setCollateralFactor(uint256 i, uint256 collateralFactor) public {
        address vaultAddress = _getRandomSupportedVault(i, VaultType.RegularBorrowable);

        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);
        _before(vaultAddress, VaultType.RegularBorrowable);
        vault.setCollateralFactor(ERC4626(address(vault)), collateralFactor);
        _after(vaultAddress, VaultType.RegularBorrowable);

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
