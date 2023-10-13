// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IPriceOracle {
    function name() external view returns (string memory);

    function getQuote(
        uint amount,
        address base,
        address quote
    ) external view returns (uint out);

    function getQuotes(
        uint amount,
        address base,
        address quote
    ) external view returns (uint bidOut, uint askOut);

    function getTick(
        uint amount,
        address base,
        address quote
    ) external view returns (uint tick);

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
