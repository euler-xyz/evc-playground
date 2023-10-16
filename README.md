# Credit Vault Connector (CVC) Playground


## Credit Vault Connector (CVC) 

The Credit Vault Connector (CVC) is an attempt to distill the core functionality required for a lending market into a foundational layer that can be used as a base building block for many diverse protocols. The CVC is primarily a mediator between Credit Vaults, which are contracts that implement the ERC-4626 interface and contain a small amount of additional logic for interfacing with other vaults.

For more information about the CVC refer to the [CVC WHITEPAPER](https://github.com/euler-xyz/euler-cvc/blob/master/docs/whitepaper.md) and the [CVC SPECS](https://github.com/euler-xyz/euler-cvc/blob/master/docs/specs.md).


## CVC Playground

This repository serves as a sandbox for exploring the CVC. It includes various example vaults, operators, and patterns that can be utilized as a foundation for creating your own smart contracts that interact with the CVC. Given the complexity of the CVC, the CVC Playground repository was established to foster the development of standard patterns and best practices for building products on top of the CVC. Please note that none of the contracts in this repository have been audited and are intended solely for testing and experimentation. They should not be used in production under any circumstances.

---

## Contracts

```
.
├── interfaces
│   ├── IIRM.sol
│   └── IPriceOracle.sol
├── utils
│   └── CVCClient.sol
└── vaults
    ├── CreditVaultBase.sol
    ├── CreditVaultRegularBorrowable.sol
    ├── CreditVaultSimple.sol
    └── CreditVaultSimpleBorrowable.sol
```

## Install

To install CVC Playground in a [**Foundry**](https://github.com/foundry-rs/foundry) project:

```sh
forge install euler-xyz/euler-cvc-playground
```

## Usage

CVC Playground includes a suite of tests written in Solidity with Foundry.

Note: The tests are not complete and are only meant to be used as a starting point for building your own test suite.

To install Foundry:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```sh
foundryup
```

To clone the repo and install dependencies:

```sh
git clone https://github.com/euler-xyz/euler-cvc-playground.git && cd euler-cvc && yarn
```

## Testing

To run the tests:

```sh
forge test
```

## Safety and Limitations

This software is experimental and is provided "as is" and "as available". No warranties are provided, and no liability will be assumed for any loss incurred through the use of this codebase.

Always include thorough tests when using code snippets from this repository to ensure compatibility with your code.

The smart contracts in this repository have not been audited and should not be used in production.

## Contributions

This software is designed to develop standard patterns and best practices for building products on top of CVC. We welcome feedback, new ideas, and contributions. If you're interested in conducting security research, writing more tests (including formal verification), improving readability and documentation, optimizing, simplifying, or developing new integrations, please feel free to contribute.

## License

Licensed under the [GPL-2.0-or-later](/LICENSE) license.
