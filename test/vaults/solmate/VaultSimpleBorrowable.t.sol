// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "evc/EthereumVaultConnector.sol";
import "../../../src/vaults/solmate/VaultSimpleBorrowable.sol";

contract VaultSimpleBorrowableTest is Test {
    IEVC evc;
    MockERC20 asset;
    VaultSimpleBorrowable vault;

    function setUp() public {
        evc = new EthereumVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new VaultSimpleBorrowable(address(evc), asset, "Asset Vault", "vASS");
    }

    function test_SimpleBorrowRepay(address alice, uint128 randomAmount) public {
        vm.assume(alice != address(0) && alice != address(evc) && alice != address(vault));
        vm.assume(randomAmount > 10);

        uint256 amount = uint256(randomAmount);

        asset.mint(alice, amount);
        assertEq(asset.balanceOf(alice), amount);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), shares);

        // controller and collateral not enabled, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(EVCUtil.ControllerDisabled.selector));
        vault.borrow((amount * 9) / 10, alice);

        vm.prank(alice);
        evc.enableController(alice, address(vault));

        // collateral still not enabled, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VaultSimpleBorrowable.AccountUnhealthy.selector));
        vault.borrow((amount * 9) / 10, alice);

        vm.prank(alice);
        evc.enableCollateral(alice, address(vault));

        // too much borrowed, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VaultSimpleBorrowable.AccountUnhealthy.selector));
        vault.borrow((amount * 9) / 10 + 1, alice);

        // finally borrow is successful
        vm.prank(alice);
        vault.borrow((amount * 9) / 10, alice);
        assertEq(asset.balanceOf(alice), (amount * 9) / 10);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.debtOf(alice), (amount * 9) / 10);

        // repay is successful
        vm.prank(alice);
        vault.repay((amount * 9) / 10, alice);
        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.debtOf(alice), 0);

        // withdraw is successful
        vm.prank(alice);
        vault.withdraw(amount, alice, alice);
        assertEq(asset.balanceOf(alice), amount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.debtOf(alice), 0);
    }

    function test_SimpleBorrowRepayWithBatch(address alice, uint128 randomAmount) public {
        vm.assume(alice != address(0) && alice != address(evc) && alice != address(vault));
        vm.assume(randomAmount > 10);

        uint256 amount = uint256(randomAmount);

        asset.mint(alice, amount);
        assertEq(asset.balanceOf(alice), amount);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](4);
        items[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(VaultSimple.deposit.selector, amount, alice)
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeWithSelector(IEVC.enableController.selector, alice, address(vault))
        });
        items[2] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeWithSelector(IEVC.enableCollateral.selector, alice, address(vault))
        });
        items[3] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(VaultSimpleBorrowable.borrow.selector, (amount * 9) / 10 + 1, alice)
        });

        // it will revert because of the borrow amount being too high
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VaultSimpleBorrowable.AccountUnhealthy.selector));
        evc.batch(items);

        items[3].data = abi.encodeWithSelector(VaultSimpleBorrowable.borrow.selector, (amount * 9) / 10, alice);

        // now it will succeed
        vm.prank(alice);
        evc.batch(items);
        assertEq(asset.balanceOf(alice), (amount * 9) / 10);
        assertEq(vault.maxWithdraw(alice), amount - (amount * 9) / 10);
        assertEq(vault.debtOf(alice), (amount * 9) / 10);

        items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(VaultSimpleBorrowable.repay.selector, (amount * 9) / 10, alice)
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(VaultSimple.withdraw.selector, amount, alice, alice)
        });

        vm.prank(alice);
        evc.batch(items);
        assertEq(asset.balanceOf(alice), amount);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.debtOf(alice), 0);
    }
}
