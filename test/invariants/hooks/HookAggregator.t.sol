// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {VaultSimpleBeforeAfterHooks} from "./VaultSimpleBeforeAfterHooks.t.sol";
import {VaultSimpleBorrowableBeforeAfterHooks} from "./VaultSimpleBorrowableBeforeAfterHooks.t.sol";
import {VaultRegularBorrowableBeforeAfterHooks} from "./VaultRegularBorrowableBeforeAfterHooks.t.sol";

/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is
    VaultSimpleBeforeAfterHooks,
    VaultSimpleBorrowableBeforeAfterHooks,
    VaultRegularBorrowableBeforeAfterHooks
{
    /// @notice Modular hook selector, per vault type
    function _before(address _vault, VaultType _type) internal {
        if (_type >= VaultType.Simple) {
            _svBefore(_vault);
        }
        if (_type >= VaultType.SimpleBorrowable) {
            _svbBefore(_vault);
        }
        if (_type == VaultType.RegularBorrowable) {
            _rvbBefore(_vault);
        }
    }

    /// @notice Modular hook selector, per vault type
    function _after(address _vault, VaultType _type) internal {
        if (_type >= VaultType.Simple) {
            _svAfter(_vault);
        }
        if (_type >= VaultType.SimpleBorrowable) {
            _svbAfter(_vault);
        }
        if (_type == VaultType.RegularBorrowable) {
            _rvbAfter(_vault);
        }
    }
}
