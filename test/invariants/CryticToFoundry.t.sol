// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title CryticToFoundry
/// @notice Foundry wrapper for fuzzer failed call sequences
/// @dev Regression testing for failed call sequences
contract CryticToFoundry is Invariants, Setup {
    modifier setup() override {
        _;
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() public {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        actor = actors[USER1];
    }

    function test_hooks() public {
        assert_VaultBase_invariantA(vaults[0]);
    }

    function test_VaultSimpleBorrowable_invariantA() public {
        this.transferFrom(
            512000000,
            98486275380736287597876803469925129194975432820152697795013895226765300128,
            0x0000000000000000000000000000000000000041,
            115792089237316195423546560861005357749589898509895355986843660353153328480272
        );
        assert(echidna_invariant_VaultSimpleBorrowable_invariantA());
    }

    function test_setCollateralFactor() public {
        this.setCollateralFactor(2, 100);
    }
}
