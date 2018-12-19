#!/bin/bash
#
# MIT License
#
# Copyright (c) 2018 Institutional Shareholder Services. All other rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

echo "Running Geth Node ${TASK_NAME}"

mkdir -p ethdata/keystore
mkdir -p ethdata/geth
mkdir -p run

: "${POD_INSTANCE_INDEX:=0}"
: "${GETH_HTTP_PORT:=8101}"
: "${GETH_WS_PORT:=8546}"
: "${GETH_P2P_PORT:=30301}"
: "${GETH_BIN:=./geth}"
: "${NETWORK_ID:=18}"
: "${GETH_VERBOSITY:=3}"
: "${GETH_MODE:=private}"
: "${GETH_SYNCMODE:=full}"
: "${GETH_ARGS:=--metrics}"
: "${ENDPOINTS_URL:=http://api.${FRAMEWORK_NAME}.marathon.l4lb.thisdcos.directory:80/v1/endpoints}"

GETH_ARGS="${GETH_ARGS} --networkid ${NETWORK_ID}"
GETH_ARGS="${GETH_ARGS} --verbosity ${GETH_VERBOSITY}"
GETH_ARGS="${GETH_ARGS} --syncmode ${GETH_SYNCMODE}"
GETH_ARGS="${GETH_ARGS} --port ${GETH_P2P_PORT}"
GETH_ARGS="${GETH_ARGS} --datadir ethdata"
GETH_ARGS="${GETH_ARGS} --ipcpath run/geth.ipc"

if [ -z ${GETH_RPCAPI+x} ] ; then
    echo "Disabling rpc api listeners"
else
    echo "Enabling rpc api listeners"
    GETH_ARGS="${GETH_ARGS} --rpc --rpcaddr 0.0.0.0 --rpccorsdomain='*' --rpcapi ${GETH_RPCAPI} --rpcport ${GETH_HTTP_PORT}"
    GETH_ARGS="${GETH_ARGS} --ws --wsaddr 0.0.0.0 --wsorigins='*' --wsport ${GETH_WS_PORT}"
fi

if [ "${ETHSTATS_NODE_COUNT}" -gt "0" ]; then
    : "${ETHSTATS_LISTENER:=$(curl ${ENDPOINTS_URL}/geth-ethstats-http-port | ./jq -r .address[0])}"
    GETH_ARGS="${GETH_ARGS} --ethstats=${TASK_NAME}:${WS_SECRET}@${ETHSTATS_LISTENER}"
fi

if [ "${BOOT_NODE_COUNT}" -gt "0" ]; then
    echo "Configuring Bootnode"
    : "${BOOT_ADDRESS:=$(cat ethdata/bootnode.json | ./jq -r .boot_address)}"
    : "${BOOT_LISTENER:=$(curl ${ENDPOINTS_URL}/geth-boot-p2p-port | ./jq -r .address[0])}"
    : "${BOOT_ENODE:=enode://${BOOT_ADDRESS}@${BOOT_LISTENER}}"
    GETH_ARGS="${GETH_ARGS} --bootnodes=${BOOT_ENODE}"
fi

RUN_GETH="${GETH_BIN} ${GETH_ARGS}"
echo "RUN_GETH: ${RUN_GETH}"
echo "Effective Config:"
$RUN_GETH dumpconfig

if [ -z ${CREATE_GENESIS+x} ] ; then
    echo "Genesis not created, connecting to an external network"
else
    echo "Initializing node using genesis.json"
    ${GETH_BIN} --datadir ethdata init ethdata/genesis.json
fi

if [ -z ${CREATE_ACCOUNTS+x} ] && [ -z ${ACCOUNT_PRIVATEKEYS+x} ] ; then
    echo "Create account was false and no private keys were supplied"
    $RUN_GETH
else
    GETH_KEY=$(cat ethdata/accounts.json | ./jq -r ".keys[${POD_INSTANCE_INDEX} % (.keys | length)]")
    echo ${GETH_KEY} > ethdata/keystore/key1
    if [ -z ${UNLOCK_ACCOUNTS+x} ] ; then
        echo "Account stored in keystore, but it is locked"
        $RUN_GETH
    else
        GETH_ADDRESS=$(cat ethdata/accounts.json | ./jq -r ".addresses[${POD_INSTANCE_INDEX} % (.addresses | length)]")
        $RUN_GETH --unlock=${GETH_ADDRESS} --password <(echo ${ACCOUNT_SECRET})
    fi
fi
