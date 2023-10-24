// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";
import "../../src/vaults/CreditVaultSimple.sol";
import "../../src/utils/TipsPiggyBank.sol";
import "../utils/CVCPermitSignerECDSA.sol";

contract GaslessTxTest is Test {
    ICVC cvc;
    MockERC20 asset;
    CreditVaultSimple vault;
    TipsPiggyBank piggyBank;
    CVCPermitSignerECDSA permitSigner;

    function setUp() public {
        cvc = new CreditVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new CreditVaultSimple(cvc, asset, "Vault", "VAU");
        piggyBank = new TipsPiggyBank();
        permitSigner = new CVCPermitSignerECDSA(address(cvc));
    }

    function test_GaslessTx() public {
        uint alicePrivateKey = 0x12345;
        address alice = vm.addr(alicePrivateKey);
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint).max);

        // alice signs the calldata to deposit assets to the vault on her behalf.
        // the signed calldata can be executed by anyone using the permit() function on the CVC.
        // additionally, she transfers 1% of the deposited amount to the tips piggy bank contract
        // that can be withdrawn by the relayer as a tip for sending the transaction
        ICVC.BatchItem[] memory items = new ICVC.BatchItem[](2);
        items[0] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                CreditVaultSimple.deposit.selector,
                100e18,
                alice
            )
        });
        items[1] = ICVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(
                ERC20.transfer.selector,
                address(piggyBank),
                1e18
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

        // having the signature, anyone can execute the calldata on behalf of alice and get tipped
        items[0] = ICVC.BatchItem({
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
        items[1] = ICVC.BatchItem({
            targetContract: address(piggyBank),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(
                TipsPiggyBank.withdraw.selector,
                address(vault),
                address(this)
            )
        });

        // -- cvc.batch()
        // ---- cvc.permit()
        // -------- cvc.batch()
        // ---------------- vault.deposit() using cvc.callInternal()
        // ---------------- vault.transfer() using cvc.callInternal() to transfer the tip in form of the vault shares to the piggy bank
        // ---- piggyBank.withdraw() to withdraw the tip to the relayer
        cvc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 0);
        assertEq(vault.maxWithdraw(alice), 99e18);
        assertEq(vault.maxWithdraw(address(this)), 1e18);

        // if we knew the relayer address when signing the calldata, we could have tipped the relayer without needing the piggy bank contract.
        // in such situation, the shares transfer could be just a regular batch item and the relayer address could be embedded
        // in the calldata directly
    }
}
