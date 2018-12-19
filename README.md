# DC/OS Ethereum

DC/OS Ethereum is a Mesos framework for managing a geth-based ethereum cluster. [Ethereum](https://www.ethereum.org/) is a decentralized platform for building applications using blockchain.

See our blog post for more information: ["Ethereum on DC/OS: Automating Private Blockchain Deployment"](https://medium.com/iss-lab/ethereum-on-dc-os-d6b6bf7ddd80)

## Introduction

This framework deploys an [Ethereum](https://www.ethereum.org/) network onto a DC/OS cluster. It can be configured as a private network or it can connect to Rinkeby, TestNet, MainNet, etc. For further information on running a private network, refer to [Geth's documentation](https://github.com/ethereum/go-ethereum/wiki/Private-network). This framework is comprised of 4 components:

1. *boot node*: used for Geth node discovery
1. *ethstats*: [Ethereum Network Stats](https://github.com/cubedro/eth-netstats)
1. *sealer nodes*: Geth miner nodes
1. *client nodes*: Geth transaction nodes with mining disabled whose responsbility is to respond to API (websocket, rpc) queries

## Prerequisites

* DC/OS 1.10+

## Installing the Framework

```
$ dcos package install ethereum
```

## Usage

CLI Usage and useful commands can be found in [docs/USAGE.md](./docs/USAGE.md). In general you can find commands by running:

```
$ dcos ethereum --help
```

## Uninstalling the Framework

To uninstall/delete the deployment:

```
$ dcos package uninstall ethereum
```

The command removes all of the components associated with the framework including the blockchain data.
