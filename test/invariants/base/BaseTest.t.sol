// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Vm} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

// Utils
import {Actor} from "../utils/Actor.sol";
import {PropertiesConstants} from "../utils/PropertiesConstants.sol";
import {StdAsserts} from "../utils/StdAsserts.sol";

// Base
import {BaseStorage} from "./BaseStorage.t.sol";

// Contracts
import {
    VaultSimpleExtended as VaultSimple,
    VaultSimpleBorrowableExtended as VaultSimpleBorrowable,
    VaultRegularBorrowableExtended as VaultRegularBorrowable,
    VaultBorrowableWETHExtended as VaultBorrowableWETH
} from "test/invariants/helpers/extended/VaultsExtended.sol";

/// @notice Base contract for all test contracts extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev inherits Storage, Testing constants assertions and utils needed for testing
abstract contract BaseTest is BaseStorage, PropertiesConstants, StdAsserts, StdUtils {
    bool public IS_TEST = true;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   ACTOR PROXY MECHANISM                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Actor proxy mechanism
    modifier setup() virtual {
        actor = actors[msg.sender];
        _;
        actor = Actor(payable(address(0)));
    }

    /// @dev Solves medusa backward time warp issue
    modifier monotonicTimestamp(address _vault) virtual {
        if (block.timestamp < VaultSimple(_vault).getLastInterestUpdate()) {
            vm.warp(VaultSimple(_vault).getLastInterestUpdate());
        }
        _;
    }

    /// @dev sets the bottom limit index af the vaults array that the property will be tested against
    modifier targetVaultsFrom(VaultType _vaultType) {
        limitVault = uint256(_vaultType);
        _;
        limitVault = 0;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     CHEAT CODE SETUP                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    Vm internal constant vm = Vm(VM_ADDRESS);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _makeAddr(string memory name) internal pure returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
    }

    function _getRandomActor(uint256 _i) internal view returns (address) {
        uint256 _actorIndex = _i % NUMBER_OF_ACTORS;
        return actorAddresses[_actorIndex];
    }
}
