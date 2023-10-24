// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/MessageHashUtils.sol";
import "openzeppelin/utils/ShortStrings.sol";
import "euler-cvc/CreditVaultConnector.sol";

// This contract is used only for testing purposes.
// It's a utility contract that helps to sign permit message for the CVC contract using ECDSA.
abstract contract EIP712 {
    using ShortStrings for *;

    bytes32 internal constant _TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 internal immutable _hashedName;
    bytes32 internal immutable _hashedVersion;
    ShortString private immutable _name;
    ShortString private immutable _version;
    string private _nameFallback;
    string private _versionFallback;

    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() internal view virtual returns (bytes32);

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view virtual returns (bytes32) {
        return
            MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}

contract CVCPermitSignerECDSA is EIP712, Test {
    CreditVaultConnector private immutable cvc;

    constructor(
        address _cvc
    )
        EIP712(
            CreditVaultConnector(payable(_cvc)).name(),
            CreditVaultConnector(payable(_cvc)).version()
        )
    {
        cvc = CreditVaultConnector(payable(_cvc));
    }

    function _buildDomainSeparator() internal view override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _TYPE_HASH,
                    _hashedName,
                    _hashedVersion,
                    block.chainid,
                    address(cvc)
                )
            );
    }

    function signPermit(
        address signer,
        uint nonceNamespace,
        uint nonce,
        uint deadline,
        bytes calldata data,
        uint privateKey
    ) external view returns (bytes memory signature) {
        bytes32 structHash = keccak256(
            abi.encode(
                cvc.PERMIT_TYPEHASH(),
                signer,
                nonceNamespace,
                nonce,
                deadline,
                keccak256(data)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            _hashTypedDataV4(structHash)
        );
        signature = abi.encodePacked(r, s, v);
    }
}
