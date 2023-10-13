// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "euler-cvc/CreditVaultConnector.sol";
import "../src/CreditVaultRegularBorrowable.sol";
import "./mocks/IRMMock.sol";
import "./mocks/PriceOracleMock.sol";

contract CreditVaultRegularBorrowableTest is Test {
    ICVC cvc;
    MockERC20 referenceAsset;
    MockERC20 liabilityAsset;
    MockERC20 collateralAsset1;
    MockERC20 collateralAsset2;
    IRMMock irm;
    PriceOracleMock oracle;

    CreditVaultRegularBorrowable liabilityVault;
    CreditVaultSimple collateralVault1;
    CreditVaultSimple collateralVault2;

    function setUp() public {
        cvc = new CreditVaultConnector();
        referenceAsset = new MockERC20("Reference Asset", "RA", 18);
        liabilityAsset = new MockERC20("Liability Asset", "LA", 18);
        collateralAsset1 = new MockERC20("Collateral Asset 1", "CA1", 18);
        collateralAsset2 = new MockERC20("Collateral Asset 2", "CA2", 6);
        irm = new IRMMock();
        oracle = new PriceOracleMock();

        liabilityVault = new CreditVaultRegularBorrowable(
            cvc,
            liabilityAsset,
            irm,
            oracle,
            referenceAsset,
            "Liability Vault",
            "LV"
        );

        collateralVault1 = new CreditVaultSimple(
            cvc,
            collateralAsset1,
            "Collateral Vault 1",
            "CV1"
        );

        collateralVault2 = new CreditVaultSimple(
            cvc,
            collateralAsset2,
            "Collateral Vault 2",
            "CV2"
        );

        irm.setInterestRate(10); // 10% APY
        oracle.setQuote(address(liabilityAsset), address(referenceAsset), 1e17); // 1 LA = 0.1 RA

        oracle.setQuote(
            address(collateralAsset1),
            address(referenceAsset),
            1e16
        ); // 1 CA1 = 0.01 RA

        oracle.setQuote(
            address(collateralAsset2),
            address(referenceAsset),
            1e17
        ); // 1 CA2 = 0.1 RA
    }

    function mintAndApprove(address alice, address bob) public {
        liabilityAsset.mint(alice, 100e18);
        collateralAsset1.mint(bob, 100e18);
        collateralAsset2.mint(bob, 100e6);
        assertEq(liabilityAsset.balanceOf(alice), 100e18);
        assertEq(collateralAsset1.balanceOf(bob), 100e18);
        assertEq(collateralAsset2.balanceOf(bob), 100e6);

        vm.prank(alice);
        liabilityAsset.approve(address(liabilityVault), type(uint).max);

        vm.prank(bob);
        collateralAsset1.approve(address(collateralVault1), type(uint).max);

        vm.prank(bob);
        collateralAsset2.approve(address(collateralVault2), type(uint).max);
    }

    function test_RegularBorrowRepay(address alice, address bob) public {
        vm.assume(
            alice != address(0) &&
                alice != address(cvc) &&
                bob != address(0) &&
                bob != address(cvc) &&
                !cvc.haveCommonOwner(alice, bob)
        );

        mintAndApprove(alice, bob);

        liabilityVault.setCollateralFactor(liabilityVault, 100); // cf = 1, self-collateralization
        liabilityVault.setCollateralFactor(collateralVault1, 100); // cf = 1
        liabilityVault.setCollateralFactor(collateralVault2, 50); // cf = 0.5

        // alice deposits 50 LA
        vm.prank(alice);
        liabilityVault.deposit(50e18, alice);
        assertEq(liabilityAsset.balanceOf(alice), 50e18);
        assertEq(liabilityVault.maxWithdraw(alice), 50e18);

        // bob deposits 100 CA1 which lets him borrow 10 LA
        vm.prank(bob);
        collateralVault1.deposit(100e18, bob);
        assertEq(collateralAsset1.balanceOf(bob), 0);
        assertEq(collateralVault1.maxWithdraw(bob), 100e18);

        // bob deposits 50 CA2 which lets him borrow 25 LA
        vm.prank(bob);
        collateralVault2.deposit(50e6, bob);
        assertEq(collateralAsset2.balanceOf(bob), 50e6);
        assertEq(collateralVault2.maxWithdraw(bob), 50e6);

        // controller and collateral not enabled, hence borrow unsuccessful
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(CVCClient.ControllerDisabled.selector)
        );
        liabilityVault.borrow(35e18, bob);

        vm.prank(bob);
        cvc.enableController(bob, address(liabilityVault));

        // collateral still not enabled, hence borrow unsuccessful
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                bob,
                bytes("account unhealthy")
            )
        );
        liabilityVault.borrow(35e18, bob);

        vm.prank(bob);
        cvc.enableCollateral(bob, address(collateralVault1));

        // too much borrowed because only one collateral enabled, hence borrow unsuccessful
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                bob,
                bytes("account unhealthy")
            )
        );
        liabilityVault.borrow(35e18, bob);

        vm.prank(bob);
        cvc.enableCollateral(bob, address(collateralVault2));

        // too much borrowed, hence borrow unsuccessful
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                bob,
                bytes("account unhealthy")
            )
        );
        liabilityVault.borrow(35e18 + 0.01e18, bob);

        // finally borrow is successful
        vm.prank(bob);
        liabilityVault.borrow(35e18, bob);
        assertEq(liabilityAsset.balanceOf(bob), 35e18);
        assertEq(liabilityVault.debtOf(bob), 35e18);
        assertEq(liabilityVault.maxWithdraw(alice), 15e18);

        // jump one year ahead, bob's liability increased by 10% APY.
        // his account is no longer healthy
        vm.warp(block.timestamp + 365 days);
        assertEq(liabilityAsset.balanceOf(bob), 35e18);
        assertEq(liabilityVault.debtOf(bob), 35e18 + 3.680982126514837395e18);
        assertEq(liabilityVault.maxWithdraw(alice), 15e18);
        assertEq(cvc.checkAccountStatus(bob), false);

        // bob repays only some of his debt, his account is still unhealthy
        vm.prank(bob);
        liabilityAsset.approve(address(liabilityVault), type(uint).max);

        vm.prank(bob);
        liabilityVault.repay(2.680982126514837395e18, bob);
        assertEq(
            liabilityAsset.balanceOf(bob),
            35e18 - 2.680982126514837395e18
        );
        assertEq(liabilityVault.debtOf(bob), 35e18 + 1e18);
        assertEq(
            liabilityVault.maxWithdraw(alice),
            15e18 + 2.680982126514837395e18
        );
        assertEq(cvc.checkAccountStatus(bob), false);

        // alice kicks in to liquidate bob. first enable controller and collaterals
        vm.prank(alice);
        cvc.enableController(alice, address(liabilityVault));

        vm.prank(alice);
        cvc.enableCollateral(alice, address(liabilityVault));

        vm.prank(alice);
        cvc.enableCollateral(alice, address(collateralVault1));

        vm.prank(alice);
        cvc.enableCollateral(alice, address(collateralVault2));

        // liquidation fails multiple times as alice tries to liquidate too much
        vm.prank(alice);
        vm.expectRevert(CVCClient.CollateralLiquidationFailed.selector);
        liabilityVault.liquidate(bob, address(collateralVault1), 30e18);

        vm.prank(alice);
        vm.expectRevert(
            CreditVaultRegularBorrowable.RepayAssetsExceeded.selector
        );
        liabilityVault.liquidate(bob, address(collateralVault2), 30e18);

        // finally liquidation is successful
        vm.prank(alice);
        liabilityVault.liquidate(bob, address(collateralVault2), 6e18); // liquidation incentive at a time is 3%
        assertEq(
            liabilityAsset.balanceOf(bob),
            35e18 - 2.680982126514837395e18
        ); // bob's LA balance stays unchanged
        assertEq(liabilityVault.debtOf(bob), 30e18); // bob's debt decreased by 6 LA due to liquidation
        assertEq(collateralVault1.maxWithdraw(bob), 100e18); // bob's CA1 deposit stays unchanged
        assertEq(collateralVault2.maxWithdraw(bob), 50e6 - 6.18e6); // bob's CA2 deposit decreased by 6.18 CA2 due to liquidation
        assertEq(liabilityVault.debtOf(alice), 6e18); // alices's debt increased to 6 LA due to liquidation (she took on bob's debt)
        assertEq(
            liabilityVault.maxWithdraw(alice),
            15e18 + 2.680982126514837395e18
        ); // alice's ability to withdraw LA did't change
        assertEq(collateralVault1.maxWithdraw(alice), 0); // alices's CA1 deposit stays unchanged
        assertEq(collateralVault2.maxWithdraw(alice), 6.18e6); // alices's CA2 deposit increased by 6.18 CA2 due to liquidation (she took on bob's collateral)
        assertEq(cvc.checkAccountStatus(alice), true);
        assertEq(cvc.checkAccountStatus(bob), true);

        // alice repays her debt taken on from bob
        vm.prank(alice);
        liabilityVault.repay(6e18, alice);
        assertEq(liabilityAsset.balanceOf(alice), 50e18 - 6e18);
        assertEq(liabilityVault.debtOf(alice), 0);

        // she disables collaterals and controller
        vm.prank(alice);
        liabilityVault.disableController(alice);

        vm.prank(alice);
        cvc.disableCollateral(alice, address(liabilityVault));

        vm.prank(alice);
        cvc.disableCollateral(alice, address(collateralVault1));

        vm.prank(alice);
        cvc.disableCollateral(alice, address(collateralVault2));

        // then alice withdraws the collateral seized
        vm.prank(alice);
        collateralVault2.withdraw(6.18e6, alice, alice);
        assertEq(collateralAsset2.balanceOf(alice), 6.18e6);
        assertEq(collateralVault2.maxWithdraw(alice), 0);

        // bob repays the rest of his debt
        vm.prank(bob);
        liabilityVault.repay(30e18, bob);
        assertEq(
            liabilityAsset.balanceOf(bob),
            35e18 - 2.680982126514837395e18 - 30e18
        );
        assertEq(liabilityVault.debtOf(bob), 0);

        // he disables collaterals and controller
        vm.prank(bob);
        liabilityVault.disableController(bob);

        vm.prank(bob);
        cvc.disableCollateral(bob, address(collateralVault1));

        vm.prank(bob);
        cvc.disableCollateral(bob, address(collateralVault2));

        // finally, bob withdraws his collaterals
        vm.prank(bob);
        collateralVault1.withdraw(100e18, bob, bob);
        assertEq(collateralAsset1.balanceOf(bob), 100e18);
        assertEq(collateralVault1.maxWithdraw(bob), 0);

        vm.prank(bob);
        collateralVault2.withdraw(50e6 - 6.18e6, bob, bob);
        assertEq(collateralAsset2.balanceOf(bob), 100e6 - 6.18e6);
        assertEq(collateralVault2.maxWithdraw(bob), 0);

        // alice withdraws her LA deposit
        vm.prank(alice);
        liabilityVault.withdraw(
            50e18 - 35e18 + 2.680982126514837395e18 + 6e18 + 30e18,
            alice,
            alice
        );
        assertEq(
            liabilityAsset.balanceOf(alice),
            100e18 - 35e18 + 2.680982126514837395e18 + 30e18
        );
        assertEq(liabilityVault.maxWithdraw(alice), 0);

        // final checks
        assertEq(liabilityAsset.balanceOf(address(liabilityVault)), 0);
        assertEq(
            liabilityAsset.balanceOf(address(alice)),
            100e18 - 35e18 + 2.680982126514837395e18 + 30e18
        );
        assertEq(
            liabilityAsset.balanceOf(address(bob)),
            35e18 - 2.680982126514837395e18 - 30e18
        );
        assertEq(liabilityVault.maxWithdraw(alice), 0);
        assertEq(liabilityVault.maxWithdraw(bob), 0);
        assertEq(liabilityVault.debtOf(alice), 0);
        assertEq(liabilityVault.debtOf(bob), 0);

        assertEq(collateralAsset1.balanceOf(address(collateralVault1)), 0);
        assertEq(collateralAsset1.balanceOf(address(alice)), 0);
        assertEq(collateralAsset1.balanceOf(address(bob)), 100e18);
        assertEq(collateralVault1.maxWithdraw(alice), 0);
        assertEq(collateralVault1.maxWithdraw(bob), 0);

        assertEq(collateralAsset2.balanceOf(address(collateralVault2)), 0);
        assertEq(collateralAsset2.balanceOf(address(alice)), 6.18e6);
        assertEq(collateralAsset2.balanceOf(address(bob)), 100e6 - 6.18e6);
        assertEq(collateralVault2.maxWithdraw(alice), 0);
        assertEq(collateralVault2.maxWithdraw(bob), 0);
    }

    function test_RegularBorrowRepayWithBatch(
        address alice,
        address bob
    ) public {
        vm.assume(
            alice != address(0) &&
                alice != address(cvc) &&
                bob != address(0) &&
                bob != address(cvc) &&
                !cvc.haveCommonOwner(alice, bob)
        );

        mintAndApprove(alice, bob);

        liabilityVault.setCollateralFactor(liabilityVault, 100); // cf = 1, self-collateralization
        liabilityVault.setCollateralFactor(collateralVault1, 100); // cf = 1
        liabilityVault.setCollateralFactor(collateralVault2, 50); // cf = 0.5

        // alice deposits 50 LA
        vm.prank(alice);
        liabilityVault.deposit(50e18, alice);
        assertEq(liabilityAsset.balanceOf(alice), 50e18);
        assertEq(liabilityVault.maxWithdraw(alice), 50e18);

        // bob deposits collaterals, enables them, enables controller and borrows
        ICVC.BatchItem[] memory items = new ICVC.BatchItem[](6);
        items[0] = ICVC.BatchItem({
            targetContract: address(collateralVault1),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                100e18,
                bob
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(collateralVault2),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                50e6,
                bob
            )
        });
        items[2] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableController.selector,
                bob,
                address(liabilityVault)
            )
        });
        items[3] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                bob,
                address(collateralVault1)
            )
        });
        items[4] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                bob,
                address(collateralVault2)
            )
        });
        items[5] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.borrow.selector,
                35e18 + 0.01e18,
                bob
            )
        });

        // it will revert because of the borrow amount being to high
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditVaultConnector.CVC_AccountStatusViolation.selector,
                bob,
                bytes("account unhealthy")
            )
        );
        cvc.batch(items);

        items[5] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.borrow.selector,
                35e18,
                bob
            )
        });

        // now it will succeed
        vm.prank(bob);
        cvc.batch(items);

        assertEq(liabilityAsset.balanceOf(address(liabilityVault)), 15e18);
        assertEq(liabilityAsset.balanceOf(address(alice)), 50e18);
        assertEq(liabilityAsset.balanceOf(address(bob)), 35e18);
        assertEq(liabilityVault.maxWithdraw(alice), 15e18);
        assertEq(liabilityVault.maxWithdraw(bob), 0);
        assertEq(liabilityVault.debtOf(alice), 0);
        assertEq(liabilityVault.debtOf(bob), 35e18);

        assertEq(collateralAsset1.balanceOf(address(collateralVault1)), 100e18);
        assertEq(collateralAsset1.balanceOf(address(alice)), 0);
        assertEq(collateralAsset1.balanceOf(address(bob)), 0);
        assertEq(collateralVault1.maxWithdraw(alice), 0);
        assertEq(collateralVault1.maxWithdraw(bob), 100e18);

        assertEq(collateralAsset2.balanceOf(address(collateralVault2)), 50e6);
        assertEq(collateralAsset2.balanceOf(address(alice)), 0);
        assertEq(collateralAsset2.balanceOf(address(bob)), 50e6);
        assertEq(collateralVault2.maxWithdraw(alice), 0);
        assertEq(collateralVault2.maxWithdraw(bob), 50e6);

        // jump one year ahead, bob's liability increased by 10% APY.
        // his account is no longer healthy
        vm.warp(block.timestamp + 365 days);
        assertEq(liabilityAsset.balanceOf(bob), 35e18);
        assertEq(liabilityVault.debtOf(bob), 35e18 + 3.680982126514837395e18);
        assertEq(liabilityVault.maxWithdraw(alice), 15e18);
        assertEq(cvc.checkAccountStatus(bob), false);

        // bob repays only some of his debt, his account is still unhealthy
        vm.prank(bob);
        liabilityAsset.approve(address(liabilityVault), type(uint).max);

        vm.prank(bob);
        liabilityVault.repay(2.680982126514837395e18, bob);
        assertEq(
            liabilityAsset.balanceOf(bob),
            35e18 - 2.680982126514837395e18
        );
        assertEq(liabilityVault.debtOf(bob), 35e18 + 1e18);
        assertEq(
            liabilityVault.maxWithdraw(alice),
            15e18 + 2.680982126514837395e18
        );
        assertEq(cvc.checkAccountStatus(bob), false);

        // alice kicks in to liquidate bob, repay the debt and withdraw seized collateral
        items = new ICVC.BatchItem[](11);
        items[0] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableController.selector,
                alice,
                address(liabilityVault)
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                alice,
                address(liabilityVault)
            )
        });
        items[2] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                alice,
                address(collateralVault1)
            )
        });
        items[3] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.enableCollateral.selector,
                alice,
                address(collateralVault2)
            )
        });
        items[4] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultRegularBorrowable.liquidate.selector,
                bob,
                address(collateralVault2),
                6e18
            )
        });
        items[5] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.repay.selector,
                6e18,
                alice
            )
        });
        items[6] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.disableController.selector,
                alice
            )
        });
        items[7] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.disableCollateral.selector,
                alice,
                address(liabilityVault)
            )
        });
        items[8] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.disableCollateral.selector,
                alice,
                address(collateralVault1)
            )
        });
        items[9] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.disableCollateral.selector,
                alice,
                address(collateralVault2)
            )
        });
        items[10] = ICVC.BatchItem({
            targetContract: address(collateralVault2),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                6.18e6,
                alice,
                alice
            )
        });

        vm.prank(alice);
        cvc.batch(items);

        assertEq(
            liabilityAsset.balanceOf(address(liabilityVault)),
            50e18 - 35e18 + 2.680982126514837395e18 + 6e18
        );
        assertEq(liabilityAsset.balanceOf(address(alice)), 50e18 - 6e18);
        assertEq(
            liabilityAsset.balanceOf(address(bob)),
            35e18 - 2.680982126514837395e18
        );
        assertEq(
            liabilityVault.maxWithdraw(alice),
            50e18 - 35e18 + 2.680982126514837395e18 + 6e18
        );
        assertEq(liabilityVault.maxWithdraw(bob), 0);
        assertEq(liabilityVault.debtOf(alice), 0);
        assertEq(liabilityVault.debtOf(bob), 30e18);

        assertEq(collateralAsset1.balanceOf(address(collateralVault1)), 100e18);
        assertEq(collateralAsset1.balanceOf(address(alice)), 0);
        assertEq(collateralAsset1.balanceOf(address(bob)), 0);
        assertEq(collateralVault1.maxWithdraw(alice), 0);
        assertEq(collateralVault1.maxWithdraw(bob), 100e18);

        assertEq(
            collateralAsset2.balanceOf(address(collateralVault2)),
            50e6 - 6.18e6
        );
        assertEq(collateralAsset2.balanceOf(address(alice)), 6.18e6);
        assertEq(collateralAsset2.balanceOf(address(bob)), 50e6);
        assertEq(collateralVault2.maxWithdraw(alice), 0);
        assertEq(collateralVault2.maxWithdraw(bob), 50e6 - 6.18e6);

        // bob repays his debt and withdraws his collaterals
        items = new ICVC.BatchItem[](6);
        items[0] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.repay.selector,
                30e18,
                bob
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimpleBorrowable.disableController.selector,
                bob
            )
        });
        items[2] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.disableCollateral.selector,
                bob,
                address(collateralVault1)
            )
        });
        items[3] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.disableCollateral.selector,
                bob,
                address(collateralVault2)
            )
        });
        items[4] = ICVC.BatchItem({
            targetContract: address(collateralVault1),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                100e18,
                bob,
                bob
            )
        });
        items[5] = ICVC.BatchItem({
            targetContract: address(collateralVault2),
            onBehalfOfAccount: bob,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                50e6 - 6.18e6,
                bob,
                bob
            )
        });

        vm.prank(bob);
        cvc.batch(items);

        // alice withdraws her LA deposit
        vm.prank(alice);
        liabilityVault.withdraw(
            50e18 - 35e18 + 2.680982126514837395e18 + 6e18 + 30e18,
            alice,
            alice
        );

        // final checks
        assertEq(liabilityAsset.balanceOf(address(liabilityVault)), 0);
        assertEq(
            liabilityAsset.balanceOf(address(alice)),
            100e18 - 35e18 + 2.680982126514837395e18 + 30e18
        );
        assertEq(
            liabilityAsset.balanceOf(address(bob)),
            35e18 - 2.680982126514837395e18 - 30e18
        );
        assertEq(liabilityVault.maxWithdraw(alice), 0);
        assertEq(liabilityVault.maxWithdraw(bob), 0);
        assertEq(liabilityVault.debtOf(alice), 0);
        assertEq(liabilityVault.debtOf(bob), 0);

        assertEq(collateralAsset1.balanceOf(address(collateralVault1)), 0);
        assertEq(collateralAsset1.balanceOf(address(alice)), 0);
        assertEq(collateralAsset1.balanceOf(address(bob)), 100e18);
        assertEq(collateralVault1.maxWithdraw(alice), 0);
        assertEq(collateralVault1.maxWithdraw(bob), 0);

        assertEq(collateralAsset2.balanceOf(address(collateralVault2)), 0);
        assertEq(collateralAsset2.balanceOf(address(alice)), 6.18e6);
        assertEq(collateralAsset2.balanceOf(address(bob)), 100e6 - 6.18e6);
        assertEq(collateralVault2.maxWithdraw(alice), 0);
        assertEq(collateralVault2.maxWithdraw(bob), 0);
    }
}
