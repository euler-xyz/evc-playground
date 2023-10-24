// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";

/// @title CVCClient
/// @dev This contract is an abstract base contract for interacting with the Credit Vault Connector (CVC).
/// It provides utility functions for authenticating callers in the context of the CVC,
/// scheduling and forgiving status checks, and liquidating collateral shares.
abstract contract CVCClient {
    ICVC private immutable cvc;

    error NotAuthorized();
    error ControllerDisabled();

    constructor(ICVC _cvc) {
        cvc = _cvc;
    }

    /// @notice Modifier to ensure that the function is only called by the CVC.
    modifier onlyCVC() {
        if (msg.sender != address(cvc)) revert NotAuthorized();
        _;
    }

    /// @notice Authenticates the caller in the context of the CVC.
    /// @return The address of the account on behalf of which the operation is being executed.
    function CVCAuthenticate() internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount, ) = cvc.getExecutionContext(address(0));
            return onBehalfOfAccount;
        }

        return msg.sender;
    }

    /// @notice Authenticates the caller for a borrow operation in the context of the CVC.
    /// @dev Ensures that the vault is enabled as a controller for the account.
    /// @return The address of the account on behalf of which the operation is being executed.
    function CVCAuthenticateForBorrow() internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount, bool controllerEnabled) = cvc
                .getExecutionContext(address(this));

            if (!controllerEnabled) {
                revert ControllerDisabled();
            }

            return onBehalfOfAccount;
        } else if (!cvc.isControllerEnabled(msg.sender, address(this))) {
            revert ControllerDisabled();
        }

        return msg.sender;
    }

    /// @notice Retrieves the owner of an account.
    /// @param account The address of the account.
    /// @return owner The address of the account owner.
    function getAccountOwner(
        address account
    ) internal view returns (address owner) {
        if (msg.sender == address(cvc)) {
            owner = cvc.getAccountOwner(account);
        } else {
            owner = account;
        }
    }

    /// @notice Retrieves the collaterals enabled for an account.
    /// @param account The address of the account.
    /// @return An array of addresses that are enabled collaterals for the account.
    function getCollaterals(
        address account
    ) internal view returns (address[] memory) {
        return cvc.getCollaterals(account);
    }

    /// @notice Checks whether a vault is enabled as a collateral for an account.
    /// @param account The address of the account.
    /// @param vault The address of the vault.
    /// @return A boolean value that indicates whether the vault is an enabled collateral for the account.
    function isCollateralEnabled(
        address account,
        address vault
    ) internal view returns (bool) {
        return cvc.isCollateralEnabled(account, vault);
    }

    /// @notice Retrieves the controllers enabled for an account.
    /// @param account The address of the account.
    /// @return An array of addresses that are the enabled controllers for the account.
    function getControllers(
        address account
    ) internal view returns (address[] memory) {
        return cvc.getControllers(account);
    }

    /// @notice Checks whether a vault is enabled as a controller for an account.
    /// @param account The address of the account.
    /// @param vault The address of the vault.
    /// @return A boolean value that indicates whether the vault is an enabled controller for the account.
    function isControllerEnabled(
        address account,
        address vault
    ) internal view returns (bool) {
        return cvc.isControllerEnabled(account, vault);
    }

    /// @notice Releases the account from the control of the calling contract.
    /// @dev Ensure that the account does not have any liabilities before doing this.
    /// @param account The address of the account.
    function releaseAccountFromControl(address account) internal {
        cvc.disableController(account);
    }

    /// @notice Schedules a status check for an account.
    /// @param account The address of the account.
    function requireAccountStatusCheck(address account) internal {
        cvc.requireAccountStatusCheck(account);
    }

    /// @notice Schedules a status check for the calling vault.
    function requireVaultStatusCheck() internal {
        cvc.requireVaultStatusCheck();
    }

    /// @notice Schedules a status check for an account and the calling vault.
    /// @param account The address of the account.
    function requireAccountAndVaultStatusCheck(address account) internal {
        if (account == address(0)) {
            cvc.requireVaultStatusCheck();
        } else {
            cvc.requireAccountAndVaultStatusCheck(account);
        }
    }

    /// @notice Forgives a previously deferred account status check.
    /// @dev Can only be called by the enabled controller of the account.
    /// @param account The address of the account.
    function forgiveAccountStatusCheck(address account) internal {
        cvc.forgiveAccountStatusCheck(account);
    }

    /// @notice Checks whether the status check is deferred for a given account.
    /// @param account The address of the account.
    /// @return A boolean flag that indicates whether the status check is deferred.
    function isAccountStatusCheckDeferred(
        address account
    ) internal view returns (bool) {
        return cvc.isAccountStatusCheckDeferred(account);
    }

    /// @notice Liquidates a certain amount of collateral shares from a violator's vault.
    /// @dev This function impersonates the violator and transfers the specified amount of shares from the violator's vault to the liquidator.
    /// @param vault The address of the vault from which the shares are being liquidated.
    /// @param violator The address of the violator whose shares are being liquidated.
    /// @param liquidator The address to which the liquidated shares are being transferred.
    /// @param shares The amount of shares to be liquidated.
    function liquidateCollateralShares(
        address vault,
        address violator,
        address liquidator,
        uint shares
    ) internal {
        // Impersonate the violator to transfer shares from the violator's vault to the liquidator.
        cvc.impersonate(
            vault,
            violator,
            abi.encodeCall(ERC20.transfer, (liquidator, shares))
        );
    }
}
