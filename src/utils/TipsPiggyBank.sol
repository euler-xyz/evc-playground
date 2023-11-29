// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "solmate/utils/SafeTransferLib.sol";

/// @title TipsPiggyBank
/// @notice This contract is used for handling tips by having a static deposit address and letting anyone withdraw the
/// tokens to a specified receiver.
contract TipsPiggyBank {
    using SafeTransferLib for ERC20;

    /// @notice Withdraws the specified token to the receiver.
    /// @param token The ERC20 token to be withdrawn.
    /// @param receiver The address to receive the withdrawn tokens.
    function withdraw(ERC20 token, address receiver) external {
        token.safeTransfer(receiver, token.balanceOf(address(this)));
    }
}
