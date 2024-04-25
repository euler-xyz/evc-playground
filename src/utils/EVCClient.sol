// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "evc/utils/EVCUtil.sol";

/// @title EVCClient
/// @dev This contract is an abstract base contract for interacting with the Ethereum Vault Connector (EVC).
/// It provides utility functions for authenticating callers in the context of the EVC,
/// scheduling and forgiving status checks, and liquidating collateral shares.
abstract contract EVCClient is EVCUtil {
    error SharesSeizureFailed();

    constructor(address _evc) EVCUtil(_evc) {}

    /// @notice Retrieves the collaterals enabled for an account.
    /// @param account The address of the account.
    /// @return An array of addresses that are enabled collaterals for the account.
    function getCollaterals(address account) internal view returns (address[] memory) {
        return evc.getCollaterals(account);
    }

    /// @notice Checks whether a vault is enabled as a collateral for an account.
    /// @param account The address of the account.
    /// @param vault The address of the vault.
    /// @return A boolean value that indicates whether the vault is an enabled collateral for the account.
    function isCollateralEnabled(address account, address vault) internal view returns (bool) {
        return evc.isCollateralEnabled(account, vault);
    }

    /// @notice Retrieves the controllers enabled for an account.
    /// @param account The address of the account.
    /// @return An array of addresses that are the enabled controllers for the account.
    function getControllers(address account) internal view returns (address[] memory) {
        return evc.getControllers(account);
    }

    /// @notice Checks whether a vault is enabled as a controller for an account.
    /// @param account The address of the account.
    /// @param vault The address of the vault.
    /// @return A boolean value that indicates whether the vault is an enabled controller for the account.
    function isControllerEnabled(address account, address vault) internal view returns (bool) {
        return evc.isControllerEnabled(account, vault);
    }

    /// @notice Disables the controller for an account
    /// @dev Ensure that the account does not have any liabilities before doing this.
    /// @param account The address of the account.
    function disableController(address account) internal {
        evc.disableController(account);
    }

    /// @notice Schedules a status check for an account.
    /// @param account The address of the account.
    function requireAccountStatusCheck(address account) internal {
        evc.requireAccountStatusCheck(account);
    }

    /// @notice Schedules a status check for the calling vault.
    function requireVaultStatusCheck() internal {
        evc.requireVaultStatusCheck();
    }

    /// @notice Schedules a status check for an account and the calling vault.
    /// @param account The address of the account.
    function requireAccountAndVaultStatusCheck(address account) internal {
        if (account == address(0)) {
            evc.requireVaultStatusCheck();
        } else {
            evc.requireAccountAndVaultStatusCheck(account);
        }
    }

    /// @notice Forgives a previously deferred account status check.
    /// @dev Can only be called by the enabled controller of the account.
    /// @param account The address of the account.
    function forgiveAccountStatusCheck(address account) internal {
        evc.forgiveAccountStatusCheck(account);
    }

    /// @notice Checks whether the status check is deferred for a given account.
    /// @param account The address of the account.
    /// @return A boolean flag that indicates whether the status check is deferred.
    function isAccountStatusCheckDeferred(address account) internal view returns (bool) {
        return evc.isAccountStatusCheckDeferred(account);
    }

    /// @notice Checks whether the status check is deferred for a given vault.
    /// @param vault The address of the vault.
    /// @return A boolean flag that indicates whether the status check is deferred.
    function isVaultStatusCheckDeferred(address vault) internal view returns (bool) {
        return evc.isVaultStatusCheckDeferred(vault);
    }

    /// @notice Liquidates a certain amount of collateral shares from a violator's vault.
    /// @dev This function controls the collateral in order to transfers the specified amount of shares from the
    /// violator's vault to the liquidator.
    /// @param vault The address of the vault from which the shares are being liquidated.
    /// @param liquidated The address of the account which has the shares being liquidated.
    /// @param liquidator The address to which the liquidated shares are being transferred.
    /// @param shares The amount of shares to be liquidated.
    function liquidateCollateralShares(
        address vault,
        address liquidated,
        address liquidator,
        uint256 shares
    ) internal {
        // Control the collateral in order to transfer shares from the violator's vault to the liquidator.
        bytes memory result = evc.controlCollateral(
            vault, liquidated, 0, abi.encodeWithSignature("transfer(address,uint256)", liquidator, shares)
        );

        if (!(result.length == 0 || abi.decode(result, (bool)))) {
            revert SharesSeizureFailed();
        }
    }
}
