## Polygon zkEVM DAI

Native & capital efficient DAI on
[Polygon zkEVM](https://polygon.technology/polygon-zkevm) powered by
[Spark protocol](https://www.sparkprotocol.io/).

### Introduction

Polygon zkEVM provides secure bridge for developers to move assets across chains
(L1 <-> zkEVM). Developer can send cross-chain message from L1 to zkEVM or zkEVM
to L1 using the bridge.

Spark Protocol is a MakerDAO powered lending market. User can borrow DAI using
various collateral and deposit DAI to DAI Saving Rates via sDAI to earn interest.

In order to build native and capital efficient DAI on Polygon zkEVM, we will
utilize Spark protocol `sDAI` for escrowed token. This will utilize locked
liquidity, hence the capital efficiency.

Native DAI implementation is consist of two smart contracts:

1. **L1Escrow**: This contract is deployed on Ethereum mainnet and interact
   directly with Spark protocol.
2. **L2Dai**: This contract is deployed on Polygon zkEVM.

With Native DAI, user can do the following:

1. Bridge DAI from Ethereum mainnet to Polygon zkEVM via `L1Escrow` contract.
2. Bridge DAI from Polygon zkEVM to Ethereum mainnet via `L2Dai` contract.

## Get started

### Requirements

This repository is using foundry. You can install foundry via
[foundryup](https://book.getfoundry.sh/getting-started/installation).

### Setup

Clone the repository:

```sh
git clone git@github.com:pyk/zkevm-dai.git
cd zkevm-dai/
```

Install the dependencies:

```sh
forge install
```

### Tests

Use the following command to run the test:

```sh
forge test --fork-url $ETH_RPC_URL --match-path test/L1Escrow.t.sol
```

You can also run individual test using the following command:

```sh
forge test --fork-url $ETH_RPC_URL --match-test testSendExcessYield -vvvv
```

> **Note**
> You can set `ETHERSCAN_API_KEY` to helps you debug the call trace.

## Deployment

Use the following command to deploy on Goerli:

```sh
forge script ...
```

## Contract addresses

On Goerli Testnet:

| Smart contract       | Address on Goerli                            |
| -------------------- | -------------------------------------------- |
| DAI                  | `0x11fe4b6ae13d2a6055c8d9cf65c55bac32b5d844` |
| Polygon ZkEVM Bridge | `0xf6beeebb578e214ca9e23b0e9683454ff88ed2a7` |
| sDAI                 | `0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C` |
| L1Escrow             |                                              |
| L2Dai                |                                              |

On Polygon zkEVM testnet:

| Smart contract       | Address on Goerli                            |
| -------------------- | -------------------------------------------- |
| DAI                  | `0x11fe4b6ae13d2a6055c8d9cf65c55bac32b5d844` |
| Polygon ZkEVM Bridge | `0xf6beeebb578e214ca9e23b0e9683454ff88ed2a7` |
| sDAI                 | `0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C` |
| L1Escrow             |                                              |
| L2Dai                |                                              |

On Ethereum Mainnet:

| Smart contract       | Address on Goerli                            |
| -------------------- | -------------------------------------------- |
| DAI                  | `0x11fe4b6ae13d2a6055c8d9cf65c55bac32b5d844` |
| Polygon ZkEVM Bridge | `0xf6beeebb578e214ca9e23b0e9683454ff88ed2a7` |
| sDAI                 | `0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C` |
| L1Escrow             |                                              |
| L2Dai                |                                              |

On Polygon zkEVM:

| Smart contract       | Address on Goerli                            |
| -------------------- | -------------------------------------------- |
| DAI                  | `0x11fe4b6ae13d2a6055c8d9cf65c55bac32b5d844` |
| Polygon ZkEVM Bridge | `0xf6beeebb578e214ca9e23b0e9683454ff88ed2a7` |
| sDAI                 | `0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C` |
| L1Escrow             |                                              |
| L2Dai                |                                              |

## Known Issues

### Rounding Issue

When we deposit `x` amount of DAI to sDAI, we will get `y` amount of sDAI based
on the current exchange rate `r`. Due to how `y` is rounded down by sDAI, there
is possibility that when we redeem `y` amount of sDAI we will get `x' = x - 1`
amount of DAI.

For, example:

```solidity
uint256 x = 1000000000000000001;
uint256 y = sdai.deposit(x);
uint255 x_ = sdai.redeem(y); // x_ = 1000000000000000000
```

> **Note**
> See [sDAI.t.sol](./test/sDAI.t.sol) for more details.

Ofcourse, `r` will be increased over time and this 1 wei will be covered.

To make sure that bridged DAI is always 1:1, it is advised to donate small
amount of DAI on `L1Escrow` on the first time it get deployed (e.g. 0.01 DAI).

`sendExcessYield` will send excess yield if the total yield is more than
0.05 DAI and will leave 0.01 DAI from the yield in L1Escrow.

### Locked DAI in L1Escrow may greater than totalProtocolDAI

Currently there is no way to check the maximum deposit amount of sDAI.
`sdai.maxDeposit(address)` is hardcoded to `type(uint256).max`.

`sdai.deposit(amount, recipient)` may reverted and it is possible that total
amount of locked DAI in the `L1Escrow` is greater than the specified
`totalProtocolDAI`.
