// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "euler-cvc/interfaces/ICreditVault.sol";
import "../utils/CVCClient.sol";

abstract contract CreditVaultBase is ICreditVault, CVCClient {
    uint internal constant REENTRANCY_GUARD__UNLOCKED = 1;
    uint internal constant REENTRANCY_GUARD__LOCKED = 2;

    uint private reentrancyGuard;
    bytes private snapshot;

    error Reentrancy();

    constructor(ICVC _cvc) CVCClient(_cvc) {
        reentrancyGuard = REENTRANCY_GUARD__UNLOCKED;
    }

    modifier nonReentrant() {
        if (reentrancyGuard != REENTRANCY_GUARD__UNLOCKED) {
            revert Reentrancy();
        }

        reentrancyGuard = REENTRANCY_GUARD__LOCKED;
        _;
        reentrancyGuard = REENTRANCY_GUARD__UNLOCKED;
    }

    modifier nonReentrantWithChecks(address account) {
        if (reentrancyGuard != REENTRANCY_GUARD__UNLOCKED) {
            revert Reentrancy();
        }

        reentrancyGuard = REENTRANCY_GUARD__LOCKED;
        takeVaultSnapshot();

        _;

        reentrancyGuard = REENTRANCY_GUARD__UNLOCKED;
        requireAccountAndVaultStatusCheck(account);
    }

    function takeVaultSnapshot() internal {
        if (snapshot.length == 0) {
            snapshot = doTakeVaultSnapshot();
        }
    }

    function checkVaultStatus()
        external
        CVCOnly
        returns (bool isValid, bytes memory data)
    {
        bytes memory oldSnapshot = snapshot;
        delete snapshot;

        (isValid, data) = doCheckVaultStatus(oldSnapshot);
    }

    function checkAccountStatus(
        address account,
        address[] calldata collaterals
    ) external view returns (bool isValid, bytes memory data) {
        (isValid, data) = doCheckAccountStatus(account, collaterals);
    }

    function doTakeVaultSnapshot()
        internal
        view
        virtual
        returns (bytes memory snapshot);

    function doCheckVaultStatus(
        bytes memory snapshot
    ) internal virtual returns (bool isValid, bytes memory data);

    function doCheckAccountStatus(
        address,
        address[] calldata
    ) internal view virtual returns (bool isValid, bytes memory data);

    function disableController(address account) external virtual;
}
