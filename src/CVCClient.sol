// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";

abstract contract CVCClient {
    ICVC private immutable cvc;

    error NotAuthorized();
    error ControllerDisabled();
    error CollateralLiquidationFailed();

    constructor(ICVC _cvc) {
        cvc = _cvc;
    }

    modifier CVCOnly() {
        if (msg.sender != address(cvc)) revert NotAuthorized();
        _;
    }

    function CVCAuthenticate() internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount, ) = cvc.getExecutionContext(address(0));
            return onBehalfOfAccount;
        }

        return msg.sender;
    }

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

    function getAccountOwner(
        address account
    ) internal view returns (address owner) {
        if (msg.sender == address(cvc)) {
            owner = cvc.getAccountOwner(account);
        } else {
            owner = account;
        }
    }

    function getCollaterals(
        address account
    ) internal view returns (address[] memory) {
        return cvc.getCollaterals(account);
    }

    function isCollateralEnabled(
        address account,
        address vault
    ) internal view returns (bool) {
        return cvc.isCollateralEnabled(account, vault);
    }

    function getControllers(
        address account
    ) internal view returns (address[] memory) {
        return cvc.getControllers(account);
    }

    function isControllerEnabled(
        address account,
        address vault
    ) internal view returns (bool) {
        return cvc.isControllerEnabled(account, vault);
    }

    function disableSelfAsController(address account) internal {
        cvc.disableController(account);
    }

    function requireAccountStatusCheck(address account) internal {
        cvc.requireAccountStatusCheck(account);
    }

    function requireVaultStatusCheck() internal {
        cvc.requireVaultStatusCheck();
    }

    function requireAccountAndVaultStatusCheck(address account) internal {
        if (account == address(0)) {
            cvc.requireVaultStatusCheck();
        } else {
            cvc.requireAccountAndVaultStatusCheck(account);
        }
    }

    function forgiveAccountStatusCheck(address account) internal {
        cvc.forgiveAccountStatusCheck(account);
    }

    function isAccountStatusCheckDeferred(
        address account
    ) internal view returns (bool) {
        return cvc.isAccountStatusCheckDeferred(account);
    }

    function liquidateCollateralShares(
        address vault,
        address violator,
        address liquidator,
        uint shares
    ) internal {
        (bool success, ) = cvc.impersonate(
            vault,
            violator,
            abi.encodeCall(ERC20.transfer, (liquidator, shares))
        );

        if (!success) {
            revert CollateralLiquidationFailed();
        }
    }
}
