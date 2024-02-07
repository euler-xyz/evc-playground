// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {Actor} from "../utils/Actor.sol";
import {VaultSimpleBeforeAfterHooks} from "../hooks/VaultSimpleBeforeAfterHooks.t.sol";
import {BaseHandler, VaultSimple} from "../base/BaseHandler.t.sol";

/// @title VaultSimpleHandler
/// @notice Handler test contract for the VaultSimple actions
contract VaultSimpleHandler is BaseHandler, VaultSimpleBeforeAfterHooks {
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

    function deposit(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.deposit.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));
        }
    }

    function depositToActor(uint256 assets, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.deposit.selector, assets, receiver));

        if (success) {
            _svAfter(vaultAddress);

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));
        }
    }

    function mint(uint256 shares, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.mint.selector, shares, receiver));

        if (success) {
            _svAfter(vaultAddress);

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));
        }
    }

    function mintToActor(uint256 shares, uint256 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) =
            actor.proxy(vaultAddress, abi.encodeWithSelector(VaultSimple.mint.selector, shares, receiver));

        if (success) {
            _svAfter(vaultAddress);

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(vaultAddress, assets, address(receiver));
            _increaseGhostShares(vaultAddress, shares, address(receiver));
        }
    }

    function withdraw(uint256 assets, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) = actor.proxy(
            vaultAddress, abi.encodeWithSelector(VaultSimple.withdraw.selector, assets, receiver, address(actor))
        );

        if (success) {
            _svAfter(vaultAddress);

            uint256 shares = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(vaultAddress, assets, address(actor));
            _decreaseGhostShares(vaultAddress, shares, address(actor));
        }
    }

    function redeem(uint256 shares, address receiver) external setup {
        bool success;
        bytes memory returnData;

        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        _svBefore(vaultAddress);
        (success, returnData) = actor.proxy(
            vaultAddress, abi.encodeWithSelector(VaultSimple.redeem.selector, shares, receiver, address(actor))
        );

        if (success) {
            _svAfter(vaultAddress);

            uint256 assets = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(vaultAddress, assets, address(actor));
            _decreaseGhostShares(vaultAddress, shares, address(actor));
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setSupplyCap(uint256 newSupplyCap) external {
        address vaultAddress = _getRandomSupportedVault(VaultType.Simple);

        VaultSimple vault = VaultSimple(vaultAddress);

        // Since the owner is the deployer of the vault, we dont need to use a a proxy
        _svBefore(vaultAddress);
        vault.setSupplyCap(newSupplyCap);
        _svAfter(vaultAddress);

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
