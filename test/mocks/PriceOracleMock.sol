// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "../../src/interfaces/IPriceOracle.sol";

contract PriceOracleMock is IPriceOracle {
    mapping(address base => mapping(address quote => uint)) internal quotes;

    function setQuote(address base, address quote, uint quoteValue) external {
        quotes[base][quote] = quoteValue;
    }

    function name() external pure returns (string memory) {
        return "PriceOracleMock";
    }

    function getQuote(
        uint amount,
        address base,
        address quote
    ) external view returns (uint out) {
        return (quotes[base][quote] * amount) / 10 ** ERC20(base).decimals();
    }

    function getQuotes(
        uint amount,
        address base,
        address quote
    ) external view returns (uint bidOut, uint askOut) {
        uint out = (quotes[base][quote] * amount) /
            10 ** ERC20(base).decimals();
        return (out, out);
    }

    function getTick(uint, address, address) external pure returns (uint) {
        return 0;
    }

    function getTicks(
        uint,
        address,
        address
    ) external pure returns (uint, uint) {
        return (0, 0);
    }
}
