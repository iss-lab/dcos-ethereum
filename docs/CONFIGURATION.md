# DC/OS Ethereum Configuration

## Examples

* [accounts.json](examples/accounts.json): Specify custom accounts to use for client and sealer nodes.
* [defaults.json](examples/defaults.json): Complete configuration with all default values.
* [ethereum.json](examples/ethereum.json): Connect nodes to the Ethereum MainNet.
* [rinkeby.json](examples/rinkeby.json): Connect to the Rinkeby network.
* [testnet.json](examples/testnet.json): Connect to the TestNet.
* [traefik.json](examples/traefik.json): Loadbalance nodes using Traefik using Mesos task labels.

## Using Static Accounts

By default, the framework will create one account per sealer / client node, but this functionality can be disabled in favor of specifying your own accounts. Credit for account creation instructions to https://github.com/helm/charts/tree/master/stable/ethereum

1. Create an Ethereum address and private key. To create a new Ethereum wallet, refer to [this blog post](https://kobl.one/blog/create-full-ethereum-keypair-and-address/) which will walkthrough the following instructions in greater detail:

    ```
    $ git clone https://github.com/vkobel/ethereum-generate-wallet
    $ cd ethereum-generate-wallet
    $ pip3 install -r requirements.txt
    $ python3 ethereum-wallet-generator.py

    Private key: 38000e15ca07309cc2d0b30faaaadb293c45ea222a117e9e9c6a2a9872bb3bcf
    Public key:  60758d37d431d34b920847212febbd583008ec2a34d00f907d48bd48b88dc2661806eb99cb6178312d228b2fd08cdb88bafc352d0395ae09b2fe453f0c4403ad
    Address:     0xab70383d9207c6cc43ab85eeef9db4d33a8ad4e8
    ```

2. Create an options.json

    ```
    {
      "sealer": {
        "create_accounts": false,
        "account_privatekeys": "[PRIVATE_KEY]",
        "account_secret": "[SECRET]"
      },
      "client": {
        "create_accounts": false,
        "account_privatekeys": "[PRIVATE_KEY]",
        "account_secret": "[SECRET]"
      }
    }
    ```

2. Install the framework as follows:

    ```
    $ dcos package install ethereum --options options.json
    ```

    using the above generated example, the configurations would equate to:

    * `sealer.account_privatekeys` = `38000e15ca07309cc2d0b30faaaadb293c45ea222a117e9e9c6a2a9872bb3bcf`
    * `sealer.account_secret` = any passphrase that Geth will use to encrypt your private key
    * `client.account_privatekeys` = `38000e15ca07309cc2d0b30faaaadb293c45ea222a117e9e9c6a2a9872bb3bcf`
    * `client.account_secret` = the same passphrase, since we are re-using the account

## Reference

The following tables list the configurable parameters of the framework and their default values. For more details on possible values, see the config schema ([universe/config.json](./universe/config.json)).

### Service

| Parameter                       | Description                                          | Default         |
|---------------------------------|------------------------------------------------------|-----------------|
| `name`                          | The name of the service instance                     | "ethereum" |
| `user`                          | The user that the service will run as                | "root"          |
| `service_account`               | The service account for DC/OS service authentication | ""              |
| `service_account_secret`        | Name of the DC/OS Secret Store credentials           | ""              |
| `virtual_network_enabled`       | Enable virtual networking                            | false           |
| `virtual_network_name`          | The name of the virtual network to join              | "dcos"          |
| `virtual_network_plugin_labels` | Labels to pass to the virtual network plugin         | ""              |
| `mesos_api_version`             | Configures the Mesos API version to use              | "V1"            |
| `log_level`                     | The log level for the DC/OS service                  | "INFO"          |


### Geth

| Parameter          | Description                                     | Default   |
|--------------------|-------------------------------------------------|-----------|
| `network_id`       | Chain or Network ID                             | 18        |
| `mode`             | Ethereum network / operating mode               | "private" |
| `syncmode`         | Geth sync mode                                  | "full"    |
| `consensus_engine` | Consensus engine to use                         | "clique"  |
| `clique_period`    | Number of seconds blocks should take for clique | 15        |

### Boot

| Parameter               | Description                                   | Default |
|-------------------------|-----------------------------------------------|---------|
| `count`                 | Number of bootnodes to run                    |       1 |
| `cpus`                  | Bootnode CPU requirements                     |     0.1 |
| `mem`                   | Bootnode Memory requirements (in MB)          |     256 |
| `disk`                  | Bootnode Persistent disk requirements (in MB) |  150000 |
| `disk_type`             | Disk type                                     |    ROOT |
| `placement_contstraint` | Placement constraints for nodes               |      "" |
| `labels`                | Custom Mesos task labels for bootnode         |      "" |
| `verbosity`             | Bootstrap node log verbosity (0-9)            |       3 |

### Ethstats

| Parameter               | Description                                     |        Default |
|-------------------------|-------------------------------------------------|----------------|
| `count`                 | Number of ethstats nodes to run                 |              1 |
| `cpus`                  | Ethstats node CPU requirements                  |              1 |
| `mem`                   | Ethstats node Memory requirements (in MB)       |           1024 |
| `placement_contstraint` | Placement constraints for nodes                 |             "" |
| `labels`                | Custom Mesos task labels for ethstats node      |             "" |
| `verbosity`             | Ethstats node log verbosity (0-3)               |              3 |
| `websocket_secret`      | Secret for connecting to ethstats via websocket | "my-ws-secret" |

### Sealer

| Parameter               | Description                                              | Default                                         |
|-------------------------|----------------------------------------------------------|-------------------------------------------------|
| `count`                 | Number of sealer nodes to run                            | 1                                               |
| `cpus`                  | Sealer node CPU requirements                             | 1                                               |
| `mem`                   | Sealer node Memory requirements (in MB)                  | 1024                                            |
| `disk`                  | Sealer node Persistent disk requirements (in MB)         | 150000                                          |
| `disk_type`             | Disk type                                                | ROOT                                            |
| `placement_contstraint` | Placement constraints for nodes                          | ""                                              |
| `labels`                | Custom Mesos task labels for sealer node                 | ""                                              |
| `args`                  | Additional sealer node CLI arguments for geth command    | "--metrics --mine --minerthreads=1"             |
| `verbosity`             | Sealer node log verbosity (0-9)                          | 3                                               |
| `rpcapi`                | API functionality to expose                              | "debug,db,personal,eth, network,web3,net,miner" |
| `create_accounts`       | Create and pre-fund an account for each sealer node      | true                                            |
| `unlock_accounts`       | Unlock each sealer account upon starting geth            | true                                            |
| `account_privatekeys`   | Comma separated list of private keys to use              | ""                                              |
| `account_secret`        | Account secret passphrase to use for all sealer accounts | "p@ssw0rd"                                      |

### Client

| Parameter               | Description                                              | Default                                         |
|-------------------------|----------------------------------------------------------|-------------------------------------------------|
| `count`                 | Number of client nodes to run                            | 1                                               |
| `cpus`                  | Client node CPU requirements                             | 1                                               |
| `mem`                   | Client node Memory requirements (in MB)                  | 1024                                            |
| `disk`                  | Client node Persistent disk requirements (in MB)         | 150000                                          |
| `disk_type`             | Disk type                                                | ROOT                                            |
| `placement_contstraint` | Placement constraints for nodes                          | ""                                              |
| `labels`                | Custom Mesos task labels for client node                 | ""                                              |
| `args`                  | Additional client node CLI arguments for geth command    | "--metrics"                                     |
| `verbosity`             | Client node log verbosity (0-9)                          | 3                                               |
| `rpcapi`                | API functionality to expose                              | "debug,db,personal,eth, network,web3,net,miner" |
| `create_accounts`       | Create and pre-fund an account for each client node      | true                                            |
| `unlock_accounts`       | Unlock each client account upon starting geth            | true                                            |
| `account_privatekeys`   | Comma separated list of private keys to use              | ""                                              |
| `account_secret`        | Account secret passphrase to use for all client accounts | "p@ssw0rd"                                      |
