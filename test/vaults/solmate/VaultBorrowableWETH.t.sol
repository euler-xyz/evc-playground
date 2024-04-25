// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import {IRMMock} from "../../mocks/IRMMock.sol";
import {PriceOracleMock} from "../../mocks/PriceOracleMock.sol";
import "../../../src/vaults/solmate/VaultBorrowableWETH.sol";

contract VaultBorrowableWETHTest is Test {
    IEVC evc;
    WETH weth;
    VaultBorrowableWETH vault;
    IRMMock irm;
    PriceOracleMock oracle;

    function setUp() public {
        evc = new EthereumVaultConnector();
        weth = new WETH();
        irm = new IRMMock();
        oracle = new PriceOracleMock();

        vault = new VaultBorrowableWETH(
            address(evc), ERC20(address(weth)), irm, oracle, ERC20(address(0)), "WETH VAULT", "VWETH"
        );
    }

    function test_depositAndWithdraw(address alice, uint128 amount) public {
        vm.assume(alice != address(0) && alice != address(evc) && alice != address(vault));
        vm.assume(amount > 0);

        vm.deal(alice, amount);
        vm.prank(alice);
        vault.depositETH{value: amount}(alice);
        assertEq(weth.balanceOf(address(vault)), amount);
        assertEq(weth.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), amount);

        vm.prank(alice);
        vault.withdraw(amount, alice, alice);
        assertEq(weth.balanceOf(address(vault)), 0);
        assertEq(weth.balanceOf(alice), amount);
        assertEq(vault.balanceOf(alice), 0);
    }
}
