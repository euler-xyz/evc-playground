// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "evc/interfaces/IEthereumVaultConnector.sol";
import "../../src/vaults/solmate/VaultSimple.sol";
import "../../src/utils/TipsPiggyBank.sol";
import "../utils/EVCPermitSignerECDSA.sol";

contract GaslessTxTest is Test {
    IEVC evc;
    MockERC20 asset;
    VaultSimple vault;
    TipsPiggyBank piggyBank;
    EVCPermitSignerECDSA permitSigner;

    function setUp() public {
        evc = new EthereumVaultConnector();
        asset = new MockERC20("Asset", "ASS", 18);
        vault = new VaultSimple(address(evc), asset, "Vault", "VAU");
        piggyBank = new TipsPiggyBank();
        permitSigner = new EVCPermitSignerECDSA(address(evc));
    }

    function test_GaslessTx() public {
        uint256 alicePrivateKey = 0x12345;
        address alice = vm.addr(alicePrivateKey);
        permitSigner.setPrivateKey(alicePrivateKey);
        asset.mint(alice, 100e18);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        // alice signs the calldata to deposit assets to the vault on her behalf.
        // the signed calldata can be executed by anyone using the permit() function on the evc.
        // additionally, she transfers 1% of the deposited amount to the tips piggy bank contract
        // that can be withdrawn by the relayer as a tip for sending the transaction
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(VaultSimple.deposit.selector, 100e18, alice)
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: alice,
            value: 0,
            data: abi.encodeWithSelector(ERC20.transfer.selector, address(piggyBank), 1e18)
        });

        bytes memory data = abi.encodeWithSelector(IEVC.batch.selector, items);
        bytes memory signature = permitSigner.signPermit(alice, address(0), 0, 0, type(uint256).max, 0, data);

        // having the signature, anyone can execute the calldata on behalf of alice and get tipped
        items[0] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeWithSelector(
                IEVC.permit.selector, alice, address(0), 0, 0, type(uint256).max, 0, data, signature
                )
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(piggyBank),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeWithSelector(TipsPiggyBank.withdraw.selector, address(vault), address(this))
        });

        // -- evc.batch()
        // ---- evc.permit()
        // -------- evc.batch()
        // ---------------- vault.deposit() using evc.callInternal()
        // ---------------- vault.transfer() using evc.callInternal() to transfer the tip in form of the vault shares to
        // the piggy bank
        // ---- piggyBank.withdraw() to withdraw the tip to the relayer
        evc.batch(items);

        assertEq(asset.balanceOf(address(alice)), 0);
        assertEq(vault.maxWithdraw(alice), 99e18);
        assertEq(vault.maxWithdraw(address(this)), 1e18);

        // if we knew the relayer address when signing the calldata, we could have tipped the relayer without needing
        // the piggy bank contract.
        // in such situation, the shares transfer could be just a regular batch item and the relayer address could be
        // embedded
        // in the calldata directly
    }
}
