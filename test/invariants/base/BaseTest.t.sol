// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Vm} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {Actor} from "../utils/Actor.sol";
import {PropertiesConstants} from "../utils/PropertiesConstants.sol";
import {StdAsserts} from "../utils/StdAsserts.sol";

import {BaseStorage} from "./BaseStorage.t.sol";

/// @notice Base contract for all test contracts extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev inherits Storage, Testing constants assertions and utils needed for testing
abstract contract BaseTest is
    BaseStorage,
    PropertiesConstants,
    StdAsserts,
    StdUtils
{
    bool public IS_TEST = true;

    /**************************************************************************************************************************************/
    /*** Actor Proxy Mechanism                                                                                                          ***/
    /**************************************************************************************************************************************/
    modifier setup() virtual {
        actor = actors[msg.sender];
        _;
        actor = Actor(payable(address(0)));
    }

    /**************************************************************************************************************************************/
    /*** Cheat Code Setup                                                                                                               ***/
    /**************************************************************************************************************************************/

    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));

    Vm internal constant vm = Vm(VM_ADDRESS);

    function _makeAddr(
        string memory name
    ) internal pure returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
    }
}