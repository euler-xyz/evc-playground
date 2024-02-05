// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Pretty, Strings} from "../utils/Pretty.sol";

import {BaseTest} from "../base/BaseTest.t.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseTest {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct FtVars {
        uint256 balanceBefore;
        uint256 balanceAfter;
    }

    FtVars ftVars;

    function _beforeFT() internal {
    }

    function _afterFT() internal {
    }
}
