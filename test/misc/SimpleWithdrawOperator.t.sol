// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "evc/EthereumVaultConnector.sol";
import "../../src/vaults/solmate/VaultSimpleBorrowable.sol";
import "../../src/operators/SimpleWithdrawOperator.sol";

contract SimpleWithdrawOperatorTest is Test {
    IEVC evc;
    MockERC20 asset;
    VaultSimpleBorrowable vault;
    SimpleWithdrawOperator withdrawOperator;

    function setUp() public {
        evc = new EthereumVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new VaultSimpleBorrowable(address(evc), asset, "Vault", "VAU");
        withdrawOperator = new SimpleWithdrawOperator(evc);
    }

    function test_SimpleWithdrawOperator(address alice, address bot) public {
        vm.assume(
            !evc.haveCommonOwner(alice, address(0)) && alice != address(evc) && bot != address(evc)
                && !evc.haveCommonOwner(alice, address(withdrawOperator)) && bot != address(vault) && bot != alice
        );
        address alicesSubAccount = address(uint160(alice) ^ 1);

        asset.mint(alice, 100e18);

        // alice deposits into her main account and a subaccount
        vm.startPrank(alice);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(50e18, alice);
        vault.deposit(50e18, alicesSubAccount);

        // for simplicity, let's ignore the fact that nobody borrows from a vault

        // alice authorizes the operator to act on behalf of her subaccount
        evc.setAccountOperator(alicesSubAccount, address(withdrawOperator), true);
        vm.stopPrank();

        assertEq(asset.balanceOf(address(alice)), 0);
        assertEq(vault.maxWithdraw(alice), 50e18);
        assertEq(vault.maxWithdraw(alicesSubAccount), 50e18);

        // assume that a keeper bot is monitoring the chain. when alice authorizes the operator,
        // the bot can call withdrawOnBehalf() function, withdraw on behalf of alice and get tipped
        vm.prank(bot);
        withdrawOperator.withdrawOnBehalf(address(vault), alicesSubAccount);

        assertEq(asset.balanceOf(alice), 49.5e18);
        assertEq(asset.balanceOf(bot), 0.5e18);
        assertEq(vault.maxWithdraw(alice), 50e18);
        assertEq(vault.maxWithdraw(alicesSubAccount), 0);

        // however, the bot cannot call withdrawOnBehalf() on behalf of alice's main account
        // because she didn't authorize the operator
        vm.prank(bot);
        vm.expectRevert(abi.encodeWithSelector(Errors.EVC_NotAuthorized.selector));
        withdrawOperator.withdrawOnBehalf(address(vault), alice);
    }
}
