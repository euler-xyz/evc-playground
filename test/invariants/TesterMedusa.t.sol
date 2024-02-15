// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title TesterMedusa
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract TesterMedusa is Invariants, Setup {
    constructor() payable {
        /// @dev since medusa does not support initial balances yet, we need to deal some tokens to the contract
        vm.deal(address(this), 1e26 ether);

        setUp();
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() internal {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 MEDUSA ONLY INVARIANTS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_invariant_ERC4626_invariantC(uint256 _amount) public returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantC(vaults[i], _amount);
        }
        return true;
    }

    function echidna_invariant_ERC4626_invariantD(uint256 _amount) public returns (bool) {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantD(vaults[i], _amount);
        }
        return true;
    }

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}
}
