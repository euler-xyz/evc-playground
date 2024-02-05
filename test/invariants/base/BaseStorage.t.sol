// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {VaultSimple} from "src/vaults/VaultSimple.sol";
import {VaultSimpleBorrowable} from "src/vaults/VaultSimpleBorrowable.sol";
import {VaultRegularBorrowable} from "src/vaults/VaultRegularBorrowable.sol";
import {VaultBorrowableWETH} from "src/vaults/VaultBorrowableWETH.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
    uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

    uint256 internal constant diff_tolerance = 0.000000000002e18; //compared to 1e18
    uint256 internal constant MAX_PRICE_CHANGE_PERCENT = 1.05e18; //compared to 1e18

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //  VAULT CONTRACTS: HANDLERS' TARGETS

    /// @notice VaultSimple contract
    VaultSimple internal vaultSimple;

    /// @notice VaultSimpleBorrowable contract
    VaultSimpleBorrowable internal vaultSimpleBorrowable;

    /// @notice VaultRegularBorrowable contract
    VaultRegularBorrowable internal vaultRegularBorrowable;

    /// @notice VaultBorrowableETH contract
    VaultBorrowableWETH internal vaultBorrowableWETH;

    /// @notice Array of all vaults, sorted from most simple to most complex, for modular testing
    address[] internal vaults;
}
