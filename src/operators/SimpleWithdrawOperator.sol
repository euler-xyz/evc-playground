// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "solmate/utils/SafeTransferLib.sol";
import "evc/interfaces/IEthereumVaultConnector.sol";
import "../vaults/solmate/VaultSimpleBorrowable.sol";

/// @title SimpleWithdrawOperator
/// @notice This contract allows anyone, in exchange for a tip, to pull liquidity out
/// of a heavily utilised vault on behalf of someone else. Thanks to this operator,
/// a user can delegate the monitoring of their vault to someone else and go on with their life.
contract SimpleWithdrawOperator {
    using SafeTransferLib for ERC20;

    IEVC public immutable evc;

    constructor(IEVC _evc) {
        evc = _evc;
    }

    /// @notice Allows anyone to withdraw on behalf of a onBehalfOfAccount.
    /// @dev Assumes that the onBehalfOfAccount owner had authorized the operator to withdraw on their behalf.
    /// @param vault The address of the vault.
    /// @param onBehalfOfAccount The address of the account on behalf of which the operation is being executed.
    function withdrawOnBehalf(address vault, address onBehalfOfAccount) external {
        ERC20 asset = ERC4626(vault).asset();
        uint256 assets = VaultSimpleBorrowable(vault).maxWithdraw(onBehalfOfAccount);

        if (assets == 0) return;

        // if there's anything to withdraw, withdraw it to this contract
        evc.call(
            vault,
            onBehalfOfAccount,
            0,
            abi.encodeWithSelector(VaultSimple.withdraw.selector, assets, address(this), onBehalfOfAccount)
        );

        // transfer 1% of the withdrawn assets as a tip to the msg.sender
        asset.safeTransfer(msg.sender, assets / 100);

        // transfer the rest to the owner of onBehalfOfAccount (must be owner in case it's a sub-account)
        asset.safeTransfer(evc.getAccountOwner(onBehalfOfAccount), ERC20(asset).balanceOf(address(this)));
    }
}
