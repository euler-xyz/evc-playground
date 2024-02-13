// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./ERC20CollateralForEVC.sol";

/// @title ERC20WrapperForEVC
/// @notice It extends the ERC20CollateralForEVC contract so that any ERC20 token can be wrapped and used as collateral
/// in the EVC ecosystem.
contract ERC20WrapperForEVC is ERC20CollateralForEVC {
    error ERC20WrapperForEVC_InvalidAddress();

    address private immutable _underlying;
    uint8 private immutable _decimals;

    constructor(
        IEVC _evc_,
        address _underlying_,
        string memory _name_,
        string memory _symbol_
    ) ERC20CollateralForEVC(_evc_, _name_, _symbol_) {
        if (_underlying_ == address(this)) {
            revert ERC20WrapperForEVC_InvalidAddress();
        }

        _underlying = _underlying_;
        _decimals = IERC20Metadata(_underlying_).decimals();
    }

    /// @notice Returns the address of the underlying ERC20 token.
    /// @return The address of the underlying token.
    function underlying() external view returns (address) {
        return _underlying;
    }

    /// @notice Returns the number of decimals of the wrapper token.
    /// @dev The number of decimals of the wrapper token is the same as the number of decimals of the underlying token.
    /// @return The number of decimals of the wrapper token.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Wraps the specified amount of the underlying token into this ERC20 token.
    /// @param amount The amount of the underlying token to wrap.
    /// @param receiver The address to receive the wrapped tokens.
    /// @return True if the operation was successful.
    function wrap(uint256 amount, address receiver) external returns (bool) {
        if (receiver == address(this)) {
            revert ERC20WrapperForEVC_InvalidAddress();
        }

        SafeERC20.safeTransferFrom(IERC20(_underlying), _msgSender(), address(this), amount);
        _mint(receiver, amount);

        return true;
    }

    /// @notice Unwraps the specified amount of this ERC20 token back into the underlying token.
    /// @param amount The amount of this ERC20 token to unwrap.
    /// @param receiver The address to receive the underlying tokens.
    /// @return True if the operation was successful.
    function unwrap(
        uint256 amount,
        address receiver
    ) external callThroughEVC requireAccountStatusCheck(_msgSender()) returns (bool) {
        if (receiver == address(this)) {
            revert ERC20WrapperForEVC_InvalidAddress();
        }

        _burn(_msgSender(), amount);
        SafeERC20.safeTransfer(IERC20(_underlying), _getAccountOwner(receiver), amount);

        return true;
    }
}
