// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/auth/Owned.sol";
import "solmate/mixins/ERC4626.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./CreditVaultBase.sol";

/// @title CreditVaultSimple
/// @dev It provides basic functionality for credit vaults.
/// @notice In this contract, the CVC is authenticated before any action that may affect the state of the vault or an account.
/// This is done to ensure that if it's CVC calling, the account is correctly authorized.
contract CreditVaultSimple is CreditVaultBase, Owned, ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event SupplyCapSet(uint newSupplyCap);

    uint public supplyCap;

    constructor(
        ICVC _cvc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) CreditVaultBase(_cvc) Owned(msg.sender) ERC4626(_asset, _name, _symbol) {}

    /// @dev Sets the supply cap of the vault.
    /// @param newSupplyCap The new supply cap.
    function setSupplyCap(uint newSupplyCap) external onlyOwner {
        supplyCap = newSupplyCap;
        emit SupplyCapSet(newSupplyCap);
    }

    /// @notice Takes a snapshot of the vault.
    /// @dev This function is called before any action that may affect the vault's state.
    /// @return A snapshot of the vault's state.
    function doTakeVaultSnapshot()
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        // make total supply snapshot here and return it:
        return abi.encode(convertToAssets(totalSupply));
    }

    /// @notice Checks the vault's status.
    /// @dev This function is called after any action that may affect the vault's state.
    /// @param oldSnapshot The snapshot of the vault's state before the action.
    /// @return A boolean indicating whether the vault's state is valid, and a string with an error message if it's not.
    function doCheckVaultStatus(
        bytes memory oldSnapshot
    ) internal virtual override returns (bool, bytes memory) {
        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) {
            return (false, "snapshot not taken");
        }

        // validate the vault state here:
        uint initialSupply = abi.decode(oldSnapshot, (uint));
        uint finalSupply = convertToAssets(totalSupply);

        // the supply cap can be implemented like this:
        if (
            supplyCap != 0 &&
            finalSupply > supplyCap &&
            finalSupply > initialSupply
        ) {
            return (false, "supply cap exceeded");
        }

        // if 90% of the assets were withdrawn, revert the transaction
        //if (finalSupply < initialSupply / 10) {
        //    return (false, "withdrawal too large");
        //}

        return (true, "");
    }

    /// @notice Checks the status of an account.
    /// @dev This function is called after any action that may affect the account's state.
    /// @param account The account to check.
    /// @param collaterals The collaterals of the account.
    /// @return A boolean indicating whether the account's state is valid, and a string with an error message if it's not.
    function doCheckAccountStatus(
        address account,
        address[] calldata collaterals
    ) internal view virtual override returns (bool, bytes memory) {
        // to supress the compiler warning
        account;
        collaterals;
        // --
        return (true, "");
    }

    /// @dev Disables a controller.
    /// @param account The account of the controller.
    function disableController(
        address account
    ) external virtual override nonReentrant {
        disableSelfAsController(account);
    }

    /// @dev Converts assets to shares.
    /// @param assets The assets to convert.
    /// @return The converted shares.
    function convertToShares(
        uint256 assets
    ) public view virtual override returns (uint256) {
        return _convertToShares(assets);
    }

    /// @dev Converts shares to assets.
    /// @param shares The shares to convert.
    /// @return The converted assets.
    function convertToAssets(
        uint256 shares
    ) public view virtual override returns (uint256) {
        return _convertToAssets(shares);
    }

    /// @dev Returns the total assets of the vault.
    /// @return The total assets.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @dev Approves a spender to spend a certain amount.
    /// @param spender The spender to approve.
    /// @param amount The amount to approve.
    /// @return A boolean indicating whether the approval was successful.
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        address msgSender = CVCAuthenticate();

        allowance[msgSender][spender] = amount;

        emit Approval(msgSender, spender, amount);

        return true;
    }

    /// @dev Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        return _transfer(CVCAuthenticate(), to, amount);
    }

    /// @dev Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        return _transferFrom(CVCAuthenticate(), from, to, amount);
    }

    /// @dev Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256 shares) {
        return _deposit(CVCAuthenticate(), assets, receiver);
    }

    /// @dev Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(
        uint256 shares,
        address receiver
    ) public override returns (uint256 assets) {
        return _mint(CVCAuthenticate(), shares, receiver);
    }

    /// @dev Withdraws a certain amount of assets for a receiver.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the withdrawal.
    /// @param owner The owner of the assets.
    /// @return shares The shares equivalent to the withdrawn assets.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        return _withdraw(CVCAuthenticate(), assets, receiver, owner);
    }

    /// @dev Redeems a certain amount of shares for a receiver.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        return _redeem(CVCAuthenticate(), shares, receiver, owner);
    }

    function _transfer(
        address msgSender,
        address to,
        uint256 amount
    ) internal virtual nonReentrantWithChecks(msgSender) returns (bool) {
        balanceOf[msgSender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msgSender, to, amount);

        return true;
    }

    function _transferFrom(
        address msgSender,
        address from,
        address to,
        uint256 amount
    ) internal virtual nonReentrantWithChecks(from) returns (bool) {
        uint256 allowed = allowance[from][msgSender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            allowance[from][msgSender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function _deposit(
        address msgSender,
        uint256 assets,
        address receiver
    )
        internal
        virtual
        nonReentrantWithChecks(address(0))
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function _mint(
        address msgSender,
        uint256 shares,
        address receiver
    )
        internal
        virtual
        nonReentrantWithChecks(address(0))
        returns (uint256 assets)
    {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function _withdraw(
        address msgSender,
        uint256 assets,
        address receiver,
        address owner
    ) internal virtual nonReentrantWithChecks(owner) returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msgSender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function _redeem(
        address msgSender,
        uint256 shares,
        address receiver,
        address owner
    ) internal virtual nonReentrantWithChecks(owner) returns (uint256 assets) {
        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msgSender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function _convertToShares(
        uint256 assets
    ) internal view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function _convertToAssets(
        uint256 shares
    ) internal view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function beforeWithdraw(uint256, uint256) internal virtual override {}

    function afterDeposit(uint256, uint256) internal virtual override {}
}
