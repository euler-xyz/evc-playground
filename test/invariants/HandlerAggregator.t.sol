// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Handler Contracts
import {VaultSimpleHandler} from "./handlers/VaultSimpleHandler.t.sol";
import {VaultSimpleBorrowableHandler} from "./handlers/VaultSimpleBorrowableHandler.t.sol";
import {VaultRegularBorrowableHandler} from "./handlers/VaultRegularBorrowableHandler.t.sol";
import {VaultBorrowableETHHandler} from "./handlers/VaultBorrowableETHHandler.t.sol";
import {EVCHandler} from "./handlers/EVCHandler.t.sol";
import {ERC20Handler} from "./handlers/ERC20Handler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    VaultSimpleHandler,
    VaultSimpleBorrowableHandler,
    VaultRegularBorrowableHandler,
    VaultBorrowableETHHandler,
    EVCHandler,
    ERC20Handler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {}
}
