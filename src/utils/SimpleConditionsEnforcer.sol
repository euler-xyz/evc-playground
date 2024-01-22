// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

/// @title SimpleConditionsEnforcer
/// @dev This contract is used to enforce conditions based on block timestamp and block number.
contract SimpleConditionsEnforcer {
    /// @dev Enumeration for comparison types.
    enum ComparisonType {
        EQ, // Equal to
        GT, // Greater than
        LT, // Less than
        GE, // Greater than or equal to
        LE // Less than or equal to

    }

    /// @dev Error to be thrown when a condition is not met.
    error ConditionNotMet();

    /// @dev Compares the current block timestamp with a given timestamp.
    /// @param ct The type of comparison to be made.
    /// @param timestamp The timestamp to compare with.
    function currentBlockTimestamp(ComparisonType ct, uint256 timestamp) external view {
        compare(block.timestamp, ct, timestamp);
    }

    /// @dev Compares the current block number with a given number.
    /// @param ct The type of comparison to be made.
    /// @param number The number to compare with.
    function currentBlockNumber(ComparisonType ct, uint256 number) external view {
        compare(block.number, ct, number);
    }

    /// @dev Compares two uint values based on the comparison type.
    /// @param value1 The first value to compare.
    /// @param ct The type of comparison to be made.
    /// @param value2 The second value to compare.
    function compare(uint256 value1, ComparisonType ct, uint256 value2) internal pure {
        if (ct == ComparisonType.EQ) {
            if (value1 != value2) revert ConditionNotMet();
        } else if (ct == ComparisonType.GT) {
            if (value1 <= value2) revert ConditionNotMet();
        } else if (ct == ComparisonType.LT) {
            if (value1 >= value2) revert ConditionNotMet();
        } else if (ct == ComparisonType.GE) {
            if (value1 < value2) revert ConditionNotMet();
        } else if (ct == ComparisonType.LE) {
            if (value1 > value2) revert ConditionNotMet();
        }
    }
}
