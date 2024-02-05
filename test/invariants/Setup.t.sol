// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from "./utils/Actor.sol";
import {BaseTest} from "./base/BaseTest.t.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deploy protocol contracts and protocol actors
    }

    function _setUpActor(
        address userAddress,
        address[] memory tokens,
        address[] memory callers
    ) internal returns (address actorAddress) {
        bool success;
        Actor _actor = new Actor(tokens, callers);
        actors[userAddress] = _actor;
        (success, ) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }
}