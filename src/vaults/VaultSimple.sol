// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/utils/ReentrancyGuard.sol";
import "solmate/auth/Owned.sol";
import "solmate/mixins/ERC4626.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./VaultBase.sol";

/// @title VaultSimple
/// @dev It provides basic functionality for vaults.
/// @notice In this contract, the EVC is authenticated before any action that may affect the state of the vault or an
/// account. This is done to ensure that if it's EVC calling, the account is correctly authorized. Unlike solmate,
/// VaultSimple implementation prevents from share inflation attack by using virtual assets and shares. Look into
/// Open-Zeppelin documentation for more details. This contract does not take the supply cap into account when
/// calculating max deposit and max mint values.
contract VaultSimple is VaultBase, ReentrancyGuard, Owned, ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event SupplyCapSet(uint256 newSupplyCap);

    error SnapshotNotTaken();
    error SupplyCapExceeded();

    uint256 public supplyCap;

    constructor(
        IEVC _evc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) VaultBase(_evc) Owned(msg.sender) ERC4626(_asset, _name, _symbol) {}

    /// @dev Sets the supply cap of the vault.
    /// @param newSupplyCap The new supply cap.
    function setSupplyCap(uint256 newSupplyCap) external onlyOwner {
        supplyCap = newSupplyCap;
        emit SupplyCapSet(newSupplyCap);
    }

    /// @notice Takes a snapshot of the vault.
    /// @dev This function is called before any action that may affect the vault's state.
    /// @return A snapshot of the vault's state.
    function doTakeVaultSnapshot() internal virtual override returns (bytes memory) {
        // make total supply snapshot here and return it:
        return abi.encode(_convertToAssets(totalSupply, false));
    }

    /// @notice Checks the vault's status.
    /// @dev This function is called after any action that may affect the vault's state.
    /// @param oldSnapshot The snapshot of the vault's state before the action.
    function doCheckVaultStatus(bytes memory oldSnapshot) internal virtual override {
        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) revert SnapshotNotTaken();

        // validate the vault state here:
        uint256 initialSupply = abi.decode(oldSnapshot, (uint256));
        uint256 finalSupply = _convertToAssets(totalSupply, false);

        // the supply cap can be implemented like this:
        if (supplyCap != 0 && finalSupply > supplyCap && finalSupply > initialSupply) {
            revert SupplyCapExceeded();
        }

        // example: if 90% of the assets were withdrawn, revert the transaction
        //require(finalSupply >= initialSupply / 10, "withdrawal too large");
    }

    /// @notice Checks the status of an account.
    /// @dev This function is called after any action that may affect the account's state.
    function doCheckAccountStatus(address, address[] calldata) internal view virtual override {
        // no need to do anything here because the vault does not allow borrowing
    }

    /// @dev Disables a controller.
    /// @param account The account of the controller.
    function disableController(address account) external virtual override nonReentrant {
        // ensure that the account does not have any liabilities before disabling controller
        releaseAccountFromControl(account);
    }

    /// @dev Returns the total assets of the vault.
    /// @return The total assets.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @dev Converts assets to shares.
    /// @param assets The assets to convert.
    /// @return The converted shares.
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, false);
    }

    /// @dev Converts shares to assets.
    /// @param shares The shares to convert.
    /// @return The converted assets.
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, false);
    }

    /// @notice Simulates the effects of depositing a certain amount of assets at the current block.
    /// @param assets The amount of assets to simulate depositing.
    /// @return The amount of shares that would be minted.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, false);
    }

    /// @notice Simulates the effects of minting a certain amount of shares at the current block.
    /// @param shares The amount of shares to simulate minting.
    /// @return The amount of assets that would be deposited.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, true);
    }

    /// @notice Simulates the effects of withdrawing a certain amount of assets at the current block.
    /// @param assets The amount of assets to simulate withdrawing.
    /// @return The amount of shares that would be burned.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, true);
    }

    /// @notice Simulates the effects of redeeming a certain amount of shares at the current block.
    /// @param shares The amount of shares to simulate redeeming.
    /// @return The amount of assets that would be redeemed.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, false);
    }

    /// @dev Approves a spender to spend a certain amount.
    /// @param spender The spender to approve.
    /// @param amount The amount to approve.
    /// @return A boolean indicating whether the approval was successful.
    function approve(address spender, uint256 amount) public override returns (bool) {
        address msgSender = EVCAuthenticate(false);

        allowance[msgSender][spender] = amount;

        emit Approval(msgSender, spender, amount);

        return true;
    }

    /// @dev Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public override routedThroughEVC nonReentrant returns (bool) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        balanceOf[msgSender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msgSender, to, amount);

        // despite the fact that the vault status check might not be needed for shares transfer with current logic, it's
        // added here so that if anyone changes the snapshot/vault status check mechanisms in the inheriting contracts,
        // they will not forget to add the vault status check here
        requireAccountAndVaultStatusCheck(msgSender);

        return true;
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
    ) public override routedThroughEVC nonReentrant returns (bool) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        uint256 allowed = allowance[from][msgSender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) {
            allowance[from][msgSender] = allowed - amount;
        }

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        // despite the fact that the vault status check might not be needed for shares transfer with current logic, it's
        // added here so that if anyone changes the snapshot/vault status check mechanisms in the inheriting contracts,
        // they will not forget to add the vault status check here
        requireAccountAndVaultStatusCheck(from);

        return true;
    }

    /// @dev Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(
        uint256 assets,
        address receiver
    ) public override routedThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        requireAccountAndVaultStatusCheck(address(0));
    }

    /// @dev Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(
        uint256 shares,
        address receiver
    ) public override routedThroughEVC nonReentrant returns (uint256 assets) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        requireAccountAndVaultStatusCheck(address(0));
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
    ) public override routedThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msgSender] = allowed - shares;
            }
        }

        receiver = getAccountOwner(receiver);

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);

        requireAccountAndVaultStatusCheck(owner);
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
    ) public override routedThroughEVC nonReentrant returns (uint256 assets) {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msgSender] = allowed - shares;
            }
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        receiver = getAccountOwner(receiver);

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);

        requireAccountAndVaultStatusCheck(owner);
    }

    function _convertToShares(uint256 assets, bool roundUp) internal view virtual returns (uint256) {
        return roundUp
            ? assets.mulDivUp(totalSupply + 1, totalAssets() + 1)
            : assets.mulDivDown(totalSupply + 1, totalAssets() + 1);
    }

    function _convertToAssets(uint256 shares, bool roundUp) internal view virtual returns (uint256) {
        return roundUp
            ? shares.mulDivUp(totalAssets() + 1, totalSupply + 1)
            : shares.mulDivDown(totalAssets() + 1, totalSupply + 1);
    }
}
