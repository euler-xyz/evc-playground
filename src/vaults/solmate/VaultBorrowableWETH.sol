// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "solmate/tokens/WETH.sol";
import "./VaultRegularBorrowable.sol";

/// @title VaultBorrowableWETH
/// @notice This contract extends VaultRegularBorrowable with additional feature for handling ETH deposits (and
/// redemption) into a WETH vault.
contract VaultBorrowableWETH is VaultRegularBorrowable {
    WETH internal immutable weth;

    constructor(
        address _evc,
        ERC20 _asset,
        IIRM _irm,
        IPriceOracle _oracle,
        ERC20 _referenceAsset,
        string memory _name,
        string memory _symbol
    ) VaultRegularBorrowable(_evc, _asset, _irm, _oracle, _referenceAsset, _name, _symbol) {
        weth = WETH(payable(address(_asset)));
    }

    receive() external payable virtual {}

    /// @dev Deposits a certain amount of ETH for a receiver.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function depositETH(address receiver) public payable virtual callThroughEVC nonReentrant returns (uint256 shares) {
        address msgSender = _msgSender();

        createVaultSnapshot();

        // Check for rounding error since we round down in previewDeposit.
        require((shares = _convertToShares(msg.value, false)) != 0, "ZERO_SHARES");

        // Wrap received ETH into WETH.
        weth.deposit{value: msg.value}();

        _totalAssets += msg.value;

        _mint(receiver, shares);

        emit Deposit(msgSender, receiver, msg.value, shares);

        requireAccountAndVaultStatusCheck(address(0));
    }

    /// @notice Redeems a certain amount of shares for a receiver and sends the equivalent assets as ETH.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeemToETH(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual callThroughEVC nonReentrant returns (uint256 assets) {
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

        // Convert WETH to ETH and send to the receiver.
        weth.withdraw(assets);

        (bool sent,) = receiver.call{value: assets}("");
        require(sent, "Failed to send Ether");

        _totalAssets -= assets;

        requireAccountAndVaultStatusCheck(owner);
    }
}
