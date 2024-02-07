// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Actor} from "../utils/Actor.sol";
import {ProtocolAssertions} from "../base/ProtocolAssertions.t.sol";
import {BaseStorage, VaultSimple, VaultSimpleBorrowable} from "../base/BaseStorage.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per-action assertions are implemented in the handlers
contract BaseHandler is ProtocolAssertions {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SHARED VARAIBLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // SIMPLE VAULT

    /// @notice Sum of all balances in the vault
    mapping(address => uint256) public ghost_sumBalances;

    /// @notice Sum of all balances per user in the vault
    mapping(address => mapping(address => uint256)) public ghost_sumBalancesPerUser;

    /// @notice Sum of all shares balances in the vault
    mapping(address => uint256) public ghost_sumSharesBalances;

    /// @notice Sum of all shares balances per user in the vault
    mapping(address => mapping(address => uint256)) public ghost_sumSharesBalancesPerUser;

    // SIMPLE BORROWABLE VAULT

    mapping(address => uint256) public ghost_totalBorrowed;

    mapping(address => mapping(address => uint256)) public ghost_owedAmountPerUser;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      HELPERS                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns a random vault address that supports a specific vault type, this optimises the invariant suite
    function _getRandomSupportedVault(VaultType _minVaultType) internal view returns (address) {
        require(uint8(_minVaultType) < vaults.length - 1, "BaseHandler: invalid vault type");

        // Randomize the vault selection
        uint256 randomValue = _randomize(block.timestamp, "randomVault");

        // Use mod math to get a random vault from the range of vaults that support the specific type
        uint256 range = (vaults.length - 1) - uint256(_minVaultType) + 1;
        return vaults[uint256(_minVaultType) + (randomValue % range)];
    }

    /// @notice Helper function to randomize a uint256 seed with a string salt
    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
    function _approve(address token, Actor actor_, address spender, uint256 amount) internal {
        bool success;
        bytes memory returnData;
        (success, returnData) = actor_.proxy(token, abi.encodeWithSelector(0x095ea7b3, spender, amount));
        require(success, string(returnData));
    }
}
