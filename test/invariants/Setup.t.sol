// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";

// Contracts
import {VaultSimple} from "src/vaults/VaultSimple.sol";
import {VaultSimpleBorrowable} from "src/vaults/VaultSimpleBorrowable.sol";
import {VaultRegularBorrowable} from "src/vaults/VaultRegularBorrowable.sol";
import {VaultBorrowableWETH} from "src/vaults/VaultBorrowableWETH.sol";

// Test Contracts
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

        // Deploy mock tokens
        underlying = new MockERC20("Mock Token", "TKN", 18);
    }

    function _deployVaults() internal {
        // Deploy vaults
        /// @dev vaults are stored in the vaults array in the order of complexity,
        /// this helps with property inheritance and modularity
        vaultSimple = new VaultSimple(evc, underlying, "VaultSimple", "VS");
        vaults.push(address(vaultSimple));

        vaultSimpleBorrowable = new VaultSimpleBorrowable(evc, underlying, "VaultSimpleBorrowable", "VSB");
        vaults.push(address(vaultSimpleBorrowable));

        //vaultRegularBorrowable = new VaultRegularBorrowable(evc, underlying, "VaultRegularBorrowable", "VRB");
        //vaults.push(address(vaultRegularBorrowable));

        //vaultBorrowableWETH = new VaultBorrowableWETH(evc, underlying, "VaultBorrowableWETH", "VBW");
        //vaults.push(address(vaultBorrowableWETH));
    }

    function _setUpActors() internal {
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        address[] memory tokens = new address[](1);
        tokens[0] = address(underlying);

        for (uint256 i = 0; i < NUMBER_OF_ACTORS; i++) {
            // Deply actor proxies and
            address _actor = _setUpActor(addresses[i], tokens, vaults);
            underlying.mint(_actor, INITIAL_ETH_BALANCE);
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
