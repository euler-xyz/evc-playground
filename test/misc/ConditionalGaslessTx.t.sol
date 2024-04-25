// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "evc/interfaces/IEthereumVaultConnector.sol";
import "../../src/vaults/solmate/VaultSimple.sol";
import "../../src/utils/SimpleConditionsEnforcer.sol";
import "../utils/EVCPermitSignerECDSA.sol";

contract ConditionalGaslessTxTest is Test {
    IEVC evc;
    MockERC20 asset;
    VaultSimple vault;
    SimpleConditionsEnforcer conditionsEnforcer;
    EVCPermitSignerECDSA permitSigner;

    function setUp() public {
        evc = new EthereumVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new VaultSimple(address(evc), asset, "Vault", "VAU");
        conditionsEnforcer = new SimpleConditionsEnforcer();
        permitSigner = new EVCPermitSignerECDSA(address(evc));
    }

    function test_ConditionalGaslessTx() public {
        uint256 alicePrivateKey = 0x12345;
        address alice = vm.addr(alicePrivateKey);
        permitSigner.setPrivateKey(alicePrivateKey);
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        // alice deposits into her sub-account 1
        address alicesSubAccount = address(uint160(alice) ^ 1);
        vm.prank(alice);
        vault.deposit(100e18, alicesSubAccount);

        // alice signs the calldata that allows anyone to withdraw her sub-account deposit
        // after specified timestamp in the future. The same concept can be used for implementing
        // conditional orders (e.g. stop-loss, take-profit etc.).
        // the signed calldata can be executed by anyone using the permit() function on the evc
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(conditionsEnforcer),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                SimpleConditionsEnforcer.currentBlockTimestamp.selector, SimpleConditionsEnforcer.ComparisonType.GE, 100
                )
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alicesSubAccount,
            value: 0,
            data: abi.encodeWithSelector(VaultSimple.withdraw.selector, 100e18, alice, alicesSubAccount)
        });

        bytes memory data = abi.encodeWithSelector(IEVC.batch.selector, items);
        bytes memory signature = permitSigner.signPermit(alice, address(0), 0, 0, type(uint256).max, 0, data);

        assertEq(asset.balanceOf(address(alice)), 0);
        assertEq(vault.maxWithdraw(alicesSubAccount), 100e18);

        // having the signature, anyone can execute the calldata on behalf of alice, but only after
        // the specified timestamp in the future.
        // -- evc.permit()
        // ---- evc.batch()
        // -------- conditionsEnforcer.currentBlockTimestamp() using evc.callInternal() to check the condition
        // -------- vault.withdraw() using evc.callInternal() to withdraw the funds
        vm.expectRevert(abi.encodeWithSelector(SimpleConditionsEnforcer.ConditionNotMet.selector));
        evc.permit(alice, address(0), 0, 0, type(uint256).max, 0, data, signature);

        // succeeds if enough time elapses
        vm.warp(100);
        evc.permit(alice, address(0), 0, 0, type(uint256).max, 0, data, signature);

        assertEq(asset.balanceOf(address(alice)), 100e18);
        assertEq(vault.maxWithdraw(alicesSubAccount), 0);
    }
}
