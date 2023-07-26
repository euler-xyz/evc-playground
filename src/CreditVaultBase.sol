// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "euler-cvc/interfaces/ICreditVault.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";
import "./ReentrancyGuard.sol";
import "./UnstructuredStorageBytes.sol";

abstract contract CreditVaultBase is ReentrancyGuard, UnstructuredStorageBytes, ICreditVault {
    error NotAuthorized();
    error ControllerDisabled();

    ICVC public immutable cvc;

    uint constant internal REENTRANCY_GUARD_CHECKS_IN_PROGRESS = 3;
    
    constructor(ICVC _cvc) 
    ReentrancyGuard("CreditVaultBase.reentrancyGuard") 
    UnstructuredStorageBytes("CreditVaultBase.bytes") {
        cvc = _cvc;
    }

    modifier CVCOnly() {
        if (msg.sender != address(cvc)) revert NotAuthorized();
        _;
    }

    modifier checksInProgress() {
        testReentrancyGuard(REENTRANCY_GUARD_BUSY, MustBeNonReentrant.selector);

        setReentrancyGuard(REENTRANCY_GUARD_CHECKS_IN_PROGRESS);
        _;
        setReentrancyGuard(REENTRANCY_GUARD_BUSY);
    }

    function CVCAuthenticate(address msgSender, bool controllerEnabledCheck) internal view 
    returns (address authMsgSender) {
        if (msgSender == address(cvc)) {
            (
                ICVC.ExecutionContext memory context, 
                bool controllerEnabled
            ) = cvc.getExecutionContext(controllerEnabledCheck ? address(this) : address(0));

            authMsgSender = context.onBehalfOfAccount;
            
            if (controllerEnabledCheck && !controllerEnabled) revert ControllerDisabled();
        } else {
            authMsgSender = msgSender;
            if (controllerEnabledCheck && !cvc.isControllerEnabled(authMsgSender, address(this))) revert ControllerDisabled();
        }
    }

    function requireVaultStatusCheck() internal checksInProgress {
        cvc.requireVaultStatusCheck();
    }

    function requireAccountStatusCheck(address account) internal checksInProgress {
        cvc.requireAccountStatusCheck(account);
    }

    function requireAccountsStatusCheck(address[] memory accounts) internal checksInProgress {
        cvc.requireAccountsStatusCheck(accounts);
    }

    function vaultStatusSnapshot() internal {
        testReentrancyGuard(REENTRANCY_GUARD_BUSY, MustBeNonReentrant.selector);
        if (areBytesEmpty()) setBytes(doVaultStatusSnapshot());
    }

    function checkVaultStatus() external CVCOnly returns (bool isValid, bytes memory data) {
        uint reentrancyGuard = getReentrancyGuard();

        if (
            reentrancyGuard != REENTRANCY_GUARD_INIT && 
            reentrancyGuard != REENTRANCY_GUARD_CHECKS_IN_PROGRESS
        ) revert Reentrancy();

        (isValid, data) = doCheckVaultStatus(getBytes());
    }

    function checkAccountStatus(address account, address[] calldata collaterals) external view 
    returns (bool isValid, bytes memory data) {
        uint reentrancyGuard = getReentrancyGuard();

        if (
            reentrancyGuard != REENTRANCY_GUARD_INIT && 
            reentrancyGuard != REENTRANCY_GUARD_CHECKS_IN_PROGRESS
        ) revert Reentrancy();

        (isValid, data) = doCheckAccountStatus(account, collaterals);
    }

    function doVaultStatusSnapshot() internal view virtual returns (bytes memory snapshot);

    function doCheckVaultStatus(bytes memory snapshot) internal virtual returns (bool isValid, bytes memory data);

    function doCheckAccountStatus(address, address[] calldata) internal view virtual returns (bool isValid, bytes memory data);

    function disableController(address account) external virtual;
}
