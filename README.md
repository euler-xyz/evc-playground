# Ethereum Vault Connector (EVC) Playground


## Ethereum Vault Connector (EVC) 

The Ethereum Vault Connector (EVC) is a foundational layer designed to facilitate the core functionality required for a lending market. It serves as a base building block for various protocols, providing a robust and flexible framework for developers to build upon. The EVC primarily mediates between vaults, contracts that implement the ERC-4626 interface and contain additional logic for interfacing with other vaults. The EVC not only provides a common base ecosystem but also reduces complexity in the core lending/borrowing contracts, allowing them to focus on their differentiating factors.

For more information about the EVC refer to the [EVC WHITEPAPER](https://github.com/euler-xyz/ethereum-vault-connector/blob/master/docs/whitepaper.md) and the [EVC SPECS](https://github.com/euler-xyz/ethereum-vault-connector/blob/master/docs/specs.md).


## EVC Playground

This repository serves as a sandbox for exploring the EVC. It includes various example vaults, operators, and patterns that can be utilized as a foundation for creating your own smart contracts that interact with the EVC. Given the complexity of the EVC, the EVC Playground repository was established to illustrate basic concepts related to the EVC, to foster the development of standard patterns and best practices for building products on top of the EVC. Please note that none of the contracts in this repository have been audited and are intended solely for testing and experimentation. They should not be used in production under any circumstances.

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
|   ├── EVCClient.sol
|   ├── SimpleConditionsEnforcer.sol
│   └── TipsPiggyBank.sol
└── vaults
    ├── VaultBase.sol
    ├── VaultBorrowableWETH.sol
    ├── VaultRegularBorrowable.sol
    ├── VaultSimple.sol
    └── VaultSimpleBorrowable.sol
```

---

## How to read this repository

### EVC-interoperable Vaults

If you're interested in building a vault that is interoperable with the EVC, you should start by looking at the [EVCClient](/src/utils/EVCClient.sol) contract and the contracts in the [vaults directory](/src/vaults).

The `EVCClient` contract is an abstract base contract for interacting with the EVC. It provides utility functions for authenticating callers in the context of the EVC, scheduling and forgiving status checks, and liquidating collateral shares.

The `VaultBase` is an abstract base contract that all EVC-interoperable vaults inherit from. It provides standard modifiers for reentrancy protection and account/vault status checks scheduling. It declares functions that must be defined in the child contract in order to correctly implement controller release, vault snapshotting and account/vaults status checks.

The `VaultSimple` contract is a simple vault that implements the ERC-4626 interface. It provides basic functionality for a vault. The contract showcases a pattern that should be followed in order to properly use EVC's authentication features for non-borrowing operations (when it doesn't matter whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots. Due to non-borrowing nature of the vault, the account status check is implemented as always valid.

The `VaultSimpleBorrowable` contract is a simple vault that extents the `VaultSimple` functionality by adding a borrowing functionality (but no interest accrual). The contract showcases a pattern that should be followed in order to properly use EVC's authentication features for borrowing operations (when it matters whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots and a simple account status check.

The `VaultRegularBorrowable` contract is a vault that extends the `VaultSimpleBorrowable` functionality by adding recognized collaterals, price oracle integration and interest accrual. It implements a simple liquidation pattern that showcases the EVC's `impersonate` functionality that is used in order to seize violator's collateral shares.

The `VaultBorrowableWETH` contract is a vault that extends the `VaultRegularBorrowable` functionality by adding a special function for handling ETH deposits into a WETH vault. It showcases EVC `callback` functionality for a `payable` function.

Areas of experimentation for vaults:
1. Real World Assets (RWA) lending
1. NFT lending
1. uncollateralized lending
1. P2P lending
1. deposit-only vaults that can be used a collaterals for other vaults
1. risk management
1. collateral types
1. oracles
1. interest rate models

### Gasless transactions

If you'd like to learn how EVC can be used to enable gasless transactions, you should look at the [GaslessTx](/test/misc/GaslessTx.t.sol) and [ConditionalGaslessTx](/test/misc/ConditionalGaslessTx.t.sol) tests.

The `GaslessTx` shows how one can use EVC's `permit` functionality in order to sign a permit message that contains calldata that can be executed by anyone on behalf of the signer. It also shows how a relayer of such a transaction can be incentivized by the signer.

The `ConditionalGaslessTx` shows how one can use EVC's `permit` functionality in order to sign a permit message that contains *conditional* calldata that can be executed by anyone on behalf of the signer, but only when encoded conditions are met. This concept can be used for implementing conditional orders (e.g. stop-loss, take-profit etc.).

### Operators

If you're interested in learning how to use EVC operators, you should look at the contracts in the [operators directory](/src/operators).

`SimpleWithdrawOperator` shows how to write a contract that allows anyone, in exchange for a tip, to pull liquidity out of a heavily utilised vault on behalf of someone else. Thanks to this operator, a user can delegate the monitoring of their vault to someone else and go on with their life.

`LigthweightOrderOperator` shows how to write a stateful operator for orders management. It allows for submitting orders that can execute any arbitrary calldata that does not require authentication (i.e. enforcing order conditions) as well as the calldata that requires EVC authentication (i.e. vaults interactions). Submitted orders are publicly visible and therefore executable by anyone in exchange for a tip. The owner of the order can cancel it at any time. 
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

To install EVC Playground in a [**Foundry**](https://github.com/foundry-rs/foundry) project:

```sh
forge install euler-xyz/evc-playground
```

## Usage

EVC Playground includes a suite of tests written in Solidity with Foundry.

Note: The tests are not complete and are only meant to be used as a starting point for building your own test suite.

To install Foundry:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```sh
foundryup
```

To clone the repo:

```sh
git clone https://github.com/euler-xyz/evc-playground.git && cd evc-playground
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

This software is designed to develop standard patterns and best practices for building products on top of EVC. We welcome feedback, new ideas, and contributions. If you're interested in conducting security research, writing more tests (including formal verification), improving readability and documentation, optimizing, simplifying, or developing new integrations, please feel free to contribute.

## License

Licensed under the [GPL-2.0-or-later](/LICENSE) license.
