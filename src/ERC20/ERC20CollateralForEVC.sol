// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";
import "evc/utils/EVCUtil.sol";

/// @title ERC20CollateralForEVC
/// @notice It extends the ERC20 token standard to add the EVC authentication and account status checks so that the
/// token contract can be used as collateral in the EVC ecosystem.
abstract contract ERC20CollateralForEVC is EVCUtil, ERC20 {
    constructor(IEVC _evc, string memory _name, string memory _symbol) EVCUtil(_evc) ERC20(_name, _symbol) {}

    /// @notice Modifier to require an account status check on the EVC.
    /// @dev Calls `requireAccountStatusCheck` function from EVC for the specified account after the function body.
    /// @param account The address of the account to check.
    modifier requireAccountStatusCheck(address account) {
        _;
        evc.requireAccountStatusCheck(account);
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }

    /// @notice Transfers a certain amount of tokens to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(
        address to,
        uint256 amount
    ) public virtual override callThroughEVC requireAccountStatusCheck(_msgSender()) returns (bool) {
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of tokens from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override callThroughEVC requireAccountStatusCheck(from) returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
