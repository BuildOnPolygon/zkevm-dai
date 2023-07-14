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
forge test --fork-url $ETH_RPC_URL --match-test testBridgeDAIWithPermit -vvvv
```

### Deployment

Use the following command to deploy on Goerli:

```sh
forge script ...
```

### Contract addresses

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
