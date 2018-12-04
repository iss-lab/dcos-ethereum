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

echo "Running Geth Bootnode"

: "${GETH_P2P_PORT:=30310}"

: "${BOOT_BIN:=./bootnode}"
: "${GETH_VERBOSITY:=3}"

BOOT_KEY=$(cat ethdata/bootnode.json | ./jq -r .boot_key)

echo ${BOOT_KEY} > ethdata/boot.key

${BOOT_BIN} -verbosity=${GETH_VERBOSITY} -nodekey=ethdata/boot.key -addr=":${GETH_P2P_PORT}"
