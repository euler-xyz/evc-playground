// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../../src/interfaces/IIRM.sol";

contract IRMMock is IIRM {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
    int96 internal constant MAX_ALLOWED_INTEREST_RATE = int96(int256(uint256(5 * 1e27) / SECONDS_PER_YEAR)); // 500% APR
    int96 internal constant MIN_ALLOWED_INTEREST_RATE = 0;

    uint256 internal interestRate;

    function setInterestRate(uint256 _interestRate) external {
        interestRate = _interestRate;
    }

    function computeInterestRate(address market, address asset, uint32 utilisation) external returns (int96) {
        int96 rate = computeInterestRateImpl(market, asset, utilisation);

        if (rate > MAX_ALLOWED_INTEREST_RATE) {
            rate = MAX_ALLOWED_INTEREST_RATE;
        } else if (rate < MIN_ALLOWED_INTEREST_RATE) {
            rate = MIN_ALLOWED_INTEREST_RATE;
        }

        return rate;
    }

    function computeInterestRateImpl(address, address, uint32) internal virtual returns (int96) {
        return int96(int256(uint256((1e27 * interestRate) / 100) / (86400 * 365))); // not SECONDS_PER_YEAR to avoid
            // breaking tests
    }

    function reset(address market, bytes calldata resetParams) external virtual {}
}
