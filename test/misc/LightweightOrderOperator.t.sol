// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "euler-cvc/CreditVaultConnector.sol";
import "../../src/vaults/CreditVaultSimple.sol";
import "../../src/operators/LightweightOrderOperator.sol";
import "../../src/utils/SimpleConditionsEnforcer.sol";
import "../utils/CVCPermitSignerECDSA.sol";

contract LightweightOrderOperatorTest is Test {
    ICVC cvc;
    MockERC20 asset;
    CreditVaultSimple vault;
    LightweightOrderOperator orderOperator;
    SimpleConditionsEnforcer conditionsEnforcer;
    CVCPermitSignerECDSA permitSigner;

    event OrderPending(LightweightOrderOperator.Order order);
    event OrderExecuted(bytes32 indexed orderHash, address indexed caller);
    event OrderCancelled(bytes32 indexed orderHash);

    function setUp() public {
        cvc = new CreditVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new CreditVaultSimple(cvc, asset, "Vault", "VAU");
        orderOperator = new LightweightOrderOperator(cvc);
        conditionsEnforcer = new SimpleConditionsEnforcer();
        permitSigner = new CVCPermitSignerECDSA(address(cvc));
    }

    function test_LightweightOrderOperator(uint alicePK) public {
        vm.assume(
            alicePK > 10 &&
                alicePK <
                115792089237316195423570985008687907852837564279074904382605163141518161494337
        );

        address alice = vm.addr(alicePK);
        address alicesSubAccount = address(uint160(alice) ^ 1);
        vm.assume(
            alice != address(0) &&
                alice != address(cvc) &&
                !cvc.haveCommonOwner(alice, address(orderOperator))
        );
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint).max);

        // alice authorizes the operator to act on behalf of her main account
        vm.prank(alice);
        cvc.setAccountOperator(alice, address(orderOperator), true);

        // alice submits an order so that anyone can deposit on her behalf to her sub-account,
        // but only after a specified timestamp in the future. for that, the order can be
        // divided into two parts: CVC operations and non-CVC operations.
        // we can use the non-CVC operations to check the conditions (as checking them
        // does not require any kind of authentication) and the CVC operations
        // for the actual deposit. moreover, we can specify a tip that will be
        // paid to the operator when the order is executed.
        LightweightOrderOperator.NonCVCBatchItem[]
            memory nonCVCItems = new LightweightOrderOperator.NonCVCBatchItem[](
                1
            );
        nonCVCItems[0] = LightweightOrderOperator.NonCVCBatchItem({
            targetContract: address(conditionsEnforcer),
            data: abi.encodeWithSelector(
                SimpleConditionsEnforcer.currentBlockTimestamp.selector,
                SimpleConditionsEnforcer.ComparisonType.GE,
                100
            )
        });

        ICVC.BatchItem[] memory CVCItems = new ICVC.BatchItem[](2);
        CVCItems[0] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                1e18,
                alicesSubAccount // deposit into alice's sub-account
            )
        });
        CVCItems[1] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                0.01e18,
                address(orderOperator) // deposit into the operator's account in order to payout the execution tip in the vault's shares
            )
        });

        LightweightOrderOperator.Order memory order = LightweightOrderOperator
            .Order({
                nonCVCOperations: nonCVCItems,
                CVCOperations: CVCItems,
                submissionTipToken: ERC20(address(0)), // no tip for submission
                executionTipToken: ERC20(address(vault)),
                salt: 0
            });

        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        cvc.call(
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.submit.selector,
                order
            )
        );

        // anyone can execute the order now as long as the condition is met
        ICVC.BatchItem[] memory items = new ICVC.BatchItem[](2);
        items[0] = ICVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.setTipReceiver.selector,
                address(this) // set the tip receiver to this contract
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.execute.selector,
                order
            )
        });

        vm.expectRevert(SimpleConditionsEnforcer.ConditionNotMet.selector);
        cvc.batch(items);

        // now it succeeds
        vm.warp(100);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        cvc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 98.99e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 1e18);
        assertEq(vault.maxWithdraw(address(this)), 0.01e18); // tip

        // it's neither possible to cancel the order now nor to submit/execute it again
        vm.prank(alice);
        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        cvc.call(
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.cancel.selector,
                order
            )
        );

        vm.prank(alice);
        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        cvc.call(
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.submit.selector,
                order
            )
        );

        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        cvc.batch(items);

        // alice submits an identical order but with a different salt value
        order.salt = 1;
        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        cvc.call(
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.submit.selector,
                order
            )
        );

        // and she cancels it right away
        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderCancelled(keccak256(abi.encode(order)));
        cvc.call(
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.cancel.selector,
                order
            )
        );

        // so that no one can execute it
        items[1].data = abi.encodeWithSelector(
            LightweightOrderOperator.execute.selector,
            order
        );

        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        cvc.batch(items);

        // alice signs a permit message so that anyone can submit the order on her behalf
        // and get tipped.
        // first update salt and the tip
        order.salt = 2;
        order.submissionTipToken = ERC20(address(vault));

        // then prepare the data for the permit
        items[0] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                0.01e18,
                address(orderOperator) // deposit into the operator's account in order to payout the submission tip in the vault's shares
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.submit.selector,
                order
            )
        });

        bytes memory data = abi.encodeWithSelector(ICVC.batch.selector, items);
        bytes memory signature = permitSigner.signPermit(
            alice,
            0,
            1,
            type(uint).max,
            data,
            alicePK
        );

        // having the signature, anyone can submit the order and get tipped
        items[0] = ICVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.setTipReceiver.selector,
                address(this) // set the tip receiver to this contract
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.permit.selector,
                alice,
                0,
                1,
                type(uint).max,
                data,
                signature
            )
        });

        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        cvc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 98.98e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 1e18);
        assertEq(vault.maxWithdraw(address(this)), 0.02e18); // tips accumulating!

        // then anyone can execute the order as long as the condition is met
        items[1] = ICVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.execute.selector,
                order
            )
        });

        vm.warp(99);
        vm.expectRevert(SimpleConditionsEnforcer.ConditionNotMet.selector);
        cvc.batch(items);

        // now it succeeds
        vm.warp(100);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        cvc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 97.97e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 2e18);
        assertEq(vault.maxWithdraw(address(this)), 0.03e18); // tips accumulating!

        // anyone can also execute the signed order directly if they have an appropriate signature
        order.salt = 3;
        order.submissionTipToken = ERC20(address(0));

        data = abi.encodeWithSelector(
            ICVC.call.selector,
            address(orderOperator),
            alice,
            abi.encodeWithSelector(
                LightweightOrderOperator.execute.selector,
                order
            )
        );
        signature = permitSigner.signPermit(
            alice,
            0,
            2,
            type(uint).max,
            data,
            alicePK
        );

        items[1] = ICVC.BatchItem({
            targetContract: address(cvc),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                ICVC.permit.selector,
                alice,
                0,
                2,
                type(uint).max,
                data,
                signature
            )
        });

        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        cvc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 96.96e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 3e18);
        assertEq(vault.maxWithdraw(address(this)), 0.04e18); // tips accumulating!
    }
}
