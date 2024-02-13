// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";

// Contracts
import {
    VaultSimpleExtended as VaultSimple,
    VaultSimpleBorrowableExtended as VaultSimpleBorrowable,
    VaultRegularBorrowableExtended as VaultRegularBorrowable,
    VaultBorrowableWETHExtended as VaultBorrowableWETH
} from "test/invariants/helpers/extended/VaultsExtended.sol";

// Test Contracts
import {IRMMock} from "../mocks/IRMMock.sol";
import {PriceOracleMock} from "../mocks/PriceOracleMock.sol";
import {Actor} from "./utils/Actor.sol";
import {BaseTest} from "./base/BaseTest.t.sol";

/// @title Setup
/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deplopy EVC and needed contracts
        _deployProtocolCore();

        // Deploy vaults
        _deployVaults();
    }

    function _deployProtocolCore() internal {
        // Deploy the EVC
        evc = new EthereumVaultConnector();

        // Deploy the reference assets
        referenceAsset = new MockERC20("Reference Asset", "RA", 18);
        referenceAssets.push(address(referenceAsset));

        // Deploy base assets
        liabilityAsset = new MockERC20("Liability Asset", "LA", 18);//TODO: add two liabilityes
        collateralAsset1 = new MockERC20("Collateral Asset 1", "CA1", 18);
        collateralAsset2 = new MockERC20("Collateral Asset 2", "CA2", 6);
        baseAssets.push(address(liabilityAsset));
        baseAssets.push(address(collateralAsset1));
        baseAssets.push(address(collateralAsset2));

        // Deploy the IRM and the Price Oracle
        irm = new IRMMock();
        oracle = new PriceOracleMock();
    }

    function _deployVaults() internal {
        // Deploy vaults
        /// @dev vaults are stored in the vaults array in the order of complexity,
        /// this helps with property inheritance and modularity
        vaultSimple = new VaultSimple(evc, collateralAsset1, "VaultSimple", "VS");
        vaults.push(address(vaultSimple));
        vaultNames[address(vaultSimple)] = "VaultSimple";

        vaultSimpleBorrowable = new VaultSimpleBorrowable(evc, collateralAsset2, "VaultSimpleBorrowable", "VSB");
        vaults.push(address(vaultSimpleBorrowable));
        vaultNames[address(vaultSimpleBorrowable)] = "VaultSimpleBorrowable";

        vaultRegularBorrowable = new VaultRegularBorrowable(
            evc, liabilityAsset, irm, oracle, referenceAsset, "VaultRegularBorrowable", "VRB"
        );
        vaults.push(address(vaultRegularBorrowable));
        vaultNames[address(vaultRegularBorrowable)] = "VaultRegularBorrowable";

        //vaultBorrowableWETH = new VaultBorrowableWETH(evc, underlying, "VaultBorrowableWETH", "VBW");
        //vaults.push(address(vaultBorrowableWETH));
    }

    function _setUpActors() internal {
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        address[] memory tokens = new address[](3);
        tokens[0] = address(liabilityAsset);
        tokens[1] = address(collateralAsset1);
        tokens[2] = address(collateralAsset2);

        for (uint256 i = 0; i < NUMBER_OF_ACTORS; i++) {
            // Deply actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, vaults);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                MockERC20 _token = MockERC20(tokens[j]);
                _token.mint(_actor, INITIAL_BALANCE);
            }
            actorAddresses.push(_actor);
        }
    }

    function _setUpActor(
        address userAddress,
        address[] memory tokens,
        address[] memory callers
    ) internal returns (address actorAddress) {
        bool success;
        Actor _actor = new Actor(tokens, callers);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }
}
