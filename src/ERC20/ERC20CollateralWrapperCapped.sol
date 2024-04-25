// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "./ERC20CollateralWrapper.sol";

/// @title ERC20WrapperForEVCCapped
/// @notice It extends the ERC20CollateralWrapper contract by adding a supply cap to the wrapped token.
contract ERC20CollateralWrapperCapped is ERC20CollateralWrapper {
    error ERC20CollateralWrapperCapped_SupplyCapExceeded();

    uint256 private immutable _supplyCap;
    bytes private _totalSupplySnapshot;

    constructor(
        address _evc_,
        IERC20 _underlying_,
        string memory _name_,
        string memory _symbol_,
        uint256 _supplyCap_
    ) ERC20CollateralWrapper(_evc_, _underlying_, _name_, _symbol_) {
        _supplyCap = _supplyCap_;
    }

    /// @notice Ensures operations do not exceed the supply cap by taking a snapshot of the total supply and scheduling
    /// a vault status check if needed.
    modifier requireSupplyCapCheck() {
        if (_supplyCap > 0 && _totalSupplySnapshot.length == 0) {
            _totalSupplySnapshot = abi.encode(totalSupply());
        }

        _;

        if (_supplyCap > 0) {
            evc.requireVaultStatusCheck();
        }
    }

    /// @notice Returns the supply cap for the wrapped token.
    /// @return The supply cap as a uint256.
    function getSupplyCap() external view returns (uint256) {
        return _supplyCap;
    }

    /// @notice Checks the vault status and ensures the final supply does not exceed the initial supply or supply cap.
    /// @dev Reverts with `ERC20WrapperForEVCCapped_SupplyCapExceeded` if the final supply exceeds the initial supply
    /// and the supply cap.
    /// @return The function selector for `checkVaultStatus` which is considered a magic value.
    function checkVaultStatus() external virtual onlyEVCWithChecksInProgress returns (bytes4) {
        uint256 initialSupply = abi.decode(_totalSupplySnapshot, (uint256));
        uint256 finalSupply = totalSupply();

        if (finalSupply > _supplyCap && finalSupply > initialSupply) {
            revert ERC20CollateralWrapperCapped_SupplyCapExceeded();
        }

        delete _totalSupplySnapshot;
        return this.checkVaultStatus.selector;
    }

    /// @notice Wraps the specified amount of the underlying token into this ERC20 token.
    /// @param amount The amount of the underlying token to wrap.
    /// @param receiver The address to receive the wrapped tokens.
    /// @return True if the operation was successful.
    function wrap(uint256 amount, address receiver) public virtual override requireSupplyCapCheck returns (bool) {
        return super.wrap(amount, receiver);
    }

    /// @notice Unwraps the specified amount of this ERC20 token back into the underlying token.
    /// @param amount The amount of this ERC20 token to unwrap.
    /// @param receiver The address to receive the underlying tokens.
    /// @return True if the operation was successful.
    function unwrap(uint256 amount, address receiver) public virtual override requireSupplyCapCheck returns (bool) {
        return super.unwrap(amount, receiver);
    }
}
