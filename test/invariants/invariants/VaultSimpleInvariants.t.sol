// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Base Contracts
import {VaultSimple} from "../base/BaseStorage.t.sol";
import {Actor} from "../utils/Actor.sol";
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title VaultSimpleInvariants
/// @notice Implements Invariants for the protocol
/// @notice Implements View functions assertions for the protocol, checked in assertion testing mode
/// @dev Inherits HandlerAggregator for checking actions in assertion testing mode
abstract contract VaultSimpleInvariants is HandlerAggregator {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                   INVARIANTS SPEC: Handwritten / pseudo-code invariants                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    VaultSimple
        Invariant A: totalAssets == sum of all balances
        Invariant B: totalSupply == sum of all minted shares
        Invariant C: balanceOf(actor) == sum of all shares owned by address
        Invariant D: totalSupply == sum of balanceOf(actors)

    ERC4626
        assets:
            Invariant A: asset MUST NOT revert
            Invariant B: totalAssets MUST NOT revert
            Invariant C: convertToShares MUST NOT show any variations depending on the caller
            Invariant D: convertToAssets MUST NOT show any variations depending on the caller

        deposit:
            Invariant A: maxDeposit MUST NOT revert
            Invariant B: previewDeposit MUST return close to and no more than shares minted at deposit if 
                called in the same transaction
            Invariant C: deposit should return the same or more shares as previewDeposit if called in the 
                same transaction

        mint:
            Invariant A: maxMint MUST NOT revert
            Invariant B: previewMint MUST return close to and no fewer than assets deposited at mint if 
                called in the same transaction 
            Invariant C: mint should return the same or fewer assets as previewMint if called in the 
                same transaction

        withdraw:
            Invariant A: MUST NOT revert
            Invariant B: previewWithdraw MUST return close to and no fewer than shares burned at withdraw if 
                called in the same transaction
            Invariant C: withdraw should return the same or fewer shares as previewWithdraw if called in the 
                same transaction
        
        redeem:
            Invariant A: MUST NOT revert
            Invariant B: previewRedeem MUST return close to and no more than assets redeemed at redeem if 
                called in the same transaction
            Invariant C: redeem should return the same or more assets as previewRedeem if called in the 
                same transaction

        roundtrip:
            Invariant A: redeem(deposit(a)) <= a
            Invariant B:
                s = deposit(a)
                s' = withdraw(a)
                s' >= s
            Invariant C:
                deposit(redeem(s)) <= s
            Invariant D:
                a = redeem(s)
                a' = mint(s)
                a' >= a
            Invariant E:
                withdraw(mint(s)) >= s
            Invariant F:
                a = mint(s)
                a' = redeem(s)
                a' <= a
            Invariant G:
                mint(withdraw(a)) >= a
            Invariant H:
                s = withdraw(a)
                s' = deposit(a)
                s' <= s
    */

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    // VaultSimple

    function assert_VaultSimple_invariantA(address _vault) internal {
        //TODO: implement balance changes
        uint256 totalAssets = VaultSimple(_vault).totalAssets();

        assertEq(totalAssets, ghost_sumBalances[_vault], string.concat("VaultSimple_invariantA: ", vaultNames[_vault]));
    }

    function assert_VaultSimple_invariantB(address _vault) internal {
        uint256 totalSupply = VaultSimple(_vault).totalSupply();

        assertEq(totalSupply, ghost_sumBalances[_vault], string.concat("VaultSimple_invariantB: ", vaultNames[_vault]));
    }

    function assert_VaultSimple_invariantC(address _vault, address _account) internal returns (uint256 balanceOf) {
        balanceOf = VaultSimple(_vault).balanceOf(_account);

        assertEq(
            balanceOf,
            ghost_sumSharesBalancesPerUser[_vault][_account],
            string.concat("VaultSimple_invariantC: ", vaultNames[_vault])
        );
    }

    function assert_VaultSimple_invariantD(address _vault, uint256 _sumBalances) internal {
        uint256 totalSupply = VaultSimple(_vault).totalSupply();

        assertEq(totalSupply, _sumBalances, string.concat("VaultSimple_invariantD: ", vaultNames[_vault]));
    }

    // ERC4626

    // assets

    function assert_ERC4626_assets_invariantA(address _vault) internal {
        try IERC4626(_vault).asset() {}
        catch Error(string memory reason) {
            fail(string.concat("ERC4626_assets_invariantA: ", reason));
        }
    }

    function assert_ERC4626_assets_invariantB(address _vault) internal {
        try IERC4626(_vault).totalAssets() returns (uint256 totalAssets) {
            totalAssets;
        } catch Error(string memory reason) {
            fail(string.concat("ERC4626_assets_invariantB: ", reason));
        }
    }

    function assert_ERC4626_assets_invariantC(address _vault, uint256 _assets) internal {
        uint256 shares;
        bool notFirstLoop;
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            vm.prank(actorAddresses[i]);
            uint256 tempShares = IERC4626(_vault).convertToShares(_assets);

            if (notFirstLoop) {
                assertEq(shares, tempShares, string.concat("ERC4626_assets_invariantC: ", vaultNames[_vault]));
            } else {
                shares = tempShares;
                notFirstLoop = true;
            }
        }
    }

    function assert_ERC4626_assets_invariantD(address _vault, uint256 _shares) internal {
        uint256 assets;
        bool notFirstLoop;
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            vm.prank(actorAddresses[i]);
            uint256 tempAssets = IERC4626(_vault).convertToAssets(_shares);

            if (notFirstLoop) {
                assertEq(assets, tempAssets, string.concat("ERC4626_assets_invariantD: ", vaultNames[_vault]));
            } else {
                assets = tempAssets;
                notFirstLoop = true;
            }
        }
    }
}
