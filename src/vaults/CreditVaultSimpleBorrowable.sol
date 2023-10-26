// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./CreditVaultSimple.sol";

interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

/// @title CreditVaultSimpleBorrowable
/// @notice This contract extends CreditVaultSimple to add borrowing functionality.
/// @notice In this contract, the CVC is authenticated before any action that may affect the state of the vault or an account.
/// This is done to ensure that if it's CVC calling, the account is correctly authorized and the vault is enabled as a controller if needed.
contract CreditVaultSimpleBorrowable is CreditVaultSimple {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event BorrowCapSet(uint newBorrowCap);
    event Borrow(address indexed caller, address indexed owner, uint256 assets);
    event Repay(
        address indexed caller,
        address indexed receiver,
        uint256 assets
    );

    error FlashloanNotRepaid();
    error BorrowCapExceeded();
    error AccountUnhealthy();

    uint public borrowCap;
    uint public totalBorrowed;
    mapping(address account => uint assets) internal owed;

    constructor(
        ICVC _cvc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) CreditVaultSimple(_cvc, _asset, _name, _symbol) {}

    /// @notice Sets the borrow cap.
    /// @param newBorrowCap The new borrow cap.
    function setBorrowCap(uint newBorrowCap) external onlyOwner {
        borrowCap = newBorrowCap;
        emit BorrowCapSet(newBorrowCap);
    }

    /// @notice Returns the debt of an account.
    /// @param account The account to check.
    /// @return The debt of the account.
    function debtOf(address account) public view virtual returns (uint) {
        return owed[account];
    }

    /// @notice Returns the maximum amount that can be withdrawn by an owner.
    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be withdrawn.
    function maxWithdraw(
        address owner
    ) public view virtual override returns (uint256) {
        return
            convertToAssets(balanceOf[owner]) > totalAssets()
                ? totalAssets()
                : convertToAssets(balanceOf[owner]);
    }

    /// @notice Returns the maximum amount that can be redeemed by an owner.
    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be redeemed.
    function maxRedeem(
        address owner
    ) public view virtual override returns (uint256) {
        return balanceOf[owner] > totalSupply ? totalSupply : balanceOf[owner];
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
        // make total supply and total borrows snapshot:
        return abi.encode(convertToAssets(totalSupply), totalBorrowed);
    }

    /// @notice Checks the vault's status.
    /// @dev This function is called after any action that may affect the vault's state.
    /// @param oldSnapshot The snapshot of the vault's state before the action.
    function doCheckVaultStatus(
        bytes memory oldSnapshot
    ) internal virtual override {
        // use the vault status hook to update the interest rate (it should happen only once per transaction)
        _updateInterest();

        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) revert SnapshotNotTaken();

        // validate the vault state here:
        (uint initialSupply, uint initialBorrowed) = abi.decode(
            oldSnapshot,
            (uint, uint)
        );
        uint finalSupply = convertToAssets(totalSupply);
        uint finalBorrowed = totalBorrowed;

        // the supply cap can be implemented like this:
        if (
            supplyCap != 0 &&
            finalSupply > supplyCap &&
            finalSupply > initialSupply
        ) {
            revert SupplyCapExceeded();
        }

        // or borrow cap can be implemented like this:
        if (
            borrowCap != 0 &&
            finalBorrowed > borrowCap &&
            finalBorrowed > initialBorrowed
        ) {
            revert BorrowCapExceeded();
        }
    }

    /// @notice Checks the status of an account.
    /// @dev This function is called after any action that may affect the account's state.
    /// @param account The account to check.
    /// @param collaterals The collaterals of the account.
    function doCheckAccountStatus(
        address account,
        address[] calldata collaterals
    ) internal view virtual override {
        uint liabilityAssets = debtOf(account);

        if (liabilityAssets == 0) return;

        // in this simple example, let's say that it's only possible to borrow against
        // the same asset up to 90% of its value
        for (uint i = 0; i < collaterals.length; ++i) {
            if (collaterals[i] == address(this)) {
                uint collateral = convertToAssets(balanceOf[account]);
                uint maxLiability = (collateral * 9) / 10;

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

    /// @notice Executes a flash loan.
    /// @dev This function transfers the specified amount of assets to the caller, and expects them to be returned by the end of the transaction.
    /// @param amount The amount of assets to loan.
    /// @param data The data to pass to the flash loan function.
    function flashLoan(
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        uint origBalance = asset.balanceOf(address(this));

        asset.safeTransfer(msg.sender, amount);

        IFlashLoan(msg.sender).onFlashLoan(data);

        if (asset.balanceOf(address(this)) < origBalance) {
            revert FlashloanNotRepaid();
        }
    }

    /// @notice Borrows assets.
    /// @dev This function transfers the specified amount of assets to the receiver.
    /// @param assets The amount of assets to borrow.
    /// @param receiver The receiver of the assets.
    function borrow(uint256 assets, address receiver) external {
        _borrow(CVCAuthenticateForBorrow(), assets, receiver);
    }

    /// @notice Repays a debt.
    /// @dev This function transfers the specified amount of assets from the caller to the vault.
    /// @param assets The amount of assets to repay.
    /// @param receiver The receiver of the repayment.
    function repay(uint256 assets, address receiver) external {
        _repay(CVCAuthenticate(), assets, receiver);
    }

    /// @notice Winds up the vault.
    /// @dev This function deposits assets into the vault and borrows the same amount.
    /// @param assets The amount of assets to wind up.
    /// @param collateralReceiver The receiver of the collateral.
    /// @return shares The amount of shares minted.
    function wind(
        uint256 assets,
        address collateralReceiver
    ) external returns (uint shares) {
        return _wind(CVCAuthenticateForBorrow(), assets, collateralReceiver);
    }

    /// @notice Unwinds the vault.
    /// @dev This function repays a debt and withdraws the same amount of assets.
    /// @param assets The amount of assets to unwind.
    /// @param debtFrom The account to repay the debt from.
    /// @return shares The amount of shares burned.
    function unwind(
        uint256 assets,
        address debtFrom
    ) external returns (uint shares) {
        return _unwind(CVCAuthenticateForBorrow(), assets, debtFrom);
    }

    /// @notice Pulls debt from an account.
    /// @dev This function decreases the debt of one account and increases the debt of another.
    /// @param from The account to pull the debt from.
    /// @param assets The amount of debt to pull.
    /// @return A boolean indicating whether the operation was successful.
    function pullDebt(address from, uint assets) external returns (bool) {
        return _pullDebt(CVCAuthenticateForBorrow(), from, assets);
    }

    function _borrow(
        address msgSender,
        uint256 assets,
        address receiver
    ) internal virtual nonReentrantWithChecks(msgSender) {
        _accrueInterest();

        require(assets != 0, "ZERO_ASSETS");

        _increaseOwed(msgSender, assets);

        emit Borrow(msgSender, receiver, assets);

        asset.safeTransfer(receiver, assets);
    }

    function _repay(
        address msgSender,
        uint256 assets,
        address receiver
    ) internal virtual nonReentrantWithChecks(address(0)) {
        _accrueInterest();

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
    }

    function _wind(
        address msgSender,
        uint256 assets,
        address collateralReceiver
    ) internal virtual nonReentrantWithChecks(msgSender) returns (uint shares) {
        _accrueInterest();

        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        _mint(collateralReceiver, shares);

        _increaseOwed(msgSender, assets);

        emit Deposit(msgSender, collateralReceiver, assets, shares);
        emit Borrow(msgSender, msgSender, assets);
    }

    function _unwind(
        address msgSender,
        uint256 assets,
        address debtFrom
    ) internal virtual nonReentrantWithChecks(msgSender) returns (uint shares) {
        _accrueInterest();

        shares = previewWithdraw(assets);

        _decreaseOwed(debtFrom, assets);

        _burn(msgSender, shares);

        emit Repay(msgSender, debtFrom, assets);
        emit Withdraw(msgSender, msgSender, msgSender, assets, shares);

        if (debtOf(debtFrom) == 0) {
            releaseAccountFromControl(debtFrom);
        }
    }

    function _pullDebt(
        address msgSender,
        address from,
        uint assets
    ) internal virtual nonReentrantWithChecks(msgSender) returns (bool) {
        _accrueInterest();

        require(assets != 0, "ZERO_AMOUNT");

        _decreaseOwed(from, assets);
        _increaseOwed(msgSender, assets);

        emit Repay(msgSender, from, assets);
        emit Borrow(msgSender, msgSender, assets);

        if (debtOf(from) == 0) {
            releaseAccountFromControl(from);
        }

        return true;
    }

    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    function _convertToShares(
        uint256 assets
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return
            supply == 0
                ? assets
                : assets.mulDivDown(supply, totalAssets() + totalBorrowed);
    }

    /// @dev This function is overriden to take into account the fact that some of the assets may be borrowed.
    function _convertToAssets(
        uint256 shares
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return
            supply == 0
                ? shares
                : shares.mulDivDown(totalAssets() + totalBorrowed, supply);
    }

    /// @notice Increases the owed amount of an account.
    /// @param account The account.
    /// @param assets The assets.
    function _increaseOwed(address account, uint assets) internal virtual {
        owed[account] = debtOf(account) + assets;
        totalBorrowed += assets;
    }

    /// @notice Decreases the owed amount of an account.
    /// @param account The account.
    /// @param assets The assets.
    function _decreaseOwed(address account, uint assets) internal virtual {
        owed[account] = debtOf(account) - assets;
        totalBorrowed -= assets;
    }

    function _accrueInterest() internal virtual {}

    function _updateInterest() internal virtual {}
}
