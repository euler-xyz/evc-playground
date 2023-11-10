// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "../../src/interfaces/IPriceOracle.sol";

contract PriceOracleMock is IPriceOracle {
    mapping(address base => mapping(address quote => uint256)) internal quotes;

    function setQuote(address base, address quote, uint256 quoteValue) external {
        quotes[base][quote] = quoteValue;
    }

    function name() external pure returns (string memory) {
        return "PriceOracleMock";
    }

    function getQuote(uint256 amount, address base, address quote) external view returns (uint256 out) {
        return (quotes[base][quote] * amount) / 10 ** ERC20(base).decimals();
    }

    function getQuotes(
        uint256 amount,
        address base,
        address quote
    ) external view returns (uint256 bidOut, uint256 askOut) {
        uint256 out = (quotes[base][quote] * amount) / 10 ** ERC20(base).decimals();
        return (out, out);
    }

    function getTick(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function getTicks(uint256, address, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }
}
