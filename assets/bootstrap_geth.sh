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

if [ -f ethdata/genesis.json ]; then
    echo "Copying existing account and genesis data"
    cp ethdata/*.json ethereum-scheduler/
    exit 0
fi

: "${BOOT_BIN:=./bootnode}"
: "${GETH_BIN:=./geth}"
: "${BOOTSTRAP_GETH_BIN:=./bootstrap_geth}"
: "${GENESIS_ENGINE:=clique}"
: "${GENESIS_PERIOD:=15}"
: "${TASKCFG_ALL_NETWORK_ID:=18}"
CLIENT_ACCOUNTS=${CLIENT_NODE_COUNT}
SEALER_ACCOUNTS=${SEALER_NODE_COUNT}

if [ -z ${TASKCFG_SEALER_CREATE_ACCOUNTS+x} ]; then
    echo "Not creating new sealer accounts"
    SEALER_ACCOUNTS=0
fi
if [ -z ${TASKCFG_CLIENT_CREATE_ACCOUNTS+x} ]; then
    echo "Not creating new client accounts"
    CLIENT_ACCOUNTS=0
fi

if [ -z ${TASKCFG_SEALER_ACCOUNT_PRIVATEKEYS+x} ]; then
    echo "Not importing sealer accounts"
else
    echo "Importing sealer accounts"
    while IFS=',' read -ra PKS; do
        for i in "${PKS[@]}"; do
            ${GETH_BIN} account import --keystore ethdata/sealers --password <(echo ${TASKCFG_SEALER_ACCOUNT_SECRET}) <(echo ${i})
        done
    done <<< "${TASKCFG_SEALER_ACCOUNT_PRIVATEKEYS}"
fi

if [ -z ${TASKCFG_CLIENT_ACCOUNT_PRIVATEKEYS+x} ]; then
    echo "Not importing client accounts"
else
    echo "Importing client accounts"
    while IFS=',' read -ra PKS; do
        for i in "${PKS[@]}"; do
            ${GETH_BIN} account import --keystore ethdata/clients --password <(echo ${TASKCFG_CLIENT_ACCOUNT_SECRET}) <(echo ${i})
        done
    done <<< "${TASKCFG_CLIENT_ACCOUNT_PRIVATEKEYS}"
fi

echo "Generating bootnode"
${BOOT_BIN} -genkey boot.key
BOOT_KEY=$(cat boot.key)
BOOT_ADDRESS=$(${BOOT_BIN} -nodekey=boot.key -writeaddress)
echo "{\"boot_key\": \"${BOOT_KEY}\", \"boot_address\": \"${BOOT_ADDRESS}\"}" > ethdata/bootnode.json

${BOOTSTRAP_GETH_BIN} \
    -numSignerAddresses ${SEALER_ACCOUNTS} \
    -numClientAddresses ${CLIENT_ACCOUNTS} \
    -signerAuth ${TASKCFG_SEALER_ACCOUNT_SECRET} \
    -clientAuth ${TASKCFG_CLIENT_ACCOUNT_SECRET} \
    -chainID ${TASKCFG_ALL_NETWORK_ID} \
    -engine ${GENESIS_ENGINE} \
    -period ${GENESIS_PERIOD} \
    -signerKeystore ethdata/sealers \
    -clientKeystore ethdata/clients \
    -genesisFilename ethdata/genesis.json \
    -signerFilename ethdata/sealers.json \
    -clientFilename ethdata/clients.json

cp ethdata/*.json ethereum-scheduler/
