# DC/OS Ethereum

DC/OS Ethereum is a Mesos framework for managing a geth-based ethereum cluster. [Ethereum](https://www.ethereum.org/) is a decentralized platform for building applications using blockchain.

## Introduction

This framework deploys an [Ethereum](https://www.ethereum.org/) network onto a DC/OS cluster. It can be configured as a private network or it can connect to Rinkeby, TestNet, MainNet, etc. For further information on running a private network, refer to [Geth's documentation](https://github.com/ethereum/go-ethereum/wiki/Private-network). This framework is comprised of 4 components:

1. *boot node*: used for Geth node discovery
1. *ethstats*: [Ethereum Network Stats](https://github.com/cubedro/eth-netstats)
1. *sealer nodes*: Geth miner nodes
1. *client nodes**: Geth transaction nodes with mining disabled whose responsbility is to respond to API (websocket, rpc** queries

## Prerequisites

* DC/OS 1.11+

## Installing the Framework

**Note:** This framework is not yet included in the DC/OS catalogue (universe), but it can still be installed in the mean time by hosting your own package repository. In the future the following steps will not be required.

1. Download https://github.com/iss-lab/dcos-ethereum/releases/download/v0.1.0/stub-universe-ethereum.json

2. Upload it a `${HTTP_HOST}` accessible from your DC/OS cluster and serve it with an nginx docker container:

    ```
    mkdir artifacts
    cp ethereum-stub-universe.json artifacts/
    docker run -d -p 8888:80 \
        --restart=always \
        -v $PWD/artifacts:/usr/share/nginx/html:ro \
        nginx /bin/bash \
        -c 'echo "types { application/vnd.dcos.universe.repo+json json; application/zip zip; application/octet-stream bin exe dll; }" > /etc/nginx/mime.types && exec nginx -g "daemon off;"'
    ```

3. Create an `options.json`. Examples and config field reference can be found in [docs/CONFIGURATION.md](./docs/CONFIGURATION.md)

4. Add your repository to your DC/OS cluster

    ```
    dcos package repo add --index=0 ethereum-local \
        http://${HTTP_HOST}:8888/stub-universe-ethereum.json
    ```

5. Install the framework

    ```
    dcos package install ethereum --options options.json
    ```

## Usage

CLI Usage and useful commands can be found in [docs/USAGE.md](./docs/USAGE.md). In general you can find commands by running:

```
dcos ethereum --help
```

## Uninstalling the Framework

To uninstall/delete the deployment:

```
$ dcos package uninstall ethereum
```

The command removes all of the components associated with the framework including the blockchain data.
