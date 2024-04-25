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
    error Reentrancy();

    uint256 private constant REENTRANCY_UNLOCKED = 1;
    uint256 private constant REENTRANCY_LOCKED = 2;

    uint256 private reentrancyLock;
    bytes private snapshot;

    constructor(address _evc) EVCClient(_evc) {
        reentrancyLock = REENTRANCY_UNLOCKED;
    }

    /// @notice Prevents reentrancy
    modifier nonReentrant() virtual {
        if (reentrancyLock != REENTRANCY_UNLOCKED) {
            revert Reentrancy();
        }

        reentrancyLock = REENTRANCY_LOCKED;

        _;

        reentrancyLock = REENTRANCY_UNLOCKED;
    }

    /// @notice Prevents read-only reentrancy (should be used for view functions)
    modifier nonReentrantRO() virtual {
        if (reentrancyLock != REENTRANCY_UNLOCKED) {
            revert Reentrancy();
        }

        _;
    }

    /// @notice Creates a snapshot of the vault state
    function createVaultSnapshot() internal {
        // We delete snapshots on `checkVaultStatus`, which can only happen at the end of the EVC batch. Snapshots are
        // taken before any action is taken on the vault that affects the cault asset records and deleted at the end, so
        // that asset calculations are always based on the state before the current batch of actions.
        if (snapshot.length == 0) {
            snapshot = doCreateVaultSnapshot();
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

    /// @notice Creates a snapshot of the vault state
    /// @dev Must be overridden by child contracts
    function doCreateVaultSnapshot() internal virtual returns (bytes memory snapshot);

    /// @notice Checks the vault status
    /// @dev Must be overridden by child contracts
    function doCheckVaultStatus(bytes memory snapshot) internal virtual;

    /// @notice Checks the account status
    /// @dev Must be overridden by child contracts
    function doCheckAccountStatus(address, address[] calldata) internal view virtual;

    /// @notice Disables a controller for an account
    /// @dev Must be overridden by child contracts. Must call the EVC.disableController() only if it's safe to do so
    /// (i.e. the account has repaid their debt in full)
    function disableController() external virtual;
}
