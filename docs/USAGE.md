# DC/OS Ethereum Usage

### Validate installation

Validate that the installation added the enhanced DC/OS CLI for Ethereum:

```bash
$ dcos ethereum --help
usage: dcos ethereum [<flags>] <command>


Flags:
  -h, --help             Show context-sensitive help.
  -v, --verbose          Enable extra logging of requests/responses
      --name="ethereum"  Name of the service instance to query

Commands:
  help [<command> ...]
    Show help.


  debug config list
    List IDs of all available configurations


  debug config show <config_id>
    Display a specified configuration


  debug config target
    Display the target configuration


  debug config target_id
    List ID of the target configuration


  debug pod pause [<flags>] <pod>
    Pauses a pod's tasks for debugging

    -t, --tasks=TASKS ...  List of specific tasks to be paused, otherwise the entire pod


  debug pod resume [<flags>] <pod>
    Resumes a pod's normal execution following a pause command

    -t, --tasks=TASKS ...  List of specific tasks to be resumed, otherwise the entire pod


  debug state framework_id
    Display the Mesos framework ID


  debug state properties
    List names of all custom properties


  debug state property <name>
    Display the content of a specified property


  debug state refresh_cache
    Refresh the state cache, used for debugging


  describe
    View the configuration for this service


  endpoints [<name>]
    View client endpoints


  plan list
    Show all plans for this service


  plan status [<flags>] <plan>
    Display the status of the plan with the provided plan name

    --json  Show raw JSON response instead of user-friendly tree


  plan start [<flags>] <plan>
    Start the plan with the provided name and any optional plan arguments

    -p, --params=PARAMS ...  Envvar definition in VAR=value form; can be repeated for multiple variables


  plan stop <plan>
    Stop the running plan with the provided name


  plan pause <plan> [<phase>]
    Pause the plan, or a specific phase in that plan with the provided phase name (or UUID)


  plan resume <plan> [<phase>]
    Resume the plan, or a specific phase in that plan with the provided phase name (or UUID)


  plan force-restart <plan> [<phase> [<step>]]
    Restart the plan with the provided name, or a specific phase in the plan with the provided name, or a specific step in a phase of the plan with the provided step name.


  plan force-complete <plan> <phase> <step>
    Force complete a specific step in the provided phase. Example uses include the following: Abort a sidecar operation due to observed failure or known required manual preparation that was not performed


  pod list
    Display the list of known pod instances


  pod status [<flags>] [<pod>]
    Display the status for tasks in one pod or all pods

    --json  Show raw JSON response instead of user-friendly tree


  pod info <pod>
    Display the full state information for tasks in a pod


  pod restart <pod>
    Restarts a given pod without moving it to a new agent


  pod replace <pod>
    Destroys a given pod and moves it to a new agent


  update start [<flags>]
    Launches an update operation

    --options=OPTIONS  Path to a JSON file that contains customized package installation options, or 'stdin' to read from stdin
    --package-version=PACKAGE-VERSION
                       The desired package version
    --replace          Replace the existing configuration in whole. Otherwise, the existing configuration and options are merged.


  update force-complete <phase> <step>
    Force complete a specific step in the provided phase


  update force-restart [<phase> [<step>]]
    Restart update plan, or specific step in the provided phase


  update package-versions
    View a list of available package versions to downgrade or upgrade to


  update pause
    Pause update plan


  update resume
    Resume update plan


  update status [<flags>]
    View status of a running update

    --json  Show raw JSON response instead of user-friendly tree
```

In addition, you can go to the DC/OS UI to validate that the Ethereum service is running and healthy.

### List Endpoints

You can retrieve the connection info from the CLI:

```
$ dcos ethereum endpoints
```

Sample output:

```
[
  "geth-boot-p2p-port",
  "geth-client-http-port",
  "geth-client-p2p-port",
  "geth-client-ws-port",
  "geth-ethstats-http-port",
  "geth-sealer-http-port",
  "geth-sealer-p2p-port",
  "geth-sealer-ws-port"
]
```

#### Client Node HTTP

```bash
$ dcos ethereum endpoints geth-client-http-port
{
  "address": [
    "10.0.3.228:1032",
    "10.0.3.228:1035"
  ],
  "dns": [
    "client-0-node.ethereum.autoip.dcos.thisdcos.directory:1032",
    "client-1-node.ethereum.autoip.dcos.thisdcos.directory:1035"
  ]
}
```

## Perform RPC operations

We will use geth console interactively, so we will start a geth-console task:

```
$ vi geth-console.json
{
  "id": "/geth-console",
  "instances": 1,
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "ethereum/client-go:alltools-latest"
    }
  },
  "cpus": 0.5,
  "mem": 256,
  "cmd": "while true; do sleep 10000000; done"
}

$ dcos marathon app add geth-console.json
Created deployment fc984dfa-30d4-4d68-8b9e-b9e8038cd20d
```

Start a `geth attach` session in the previously started container:

```
$ dcos task exec -it geth-console /usr/local/bin/geth attach http://10.0.3.228:1032
Welcome to the Geth JavaScript console!

instance: Geth/v1.8.12-stable-37685930/linux-amd64/go1.10.3
coinbase: 0x0fd4aef71ee0edd5d18a4d76b959159a14d2fe32
at block: 5906 (Wed, 05 Dec 2018 20:33:46 UTC)
 modules: debug:1.0 eth:1.0 miner:1.0 net:1.0 personal:1.0 rpc:1.0 web3:1.0

>
```

You are now connected to your Ethereum cluster. Let's find the account created for this node:

```
> eth.accounts

["0x0fd4aef71ee0edd5d18a4d76b959159a14d2fe32"]
```

Next, check the account balance:

```
> eth.getBalance("0x0fd4aef71ee0edd5d18a4d76b959159a14d2fe32")

9.04625697166532776746648320380374280103671755200316906558262375061821325312e+74
```

We can also find the number of peers connected to this node:

```
> net.peerCount

4
```

For more information on geth attach and the JSRE REPL console, visit [github.com/ethereum/go-ethereum/wiki/JavaScript-Console](https://github.com/ethereum/go-ethereum/wiki/JavaScript-Console/). The available commands can be found at [github.com/ethereum/wiki/wiki/JavaScript-API](https://github.com/ethereum/wiki/wiki/JavaScript-API).
