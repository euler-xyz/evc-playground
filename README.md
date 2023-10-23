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
└── operators
|   ├── LightweightOrderOperator.sol
│   └── SimpleWithdrawOperator.sol
├── utils
|   ├── CVCClient.sol
|   ├── CVCPermitSignerECDSA.sol
|   ├── SimpleConditionsEnforcer.sol
│   └── TipsPiggyBank.sol
└── vaults
    ├── CreditVaultBase.sol
    ├── CreditVaultRegularBorrowable.sol
    ├── CreditVaultSimple.sol
    └── CreditVaultSimpleBorrowable.sol
```

---

## How to read this repository

### CVC-interoperable Vaults

If you're interested in building a vault that is interoperable with the CVC, you should start by looking at the [CVCClient](/src/utils/CVCClient.sol) contract and the contracts in the [vaults directory](/src/vaults).

The `CVCClient` contract is an abstract base contract for interacting with the CVC. It provides utility functions for authenticating callers in the context of the CVC, scheduling and forgiving status checks, and liquidating collateral shares.

The `CreditVaultBase` is an abstract base contract that all CVC-interoperable vaults inherit from. It provides standard modifiers for reentrancy protection and account/vault status checks scheduling. It declares functions that must be defined in the child contract in order to correctly implement controller release, vault snapshotting and account/vaults status checks.

The `CreditVaultSimple` contract is a simple vault that implements the ERC-4626 interface. It provides basic functionality for a credit vault. The contract showcases a pattern that should be followed in order to properly use CVC's authentication features for non-borrowing operations (when it doesn't matter whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots. Due to non-borrowing nature of the vault, the account status check is implemented as always valid.

The `CreditVaultSimpleBorrowable` contract is a simple vault that extents the `CreditVaultSimple` functionality by adding a borrowing functionality (but no interest accural). The contract showcases a pattern that should be followed in order to properly use CVC's authentication features for borrowing operations (when it matters whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots and a simple account status check.

The `CreditVaultRegularBorrowable` contract is a vault that extends the `CreditVaultSimpleBorrowable` functionality by adding recognized collaterals, price oracle intergration and interest accural. It implements a simple liquidation pattern that showcases the CVC's `impersonate` functionality that is used in order to seize violator's collateral shares.

Areas of experimentation for vaults:
1. Real World Assets (RWA) lending
1. NFT lending
1. uncollateralized lending
1. P2P lending
1. risk management
1. collateral types
1. oracles
1. interest rate models

### Gasless transactions

If you'd like to learn how CVC can be used to enable gasless transactions, you should look at the [GaslessTx](/test/misc/GaslessTx.t.sol) and [ConditionalGaslessTx](/test/misc/ConditionalGaslessTx.t.sol) tests.

The `GaslessTx` shows how one can use CVC's `permit` functionality in order to sign a permit message that contains calldata that can be executed by anyone on behalf of the signer. It also shows how a relayer of such a transaction can be incentivized by the signer.

The `ConditionalGaslessTx` shows how one can use CVC's `permit` functionality in order to sign a permit message that contains *conditional* calldata that can be executed by anyone on behalf of the signer, but only when encoded conditions are met.

### Operators

If you're interested in learning how to use CVC operators, you should look at the contracts in the [operators directory](/src/operators).

`SimpleWithdrawOperator` shows how to write a contract that allows anyone, in exchange for a tip, to pull liquidity out of a heavily utilised vault on behalf of someone else. Thanks to this operator, a user can delegate the monitoring of their vault to someone else and go on with their life.

`LigthweightOrderOperator` shows how to write a stateful operator for orders management. It allows for submitting orders that can execute any arbitrary calldata that does not require authentication (i.e. enforcing order conditions) as well as the calldata that requires CVC authentication (i.e. vaults interactions). Submitted orders are publicly visible and therefore executable by anyone in exchange for a tip. The owner of the order can cancel it at any time. 
In order to understand how the operator works, it's best to look at the relevant [test](/test/misc/LightweightOrderOperator.t.sol).

Areas of experimentation for permits and operators:
1. gasless transactions, ability to pay for gas in any ERC20 token
1. intents support
1. conditional orders (e.g. stop-loss, take-profit, trailing-stop etc.)
1. position managers (e.g. rebalancing)
1. opt-in liquidation flows
1. lending pool optimizers

---

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
git clone https://github.com/euler-xyz/euler-cvc-playground.git && cd euler-cvc-playground && yarn
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
