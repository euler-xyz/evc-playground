// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IPriceOracle {
    /// @notice Returns the name of the price oracle.
    function name() external view returns (string memory);

    /// @notice Returns the quote for a given amount of base asset in quote asset.
    /// @param amount The amount of base asset.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @return out The quote amount in quote asset.
    function getQuote(
        uint amount,
        address base,
        address quote
    ) external view returns (uint out);

    /// @notice Returns the bid and ask quotes for a given amount of base asset in quote asset.
    /// @param amount The amount of base asset.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @return bidOut The bid quote amount in quote asset.
    /// @return askOut The ask quote amount in quote asset.
    function getQuotes(
        uint amount,
        address base,
        address quote
    ) external view returns (uint bidOut, uint askOut);

    /// @notice Returns the tick for a given amount of base asset in quote asset.
    /// @param amount The amount of base asset.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @return tick The tick value.
    function getTick(
        uint amount,
        address base,
        address quote
    ) external view returns (uint tick);

    /// @notice Returns the bid and ask ticks for a given amount of base asset in quote asset.
    /// @param amount The amount of base asset.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @return bidTick The bid tick value.
    /// @return askTick The ask tick value.
    function getTicks(
        uint amount,
        address base,
        address quote
    ) external view returns (uint bidTick, uint askTick);

    error PO_BaseUnsupported();
    error PO_QuoteUnsupported();
    error PO_Overflow();
    error PO_NoPath();
}