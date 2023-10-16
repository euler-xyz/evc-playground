// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./CreditVaultSimple.sol";

interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

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

    uint public borrowCap;
    uint public totalBorrowed;
    mapping(address account => uint assets) internal owed;

    constructor(
        ICVC _cvc,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) CreditVaultSimple(_cvc, _asset, _name, _symbol) {}

    function setBorrowCap(uint newBorrowCap) external onlyOwner {
        borrowCap = newBorrowCap;
        emit BorrowCapSet(newBorrowCap);
    }

    function debtOf(address account) public view virtual returns (uint) {
        return owed[account];
    }

    function maxWithdraw(
        address owner
    ) public view virtual override returns (uint256) {
        return
            convertToAssets(balanceOf[owner]) > totalAssets()
                ? totalAssets()
                : convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(
        address owner
    ) public view virtual override returns (uint256) {
        return balanceOf[owner] > totalSupply ? totalSupply : balanceOf[owner];
    }

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

    function doCheckVaultStatus(
        bytes memory oldSnapshot
    ) internal virtual override returns (bool, bytes memory) {
        // use the vault status hook to update the interest rate
        _updateInterest();

        // sanity check in case the snapshot hasn't been taken
        if (oldSnapshot.length == 0) {
            return (false, "snapshot not taken");
        }

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
            return (false, "supply cap exceeded");
        }

        // or borrow cap can be implemented like this:
        if (
            borrowCap != 0 &&
            finalBorrowed > borrowCap &&
            finalBorrowed > initialBorrowed
        ) {
            return (false, "borrow cap exceeded");
        }

        // if 90% of the assets were withdrawn, revert the transaction
        //if (finalSupply < initialSupply / 10) {
        //    return (false, "withdrawal too large");
        //}

        return (true, "");
    }

    function doCheckAccountStatus(
        address account,
        address[] calldata collaterals
    ) internal view virtual override returns (bool, bytes memory) {
        uint liabilityAssets = debtOf(account);

        if (liabilityAssets == 0) return (true, "");

        // in this simple example, let's say that it's only possible to borrow against
        // the same asset up to 90% of its value
        for (uint i = 0; i < collaterals.length; ++i) {
            if (collaterals[i] == address(this)) {
                uint collateral = convertToAssets(balanceOf[account]);
                uint maxLiability = (collateral * 9) / 10;

                if (liabilityAssets <= maxLiability) {
                    return (true, "");
                }
            }
        }

        return (false, "account unhealthy");
    }

    function disableController(address account) external override nonReentrant {
        if (debtOf(account) == 0) {
            disableSelfAsController(account);
        }
    }

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

    function borrow(uint256 assets, address receiver) external {
        _borrow(CVCAuthenticateForBorrow(), assets, receiver);
    }

    function repay(uint256 assets, address receiver) external {
        _repay(CVCAuthenticate(), assets, receiver);
    }

    function wind(
        uint256 assets,
        address collateralReceiver
    ) external returns (uint shares) {
        return _wind(CVCAuthenticateForBorrow(), assets, collateralReceiver);
    }

    function unwind(
        uint256 assets,
        address debtFrom
    ) external returns (uint shares) {
        return _unwind(CVCAuthenticateForBorrow(), assets, debtFrom);
    }

    function pullDebt(uint assets, address from) external returns (bool) {
        return _pullDebt(CVCAuthenticateForBorrow(), assets, from);
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
            disableSelfAsController(receiver);
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
            disableSelfAsController(debtFrom);
        }
    }

    function _pullDebt(
        address msgSender,
        uint assets,
        address from
    ) internal virtual nonReentrantWithChecks(msgSender) returns (bool) {
        _accrueInterest();

        require(assets != 0, "ZERO_AMOUNT");

        _decreaseOwed(from, assets);
        _increaseOwed(msgSender, assets);

        emit Repay(msgSender, from, assets);
        emit Borrow(msgSender, msgSender, assets);

        if (debtOf(from) == 0) {
            disableSelfAsController(from);
        }

        return true;
    }

    function _convertToShares(
        uint256 assets
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return
            supply == 0
                ? assets
                : assets.mulDivDown(supply, totalAssets() + totalBorrowed);
    }

    function _convertToAssets(
        uint256 shares
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return
            supply == 0
                ? shares
                : shares.mulDivDown(totalAssets() + totalBorrowed, supply);
    }

    function _increaseOwed(address account, uint assets) internal virtual {
        owed[account] = debtOf(account) + assets;
        totalBorrowed += assets;
    }

    function _decreaseOwed(address account, uint assets) internal virtual {
        owed[account] = debtOf(account) - assets;
        totalBorrowed -= assets;
    }

    function _accrueInterest() internal virtual {}

    function _updateInterest() internal virtual {}
}
