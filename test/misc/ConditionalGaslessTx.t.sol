// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";
import "../../src/vaults/CreditVaultSimple.sol";
import "../../src/utils/SimpleConditionsEnforcer.sol";
import "../utils/CVCPermitSignerECDSA.sol";

contract ConditionalGaslessTxTest is Test {
    ICVC cvc;
    MockERC20 asset;
    CreditVaultSimple vault;
    SimpleConditionsEnforcer conditionsEnforcer;
    CVCPermitSignerECDSA permitSigner;

    function setUp() public {
        cvc = new CreditVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new CreditVaultSimple(cvc, asset, "Vault", "VAU");
        conditionsEnforcer = new SimpleConditionsEnforcer();
        permitSigner = new CVCPermitSignerECDSA(address(cvc));
    }

    function test_ConditionalGaslessTx() public {
        uint alicePrivateKey = 0x12345;
        address alice = vm.addr(alicePrivateKey);
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint).max);

        // alice deposits into her sub-account 1
        address alicesSubAccount = address(uint160(alice) ^ 1);
        vm.prank(alice);
        vault.deposit(100e18, alicesSubAccount);

        // alice signs the calldata that allows anyone to withdraw her sub-account deposit
        // after specified timestamp in the future. The same concept can be used for implementing
        // conditional orders (e.g. stop-loss, take-profit etc.).
        // the signed calldata can be executed by anyone using the permit() function on the CVC
        ICVC.BatchItem[] memory items = new ICVC.BatchItem[](2);
        items[0] = ICVC.BatchItem({
            targetContract: address(conditionsEnforcer),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                SimpleConditionsEnforcer.currentBlockTimestamp.selector,
                SimpleConditionsEnforcer.ComparisonType.GE,
                100
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alicesSubAccount,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.withdraw.selector,
                100e18,
                alice,
                alicesSubAccount
            )
        });

        bytes memory data = abi.encodeWithSelector(ICVC.batch.selector, items);
        bytes memory signature = permitSigner.signPermit(
            alice,
            0,
            1,
            type(uint).max,
            data,
            alicePrivateKey
        );

        assertEq(asset.balanceOf(address(alice)), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 100e18);

        // having the signature, anyone can execute the calldata on behalf of alice, but only after
        // the specified timestamp in the future.
        // -- cvc.permit()
        // ---- cvc.batch()
        // -------- conditionsEnforcer.currentBlockTimestamp() using cvc.callInternal() to check the condition
        // -------- vault.withdraw() using cvc.callInternal() to withdraw the funds
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleConditionsEnforcer.ConditionNotMet.selector
            )
        );
        cvc.permit(alice, 0, 1, type(uint).max, data, signature);

        // succeeds if enough time elapses
        vm.warp(100);
        cvc.permit(alice, 0, 1, type(uint).max, data, signature);

        assertEq(asset.balanceOf(address(alice)), 100e18);
        assertEq(vault.maxWithdraw(alicesSubAccount), 0);
    }
}
