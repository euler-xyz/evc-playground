// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../interfaces/IIRM.sol";
import "../interfaces/IPriceOracle.sol";
import "./CreditVaultSimpleBorrowable.sol";

contract CreditVaultRegularBorrowable is CreditVaultSimpleBorrowable {
    using SafeTransferLib for ERC20;
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

    function setIRM(IIRM _irm) external onlyOwner {
        irm = _irm;
    }

    function setReferenceAsset(ERC20 _referenceAsset) external onlyOwner {
        referenceAsset = _referenceAsset;
    }

    function setOracle(IPriceOracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setCollateralFactor(
        ERC4626 vault,
        uint _collateralFactor
    ) external onlyOwner {
        if (_collateralFactor > COLLATERAL_FACTOR_SCALE) {
            revert InvalidCollateralFactor();
        }

        collateralFactor[vault] = _collateralFactor;
    }

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

    function doCheckAccountStatus(
        address account,
        address[] calldata collaterals
    ) internal view virtual override returns (bool, bytes memory) {
        if (debtOf(account) == 0) return (true, "");

        (
            ,
            uint liabilityValue,
            uint collateralValue
        ) = _calculateLiabilityAndCollateral(account, collaterals);

        if (collateralValue >= liabilityValue) {
            return (true, "");
        }

        return (false, "account unhealthy");
    }

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
            if (!isCollateralEnabled(violator, collateral)) {
                revert CollateralDisabled();
            }

            balanceOf[violator] -= seizeShares;
            balanceOf[msgSender] += seizeShares;

            emit Transfer(violator, msgSender, seizeShares);
        } else {
            liquidateCollateralShares(
                collateral,
                violator,
                msgSender,
                seizeShares
            );
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

            if (
                (100 * collateralValue) / liabilityValue >
                MAX_HEALTH_FACTOR_AFTER_LIQUIDATION
            ) {
                revert RepayAssetsExceeded();
            }
        }
    }

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

    function _increaseOwed(
        address account,
        uint assets
    ) internal virtual override {
        super._increaseOwed(account, assets);
        userInterestAccumulator[account] = interestAccumulator;
    }

    function _decreaseOwed(
        address account,
        uint assets
    ) internal virtual override {
        super._decreaseOwed(account, assets);
        userInterestAccumulator[account] = interestAccumulator;
    }

    function _accrueInterest() internal virtual override {
        if (lastInterestUpdate == block.timestamp) return;

        (totalBorrowed, interestAccumulator) = _accrueInterestCalculate();
        lastInterestUpdate = block.timestamp;
    }

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
