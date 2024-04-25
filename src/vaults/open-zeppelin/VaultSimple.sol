// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "../VaultBase.sol";

/// @title VaultSimple
/// @dev It provides basic functionality for vaults.
/// @notice In this contract, the EVC is authenticated before any action that may affect the state of the vault or an
/// account. This is done to ensure that if it's EVC calling, the account is correctly authorized. This contract does
/// not take the supply cap into account when calculating max deposit and max mint values.
contract VaultSimple is VaultBase, Ownable, ERC4626 {
    event SupplyCapSet(uint256 newSupplyCap);

    error SnapshotNotTaken();
    error SupplyCapExceeded();

    uint256 internal _totalAssets;
    uint256 public supplyCap;

    constructor(
        address _evc,
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) VaultBase(_evc) Ownable(msg.sender) ERC4626(_asset) ERC20(_name, _symbol) {}

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }

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
        uint256 finalSupply = _convertToAssets(totalSupply(), Math.Rounding.Floor);

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
        return super.convertToShares(assets);
    }

    /// @notice Converts shares to assets.
    /// @dev That function is manipulable in its current form as it uses exact values. Considering that other vaults may
    /// rely on it, for a production vault, a manipulation resistant mechanism should be implemented.
    /// @dev Considering that this function may be relied on by controller vaults, it's read-only re-entrancy protected.
    /// @param shares The shares to convert.
    /// @return The converted assets.
    function convertToAssets(uint256 shares) public view virtual override nonReentrantRO returns (uint256) {
        return super.convertToAssets(shares);
    }

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(
        address to,
        uint256 amount
    ) public virtual override (IERC20, ERC20) callThroughEVC nonReentrant returns (bool) {
        createVaultSnapshot();
        bool result = super.transfer(to, amount);

        // despite the fact that the vault status check might not be needed for shares transfer with current logic, it's
        // added here so that if anyone changes the snapshot/vault status check mechanisms in the inheriting contracts,
        // they will not forget to add the vault status check here
        requireAccountAndVaultStatusCheck(_msgSender());
        return result;
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
    ) public virtual override (IERC20, ERC20) callThroughEVC nonReentrant returns (bool) {
        createVaultSnapshot();
        bool result = super.transferFrom(from, to, amount);

        // despite the fact that the vault status check might not be needed for shares transfer with current logic, it's
        // added here so that if anyone changes the snapshot/vault status check mechanisms in the inheriting contracts,
        // they will not forget to add the vault status check here
        requireAccountAndVaultStatusCheck(from);
        return result;
    }

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override callThroughEVC nonReentrant returns (uint256 shares) {
        createVaultSnapshot();
        shares = super.deposit(assets, receiver);
        _totalAssets += assets;
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
        createVaultSnapshot();
        assets = super.mint(shares, receiver);
        _totalAssets += assets;
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
        createVaultSnapshot();
        shares = super.withdraw(assets, receiver, owner);
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
        createVaultSnapshot();
        assets = super.redeem(shares, receiver, owner);
        _totalAssets -= assets;
        requireAccountAndVaultStatusCheck(owner);
    }
}
