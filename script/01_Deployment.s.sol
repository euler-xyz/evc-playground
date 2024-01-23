// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "evc/EthereumVaultConnector.sol";
import "../src/vaults/VaultRegularBorrowable.sol";
import "../src/view/BorrowableVaultLensForEVC.sol";
import "../test/mocks/IRMMock.sol";
import "../test/mocks/PriceOracleMock.sol";

/// @title Deployment script
/// @notice This script is used for deploying the EVC and a couple vaults for testing purposes
contract Deployment is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC"), 0);
        vm.startBroadcast(deployerPrivateKey);

        // deploy the EVC
        IEVC evc = new EthereumVaultConnector();

        // deploy mock ERC-20 tokens
        MockERC20 asset1 = new MockERC20("Asset 1", "A1", 18);
        MockERC20 asset2 = new MockERC20("Asset 2", "A2", 18);
        MockERC20 asset3 = new MockERC20("Asset 3", "A3", 6);

        // mint some tokens to the deployer
        address deployer = vm.addr(deployerPrivateKey);
        asset1.mint(deployer, 1e6 * 1e18);
        asset2.mint(deployer, 1e6 * 1e18);
        asset3.mint(deployer, 1e6 * 1e6);

        // deply mock IRM
        IRMMock irm = new IRMMock();

        // setup the IRM
        irm.setInterestRate(10); // 10% APY

        // deploy mock price oracle
        PriceOracleMock oracle = new PriceOracleMock();

        // setup the price oracle
        oracle.setQuote(address(asset1), address(asset1), 1e18); // 1 A1 = 1 A1
        oracle.setQuote(address(asset2), address(asset1), 1e16); // 1 A2 = 0.01 A1
        oracle.setQuote(address(asset3), address(asset1), 1e18); // 1 A3 = 1 A1

        // deploy vaults
        VaultRegularBorrowable vault1 =
            new VaultRegularBorrowable(evc, asset1, irm, oracle, asset1, "Vault Asset 1", "VA1");

        VaultRegularBorrowable vault2 =
            new VaultRegularBorrowable(evc, asset2, irm, oracle, asset1, "Vault Asset 2", "VA2");

        VaultRegularBorrowable vault3 =
            new VaultRegularBorrowable(evc, asset3, irm, oracle, asset1, "Vault Asset 3", "VA3");

        // setup the vaults
        vault1.setCollateralFactor(vault1, 95); // cf = 0.95, self-collateralization

        vault2.setCollateralFactor(vault2, 95); // cf = 0.95, self-collateralization
        vault2.setCollateralFactor(vault1, 50); // cf = 0.50

        vault3.setCollateralFactor(vault3, 95); // cf = 0.95, self-collateralization
        vault3.setCollateralFactor(vault1, 50); // cf = 0.50
        vault3.setCollateralFactor(vault2, 80); // cf = 0.8

        // deploy the lens
        BorrowableVaultLensForEVC lens = new BorrowableVaultLensForEVC(evc);

        vm.stopBroadcast();

        // display the addresses
        console.log("Deployer", deployer);
        console.log("EVC", address(evc));
        console.log("IRM", address(irm));
        console.log("Price Oracle", address(oracle));
        console.log("Asset 1", address(asset1));
        console.log("Asset 2", address(asset2));
        console.log("Asset 3", address(asset3));
        console.log("Vault Asset 1", address(vault1));
        console.log("Vault Asset 2", address(vault2));
        console.log("Vault Asset 3", address(vault3));
        console.log("Lens", address(lens));
    }
}
