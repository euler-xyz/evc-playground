// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/MessageHashUtils.sol";
import "openzeppelin/utils/ShortStrings.sol";
import "evc/EthereumVaultConnector.sol";

// This contract is used only for testing purposes.
// It's a utility contract that helps to sign permit message for the evc contract using ECDSA.
abstract contract EIP712 {
    using ShortStrings for *;

    bytes32 internal constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address signer,address sender,uint256 nonceNamespace,uint256 nonce,uint256 deadline,uint256 value,bytes data)"
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

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}

contract EVCPermitSignerECDSA is EIP712, Test {
    EthereumVaultConnector private immutable evc;
    uint256 internal privateKey;

    constructor(address _evc)
        EIP712(EthereumVaultConnector(payable(_evc)).name(), EthereumVaultConnector(payable(_evc)).version())
    {
        evc = EthereumVaultConnector(payable(_evc));
    }

    function setPrivateKey(uint256 _privateKey) external {
        privateKey = _privateKey;
    }

    function _buildDomainSeparator() internal view override returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(evc)));
    }

    function signPermit(
        address signer,
        address sender,
        uint256 nonceNamespace,
        uint256 nonce,
        uint256 deadline,
        uint256 value,
        bytes calldata data
    ) external view returns (bytes memory signature) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, signer, sender, nonceNamespace, nonce, deadline, value, keccak256(data))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, _hashTypedDataV4(structHash));
        signature = abi.encodePacked(r, s, v);
    }
}
