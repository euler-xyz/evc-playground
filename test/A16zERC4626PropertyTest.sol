// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "erc4626-tests/ERC4626.test.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "src/CreditVaultSimple.sol";
import "euler-cvc/CreditVaultConnector.sol";

// source:
// https://github.com/a16z/erc4626-tests

contract ERC4626StdTest is ERC4626Test {
    ICVC _cvc_;

    function setUp() public override {
        _cvc_ = new CreditVaultConnector();
        _underlying_ = address(new MockERC20("Mock ERC20", "MERC20", 18));
        _vault_ = address(new CreditVaultSimple(_cvc_, MockERC20(_underlying_), "Mock ERC4626", "MERC4626"));
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }
}