// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import Handler contracts,
import {DefaultHandler} from "./handlers/DefaultHandler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is DefaultHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {
    }
}
