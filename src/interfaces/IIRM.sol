// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

interface IIRM {
    /// @notice Computes the interest rate for a given vault, asset and utilisation.
    /// @param vault The address of the vault.
    /// @param asset The address of the asset.
    /// @param utilisation The utilisation rate.
    /// @return The computed interest rate in SPY (Second Percentage Yield).
    function computeInterestRate(address vault, address asset, uint32 utilisation) external returns (int96);
}
