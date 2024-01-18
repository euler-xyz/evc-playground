// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "solmate/tokens/ERC20.sol";
import "evc/interfaces/IEthereumVaultConnector.sol";

/// @title EVCClient
/// @dev This contract is an abstract base contract for interacting with the Ethereum Vault Connector (EVC).
/// It provides utility functions for authenticating callers in the context of the EVC,
/// scheduling and forgiving status checks, and liquidating collateral shares.
abstract contract EVCClient {
    IEVC private immutable evc;

    error NotAuthorized();
    error ControllerDisabled();
    error SharesSeizureFailed();

    constructor(IEVC _evc) {
        require(address(_evc) != address(0), "EVCClient: EVC address cannot be zero");

        evc = _evc;
    }

    /// @notice Ensures that the caller is the EVC in the appropriate context.
    modifier onlyEVCWithChecksInProgress() {
        if (msg.sender != address(evc) || !evc.areChecksInProgress()) {
            revert NotAuthorized();
        }

        _;
    }

    /// @notice Ensures that the msg.sender is the EVC by using the EVC callback functionality if necessary.
    modifier callThroughEVC() {
        if (msg.sender == address(evc)) {
            _;
        } else {
            bytes memory result = evc.call(address(this), msg.sender, 0, msg.data);

            assembly {
                return(add(32, result), mload(result))
            }
        }
    }

    /// @notice Ensures that the msg.sender is the EVC by using the EVC callback functionality if necessary.
    /// @dev This modifier is used for payable functions because it forwards the value to the EVC.
    modifier callThroughEVCPayable() {
        if (msg.sender == address(evc)) {
            _;
        } else {
            bytes memory result = evc.call{value: msg.value}(address(this), msg.sender, msg.value, msg.data);

            assembly {
                return(add(32, result), mload(result))
            }
        }
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view returns (address) {
        address sender = msg.sender;

        if (sender == address(evc)) {
            (sender,) = evc.getCurrentOnBehalfOfAccount(address(0));
        }

        return sender;
    }

    /// @notice Retrieves the message sender in the context of the EVC for a borrow operation.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC. This function reverts if the vault is not enabled as
    /// a controller for the account on behalf of which the operation is being executed.
    /// @return The address of the message sender.
    function _msgSenderForBorrow() internal view returns (address) {
        address sender = msg.sender;
        bool controllerEnabled;

        if (sender == address(evc)) {
            (sender, controllerEnabled) = evc.getCurrentOnBehalfOfAccount(address(this));
        } else {
            controllerEnabled = evc.isControllerEnabled(sender, address(this));
        }

        if (!controllerEnabled) {
            revert ControllerDisabled();
        }

        return sender;
    }

    /// @notice Retrieves the owner of an account.
    /// @dev Use with care. If the account is not registered on the EVC yet, the account address is returned as the
    /// owner.
    /// @param account The address of the account.
    /// @return owner The address of the account owner.
    function getAccountOwner(address account) internal view returns (address owner) {
        try evc.getAccountOwner(account) returns (address _owner) {
            owner = _owner;
        } catch {
            owner = account;
        }
    }

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
        bytes memory result =
            evc.controlCollateral(vault, liquidated, 0, abi.encodeCall(ERC20.transfer, (liquidator, shares)));

        if (!(result.length == 0 || abi.decode(result, (bool)))) {
            revert SharesSeizureFailed();
        }
    }
}
