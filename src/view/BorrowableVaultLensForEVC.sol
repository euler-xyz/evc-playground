// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "evc/interfaces/IEthereumVaultConnector.sol";
import "../vaults/VaultRegularBorrowable.sol";
import "./Types.sol";

contract BorrowableVaultLensForEVC {
    IEVC public immutable evc;

    constructor(IEVC _evc) {
        evc = _evc;
    }

    function getEVCUserInfo(address account) external view returns (EVCUserInfo memory) {
        address owner;
        try evc.getAccountOwner(account) returns (address _owner) {
            owner = _owner;
        } catch {
            owner = account;
        }

        return EVCUserInfo({
            account: account,
            addressPrefix: evc.getAddressPrefix(account),
            owner: owner,
            enabledControllers: evc.getControllers(account),
            enabledCollaterals: evc.getCollaterals(account)
        });
    }

    function getVaultUserInfo(address account, address vault) external view returns (ERC4626UserInfo memory) {
        uint256 shares = ERC4626(vault).balanceOf(account);

        return ERC4626UserInfo({
            account: account,
            vault: vault,
            shares: shares,
            assets: ERC4626(vault).convertToAssets(shares),
            borrowed: VaultRegularBorrowable(vault).debtOf(account),
            isController: evc.isControllerEnabled(account, vault),
            isCollateral: evc.isCollateralEnabled(account, vault)
        });
    }

    function getVaultInfo(address vault) external view returns (ERC4626VaultInfo memory) {
        address asset = address(ERC4626(vault).asset());

        return ERC4626VaultInfo({
            vault: vault,
            vaultName: ERC20(vault).name(),
            vaultSymbol: ERC20(vault).symbol(),
            vaultDecimals: ERC20(vault).decimals(),
            asset: asset,
            assetName: ERC20(asset).name(),
            assetSymbol: ERC20(asset).symbol(),
            assetDecimals: ERC20(asset).decimals(),
            totalShares: ERC20(vault).totalSupply(),
            totalAssets: ERC4626(vault).totalAssets(),
            totalBorrowed: VaultRegularBorrowable(vault).totalBorrowed(),
            interestRate: VaultRegularBorrowable(vault).getInterestRate(),
            irm: address(VaultRegularBorrowable(vault).irm()),
            oracle: address(VaultRegularBorrowable(vault).oracle())
        });
    }
}
