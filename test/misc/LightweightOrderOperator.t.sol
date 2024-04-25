// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "evc/EthereumVaultConnector.sol";
import "../../src/vaults/solmate/VaultSimple.sol";
import "../../src/operators/LightweightOrderOperator.sol";
import "../../src/utils/SimpleConditionsEnforcer.sol";
import "../utils/EVCPermitSignerECDSA.sol";

contract LightweightOrderOperatorTest is Test {
    IEVC evc;
    MockERC20 asset;
    VaultSimple vault;
    LightweightOrderOperator orderOperator;
    SimpleConditionsEnforcer conditionsEnforcer;
    EVCPermitSignerECDSA permitSigner;

    event OrderPending(LightweightOrderOperator.Order order);
    event OrderExecuted(bytes32 indexed orderHash, address indexed caller);
    event OrderCancelled(bytes32 indexed orderHash);

    function setUp() public {
        evc = new EthereumVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new VaultSimple(address(evc), asset, "Vault", "VAU");
        orderOperator = new LightweightOrderOperator(evc);
        conditionsEnforcer = new SimpleConditionsEnforcer();
        permitSigner = new EVCPermitSignerECDSA(address(evc));
    }

    function test_LightweightOrderOperator(uint256 alicePK) public {
        vm.assume(
            alicePK > 10 && alicePK < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );

        address alice = vm.addr(alicePK);
        address alicesSubAccount = address(uint160(alice) ^ 1);
        vm.assume(alice != address(0) && alice != address(evc) && !evc.haveCommonOwner(alice, address(orderOperator)));
        permitSigner.setPrivateKey(alicePK);
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        // alice authorizes the operator to act on behalf of her main account
        vm.prank(alice);
        evc.setAccountOperator(alice, address(orderOperator), true);

        // alice submits an order so that anyone can deposit on her behalf to her sub-account,
        // but only after a specified timestamp in the future. for that, the order can be
        // divided into two parts: evc operations and non-evc operations.
        // we can use the non-evc operations to check the conditions (as checking them
        // does not require any kind of authentication) and the evc operations
        // for the actual deposit. moreover, we can specify a tip that will be
        // paid to the operator when the order is executed.
        LightweightOrderOperator.NonEVCBatchItem[] memory nonEVCItems =
            new LightweightOrderOperator.NonEVCBatchItem[](1);
        nonEVCItems[0] = LightweightOrderOperator.NonEVCBatchItem({
            targetContract: address(conditionsEnforcer),
            data: abi.encodeWithSelector(
                SimpleConditionsEnforcer.currentBlockTimestamp.selector, SimpleConditionsEnforcer.ComparisonType.GE, 100
                )
        });

        IEVC.BatchItem[] memory evcItems = new IEVC.BatchItem[](2);
        evcItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                VaultSimple.deposit.selector,
                1e18,
                alicesSubAccount // deposit into alice's sub-account
            )
        });
        evcItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                VaultSimple.deposit.selector,
                0.01e18,
                address(orderOperator) // deposit into the operator's account in order to payout the execution tip in the
                    // vault's shares
            )
        });

        LightweightOrderOperator.Order memory order = LightweightOrderOperator.Order({
            nonEVCOperations: nonEVCItems,
            EVCOperations: evcItems,
            submissionTipToken: ERC20(address(0)), // no tip for submission
            executionTipToken: ERC20(address(vault)),
            salt: 0
        });

        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        evc.call(
            address(orderOperator), alice, 0, abi.encodeWithSelector(LightweightOrderOperator.submit.selector, order)
        );

        // anyone can execute the order now as long as the condition is met
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.setTipReceiver.selector,
                address(this) // set the tip receiver to this contract
            )
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(LightweightOrderOperator.execute.selector, order)
        });

        vm.expectRevert(SimpleConditionsEnforcer.ConditionNotMet.selector);
        evc.batch(items);

        // now it succeeds
        vm.warp(100);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        evc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 98.99e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 1e18);
        assertEq(vault.maxWithdraw(address(this)), 0.01e18); // tip

        // it's neither possible to cancel the order now nor to submit/execute it again
        vm.prank(alice);
        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        evc.call(
            address(orderOperator), alice, 0, abi.encodeWithSelector(LightweightOrderOperator.cancel.selector, order)
        );

        vm.prank(alice);
        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        evc.call(
            address(orderOperator), alice, 0, abi.encodeWithSelector(LightweightOrderOperator.submit.selector, order)
        );

        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        evc.batch(items);

        // alice submits an identical order but with a different salt value
        order.salt = 1;
        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        evc.call(
            address(orderOperator), alice, 0, abi.encodeWithSelector(LightweightOrderOperator.submit.selector, order)
        );

        // and she cancels it right away
        vm.prank(alice);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderCancelled(keccak256(abi.encode(order)));
        evc.call(
            address(orderOperator), alice, 0, abi.encodeWithSelector(LightweightOrderOperator.cancel.selector, order)
        );

        // so that no one can execute it
        items[1].data = abi.encodeWithSelector(LightweightOrderOperator.execute.selector, order);

        vm.expectRevert(LightweightOrderOperator.InvalidOrderState.selector);
        evc.batch(items);

        // alice signs a permit message so that anyone can submit the order on her behalf
        // and get tipped.
        // first update salt and the tip
        order.salt = 2;
        order.submissionTipToken = ERC20(address(vault));

        // then prepare the data for the permit
        items[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                VaultSimple.deposit.selector,
                0.01e18,
                address(orderOperator) // deposit into the operator's account in order to payout the submission tip in the
                    // vault's shares
            )
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(LightweightOrderOperator.submit.selector, order)
        });

        bytes memory data = abi.encodeWithSelector(IEVC.batch.selector, items);
        bytes memory signature = permitSigner.signPermit(alice, address(0), 0, 0, type(uint256).max, 0, data);

        // having the signature, anyone can submit the order and get tipped
        items[0] = IEVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                LightweightOrderOperator.setTipReceiver.selector,
                address(this) // set the tip receiver to this contract
            )
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeWithSelector(
                IEVC.permit.selector, alice, address(0), 0, 0, type(uint256).max, 0, data, signature
                )
        });

        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderPending(order);
        evc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 98.98e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 1e18);
        assertEq(vault.maxWithdraw(address(this)), 0.02e18); // tips accumulating!

        // then anyone can execute the order as long as the condition is met
        items[1] = IEVC.BatchItem({
            targetContract: address(orderOperator),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(LightweightOrderOperator.execute.selector, order)
        });

        vm.warp(99);
        vm.expectRevert(SimpleConditionsEnforcer.ConditionNotMet.selector);
        evc.batch(items);

        // now it succeeds
        vm.warp(100);
        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        evc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 97.97e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 2e18);
        assertEq(vault.maxWithdraw(address(this)), 0.03e18); // tips accumulating!

        // anyone can also execute the signed order directly if they have an appropriate signature
        order.salt = 3;
        order.submissionTipToken = ERC20(address(0));

        data = abi.encodeWithSelector(
            IEVC.call.selector,
            address(orderOperator),
            alice,
            0,
            abi.encodeWithSelector(LightweightOrderOperator.execute.selector, order)
        );
        signature = permitSigner.signPermit(alice, address(0), 0, 1, type(uint256).max, 0, data);

        items[1] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeWithSelector(
                IEVC.permit.selector, alice, address(0), 0, 1, type(uint256).max, 0, data, signature
                )
        });

        vm.expectEmit(false, false, false, true, address(orderOperator));
        emit OrderExecuted(keccak256(abi.encode(order)), address(this));
        evc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 96.96e18);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 3e18);
        assertEq(vault.maxWithdraw(address(this)), 0.04e18); // tips accumulating!
    }
}
