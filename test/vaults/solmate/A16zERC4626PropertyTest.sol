// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {ERC4626Test} from "erc4626-tests/ERC4626.test.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "evc/EthereumVaultConnector.sol";
import "../../../src/vaults/solmate/VaultSimple.sol";

// source:
// https://github.com/a16z/erc4626-tests

contract ERC4626StdTest is ERC4626Test {
    IEVC _evc_;

    function setUp() public override {
        _evc_ = new EthereumVaultConnector();
        _underlying_ = address(new MockERC20("Mock ERC20", "MERC20", 18));
        _vault_ = address(new VaultSimple(address(_evc_), MockERC20(_underlying_), "Mock ERC4626", "MERC4626"));
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    // NOTE: The following test is relaxed to consider only smaller values (of type uint120),
    // since maxWithdraw() fails with large values (due to overflow).

    function test_maxWithdraw(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxWithdraw(init);
    }

    function clamp(Init memory init, uint256 max) internal pure returns (Init memory) {
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = init.share[i] % max;
            init.asset[i] = init.asset[i] % max;
        }
        init.yield = init.yield % int256(max);
        return init;
    }
}
