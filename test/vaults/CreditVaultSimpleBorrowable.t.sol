// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "euler-cvc/CreditVaultConnector.sol";
import "../../src/vaults/CreditVaultSimpleBorrowable.sol";

contract CreditVaultSimpleBorrowableTest is Test {
    ICVC cvc;
    MockERC20 asset;
    CreditVaultSimpleBorrowable vault;

    function setUp() public {
        cvc = new CreditVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new CreditVaultSimpleBorrowable(
            cvc,
            asset,
            "Asset Vault",
            "vASS"
        );
    }

    function test_SimpleBorrowRepay(
        address alice,
        uint128 randomAmount
    ) public {
        vm.assume(alice != address(0) && alice != address(cvc));
        vm.assume(randomAmount > 10);

        uint amount = uint(randomAmount);

        asset.mint(alice, amount);
        assertEq(asset.balanceOf(alice), amount);

        vm.prank(alice);
        asset.approve(address(vault), type(uint).max);

        vm.prank(alice);
        uint shares = vault.deposit(amount, alice);
        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), shares);

        // controller and collateral not enabled, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(CVCClient.ControllerDisabled.selector)
        );
        vault.borrow((amount * 9) / 10, alice);

        vm.prank(alice);
        cvc.enableController(alice, address(vault));

        // collateral still not enabled, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                alice,
                bytes("account unhealthy")
            )
        );
        vault.borrow((amount * 9) / 10, alice);

        vm.prank(alice);
        cvc.enableCollateral(alice, address(vault));

        // too much borrowed, hence borrow unsuccessful
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                alice,
                bytes("account unhealthy")
            )
        );
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

    function test_SimpleBorrowRepayWithBatch(
        address alice,
        uint128 randomAmount
    ) public {
        vm.assume(alice != address(0));
        vm.assume(randomAmount > 10);

        uint amount = uint(randomAmount);

        asset.mint(alice, amount);
        assertEq(asset.balanceOf(alice), amount);

        vm.prank(alice);
        asset.approve(address(vault), type(uint).max);

        ICVC.BatchItem[] memory items = new ICVC.BatchItem[](4);
        items[0] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                amount,
                alice
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableController.selector,
                alice,
                address(vault)
            )
        });
        items[2] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                alice,
                address(vault)
            )
        });
        items[3] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.borrow.selector,
                (amount * 9) / 10 + 1,
                alice
            )
        });

        // it will revert because of the borrow amount being to high
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                alice,
                bytes("account unhealthy")
            )
        );
        cvc.batch(items);

        items[3].data = abi.encodeWithSelector(
            CreditVaultSimpleBorrowable.borrow.selector,
            (amount * 9) / 10,
            alice
        );

        // now it will succeed
        vm.prank(alice);
        cvc.batch(items);
        assertEq(asset.balanceOf(alice), (amount * 9) / 10);
        assertEq(vault.maxWithdraw(alice), amount - (amount * 9) / 10);
        assertEq(vault.debtOf(alice), (amount * 9) / 10);

        items = new ICVC.BatchItem[](2);
        items[0] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.repay.selector,
                (amount * 9) / 10,
                alice
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                amount,
                alice,
                alice
            )
        });

        vm.prank(alice);
        cvc.batch(items);
        assertEq(asset.balanceOf(alice), amount);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.debtOf(alice), 0);
    }
}
