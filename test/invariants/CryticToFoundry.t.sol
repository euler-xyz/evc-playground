// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";

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

    function setUp() public {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Initialize handler contracts
        _setUpHandlers();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];
    }

    /*

    E.g. of an foundry test that replays a failed invariant call sequence    

    function test_invariant_Area1_A() public {
        this.deposit(1);
        echidna_basicInvariants_pool_B_F_G_2();
    } 
    */
}
