// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {ProtocolAssertions} from "../base/ProtocolAssertions.t.sol";
// Test Contracts
import {BaseTest} from "../base/BaseTest.t.sol";

/// @title BaseHooks
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per-action assertions are implemented in the handlers
contract BaseHooks is ProtocolAssertions {}
