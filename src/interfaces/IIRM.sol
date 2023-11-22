// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IIRM {
    /// @notice Computes the interest rate for a given vault, asset and utilisation.
    /// @param vault The address of the vault.
    /// @param asset The address of the asset.
    /// @param utilisation The utilisation rate.
    /// @return The computed interest rate in SPY (Second Percentage Yield).
    function computeInterestRate(address vault, address asset, uint32 utilisation) external returns (int96);

    /// @notice Resets the parameters for a given vault.
    /// @param vault The address of the market.
    /// @param resetParams The parameters to reset.
    function reset(address vault, bytes calldata resetParams) external;
}
