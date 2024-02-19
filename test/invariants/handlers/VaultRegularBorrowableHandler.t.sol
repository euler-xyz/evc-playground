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

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       GHOST VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function liquidate(uint256 repayAssets, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(j, VaultType.RegularBorrowable);

        address violator = _getActorWithDebt(vaultAddress);

        require(violator != address(0), "VaultRegularBorrowableHandler: no violator");

        bool violatorStatus = isAccountHealthy(vaultAddress, violator);

        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);

        repayAssets = clampBetween(repayAssets, 1, vault.debtOf(violator));

        {
            // Get one of the three actors randomly
            address collateral = _getRandomAccountCollateral(i + j, address(actor));

            _before(vaultAddress, VaultType.RegularBorrowable);
            (success, returnData) = actor.proxy(
                vaultAddress,
                abi.encodeWithSelector(VaultRegularBorrowable.liquidate.selector, violator, collateral, repayAssets)
            );
        }
        if (success) {
            _after(vaultAddress, VaultType.RegularBorrowable);

            // VaultRegularBorrowable_invariantB
            assertFalse(violatorStatus);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setCollateralFactor(uint256 i, uint256 collateralFactor) public {
        address vaultAddress = _getRandomSupportedVault(i, VaultType.RegularBorrowable);

        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);
        _before(vaultAddress, VaultType.RegularBorrowable);
        vault.setCollateralFactor(vaultAddress, collateralFactor);
        _after(vaultAddress, VaultType.RegularBorrowable);

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _getActorWithDebt(address vaultAddress) internal view returns (address) {
        VaultRegularBorrowable vault = VaultRegularBorrowable(vaultAddress);
        address _actor = address(actor);
        for (uint256 k; k < NUMBER_OF_ACTORS; k++) {
            if (_actor != actorAddresses[k] && vault.debtOf(address(actorAddresses[k])) > 0) {
                return address(actorAddresses[k]);
            }
        }
        return address(0);
    }
}
