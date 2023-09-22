## Polygon zkEVM DAI Bridge

### Introduction

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

Create `.env` with the following contents:

```
ETH_RPC_URL=""
ZKEVM_RPC_URL="https://zkevm-rpc.com"
ETHERSCAN_API_KEY=""
```

Use the following command to run the test:

```sh
forge test
```

You can also run individual test using the following command:

```sh
forge test --fork-url $ETH_RPC_URL --match-test testSendExcessYield -vvvv

forge test --fork-url "https://zkevm-rpc.com" --match-path test/L2Dai.t.sol --match-test testBridgeWithMockedBridge -vvvv
```

> **Note**
> You can set `ETHERSCAN_API_KEY` to helps you debug the call trace.

## Deployment

Use the following command to deploy on Goerli:

```sh
forge script ...
```

## Contract addresses

| Smart contract       | Network       | Address                                                                                                                        |
| -------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| DAI                  | Mainnet       | [0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F)          |
| sDAI                 | Mainnet       | [0x83f20f44975d03b1b09e64809b757c47f942beea](https://etherscan.io/token/0x83f20f44975d03b1b09e64809b757c47f942beea#code)       |
| Polygon ZkEVM Bridge | Mainnet       | [0x2a3dd3eb832af982ec71669e178424b10dca2ede](https://etherscan.io/address/0x2a3dd3eb832af982ec71669e178424b10dca2ede)          |
|                      | zkEVM Mainnet | [0x2a3dd3eb832af982ec71669e178424b10dca2ede](https://zkevm.polygonscan.com/address/0x2a3dd3eb832af982ec71669e178424b10dca2ede) |
| L1Escrow             | Mainnet       | [0x4a27ac91c5cd3768f140ecabde3fc2b2d92edb98](https://etherscan.io/address/0x4a27ac91c5cd3768f140ecabde3fc2b2d92edb98)          |
| L2Dai                | zkEVM Mainnet | [0x744c5860ba161b5316f7e80d9ec415e2727e5bd5](https://zkevm.polygonscan.com/address/0x744c5860ba161b5316f7e80d9ec415e2727e5bd5) |

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
