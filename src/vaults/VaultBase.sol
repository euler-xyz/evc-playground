// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "evc/interfaces/IVault.sol";
import "../utils/EVCClient.sol";

/// @title VaultBase
/// @dev This contract is an abstract base contract for Vaults.
/// It declares functions that must be defined in the child contract in order to
/// correctly implement the controller release, vault status snapshotting and account/vaults
/// status checks.
abstract contract VaultBase is IVault, EVCClient {
    bytes private snapshot;

    constructor(IEVC _evc) EVCClient(_evc) {}

    /// @notice Takes a snapshot of the vault state
    function takeVaultSnapshot() internal {
        if (snapshot.length == 0) {
            snapshot = doTakeVaultSnapshot();
        }
    }

    /// @notice Checks the vault status
    /// @dev Executed as a result of requiring vault status check on the EVC.
    function checkVaultStatus() external onlyEVCWithChecksInProgress returns (bytes4 magicValue) {
        doCheckVaultStatus(snapshot);
        delete snapshot;

        return IVault.checkVaultStatus.selector;
    }

    /// @notice Checks the account status
    /// @dev Executed on a controller as a result of requiring account status check on the EVC.
    function checkAccountStatus(
        address account,
        address[] calldata collaterals
    ) external view onlyEVCWithChecksInProgress returns (bytes4 magicValue) {
        doCheckAccountStatus(account, collaterals);

        return IVault.checkAccountStatus.selector;
    }

    /// @notice Takes a snapshot of the vault state
    /// @dev Must be overridden by child contracts
    function doTakeVaultSnapshot() internal virtual returns (bytes memory snapshot);

    /// @notice Checks the vault status
    /// @dev Must be overridden by child contracts
    function doCheckVaultStatus(bytes memory snapshot) internal virtual;

    /// @notice Checks the account status
    /// @dev Must be overridden by child contracts
    function doCheckAccountStatus(address, address[] calldata) internal view virtual;

    /// @notice Disables a controller for an account
    /// @dev Must be overridden by child contracts
    function disableController(address account) external virtual;
}
