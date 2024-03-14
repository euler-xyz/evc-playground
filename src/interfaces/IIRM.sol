// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

interface IIRM {
    error E_IRMUpdateUnauthorized();

    /// @notice Updates the interest rate for a given vault, asset, and utilisation.
    /// @param vault The address of the vault.
    /// @param cash The amount of assets in the vault.
    /// @param borrows The amount of assets borrowed from the vault.
    /// @return The updated interest rate in SPY (Second Percentage Yield).
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256);

    /// @notice Computes the interest rate for a given vault, asset and utilisation.
    /// @param vault The address of the vault.
    /// @param cash The amount of assets in the vault.
    /// @param borrows The amount of assets borrowed from the vault.
    /// @return The computed interest rate in SPY (Second Percentage Yield).
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256);
}
