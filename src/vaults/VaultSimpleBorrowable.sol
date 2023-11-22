// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./VaultSimple.sol";
import "../interfaces/IERC3156FlashLender.sol";

/// @title VaultSimpleBorrowable
/// @notice This contract extends VaultSimple to add borrowing functionality.
/// @notice In this contract, the EVC is authenticated before any action that may affect the state of the vault or an
/// account. This is done to ensure that if it's EVC calling, the account is correctly authorized and the vault is
/// enabled as a controller if needed. This contract does not take the account health into account when calculating max
/// withdraw and max redeem values.
contract VaultSimpleBorrowable is VaultSimple, IERC3156FlashLender {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event BorrowCapSet(uint256 newBorrowCap);
    event Borrow(address indexed caller, address indexed owner, uint256 assets);
    event Repay(address indexed caller, address indexed receiver, uint256 assets);

    error FlashloanFailure();
    error FlashloanNotSupported();
    error BorrowCapExceeded();
    error AccountUnhealthy();

    uint256 public borrowCap;
    uint256 public totalBorrowed;
    mapping(address account => uint256 assets) internal owed;

    constructor(
        IEVC _evc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) VaultSimple(_evc, _asset, _name, _symbol) {}

    /// @notice Sets the borrow cap.
    /// @param newBorrowCap The new borrow cap.
    function setBorrowCap(uint256 newBorrowCap) external onlyOwner {
        borrowCap = newBorrowCap;
        emit BorrowCapSet(newBorrowCap);
    }

    /// @notice Returns the debt of an account.
    /// @param account The account to check.
    /// @return The debt of the account.
    function debtOf(address account) public view virtual returns (uint256) {
        return owed[account];
    }

    /// @notice Returns the maximum amount that can be withdrawn by an owner.
    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be withdrawn.
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        uint256 totAssets = totalAssets();
        uint256 ownerAssets = _convertToAssets(balanceOf[owner], false);

        return ownerAssets > totAssets ? totAssets : ownerAssets;
    }

    /// @notice Returns the maximum amount that can be redeemed by an owner.
    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be redeemed.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        uint256 totAssets = totalAssets();
        uint256 ownerShares = balanceOf[owner];

        return _convertToAssets(ownerShares, false) > totAssets ? _convertToShares(totAssets, false) : ownerShares;
    }

    /// @notice Takes a snapshot of the vault.
    /// @dev This function is called before any action that may affect the vault's state.
    /// @return A snapshot of the vault's state.
    function doTakeVaultSnapshot() internal virtual override returns (bytes memory) {
        (uint256 currentTotalBorrowed,) = _accrueInterest();

        // make total supply and total borrows snapshot:
        return abi.encode(_convertToAssets(totalSupply, false), currentTotalBorrowed);
    }

    /// @notice Checks the vault's status.
    /// @dev This function is called after any action that may affect the vault's state.
    /// @param oldSnapshot The snapshot of the vault's state before the action.
    function doCheckVaultStatus(bytes memory oldSnapshot) internal virtual override {
        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) revert SnapshotNotTaken();

        // use the vault status hook to update the interest rate (it should happen only once per transaction).
        // EVC.forgiveVaultStatus check should never be used for this vault, otherwise the interest rate will not be
        // updated.
        _updateInterest();

        // validate the vault state here:
        (uint256 initialSupply, uint256 initialBorrowed) = abi.decode(oldSnapshot, (uint256, uint256));
        uint256 finalSupply = _convertToAssets(totalSupply, false);
        uint256 finalBorrowed = totalBorrowed;

        // the supply cap can be implemented like this:
        if (supplyCap != 0 && finalSupply > supplyCap && finalSupply > initialSupply) {
            revert SupplyCapExceeded();
        }

        // or the borrow cap can be implemented like this:
        if (borrowCap != 0 && finalBorrowed > borrowCap && finalBorrowed > initialBorrowed) {
            revert BorrowCapExceeded();
        }
    }

    /// @notice Checks the status of an account.
    /// @dev This function is called after any action that may affect the account's state.
    /// @param account The account to check.
    /// @param collaterals The collaterals of the account.
    function doCheckAccountStatus(address account, address[] calldata collaterals) internal view virtual override {
        uint256 liabilityAssets = debtOf(account);

        if (liabilityAssets == 0) return;

        // in this simple example, let's say that it's only possible to borrow against
        // the same asset up to 90% of its value
        for (uint256 i = 0; i < collaterals.length; ++i) {
            if (collaterals[i] == address(this)) {
                uint256 collateral = _convertToAssets(balanceOf[account], false);
                uint256 maxLiability = (collateral * 9) / 10;

                if (liabilityAssets <= maxLiability) {
                    return;
                }
            }
        }

        revert AccountUnhealthy();
    }

    /// @notice Disables the controller for an account.
    /// @dev The controller is only disabled if the account has no debt.
    /// @param account The account to disable the controller for.
    function disableController(address account) external override nonReentrant {
        // ensure that the account does not have any liabilities before disabling controller
        if (debtOf(account) == 0) {
            releaseAccountFromControl(account);
        }
    }

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address token) public view returns (uint256) {
        return token == address(asset) ? asset.balanceOf(address(this)) : 0;
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address token, uint256) public view returns (uint256) {
        if (token == address(asset)) {
            return 0;
        } else {
            revert FlashloanNotSupported();
        }
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        if (token != address(asset)) {
            revert FlashloanNotSupported();
        } else if (maxFlashLoan(token) < amount) {
            revert FlashloanFailure();
        }

        uint256 origBalance = ERC20(token).balanceOf(address(this));

        ERC20(token).safeTransfer(address(receiver), amount);

        uint256 fee = flashFee(token, amount);
        bytes32 result = receiver.onFlashLoan(msg.sender, token, amount, fee, data);

        if (
            result != keccak256("ERC3156FlashBorrower.onFlashLoan")
                || ERC20(token).balanceOf(address(this)) < origBalance + fee
        ) {
            revert FlashloanFailure();
        }

        return true;
    }

    /// @notice Borrows assets.
    /// @dev This function transfers the specified amount of assets to the receiver.
    /// @param assets The amount of assets to borrow.
    /// @param receiver The receiver of the assets.
    function borrow(uint256 assets, address receiver) external routedThroughEVC nonReentrant {
        address msgSender = EVCAuthenticate(true);

        takeVaultSnapshot();

        require(assets != 0, "ZERO_ASSETS");

        receiver = getAccountOwner(receiver == address(0) ? msgSender : receiver);

        _increaseOwed(msgSender, assets);

        emit Borrow(msgSender, receiver, assets);

        asset.safeTransfer(receiver, assets);

        requireAccountAndVaultStatusCheck(msgSender);
    }

    /// @notice Repays a debt.
    /// @dev This function transfers the specified amount of assets from the caller to the vault.
    /// @param assets The amount of assets to repay.
    /// @param receiver The receiver of the repayment.
    function repay(uint256 assets, address receiver) external routedThroughEVC nonReentrant {
        address msgSender = EVCAuthenticate(false);

        takeVaultSnapshot();

        require(assets != 0, "ZERO_ASSETS");

        if (!isControllerEnabled(receiver, address(this))) {
            revert ControllerDisabled();
        }

        asset.safeTransferFrom(msgSender, address(this), assets);

        _decreaseOwed(receiver, assets);

        emit Repay(msgSender, receiver, assets);

        if (debtOf(receiver) == 0) {
            releaseAccountFromControl(receiver);
        }

        requireAccountAndVaultStatusCheck(address(0));
    }

    /// @notice Winds up the vault.
    /// @dev This function deposits assets into the vault and borrows the same amount.
    /// @dev Despite the lack of asset transfers, this function emits Deposit and Borrow events.
    /// @param assets The amount of assets to wind up.
    /// @param collateralReceiver The receiver of the collateral.
    /// @return shares The amount of shares minted.
    function wind(
        uint256 assets,
        address collateralReceiver
    ) external routedThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = EVCAuthenticate(true);

        takeVaultSnapshot();

        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        _mint(collateralReceiver, shares);

        _increaseOwed(msgSender, assets);

        emit Deposit(msgSender, collateralReceiver, assets, shares);
        emit Borrow(msgSender, msgSender, assets);

        requireAccountAndVaultStatusCheck(msgSender);
    }

    /// @notice Unwinds the vault.
    /// @dev This function repays a debt and withdraws the same amount of assets.
    /// @dev Despite the lack of asset transfers, this function emits Repay and Withdraw events.
    /// @param assets The amount of assets to unwind.
    /// @param debtFrom The account to repay the debt from.
    /// @return shares The amount of shares burned.
    function unwind(uint256 assets, address debtFrom) external routedThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = EVCAuthenticate(true);

        takeVaultSnapshot();

        shares = previewWithdraw(assets);

        _decreaseOwed(debtFrom, assets);

        _burn(msgSender, shares);

        emit Repay(msgSender, debtFrom, assets);
        emit Withdraw(msgSender, msgSender, msgSender, assets, shares);

        if (debtOf(debtFrom) == 0) {
            releaseAccountFromControl(debtFrom);
        }

        requireAccountAndVaultStatusCheck(msgSender);
    }

    /// @notice Pulls debt from an account.
    /// @dev This function decreases the debt of one account and increases the debt of another.
    /// @dev Despite the lack of asset transfers, this function emits Repay and Borrow events.
    /// @param from The account to pull the debt from.
    /// @param assets The amount of debt to pull.
    /// @return A boolean indicating whether the operation was successful.
    function pullDebt(address from, uint256 assets) external routedThroughEVC nonReentrant returns (bool) {
        address msgSender = EVCAuthenticate(true);

        takeVaultSnapshot();

        require(assets != 0, "ZERO_AMOUNT");
        require(msgSender != from, "SELF_DEBT_PULL");

        _decreaseOwed(from, assets);
        _increaseOwed(msgSender, assets);

        emit Repay(msgSender, from, assets);
        emit Borrow(msgSender, msgSender, assets);

        if (debtOf(from) == 0) {
            releaseAccountFromControl(from);
        }

        requireAccountAndVaultStatusCheck(msgSender);

        return true;
    }

    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    function _convertToShares(uint256 assets, bool roundUp) internal view virtual override returns (uint256) {
        (uint256 currentTotalBorrowed,,) = _accrueInterestCalculate();

        return roundUp
            ? assets.mulDivUp(totalSupply + 1, totalAssets() + currentTotalBorrowed + 1)
            : assets.mulDivDown(totalSupply + 1, totalAssets() + currentTotalBorrowed + 1);
    }

    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    function _convertToAssets(uint256 shares, bool roundUp) internal view virtual override returns (uint256) {
        (uint256 currentTotalBorrowed,,) = _accrueInterestCalculate();

        return roundUp
            ? shares.mulDivUp(totalAssets() + currentTotalBorrowed + 1, totalSupply + 1)
            : shares.mulDivDown(totalAssets() + currentTotalBorrowed + 1, totalSupply + 1);
    }

    /// @notice Increases the owed amount of an account.
    /// @param account The account.
    /// @param assets The assets.
    function _increaseOwed(address account, uint256 assets) internal virtual {
        owed[account] = debtOf(account) + assets;
        totalBorrowed += assets;
    }

    /// @notice Decreases the owed amount of an account.
    /// @param account The account.
    /// @param assets The assets.
    function _decreaseOwed(address account, uint256 assets) internal virtual {
        owed[account] = debtOf(account) - assets;
        totalBorrowed -= assets;
    }

    /// @notice Returns the last timestamp when the interest was updated.
    function _lastInterestUpdate() internal view virtual returns (uint256) {
        return 0;
    }

    /// @notice Accrues interest.
    /// @dev Because this contract does not implement the interest accrual, this function does not need to update the
    /// state, but only returns the current value of total borrows and 0 for the interest accumulator. This function is
    /// needed so that it can be overriden by child contracts without a need to override other functions which use it.
    /// @return The current values of total borrowed and interest accumulator.
    function _accrueInterest() internal virtual returns (uint256, uint256) {
        return (totalBorrowed, 0);
    }

    /// @notice Calculates the accrued interest.
    /// @dev Because this contract does not implement the interest accrual, this function does not need to calculate the
    /// interest, but only returns the current value of total borrows, 0 for the interest accumulator and false for the
    /// update flag. This function is needed so that it can be overriden by child contracts without a need to override
    /// other functions which use it.
    /// @return The total borrowed amount, the interest accumulator and a boolean value that indicates whether the data
    /// should be updated.
    function _accrueInterestCalculate() internal view virtual returns (uint256, uint256, bool) {
        return (totalBorrowed, 0, false);
    }

    /// @notice Updates the interest rate.
    function _updateInterest() internal virtual {}
}
