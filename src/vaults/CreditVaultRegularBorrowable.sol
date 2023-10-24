// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../interfaces/IIRM.sol";
import "../interfaces/IPriceOracle.sol";
import "./CreditVaultSimpleBorrowable.sol";

/// @title CreditVaultRegularBorrowable
/// @notice This contract extends CreditVaultSimpleBorrowable with additional features like interest rate accrual and recognition of external collateral vaults.
contract CreditVaultRegularBorrowable is CreditVaultSimpleBorrowable {
    using FixedPointMathLib for uint256;

    uint internal constant COLLATERAL_FACTOR_SCALE = 100;
    uint internal constant MAX_LIQUIDATION_INCENTIVE = 20;
    uint internal constant MAX_HEALTH_FACTOR_AFTER_LIQUIDATION = 125;

    int96 internal interestRate;
    uint internal lastInterestUpdate;
    uint internal interestAccumulator;
    mapping(address account => uint) internal userInterestAccumulator;
    mapping(ERC4626 vault => uint) internal collateralFactor;

    // IRM
    IIRM public irm;

    // oracle
    ERC20 public referenceAsset;
    IPriceOracle public oracle;

    error InvalidCollateralFactor();
    error SelfLiquidation();
    error ViolatorStatusCheckDeferred();
    error NoLiquidationOpportunity();
    error RepayAssetsExceeded();
    error CollateralDisabled();

    constructor(
        ICVC _cvc,
        ERC20 _asset,
        IIRM _irm,
        IPriceOracle _oracle,
        ERC20 _referenceAsset,
        string memory _name,
        string memory _symbol
    ) CreditVaultSimpleBorrowable(_cvc, _asset, _name, _symbol) {
        irm = _irm;
        oracle = _oracle;
        referenceAsset = _referenceAsset;
        lastInterestUpdate = block.timestamp;
        interestAccumulator = 1e27;
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

    /// @notice Sets the collateral factor of a vault.
    /// @param vault The vault.
    /// @param _collateralFactor The new collateral factor.
    function setCollateralFactor(
        ERC4626 vault,
        uint _collateralFactor
    ) external onlyOwner {
        if (_collateralFactor > COLLATERAL_FACTOR_SCALE) {
            revert InvalidCollateralFactor();
        }

        collateralFactor[vault] = _collateralFactor;
    }

    /// @notice Returns the debt of an account.
    /// @dev This function is overriden to take into account the interest rate accrual.
    /// @param account The account.
    /// @return The debt of the account.
    function debtOf(
        address account
    ) public view virtual override returns (uint) {
        uint debt = owed[account];

        if (debt == 0) return 0;

        uint256 currentInterestAccumulator;
        if (lastInterestUpdate == block.timestamp) {
            currentInterestAccumulator = interestAccumulator;
        } else {
            (, currentInterestAccumulator) = _accrueInterestCalculate();
        }

        return
            (debt * currentInterestAccumulator) /
            userInterestAccumulator[account];
    }

    /// @notice Checks the status of an account.
    /// @param account The account.
    /// @param collaterals The collaterals of the account.
    /// @return A boolean indicating whether the account is healthy, and a string with an error message if it's not.
    function doCheckAccountStatus(
        address account,
        address[] calldata collaterals
    ) internal view virtual override returns (bool, bytes memory) {
        if (debtOf(account) > 0) {
            (
                ,
                uint liabilityValue,
                uint collateralValue
            ) = _calculateLiabilityAndCollateral(account, collaterals);

            if (liabilityValue > collateralValue) {
                revert AccountUnhealthy();
            }
        }

        return (true, "");
    }

    /// @notice Liquidates a violator account.
    /// @param violator The violator account.
    /// @param collateral The collateral of the violator.
    /// @param repayAssets The assets to repay.
    function liquidate(
        address violator,
        address collateral,
        uint repayAssets
    ) external {
        _liquidate(
            CVCAuthenticateForBorrow(),
            violator,
            collateral,
            repayAssets
        );
    }

    function _liquidate(
        address msgSender,
        address violator,
        address collateral,
        uint repayAssets
    ) internal nonReentrantWithChecks(msgSender) {
        _accrueInterest();

        if (msgSender == violator) {
            revert SelfLiquidation();
        }

        if (isAccountStatusCheckDeferred(violator)) {
            revert ViolatorStatusCheckDeferred();
        }

        if (!isControllerEnabled(violator, address(this))) {
            revert ControllerDisabled();
        }

        // do not allow to seize the assets for collateral without a collateral factor.
        // note that a user can enable any address as collateral, even if it's not recognized
        // as such (cf == 0)
        if (collateralFactor[ERC4626(collateral)] == 0) {
            revert CollateralDisabled();
        }

        uint liquidationIncentive;
        {
            (
                uint liabilityAssets,
                uint liabilityValue,
                uint collateralValue
            ) = _calculateLiabilityAndCollateral(
                    violator,
                    getCollaterals(violator)
                );

            if (repayAssets > liabilityAssets) {
                revert RepayAssetsExceeded();
            }

            if (collateralValue >= liabilityValue) {
                revert NoLiquidationOpportunity();
            }

            // calculate dynamic liquidation incentive
            liquidationIncentive =
                100 -
                (100 * collateralValue) /
                liabilityValue;

            if (liquidationIncentive > MAX_LIQUIDATION_INCENTIVE) {
                liquidationIncentive = MAX_LIQUIDATION_INCENTIVE;
            }
        }

        address collateralAsset = address(ERC4626(collateral).asset());
        uint one = 10 ** ERC20(collateralAsset).decimals();

        // the liquidator will be transferred the collateral value of the repaid debt + the liquidation incentive
        uint seizeValue = (IPriceOracle(oracle).getQuote(
            repayAssets,
            address(asset),
            address(referenceAsset)
        ) * (100 + liquidationIncentive)) / 100;

        uint seizeAssets = (seizeValue * one) /
            IPriceOracle(oracle).getQuote(
                one,
                collateralAsset,
                address(referenceAsset)
            );

        uint seizeShares = ERC4626(collateral).convertToShares(seizeAssets);

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

            balanceOf[violator] -= seizeShares;
            balanceOf[msgSender] += seizeShares;

            emit Transfer(violator, msgSender, seizeShares);
        } else {
            // if external assets are being seized, the CVC will take care of safety
            // checks during the violator impersonation
            liquidateCollateralShares(
                collateral,
                violator,
                msgSender,
                seizeShares
            );

            // there's a possiblity that the liquidation does not bring the violator back to
            // a healthy state. hence, the account status check that is scheduled during the
            // impersonation may fail reverting the liquidation. hence, as a controller, we
            // can forgive the account status check for the violator allowing it end up in
            // an unhealthy state after the liquidation.
            // IMPORTANT: the account status check forgiveness must be done with care!
            // a malicious collateral could do some funky stuff during the impersonation
            // leading to withdrawal of more collateral than specified, or withdrawal of other
            // collaterals, leaving us with bad debt. to prevent that, we ensure that only
            // collaterals with cf > 0 can be seized which means that only vetted collaterals
            // are seizable and cannot do any harm during the impersonation.
            // the other option would be to snapshot the balances of all the collaterals
            // before the impersonation and compare them with expected balances after the
            // impersonation. however, this is out of scope for this playground.
            forgiveAccountStatusCheck(violator);
        }

        {
            (
                ,
                uint liabilityValue,
                uint collateralValue
            ) = _calculateLiabilityAndCollateral(
                    violator,
                    getCollaterals(violator)
                );

            // verify whether we haven't sent too much collateral to the liquidator
            if (
                liabilityValue != 0 &&
                (100 * collateralValue) / liabilityValue >
                MAX_HEALTH_FACTOR_AFTER_LIQUIDATION
            ) {
                revert RepayAssetsExceeded();
            }
        }
    }

    /// @notice Calculates the liability and collateral of an account.
    /// @param account The account.
    /// @param collaterals The collaterals of the account.
    /// @return liabilityAssets The liability assets.
    /// @return liabilityValue The liability value.
    /// @return collateralValue The risk-adjusted collateral value.
    function _calculateLiabilityAndCollateral(
        address account,
        address[] memory collaterals
    )
        internal
        view
        returns (
            uint liabilityAssets,
            uint liabilityValue,
            uint collateralValue
        )
    {
        liabilityAssets = debtOf(account);

        liabilityValue = IPriceOracle(oracle).getQuote(
            liabilityAssets,
            address(asset),
            address(referenceAsset)
        );

        for (uint i = 0; i < collaterals.length; ++i) {
            ERC4626 collateral = ERC4626(collaterals[i]);
            uint cf = collateralFactor[collateral];

            if (cf != 0) {
                collateralValue +=
                    (IPriceOracle(oracle).getQuote(
                        collateral.maxWithdraw(account),
                        address(collateral.asset()),
                        address(referenceAsset)
                    ) * cf) /
                    COLLATERAL_FACTOR_SCALE;
            }
        }
    }

    /// @dev This function is overriden to take into account the interest rate accrual.
    function _convertToShares(
        uint256 assets
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        if (supply == 0) return assets;

        uint256 assetsAndBorrows = totalAssets();
        if (lastInterestUpdate == block.timestamp) {
            assetsAndBorrows += totalBorrowed;
        } else {
            (uint newTotalBorrowed, ) = _accrueInterestCalculate();
            assetsAndBorrows += newTotalBorrowed;
        }

        return assets.mulDivDown(supply, assetsAndBorrows);
    }

    /// @dev This function is overriden to take into account the interest rate accrual.
    function _convertToAssets(
        uint256 shares
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        if (supply == 0) return shares;

        uint256 assetsAndBorrows = totalAssets();
        if (lastInterestUpdate == block.timestamp) {
            assetsAndBorrows += totalBorrowed;
        } else {
            (uint newTotalBorrowed, ) = _accrueInterestCalculate();
            assetsAndBorrows += newTotalBorrowed;
        }

        return shares.mulDivDown(assetsAndBorrows, supply);
    }

    /// @notice Increases the owed amount of an account.
    /// @dev This function is overriden to snaphot the interest accumulator for the account.
    /// @param account The account.
    /// @param assets The assets.
    function _increaseOwed(
        address account,
        uint assets
    ) internal virtual override {
        super._increaseOwed(account, assets);
        userInterestAccumulator[account] = interestAccumulator;
    }

    /// @notice Decreases the owed amount of an account.
    /// @dev This function is overriden to snaphot the interest accumulator for the account.
    /// @param account The account.
    /// @param assets The assets.
    function _decreaseOwed(
        address account,
        uint assets
    ) internal virtual override {
        super._decreaseOwed(account, assets);
        userInterestAccumulator[account] = interestAccumulator;
    }

    /// @notice Accrues interest.
    function _accrueInterest() internal virtual override {
        if (lastInterestUpdate == block.timestamp) return;

        (totalBorrowed, interestAccumulator) = _accrueInterestCalculate();
        lastInterestUpdate = block.timestamp;
    }

    /// @notice Calculates the accrued interest.
    /// @return The total borrowed amount and the interest accumulator.
    function _accrueInterestCalculate()
        internal
        view
        virtual
        returns (uint, uint)
    {
        uint timeElapsed = block.timestamp - lastInterestUpdate;
        uint oldInterestAccumulator = interestAccumulator;

        uint newInterestAccumulator = (FixedPointMathLib.rpow(
            uint(int(interestRate) + 1e27),
            timeElapsed,
            1e27
        ) * oldInterestAccumulator) / 1e27;

        uint newTotalBorrowed = (totalBorrowed * newInterestAccumulator) /
            oldInterestAccumulator;

        return (newTotalBorrowed, newInterestAccumulator);
    }

    /// @notice Updates the interest rate.
    function _updateInterest() internal virtual override {
        uint borrowed = totalBorrowed;
        uint poolAssets = totalAssets() + borrowed;

        uint32 utilisation;
        if (poolAssets != 0) {
            utilisation = uint32(
                (borrowed * type(uint32).max * 1e18) / poolAssets / 1e18
            );
        }

        interestRate = irm.computeInterestRate(
            address(this),
            address(asset),
            utilisation
        );
    }
}
