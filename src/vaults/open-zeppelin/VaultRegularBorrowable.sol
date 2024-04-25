// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "../../interfaces/IIRM.sol";
import "../../interfaces/IPriceOracle.sol";
import "./VaultSimple.sol";

/// @title VaultRegularBorrowable
/// @notice This contract extends VaultSimple to add borrowing functionality along with interest rate accrual,
/// recognition of external collateral vaults and liquidations.
/// @notice In this contract, the EVC is authenticated before any action that may affect the state of the vault or an
/// account. This is done to ensure that if it's EVC calling, the account is correctly authorized and the vault is
/// enabled as a controller if needed. This contract does not take the account health into account when calculating max
/// withdraw and max redeem values.
contract VaultRegularBorrowable is VaultSimple {
    using Math for uint256;

    uint256 internal constant COLLATERAL_FACTOR_SCALE = 100;
    uint256 internal constant MAX_LIQUIDATION_INCENTIVE = 20;
    uint256 internal constant TARGET_HEALTH_FACTOR = 125;
    uint256 internal constant ONE = 1e27;
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = uint256(5 * ONE) / SECONDS_PER_YEAR; // 500% APR

    uint256 public borrowCap;
    uint256 internal _totalBorrowed;
    uint256 internal interestRate;
    uint256 internal lastInterestUpdate;
    uint256 internal interestAccumulator;
    mapping(address account => uint256 assets) internal owed;
    mapping(address asset => uint256) internal collateralFactor;

    // IRM
    IIRM public irm;

    // oracle
    ERC20 public referenceAsset; // This is the asset that we use to calculate the value of all other assets
    IPriceOracle public oracle;

    event BorrowCapSet(uint256 newBorrowCap);
    event Borrow(address indexed caller, address indexed owner, uint256 assets);
    event Repay(address indexed caller, address indexed receiver, uint256 assets);

    error BorrowCapExceeded();
    error AccountUnhealthy();
    error OutstandingDebt();
    error InvalidCollateralFactor();
    error SelfLiquidation();
    error ViolatorStatusCheckDeferred();
    error NoLiquidationOpportunity();
    error RepayAssetsInsufficient();
    error RepayAssetsExceeded();
    error CollateralDisabled();

    constructor(
        address _evc,
        IERC20 _asset,
        IIRM _irm,
        IPriceOracle _oracle,
        ERC20 _referenceAsset,
        string memory _name,
        string memory _symbol
    ) VaultSimple(_evc, _asset, _name, _symbol) {
        irm = _irm;
        oracle = _oracle;
        referenceAsset = _referenceAsset;
        lastInterestUpdate = block.timestamp;
        interestAccumulator = ONE;
    }

    /// @notice Sets the borrow cap.
    /// @param newBorrowCap The new borrow cap.
    function setBorrowCap(uint256 newBorrowCap) external onlyOwner {
        borrowCap = newBorrowCap;
        emit BorrowCapSet(newBorrowCap);
    }

    /// @notice Sets the IRM of the vault.
    /// @param _irm The new IRM.
    function setIRM(IIRM _irm) external onlyOwner {
        irm = _irm;
    }

    /// @notice Sets the reference asset of the vault.
    /// @param _referenceAsset The new reference asset.
    function setReferenceAsset(ERC20 _referenceAsset) external onlyOwner {
        referenceAsset = _referenceAsset;
    }

    /// @notice Sets the price oracle of the vault.
    /// @param _oracle The new price oracle.
    function setOracle(IPriceOracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    /// @notice Sets the collateral factor of an asset.
    /// @param _asset The asset.
    /// @param _collateralFactor The new collateral factor.
    function setCollateralFactor(address _asset, uint256 _collateralFactor) external onlyOwner {
        if (_collateralFactor > COLLATERAL_FACTOR_SCALE) {
            revert InvalidCollateralFactor();
        }

        collateralFactor[_asset] = _collateralFactor;
    }

    /// @notice Gets the current interest rate of the vault.
    /// @dev Reverts if the vault status check is deferred because the interest rate is calculated in the
    /// checkVaultStatus().
    /// @return The current interest rate.
    function getInterestRate() external view returns (uint256) {
        if (isVaultStatusCheckDeferred(address(this))) {
            (uint256 borrowed,,) = _accrueInterestCalculate();

            uint256 newInterestRate = irm.computeInterestRateView(address(this), _totalAssets, borrowed);

            if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) {
                newInterestRate = MAX_ALLOWED_INTEREST_RATE;
            }

            return newInterestRate;
        } else {
            return interestRate;
        }
    }

    /// @notice Gets the collateral factor of an asset.
    /// @param _asset The asset.
    /// @return The collateral factor.
    function getCollateralFactor(address _asset) external view returns (uint256) {
        return collateralFactor[_asset];
    }

    /// @notice Returns the total borrowed assets from the vault.
    /// @return The total borrowed assets from the vault.
    function totalBorrowed() public view virtual returns (uint256) {
        (uint256 currentTotalBorrowed,,) = _accrueInterestCalculate();
        return currentTotalBorrowed;
    }

    /// @notice Returns the debt of an account.
    /// @param account The account to check.
    /// @return The debt of the account.
    function debtOf(address account) public view virtual returns (uint256) {
        return _debtOf(account);
    }

    /// @notice Returns the maximum amount that can be withdrawn by an owner.
    /// @dev This function is overridden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be withdrawn.
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        uint256 totAssets = _totalAssets;
        uint256 ownerAssets = _convertToAssets(balanceOf(owner), Math.Rounding.Floor);

        return ownerAssets > totAssets ? totAssets : ownerAssets;
    }

    /// @notice Returns the maximum amount that can be redeemed by an owner.
    /// @dev This function is overridden to take into account the fact that some of the assets may be borrowed.
    /// @param owner The owner of the assets.
    /// @return The maximum amount that can be redeemed.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        uint256 totAssets = _totalAssets;
        uint256 ownerShares = balanceOf(owner);

        return _convertToAssets(ownerShares, Math.Rounding.Floor) > totAssets
            ? _convertToShares(totAssets, Math.Rounding.Floor)
            : ownerShares;
    }

    /// @dev This function is overridden to take into account the fact that some of the assets may be borrowed.
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    ) internal view virtual override returns (uint256) {
        (uint256 currentTotalBorrowed,,) = _accrueInterestCalculate();

        return
            assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + currentTotalBorrowed + 1, rounding);
    }

    /// @dev This function is overridden to take into account the fact that some of the assets may be borrowed.
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual override returns (uint256) {
        (uint256 currentTotalBorrowed,,) = _accrueInterestCalculate();

        return
            shares.mulDiv(totalAssets() + currentTotalBorrowed + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /// @notice Creates a snapshot of the vault.
    /// @dev This function is called before any action that may affect the vault's state. Considering that and the fact
    /// that this function is only called once per the EVC checks deferred context, it can be also used to accrue
    /// interest.
    /// @return A snapshot of the vault's state.
    function doCreateVaultSnapshot() internal virtual override returns (bytes memory) {
        (uint256 currentTotalBorrowed,) = _accrueInterest();

        // make total assets and total borrows snapshot:
        return abi.encode(_totalAssets, currentTotalBorrowed);
    }

    /// @notice Checks the vault's status.
    /// @dev This function is called after any action that may affect the vault's state. Considering that and the fact
    /// that this function is only called once per the EVC checks deferred context, it can be also used to update the
    /// interest rate. `IVault.checkVaultStatus` can only be called from the EVC and only while checks are in progress
    /// because of the `onlyEVCWithChecksInProgress` modifier. So it can't be called at any other time to reset the
    /// snapshot mid-batch.
    /// @param oldSnapshot The snapshot of the vault's state before the action.
    function doCheckVaultStatus(bytes memory oldSnapshot) internal virtual override {
        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) revert SnapshotNotTaken();

        // use the vault status hook to update the interest rate (it should happen only once per transaction).
        // EVC.forgiveVaultStatus check should never be used for this vault, otherwise the interest rate will not be
        // updated.
        // this contract doesn't implement the interest accrual, so this function does nothing. needed for the sake of
        // inheritance
        _updateInterest();

        // validate the vault state here:
        (uint256 initialAssets, uint256 initialBorrowed) = abi.decode(oldSnapshot, (uint256, uint256));
        uint256 finalAssets = _totalAssets;
        (uint256 finalBorrowed,,) = _accrueInterestCalculate();

        // the supply cap can be implemented like this:
        if (
            supplyCap != 0 && finalAssets + finalBorrowed > supplyCap
                && finalAssets + finalBorrowed > initialAssets + initialBorrowed
        ) {
            revert SupplyCapExceeded();
        }

        // or the borrow cap can be implemented like this:
        if (borrowCap != 0 && finalBorrowed > borrowCap && finalBorrowed > initialBorrowed) {
            revert BorrowCapExceeded();
        }
    }

    /// @notice Checks the status of an account.
    /// @param account The account.
    /// @param collaterals The collaterals of the account.
    function doCheckAccountStatus(address account, address[] calldata collaterals) internal view virtual override {
        (, uint256 liabilityValue, uint256 collateralValue) =
            _calculateLiabilityAndCollateral(account, collaterals, true);

        if (liabilityValue > collateralValue) {
            revert AccountUnhealthy();
        }
    }

    /// @notice Disables the controller.
    /// @dev The controller is only disabled if the account has no debt. If the account has outstanding debt, the
    /// function reverts.
    function disableController() external virtual override nonReentrant {
        // ensure that the account does not have any liabilities before disabling controller
        address msgSender = _msgSender();
        if (_debtOf(msgSender) == 0) {
            EVCClient.disableController(msgSender);
        } else {
            revert OutstandingDebt();
        }
    }

    /// @notice Retrieves the liability and collateral value of a given account.
    /// @dev Account status is considered healthy if the collateral value is greater than or equal to the liability.
    /// @param account The address of the account to retrieve the liability and collateral value for.
    /// @return liabilityValue The total liability value of the account.
    /// @return collateralValue The total collateral value of the account.
    function getAccountLiabilityStatus(address account)
        external
        view
        virtual
        returns (uint256 liabilityValue, uint256 collateralValue)
    {
        (, liabilityValue, collateralValue) = _calculateLiabilityAndCollateral(account, getCollaterals(account), false);
    }

    /// @notice Borrows assets.
    /// @param assets The amount of assets to borrow.
    /// @param receiver The receiver of the assets.
    function borrow(uint256 assets, address receiver) external callThroughEVC nonReentrant {
        address msgSender = _msgSenderForBorrow();

        createVaultSnapshot();

        require(assets != 0, "ZERO_ASSETS");

        _increaseOwed(msgSender, assets);

        emit Borrow(msgSender, receiver, assets);

        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        _totalAssets -= assets;

        requireAccountAndVaultStatusCheck(msgSender);
    }

    /// @notice Repays a debt.
    /// @dev This function transfers the specified amount of assets from the caller to the vault.
    /// @param assets The amount of assets to repay.
    /// @param receiver The receiver of the repayment.
    function repay(uint256 assets, address receiver) external callThroughEVC nonReentrant {
        address msgSender = _msgSender();

        // sanity check: the receiver must be under control of the EVC. otherwise, we allowed to disable this vault as
        // the controller for an account with debt
        if (!isControllerEnabled(receiver, address(this))) {
            revert ControllerDisabled();
        }

        createVaultSnapshot();

        require(assets != 0, "ZERO_ASSETS");

        SafeERC20.safeTransferFrom(IERC20(asset()), msgSender, address(this), assets);

        _totalAssets += assets;

        _decreaseOwed(receiver, assets);

        emit Repay(msgSender, receiver, assets);

        requireAccountAndVaultStatusCheck(address(0));
    }

    /// @notice Pulls debt from an account.
    /// @dev This function decreases the debt of one account and increases the debt of another.
    /// @dev Despite the lack of asset transfers, this function emits Repay and Borrow events.
    /// @param from The account to pull the debt from.
    /// @param assets The amount of debt to pull.
    /// @return A boolean indicating whether the operation was successful.
    function pullDebt(address from, uint256 assets) external callThroughEVC nonReentrant returns (bool) {
        address msgSender = _msgSenderForBorrow();

        // sanity check: the account from which the debt is pulled must be under control of the EVC.
        // _msgSenderForBorrow() checks that `msgSender` is controlled by this vault
        if (!isControllerEnabled(from, address(this))) {
            revert ControllerDisabled();
        }

        createVaultSnapshot();

        require(assets != 0, "ZERO_AMOUNT");
        require(msgSender != from, "SELF_DEBT_PULL");

        _decreaseOwed(from, assets);
        _increaseOwed(msgSender, assets);

        emit Repay(msgSender, from, assets);
        emit Borrow(msgSender, msgSender, assets);

        requireAccountAndVaultStatusCheck(msgSender);

        return true;
    }

    /// @notice Liquidates a violator account.
    /// @param violator The violator account.
    /// @param collateral The collateral of the violator.
    /// @param repayAssets The assets to repay.
    function liquidate(
        address violator,
        address collateral,
        uint256 repayAssets
    ) external callThroughEVC nonReentrant {
        address msgSender = _msgSenderForBorrow();

        if (msgSender == violator) {
            revert SelfLiquidation();
        }

        if (repayAssets == 0) {
            revert RepayAssetsInsufficient();
        }

        // due to later violator's account check forgiveness,
        // the violator's account must be fully settled when liquidating
        if (isAccountStatusCheckDeferred(violator)) {
            revert ViolatorStatusCheckDeferred();
        }

        // sanity check: the violator must be under control of the EVC
        if (!isControllerEnabled(violator, address(this))) {
            revert ControllerDisabled();
        }

        createVaultSnapshot();

        uint256 seizeAssets = _calculateAssetsToSeize(violator, collateral, repayAssets);

        _decreaseOwed(violator, repayAssets);
        _increaseOwed(msgSender, repayAssets);

        emit Repay(msgSender, violator, repayAssets);
        emit Borrow(msgSender, msgSender, repayAssets);

        if (collateral == address(this)) {
            // if the liquidator tries to seize the assets from this vault,
            // we need to be sure that the violator has enabled this vault as collateral
            if (!isCollateralEnabled(violator, collateral)) {
                revert CollateralDisabled();
            }

            _update(violator, msgSender, seizeAssets);
        } else {
            // if external assets are being seized, the EVC will take care of safety
            // checks during the collateral control
            liquidateCollateralShares(collateral, violator, msgSender, seizeAssets);

            // there's a possibility that the liquidation does not bring the violator back to
            // a healthy state or the liquidator chooses not to repay enough to bring the violator
            // back to health. hence, the account status check that is scheduled during the
            // controlCollateral may fail reverting the liquidation. hence, as a controller, we
            // can forgive the account status check for the violator allowing it to end up in
            // an unhealthy state after the liquidation.
            // IMPORTANT: the account status check forgiveness must be done with care!
            // a malicious collateral could do some funky stuff during the controlCollateral
            // leading to withdrawal of more collateral than specified, or withdrawal of other
            // collaterals, leaving us with bad debt. to prevent that, we ensure that only
            // collaterals with cf > 0 can be seized which means that only vetted collaterals
            // are seizable and cannot do any harm during the controlCollateral.
            // the other option would be to snapshot the balances of all the collaterals
            // before the controlCollateral and compare them with expected balances after the
            // controlCollateral. however, this is out of scope for this playground.
            forgiveAccountStatusCheck(violator);
        }

        requireAccountAndVaultStatusCheck(msgSender);
    }

    /// @notice Calculates the liability and collateral of an account.
    /// @param account The account.
    /// @param collaterals The collaterals of the account.
    /// @param skipCollateralIfNoLiability A flag indicating whether to skip collateral calculation if the account has
    /// no liability.
    /// @return liabilityAssets The liability assets.
    /// @return liabilityValue The liability value.
    /// @return collateralValue The risk-adjusted collateral value.
    function _calculateLiabilityAndCollateral(
        address account,
        address[] memory collaterals,
        bool skipCollateralIfNoLiability
    ) internal view virtual returns (uint256 liabilityAssets, uint256 liabilityValue, uint256 collateralValue) {
        liabilityAssets = _debtOf(account);

        if (liabilityAssets == 0 && skipCollateralIfNoLiability) {
            return (0, 0, 0);
        } else if (liabilityAssets > 0) {
            // Calculate the value of the liability in terms of the reference asset
            liabilityValue = IPriceOracle(oracle).getQuote(liabilityAssets, asset(), address(referenceAsset));
        }

        // Calculate the aggregated value of the collateral in terms of the reference asset
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];
            uint256 cf = collateralFactor[collateral];

            // Collaterals with a collateral factor of 0 are worthless
            if (cf != 0) {
                uint256 collateralAssets = ERC20(collateral).balanceOf(account);

                if (collateralAssets > 0) {
                    collateralValue += (
                        IPriceOracle(oracle).getQuote(collateralAssets, collateral, address(referenceAsset)) * cf
                    ) / COLLATERAL_FACTOR_SCALE;
                }
            }
        }
    }

    /// @notice Calculates the amount of assets to seize from a violator's account during a liquidation event.
    /// @dev This function is used during the liquidation process to determine the amount of collateral to seize.
    /// @param violator The address of the violator's account.
    /// @param collateral The address of the collateral to be seized.
    /// @param repayAssets The amount of assets the liquidator is attempting to repay.
    /// @return The amount of collateral shares to seize from the violator's account.
    function _calculateAssetsToSeize(
        address violator,
        address collateral,
        uint256 repayAssets
    ) internal view returns (uint256) {
        // do not allow to seize the assets for collateral without a collateral factor.
        // note that a user can enable any address as collateral, even if it's not recognized
        // as such (cf == 0)
        uint256 cf = collateralFactor[collateral];
        if (cf == 0) {
            revert CollateralDisabled();
        }

        (uint256 liabilityAssets, uint256 liabilityValue, uint256 collateralValue) =
            _calculateLiabilityAndCollateral(violator, getCollaterals(violator), true);

        // trying to repay more than the violator owes
        if (repayAssets > liabilityAssets) {
            revert RepayAssetsExceeded();
        }

        // check if violator's account is unhealthy
        if (collateralValue >= liabilityValue) {
            revert NoLiquidationOpportunity();
        }

        // calculate dynamic liquidation incentive
        uint256 liquidationIncentive = 100 - (100 * collateralValue) / liabilityValue;

        if (liquidationIncentive > MAX_LIQUIDATION_INCENTIVE) {
            liquidationIncentive = MAX_LIQUIDATION_INCENTIVE;
        }

        // calculate the max repay value that will bring the violator back to target health factor
        uint256 maxRepayValue = (TARGET_HEALTH_FACTOR * liabilityValue - 100 * collateralValue)
            / (TARGET_HEALTH_FACTOR - (cf * (100 + liquidationIncentive)) / 100);

        // get the desired value of repay assets
        uint256 repayValue = IPriceOracle(oracle).getQuote(repayAssets, asset(), address(referenceAsset));

        // check if the liquidator is not trying to repay too much.
        // this prevents the liquidator from liquidating entire position if not necessary.
        // if the at least half of the debt needs to be repaid to bring the account back to target health factor,
        // the liquidator can repay the entire debt.
        if (repayValue > maxRepayValue && maxRepayValue < liabilityValue / 2) {
            revert RepayAssetsExceeded();
        }

        // the liquidator will be transferred the collateral value of the repaid debt + the liquidation incentive
        uint256 seizeValue = (repayValue * (100 + liquidationIncentive)) / 100;
        uint256 shareUnit = 10 ** ERC20(collateral).decimals();

        uint256 seizeAssets =
            (seizeValue * shareUnit) / IPriceOracle(oracle).getQuote(shareUnit, collateral, address(referenceAsset));

        if (seizeAssets == 0) {
            revert RepayAssetsInsufficient();
        }

        return seizeAssets;
    }

    /// @notice Increases the owed amount of an account.
    /// @dev This function is overridden to snapshot the interest accumulator for the account.
    /// @param account The account.
    /// @param assets The assets.
    function _increaseOwed(address account, uint256 assets) internal virtual {
        (, uint256 currentInterestAccumulator,) = _accrueInterestCalculate();

        uint256 delta = (assets * ONE + currentInterestAccumulator / 2) / currentInterestAccumulator;
        owed[account] += delta;
        _totalBorrowed += delta;
    }

    /// @notice Decreases the owed amount of an account.
    /// @dev This function is overridden to snapshot the interest accumulator for the account.
    /// @param account The account.
    /// @param assets The assets.
    function _decreaseOwed(address account, uint256 assets) internal virtual {
        (, uint256 currentInterestAccumulator,) = _accrueInterestCalculate();

        uint256 delta = (assets * ONE + currentInterestAccumulator / 2) / currentInterestAccumulator;
        owed[account] -= delta;

        uint256 __totalBorrowed = _totalBorrowed;
        _totalBorrowed = __totalBorrowed >= delta ? __totalBorrowed - delta : 0;
    }

    /// @notice Returns the debt of an account.
    /// @dev This function is overridden to take into account the interest rate accrual.
    /// @param account The account.
    /// @return The debt of the account.
    function _debtOf(address account) internal view virtual returns (uint256) {
        uint256 debt = owed[account];

        if (debt == 0) return 0;

        (, uint256 currentInterestAccumulator,) = _accrueInterestCalculate();

        return (debt * currentInterestAccumulator + ONE / 2) / ONE;
    }

    /// @notice Accrues interest.
    /// @return The current values of total borrowed and interest accumulator.
    function _accrueInterest() internal virtual returns (uint256, uint256) {
        (uint256 currentTotalBorrowed, uint256 currentInterestAccumulator, bool shouldUpdate) =
            _accrueInterestCalculate();

        if (shouldUpdate) {
            interestAccumulator = currentInterestAccumulator;
            lastInterestUpdate = block.timestamp;
        }

        return (currentTotalBorrowed, currentInterestAccumulator);
    }

    /// @notice Calculates the accrued interest.
    /// @return The total borrowed amount, the interest accumulator and a boolean value that indicates whether the data
    /// should be updated.
    function _accrueInterestCalculate() internal view virtual returns (uint256, uint256, bool) {
        uint256 timeElapsed = block.timestamp - lastInterestUpdate;
        uint256 borrowed = _totalBorrowed;
        uint256 accumulator = interestAccumulator;

        if (timeElapsed == 0) {
            return ((borrowed * accumulator + ONE / 2) / ONE, accumulator, false);
        }

        accumulator = (FixedPointMathLib.rpow(interestRate + ONE, timeElapsed, ONE) * accumulator) / ONE;

        return ((borrowed * accumulator + ONE / 2) / ONE, accumulator, true);
    }

    /// @notice Updates the interest rate.
    function _updateInterest() internal virtual {
        (uint256 borrowed,,) = _accrueInterestCalculate();

        uint256 newInterestRate = irm.computeInterestRate(address(this), _totalAssets, borrowed);

        if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) {
            newInterestRate = MAX_ALLOWED_INTEREST_RATE;
        }

        interestRate = newInterestRate;
    }
}
