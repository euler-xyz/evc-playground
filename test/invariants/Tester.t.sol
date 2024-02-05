// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title Tester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract Tester is Invariants, Setup {
    constructor() payable {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Initialize handler contracts
        _setUpHandlers();
    }

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}
}
