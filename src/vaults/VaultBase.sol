// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

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
    // alcueca: What are snapshots? Why do we need them?
    function takeVaultSnapshot() internal {
        // alcueca: We delete snapshots on `checkVaultStatus`, which can only happen at the end of an EVC batch (`onlyEVCWithChecksInProgress`)
        // Snapshots are taken before any action is taken on the vault that affects the cault asset records and deleted at the end, so that 
        // asset calculations are always based on the state before the current batch of actions.
        if (snapshot.length == 0) {
            snapshot = doTakeVaultSnapshot();
        }
    }

    /// @notice Checks the vault status
    /// @dev Executed as a result of requiring vault status check on the EVC.
    function checkVaultStatus() external onlyEVCWithChecksInProgress returns (bytes4 magicValue) {
        doCheckVaultStatus(snapshot);
        delete snapshot; // alcueca: I can't avoid thinking that on the very first implementation of an EVC app, in its most basic form, we are already hijacking the vault checks for something else. Do the vaults need hooks?

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
    // alcueca: The EVC won't call this function. It would be good to clearly state what is the abslute minimum that the EVC needs.
    function disableController() external virtual;
}
