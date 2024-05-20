# Ethereum Vault Connector (EVC) Playground


## Ethereum Vault Connector (EVC) 

The Ethereum Vault Connector (EVC) is a foundational layer designed to facilitate the core functionality required for a lending market. It serves as a base building block for various protocols, providing a robust and flexible framework for developers to build upon. The EVC primarily mediates between vaults, contracts that implement the ERC-4626 interface and contain additional logic for interfacing with other vaults. The EVC not only provides a common base ecosystem but also reduces complexity in the core lending/borrowing contracts, allowing them to focus on their differentiating factors.

For more information about the EVC refer to the [EVC website](https://evc.wtf).


## EVC Playground

This repository serves as a sandbox for exploring the EVC. It includes various example vaults, operators, and patterns that can be utilized as a foundation for creating your own smart contracts that interact with the EVC. Given the complexity of the EVC, the EVC Playground repository was established to illustrate basic concepts related to the EVC, to foster the development of standard patterns and best practices for building products on top of the EVC. Please note that none of the contracts in this repository have been audited and are intended solely for testing and experimentation. They should not be used in production under any circumstances.

---

## Contracts

```
.
├── ERC20
│   ├── ERC20Collateral.sol
│   ├── ERC20CollateralWrapper.sol
│   └── ERC20CollateralWrapperCapped.sol
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
    ├── open-zeppelin
    |   ├── VaultRegularBorrowable.sol
    |   └── VaultSimple.sol
    ├── solmate
    |   ├── VaultBorrowableWETH.sol
    |   ├── VaultRegularBorrowable.sol
    |   ├── VaultSimple.sol
    |   └── VaultSimpleBorrowable.sol
    └── VaultBase.sol
```

---

## How to read this repository

### EVC-interoperable Vaults

If you're interested in building a vault that is interoperable with the EVC, you should start by looking at the [EVCClient](/src/utils/EVCClient.sol) contract and the contracts in the [`vaults` directory](/src/vaults).

The `EVCClient` contract is an abstract base contract for interacting with the EVC. It inherits from [`EVCUtil`](https://github.com/euler-xyz/ethereum-vault-connector/blob/master/src/utils/EVCUtil.sol) contract and provides utility functions for authenticating callers in the context of the EVC, scheduling and forgiving status checks, and liquidating collateral shares.

The `VaultBase` is an abstract base contract that all EVC-interoperable vaults inherit from. It provides standard modifiers for re-entrancy protection and account/vault status checks scheduling. It declares functions that must be defined in the child contract in order to correctly implement controller release, vault snapshotting and account/vaults status checks.

You will find two directories in the [`vaults` directory](/src/vaults). The [`open-zeppelin`](/src/vaults/open-zeppelin) directory contains vaults that are based on Open-Zeppelin implementation of the ERC-4626. The [`solmate`](/src/vaults/solmate) directory contains vaults that are based on Solmate implementation of the ERC-4626.

The `VaultSimple` contract is a simple vault that implements the ERC-4626 interface. It provides basic functionality for a so called collateral-only vault which may be accepted as collateral by other vaults in the EVC ecosystem. The contract showcases a pattern that should be followed in order to properly use EVC's authentication features for non-borrowing operations (when it doesn't matter whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots. Due to non-borrowing nature of the vault, the account status check is implemented as always valid.

The `VaultSimpleBorrowable` contract is a simple vault that extends the `VaultSimple` functionality by adding a borrowing functionality (but no interest accrual). The contract showcases a pattern that should be followed in order to properly use EVC's authentication features for borrowing operations (when it matters whether the user has enabled a controller). It implements a simple vault status check based on a pre- and post-operation snapshots and a simple account status check.

The `VaultRegularBorrowable` contract is a vault that extends the `VaultSimpleBorrowable` functionality by adding recognized collaterals, price oracle integration and interest accrual. It implements a simple liquidation pattern that showcases the EVC's `controlCollateral` functionality that is used in order to seize violator's collateral shares.

The `VaultBorrowableWETH` contract is a vault that extends the `VaultRegularBorrowable` functionality by adding a special function for handling ETH for a WETH vault. It showcases EVC `call` callback pattern for a `payable` function.

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

### ERC20 Collateral for the EVC

If you're interested in an alternative path to make an asset suitable to become collateral for the EVC ecosystem vaults, you should look at the contracts in the [`ERC20` directory](/src/ERC20).

An alternative path to creating a collateral-only asset is to create an `ERC20Collateral` token, which is a simple extension to the `ERC20` token standard to enforce compatibility with the EVC. Users are no longer required to deposit their tokens into vaults in order to use them as collateral, they can do so directly from their wallet. This helps them retain their governance rights and other token privileges.

Whenever the user's balance decreases (outgoing transfer/token burn), the token contract calls into the EVC to check whether the outstanding loan rules are not violated. Thanks to the EVC, account status checks can be deferred until the end of a batch of multiple operations, allowing a user to freely use their tokens within a batch as long as their account is solvent at the end. `ERC20Collateral` also makes the token compatible with EVC sub-accounts system out of the box.

Existing `ERC20` tokens that are not compatible with the EVC may make use of the `ERC20CollateralWrapper` and `ERC20CollateralWrapperCapped` contracts. `ERC20CollateralWrapper` is a simple wrapper contract that gives an existing token `ERC20Collateral` functionality. `ERC20CollateralWrapperCapped` is a simple wrapper contract that gives an existing token `ERC20Collateral` functionality and adds a supply cap to the wrapped token.

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

To clone the repo and install dependencies:

```sh
git clone https://github.com/euler-xyz/evc-playground.git && cd evc-playground && forge install
```

## Testing

To run the tests:

```sh
forge test
```

## Invariant Testing Suite

This project has been set up with a suite of tests that check for specific invariants for the EVC vaults, implemented by [vnmrtz.eth](https://twitter.com/vn_martinez_). These tests are located in the `test/invariants` directory. They are written in Solidity and are designed to be run with [medusa](https://github.com/crytic/medusa) and [echidna](https://github.com/crytic/echidna) fuzzing tools.

Installation and usage of these tools is outside the scope of this README, but you can find more information in the respective repositories:
- [Echidna Installation](https://github.com/crytic/echidna)
- [Medusa Installation](https://github.com/crytic/medusa)

To run invariant tests with Echidna:

```sh
make echidna
```

To run assert tests with Echidna:

```sh
make echidna-assert
```

To run invariant tests with Medusa:

```sh
make medusa
```


## Deployment on a local anvil fork

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `ANVIL_RPC_URL="http://127.0.0.1:8545"` (the default address and port of the anvil fork)
- `RPC_URL` (remote endpoint from which the state will be fetched)
- `MNEMONIC` (the mnemonic to be used to generate the accounts. the deployer address will be the first address derived from it. the deployer will become an owner of all the deployed ownable contracts and will additionally be minted some test tokens)

Load the variables in the `.env` file and spin up a local anvil fork:

```sh
source .env && anvil --fork-url "$RPC_URL" --mnemonic "$MNEMONIC"
```

In different terminal window, deploy the contracts:

```sh
source .env && forge script script/01_Deployment.s.sol:Deployment --rpc-url "$ANVIL_RPC_URL" --broadcast
```

If deployment successful, the addresses of all the deployed contracts should be console logged in the Logs section.

## Safety and Limitations

This software is experimental and is provided "as is" and "as available". No warranties are provided, and no liability will be assumed for any loss incurred through the use of this codebase.

Always include thorough tests when using code snippets from this repository to ensure compatibility with your code.

The smart contracts in this repository have not been audited and should not be used in production.

## Contributions

This software is designed to develop standard patterns and best practices for building products on top of EVC. We welcome feedback, new ideas, and contributions. If you're interested in conducting security research, writing more tests (including formal verification), improving readability and documentation, optimizing, simplifying, or developing new integrations, please feel free to contribute.

## License

Licensed under the [GPL-2.0-or-later](/LICENSE) license.
