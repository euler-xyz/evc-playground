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

    function echidna_invariant_ERC4626_invariantC(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantC(vaults[i], _amount);
        }
        return true;
    }

    function echidna_invariant_ERC4626_invariantD(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_assets_invariantD(vaults[i], _amount);
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         ERC4626                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_invariant_ERC4626_deposit_invariantaABC(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_ERC4626_deposit_invariantA(vaults[i], actorAddresses[j]);
            }
            assert_ERC4626_deposit_invariantB(vaults[i], _amount);
            assert_ERC4626_deposit_invariantC(vaults[i], _amount);
        }
        return true;
    }

    function echidna_invariant_ERC4626_mint_invariantaABC(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_ERC4626_mint_invariantA(vaults[i], actorAddresses[j]);
            }
            assert_ERC4626_mint_invariantB(vaults[i], _amount);
            assert_ERC4626_mint_invariantC(vaults[i], _amount);
        }
        return true;
    }

    function echidna_invariant_ERC4626_withdraw_invariantaABC(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_ERC4626_withdraw_invariantA(vaults[i], actorAddresses[j]);
            }
            assert_ERC4626_withdraw_invariantB(vaults[i], _amount);
            assert_ERC4626_withdraw_invariantC(vaults[i], _amount);
        }
        return true;
    }

    function echidna_invariant_ERC4626_redeem_invariantaABC(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                assert_ERC4626_redeem_invariantA(vaults[i], actorAddresses[j]);
            }
            assert_ERC4626_redeem_invariantB(vaults[i], _amount);
            assert_ERC4626_redeem_invariantC(vaults[i], _amount);
        }
        return true;
    }

    // roundtrip invariants

    function echidna_invarian_ERC4626_roundtrip_invariantA(uint256 _amount)
        public
        targetVaultsFrom(VaultType.Simple)
        returns (bool)
    {
        for (uint256 i = limitVault; i < vaults.length; i++) {
            assert_ERC4626_roundtrip_invariantA(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantB(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantC(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantD(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantE(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantF(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantG(vaults[i], _amount);
            assert_ERC4626_roundtrip_invariantH(vaults[i], _amount);
        }
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                                                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}
}
