// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

// Contracts
import {VaultSimple} from "src/vaults/solmate/VaultSimple.sol";
import {VaultSimpleBorrowable} from "src/vaults/solmate/VaultSimpleBorrowable.sol";
import {VaultRegularBorrowable} from "src/vaults/solmate/VaultRegularBorrowable.sol";
import {VaultBorrowableWETH} from "src/vaults/solmate/VaultBorrowableWETH.sol";
import {VaultSimple as VaultSimpleOZ} from "src/vaults/open-zeppelin/VaultSimple.sol";
import {VaultRegularBorrowable as VaultRegularBorrowableOZ} from "src/vaults/open-zeppelin/VaultRegularBorrowable.sol";

// Mocks
import {IRMMock} from "test/mocks/IRMMock.sol";
import {PriceOracleMock} from "test/mocks/PriceOracleMock.sol";

// Interfaces
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";

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

    //  VAULT CONTRACTS

    /// @notice VaultSimple contract
    VaultSimple internal vaultSimple;

    /// @notice VaultSimple contract
    VaultSimpleOZ internal vaultSimpleOZ;

    /// @notice VaultSimpleBorrowable contract
    VaultSimpleBorrowable internal vaultSimpleBorrowable;

    /// @notice VaultRegularBorrowable contract
    VaultRegularBorrowable internal vaultRegularBorrowable;

    /// @notice VaultRegularBorrowable contract
    VaultRegularBorrowableOZ internal vaultRegularBorrowableOZ;

    /// @notice VaultBorrowableETH contract
    VaultBorrowableWETH internal vaultBorrowableWETH;

    /// @notice Enum for vault types, used to limit accesses to vaults array by complexity
    enum VaultType {
        Simple,
        SimpleOz,
        SimpleBorrowable,
        RegularBorrowable,
        RegularBorrowableOz,
        BorrowableWETH
    }

    /// @notice Array of all vaults, sorted from most simple to most complex, for modular testing
    address[] internal vaults;

    /// @notice refencer to the vault in order to ease debugging broken invariants
    mapping(address => string) internal vaultNames;

    /// @notice Used in handlers, sets the upper limit index af the vaults array that the property will be tested
    /// against
    uint256 internal limitVault;

    // EVC

    /// @notice EVC contract
    IEVC internal evc;

    // TOKENS

    /// @notice MockERC20 contract
    MockERC20 internal referenceAsset;
    /// @notice Array of all reference assets
    address[] internal referenceAssets;

    /// @notice MockERC20 contract
    MockERC20 internal liabilityAsset;
    /// @notice MockERC20 contract
    MockERC20 internal collateralAsset1;
    /// @notice MockERC20 contract
    MockERC20 internal collateralAsset2;
    /// @notice Array of all base assets
    address[] internal baseAssets;

    // IRM AND ORACLE

    /// @notice Interest rates manager mock contract
    IRMMock internal irm;

    /// @notice Price oracle mock contract
    PriceOracleMock internal oracle;
}
