// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "solmate/tokens/ERC4626.sol";
import "../../src/interfaces/IPriceOracle.sol";

contract PriceOracleMock is IPriceOracle {
    mapping(address vault => address asset) public resolvedVaults;
    mapping(address base => mapping(address quote => uint256)) internal prices;

    function name() external pure returns (string memory) {
        return "PriceOracleMock";
    }

    function setResolvedVault(address vault) external {
        resolvedVaults[vault] = address(ERC4626(vault).asset());
    }

    function setPrice(address base, address quote, uint256 priceValue) external {
        prices[base][quote] = priceValue;
    }

    function getQuote(uint256 amount, address base, address quote) external view returns (uint256 out) {
        uint256 price;
        (amount, base, quote, price) = _resolveOracle(amount, base, quote);

        if (base == quote) {
            out = amount;
        } else {
            out = price * amount / 10 ** ERC20(base).decimals();
        }
    }

    function getQuotes(
        uint256 amount,
        address base,
        address quote
    ) external view returns (uint256 bidOut, uint256 askOut) {
        uint256 price;
        (amount, base, quote, price) = _resolveOracle(amount, base, quote);

        if (base == quote) {
            bidOut = amount;
        } else {
            bidOut = price * amount / 10 ** ERC20(base).decimals();
        }

        askOut = bidOut;
    }

    function _resolveOracle(
        uint256 amount,
        address base,
        address quote
    ) internal view returns (uint256, address, address, uint256) {
        // Check the base case
        if (base == quote) return (amount, base, quote, 0);

        // 1. Check if base/quote is configured.
        uint256 price = prices[base][quote];
        if (price > 0) return (amount, base, quote, price);

        // 2. Recursively resolve `base`.
        address baseAsset = resolvedVaults[base];
        if (baseAsset != address(0)) {
            amount = ERC4626(base).convertToAssets(amount);
            return _resolveOracle(amount, baseAsset, quote);
        }

        // 3. Recursively resolve `quote`.
        address quoteAsset = resolvedVaults[quote];
        if (quoteAsset != address(0)) {
            amount = ERC4626(quote).convertToShares(amount);
            return _resolveOracle(amount, base, quoteAsset);
        }

        revert PO_NoPath();
    }
}
