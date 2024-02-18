// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {Actor} from "../utils/Actor.sol";
import {BaseHandler, VaultSimple} from "../base/BaseHandler.t.sol";

/// @title VaultSimpleHandler
/// @notice Handler test contract for the VaultSimple actions
contract VaultSimpleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /* 
    
    E.g. num of active pools
    uint256 public activePools;

     */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 assets, address receiver, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedShares = vault.previewDeposit(assets);

        _approve(address(vault.asset()), actor, vaultAddress, assets);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.deposit.selector, assets, receiver));

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));

            assertLe(previewedShares, shares, string.concat("ERC4626_deposit_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function depositToActor(uint256 assets, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedShares = vault.previewDeposit(assets);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.deposit.selector, assets, receiver));

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));

            assertLe(previewedShares, shares, string.concat("ERC4626_deposit_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function mint(uint256 shares, address receiver, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedAssets = vault.previewMint(shares);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.mint.selector, shares, receiver));

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));

            assertGe(previewedAssets, assets, string.concat("ERC4626_mint_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function mintToActor(uint256 shares, uint256 i, uint256 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedAssets = vault.previewMint(shares);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.mint.selector, shares, receiver));

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));

            assertGe(previewedAssets, assets, string.concat("ERC4626_mint_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function withdraw(uint256 j, uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedShares = vault.previewWithdraw(assets);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) = actor.proxy(
            vaultAddress, abi.encodeWithSelector(VaultSimple.withdraw.selector, assets, receiver, address(actor))
        );

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 shares = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(vaultAddress, assets, address(actor));
            _decreaseGhostShares(vaultAddress, shares, address(actor));

            assertGe(previewedShares, shares, string.concat("ERC4626_withdraw_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function redeem(uint256 j, uint256 shares, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        uint256 previewedAssets = vault.previewRedeem(shares);

        _before(vaultAddress, VaultType.Simple);
        (success, returnData) = actor.proxy(
            vaultAddress, abi.encodeWithSelector(VaultSimple.redeem.selector, shares, receiver, address(actor))
        );

        if (success) {
            _after(vaultAddress, VaultType.Simple);

            uint256 assets = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(vaultAddress, assets, address(actor));
            _decreaseGhostShares(vaultAddress, shares, address(actor));

            assertLe(previewedAssets, assets, string.concat("ERC4626_redeem_invariantB: ", vaultNames[vaultAddress]));
        }
    }

    function disableController(uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address vaultAddress = _getRandomSupportedVault(i, VaultType.Simple);

        (success, returnData) =
            actor.proxy(address(vaultAddress), abi.encodeWithSelector(VaultSimple.disableController.selector));

        if (success) {
            assert(true);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     ROUNDTRIP PROPERTIES                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_roundtrip_invariantA(uint256 _i, uint256 _assets) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintAndApprove(address(_vault.asset()), address(this), vaultAddress, _assets);

        uint256 shares = _vault.deposit(_assets, address(this));

        uint256 redeemedAssets = _vault.redeem(shares, address(this), address(this));

        assertLe(redeemedAssets, _assets, string.concat("ERC4626_roundtrip_invariantA: ", vaultNames[vaultAddress]));
    }

    function assert_ERC4626_roundtrip_invariantB(uint256 _i, uint256 _assets) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintAndApprove(address(_vault.asset()), address(this), vaultAddress, _assets);

        uint256 shares = _vault.deposit(_assets, address(this));

        uint256 withdrawnShares = _vault.withdraw(_assets, address(this), address(this));

        assertGe(withdrawnShares, shares, string.concat("ERC4626_roundtrip_invariantB: ", vaultNames[vaultAddress]));
    }

    function assert_ERC4626_roundtrip_invariantC(uint256 _i, uint256 _shares) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintApproveAndMint(vaultAddress, address(this), _shares);

        uint256 redeemedAssets = _vault.redeem(_shares, address(this), address(this));

        uint256 mintedShares = _vault.deposit(redeemedAssets, address(this));

        /// @dev restore original state to not break invariants
        _vault.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, _shares, string.concat("ERC4626_roundtrip_invariantC: ", vaultNames[vaultAddress]));
    }

    function assert_ERC4626_roundtrip_invariantD(uint256 _i, uint256 _shares) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintApproveAndMint(vaultAddress, address(this), _shares);

        uint256 redeemedAssets = _vault.redeem(_shares, address(this), address(this));

        uint256 depositedAssets = _vault.mint(_shares, address(this));

        /// @dev restore original state to not break invariants
        _vault.withdraw(depositedAssets, address(this), address(this));

        assertGe(
            depositedAssets, redeemedAssets, string.concat("ERC4626_roundtrip_invariantD: ", vaultNames[vaultAddress])
        );
    }

    function assert_ERC4626_roundtrip_invariantE(uint256 _i, uint256 _shares) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintAndApprove(address(_vault.asset()), address(this), vaultAddress, _vault.convertToAssets(_shares));

        uint256 depositedAssets = _vault.mint(_shares, address(this));

        uint256 withdrawnShares = _vault.withdraw(depositedAssets, address(this), address(this));

        assertGe(withdrawnShares, _shares, string.concat("ERC4626_roundtrip_invariantE: ", vaultNames[vaultAddress]));
    }

    function assert_ERC4626_roundtrip_invariantF(uint256 _i, uint256 _shares) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintAndApprove(address(_vault.asset()), address(this), vaultAddress, _vault.convertToAssets(_shares));

        uint256 depositedAssets = _vault.mint(_shares, address(this));

        uint256 redeemedAssets = _vault.redeem(_shares, address(this), address(this));

        assertLe(
            redeemedAssets, depositedAssets, string.concat("ERC4626_roundtrip_invariantF: ", vaultNames[vaultAddress])
        );
    }

    function assert_ERC4626_roundtrip_invariantG(uint256 _i, uint256 _assets) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintApproveAndDeposit(vaultAddress, address(this), _assets);

        uint256 redeemedShares = _vault.withdraw(_assets, address(this), address(this));

        uint256 depositedAssets = _vault.mint(redeemedShares, address(this));

        /// @dev restore original state to not break invariants
        _vault.withdraw(depositedAssets, address(this), address(this));

        assertGe(depositedAssets, _assets, string.concat("ERC4626_roundtrip_invariantG: ", vaultNames[vaultAddress]));
    }

    function assert_ERC4626_roundtrip_invariantH(uint256 _i, uint256 _assets) external {
        address vaultAddress = _getRandomSupportedVault(_i, VaultType.Simple);

        VaultSimple _vault = VaultSimple(vaultAddress);

        _mintApproveAndDeposit(vaultAddress, address(this), _assets);

        uint256 redeemedShares = _vault.withdraw(_assets, address(this), address(this));

        uint256 mintedShares = _vault.deposit(_assets, address(this));

        /// @dev restore original state to not break invariants
        _vault.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, redeemedShares, string.concat("ERC4626_assets_invariantH: ", vaultNames[vaultAddress]));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setSupplyCap(uint256 j, uint256 newSupplyCap) external {
        address vaultAddress = _getRandomSupportedVault(j, VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _before(vaultAddress, VaultType.Simple);
        vault.setSupplyCap(newSupplyCap);
        _after(vaultAddress, VaultType.Simple);

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //  GHOSTS UPDATES
    function _increaseGhostAssets(address vaultAddress, uint256 assets, address receiver) internal {
        ghost_sumBalances[vaultAddress] += assets;
        ghost_sumBalancesPerUser[vaultAddress][receiver] += assets;
    }

    function _decreaseGhostAssets(address vaultAddress, uint256 assets, address owner) internal {
        ghost_sumBalances[vaultAddress] -= assets;
        ghost_sumBalancesPerUser[vaultAddress][owner] -= assets;
    }

    function _increaseGhostShares(address vaultAddress, uint256 shares, address receiver) internal {
        ghost_sumSharesBalances[vaultAddress] += shares;
        ghost_sumSharesBalancesPerUser[vaultAddress][receiver] += shares;
    }

    function _decreaseGhostShares(address vaultAddress, uint256 shares, address owner) internal {
        ghost_sumSharesBalances[vaultAddress] -= shares;
        ghost_sumSharesBalancesPerUser[vaultAddress][owner] -= shares;
    }
}
