// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {ProtocolAssertions} from "../base/ProtocolAssertions.t.sol";
import {BaseStorage} from "../base/BaseStorage.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandler is ProtocolAssertions {
    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/
    
    /// @notice Helper function to randomize a uint256 seed with a string salt
    function _randomize(
        uint256 seed,
        string memory salt
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
    function _approve(
        address token,
        Actor actor_,
        address spender,
        uint256 amount
    ) internal {
        bool success;
        bytes memory returnData;
        (success, returnData) = actor_.proxy(
            token,
            abi.encodeWithSelector(0x095ea7b3, spender, amount)
        );
        require(success, string(returnData));
    }
}
