// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../../src/interfaces/IIRM.sol";

contract IRMMock is IIRM {
    uint256 internal interestRate;

    function setInterestRate(uint256 _interestRate) external {
        interestRate = _interestRate;
    }

    function computeInterestRateInternal(address, uint256, uint256) internal view returns (uint256) {
        return uint256((1e27 * interestRate) / 100) / (86400 * 365); // not SECONDS_PER_YEAR to avoid
    }

    function computeInterestRate(address vault, uint256, uint256) external view override returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();

        return computeInterestRateInternal(address(0), 0, 0);
    }

    function computeInterestRateView(address, uint256, uint256) external view override returns (uint256) {
        return computeInterestRateInternal(address(0), 0, 0);
    }
}
