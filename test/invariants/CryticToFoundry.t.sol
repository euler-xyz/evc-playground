// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";


/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
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
