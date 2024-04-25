// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "solmate/auth/Owned.sol";
import "solmate/tokens/ERC4626.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "../VaultBase.sol";

/// @title VaultSimple
/// @dev It provides basic functionality for vaults.
/// @notice In this contract, the EVC is authenticated before any action that may affect the state of the vault or an
/// account. This is done to ensure that if it's EVC calling, the account is correctly authorized. Unlike solmate,
/// VaultSimple implementation prevents from share inflation attack by using virtual assets and shares. Look into
/// Open-Zeppelin documentation for more details. This vault implements internal balance tracking. This contract does
/// not take the supply cap into account when calculating max deposit and max mint values.
contract VaultSimple is VaultBase, Owned, ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event SupplyCapSet(uint256 newSupplyCap);

    error SnapshotNotTaken();
    error SupplyCapExceeded();

    uint256 internal _totalAssets;
    uint256 public supplyCap;

    constructor(
        address _evc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) VaultBase(_evc) Owned(msg.sender) ERC4626(_asset, _name, _symbol) {}

    /// @notice Sets the supply cap of the vault.
    /// @param newSupplyCap The new supply cap.
    function setSupplyCap(uint256 newSupplyCap) external onlyOwner {
        supplyCap = newSupplyCap;
        emit SupplyCapSet(newSupplyCap);
    }

    /// @notice Creates a snapshot of the vault.
    /// @dev This function is called before any action that may affect the vault's state.
    /// @return A snapshot of the vault's state.
    function doCreateVaultSnapshot() internal virtual override returns (bytes memory) {
        // make total assets snapshot here and return it:
        return abi.encode(_totalAssets);
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
    }

    /// @notice Checks the status of an account.
    /// @dev This function is called after any action that may affect the account's state.
    function doCheckAccountStatus(address, address[] calldata) internal view virtual override {
        // no need to do anything here because the vault does not allow borrowing
    }

    /// @notice Disables the controller.
    /// @dev The controller is only disabled if the account has no debt.
    function disableController() external virtual override nonReentrant {
        // this vault doesn't allow borrowing, so we can't check that the account has no debt.
        // this vault should never be a controller, but user errors can happen
        EVCClient.disableController(_msgSender());
    }

    /// @notice Returns the total assets of the vault.
    /// @return The total assets.
    function totalAssets() public view virtual override returns (uint256) {
        return _totalAssets;
    }

    /// @notice Converts assets to shares.
    /// @dev That function is manipulable in its current form as it uses exact values. Considering that other vaults may
    /// rely on it, for a production vault, a manipulation resistant mechanism should be implemented.
    /// @dev Considering that this function may be relied on by controller vaults, it's read-only re-entrancy protected.
    /// @param assets The assets to convert.
    /// @return The converted shares.
    function convertToShares(uint256 assets) public view virtual override nonReentrantRO returns (uint256) {
        return _convertToShares(assets, false);
    }

    /// @notice Converts shares to assets.
    /// @dev That function is manipulable in its current form as it uses exact values. Considering that other vaults may
    /// rely on it, for a production vault, a manipulation resistant mechanism should be implemented.
    /// @dev Considering that this function may be relied on by controller vaults, it's read-only re-entrancy protected.
    /// @param shares The shares to convert.
    /// @return The converted assets.
    function convertToAssets(uint256 shares) public view virtual override nonReentrantRO returns (uint256) {
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

    /// @notice Approves a spender to spend a certain amount.
    /// @param spender The spender to approve.
    /// @param amount The amount to approve.
    /// @return A boolean indicating whether the approval was successful.
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address msgSender = _msgSender();

        allowance[msgSender][spender] = amount;

        emit Approval(msgSender, spender, amount);

        return true;
    }

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override callThroughEVC nonReentrant returns (bool) {
        address msgSender = _msgSender();

        createVaultSnapshot();

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

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override callThroughEVC nonReentrant returns (bool) {
        address msgSender = _msgSender();

        createVaultSnapshot();

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

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override callThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = _msgSender();

        createVaultSnapshot();

        // Check for rounding error since we round down in previewDeposit.
        require((shares = _convertToShares(assets, false)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _totalAssets += assets;

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        requireVaultStatusCheck();
    }

    /// @notice Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override callThroughEVC nonReentrant returns (uint256 assets) {
        address msgSender = _msgSender();

        createVaultSnapshot();

        assets = _convertToAssets(shares, true); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msgSender, address(this), assets);

        _totalAssets += assets;

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, assets, shares);

        requireVaultStatusCheck();
    }

    /// @notice Withdraws a certain amount of assets for a receiver.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the withdrawal.
    /// @param owner The owner of the assets.
    /// @return shares The shares equivalent to the withdrawn assets.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override callThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = _msgSender();

        createVaultSnapshot();

        shares = _convertToShares(assets, true); // No need to check for rounding error, previewWithdraw rounds up.

        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msgSender] = allowed - shares;
            }
        }

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);

        _totalAssets -= assets;

        requireAccountAndVaultStatusCheck(owner);
    }

    /// @notice Redeems a certain amount of shares for a receiver.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override callThroughEVC nonReentrant returns (uint256 assets) {
        address msgSender = _msgSender();

        createVaultSnapshot();

        if (msgSender != owner) {
            uint256 allowed = allowance[owner][msgSender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msgSender] = allowed - shares;
            }
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = _convertToAssets(shares, false)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(msgSender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);

        _totalAssets -= assets;

        requireAccountAndVaultStatusCheck(owner);
    }

    function _convertToShares(uint256 assets, bool roundUp) internal view virtual returns (uint256) {
        return roundUp
            ? assets.mulDivUp(totalSupply + 1, _totalAssets + 1)
            : assets.mulDivDown(totalSupply + 1, _totalAssets + 1);
    }

    function _convertToAssets(uint256 shares, bool roundUp) internal view virtual returns (uint256) {
        return roundUp
            ? shares.mulDivUp(_totalAssets + 1, totalSupply + 1)
            : shares.mulDivDown(_totalAssets + 1, totalSupply + 1);
    }
}
