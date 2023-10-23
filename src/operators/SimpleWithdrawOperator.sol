// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/utils/SafeTransferLib.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";
import "../vaults/CreditVaultSimpleBorrowable.sol";

/// @title SimpleWithdrawOperator
/// @notice This contract allows anyone, in exchange for a tip, to pull liquidity out 
/// of a heavily utilised vault on behalf of someone else. Thanks to this operator,
/// a user can delegate the monitoring of their vault to someone else and go on with their life.
contract SimpleWithdrawOperator {
    using SafeTransferLib for ERC20;

    ICVC public immutable cvc;

    constructor(ICVC _cvc) {
        cvc = _cvc;
    }

    /// @notice Allows anyone to withdraw on behalf of a onBehalfOfAccount.
    /// @dev Assumes that the onBehalfOfAccount owner had authorized the operator to withdraw on their behalf.
    /// @param vault The address of the vault.
    /// @param onBehalfOfAccount The address of the account on behalf of which the operation is being executed.
    function withdrawOnBehalf(
        address vault,
        address onBehalfOfAccount
    ) external {
        ERC20 asset = ERC4626(vault).asset();
        uint assets = CreditVaultSimpleBorrowable(vault).maxWithdraw(
            onBehalfOfAccount
        );

        if (assets == 0) return;

        // if there's anything to withdraw, withdraw it to this contract
        cvc.call(
            vault,
            onBehalfOfAccount,
            abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                assets,
                address(this),
                onBehalfOfAccount
            )
        );

        // transfer 1% of the withdrawn assets as a tip to the msg.sender
        asset.safeTransfer(msg.sender, assets / 100);

        // transfer the rest to the owner of onBehalfOfAccount (must be owner in case it's a sub-account)
        asset.safeTransfer(
            cvc.getAccountOwner(onBehalfOfAccount),
            ERC20(asset).balanceOf(address(this))
        );
    }
}
