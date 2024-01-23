// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

struct EVCUserInfo {
    address account;
    uint152 addressPrefix;
    address owner;
    address[] enabledControllers;
    address[] enabledCollaterals;
}

struct ERC4626UserInfo {
    address account;
    address vault;
    uint256 shares;
    uint256 assets;
    uint256 borrowed;
    bool isController;
    bool isCollateral;
}

struct ERC4626VaultInfo {
    address vault;
    string vaultName;
    string vaultSymbol;
    uint8 vaultDecimals;
    address asset;
    string assetName;
    string assetSymbol;
    uint8 assetDecimals;
    uint256 totalShares;
    uint256 totalAssets;
    uint256 totalBorrowed;
    uint256 interestRateSPY;
    uint256 interestRateAPY;
    address irm;
    address oracle;
}
