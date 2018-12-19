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

include *.mk

BASE_DIR ?= $(shell pwd)
SDK_DIR ?= ${BASE_DIR}/dcos-commons
FRAMEWORK_DIR ?= ${BASE_DIR}/dcos-commons/frameworks/ethereum
export ETHEREUM_DOCUMENTATION_PATH ?= https://github.com/iss-lab/dcos-ethereum/tree/master/docs
export ETHEREUM_ISSUES_PATH ?= https://github.com/iss-lab/dcos-ethereum/issues
export PACKAGE_VERSION ?= 0.1.1

JQ_URL ?= https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
JQ_DIST ?= jq
GETH_DIR ?= geth-alltools-linux-amd64-1.8.12-37685930
GETH_DIST ?= ${GETH_DIR}.tar.gz
GETH_URL ?= https://gethstore.blob.core.windows.net/builds/${GETH_DIST}

GETH_SCRIPTS_DIST ?= ${FRAMEWORK_DIR}/build/distributions/geth-scripts.zip
SCHEDULER_DIST ?= ${FRAMEWORK_DIR}/build/distributions/$(shell basename ${FRAMEWORK_DIR})-scheduler.zip
BOOTSTRAP_GETH_DIST ?= bootstrap_geth

export RSYNC_HOST ?= bootstrap
export HTTP_PORT ?= 8888
export HTTP_HOST ?= localhost
export HTTP_URL_ROOT ?= https://github.com/iss-lab/dcos-ethereum/releases/download/v${PACKAGE_VERSION}
export HTTP_DIR ?= ${BASE_DIR}/artifacts
export MESOS_MASTER ?= leader.mesos

.PHONY: all distclean clean scheduler package build uninstall rsync repo install deploy

all: clean build

clean:
	rm -f sdk-artifacts
	rm -f ${BOOTSTRAP_GETH_DIST}
	rm -f assets/bootstrap_geth
	rm -rf dcos-commons/frameworks/ethereum/build

distclean: clean
	rm -rf ${JQ_DIST} ${GETH_DIST} ${GETH_DIR}
	rm -f assets/bootnode assets/geth assets/jq

sdk-artifacts:
	${SDK_DIR}/build.sh -b
	touch sdk-artifacts

${JQ_DIST}:
	curl -L -o ${JQ_DIST} ${JQ_URL}
	chmod 755 ${JQ_DIST}
	cp ${JQ_DIST} ${BASE_DIR}/assets/jq

${GETH_DIST}:
	curl -L -o ${GETH_DIST} ${GETH_URL}
	rm -rf ${GETH_DIR}
	tar -xvzf ${GETH_DIST}
	cp ${GETH_DIR}/bootnode ${BASE_DIR}/assets/
	cp ${GETH_DIR}/geth ${BASE_DIR}/assets/

${BOOTSTRAP_GETH_DIST}:
	go get github.com/ethereum/go-ethereum
	xgo --targets=linux/amd64 -v --dest ./ ./cmd/bootstrap_geth
	mv ${BOOTSTRAP_GETH_DIST}-linux-amd64 ${BOOTSTRAP_GETH_DIST}
	cp ${BOOTSTRAP_GETH_DIST} assets/${BOOTSTRAP_GETH_DIST}

framework-artifacts: ${JQ_DIST} ${GETH_DIST} ${BOOTSTRAP_GETH_DIST}

scheduler:
	${SDK_DIR}/gradlew -p ${FRAMEWORK_DIR} check distZip zipGethNode

package:
	${SDK_DIR}/tools/build_package.sh \
		ethereum \
		${FRAMEWORK_DIR} \
		-a ${SCHEDULER_DIST} \
		-a ${GETH_SCRIPTS_DIST} \
		-a ${SDK_DIR}/sdk/bootstrap/bootstrap.zip \
		-a ${SDK_DIR}/sdk/cli/dcos-service-cli-linux \
		-a ${SDK_DIR}/sdk/cli/dcos-service-cli-darwin \
		-a ${SDK_DIR}/sdk/cli/dcos-service-cli.exe \
		local-files \
		${PACKAGE_VERSION}

build: sdk-artifacts framework-artifacts scheduler package

force-remove:
	echo "Removing Marathon App..."
	dcos marathon app remove ethereum --force || true
	echo "Tearing down framework..."
	dcos service shutdown $(shell dcos service --json | jq -r '. | to_entries[] | select(.value.name == "ethereum") | .value.id') || true
	dcos service shutdown $(shell dcos service --inactive --json | jq -r '. | to_entries[] | select(.value.name == "ethereum") | .value.id') || true
	echo "Removing ZK data..."
	curl -XDELETE http://${MESOS_MASTER}:8181/exhibitor/v1/explorer/znode/dcos-service-ethereum
	echo "\nSSH to master and run 'docker run mesosphere/janitor /janitor.py -r ethereum-role -p ethereum-principal -z dcos-service-ethereum'"

uninstall:
	dcos package uninstall --yes ethereum || true

rsync:
	/usr/bin/rsync -a ${HTTP_DIR} ${RSYNC_HOST}:artifacts

repo:
	dcos package repo remove ethereum-local || true
	dcos package repo add --index=0 ethereum-local http://${HTTP_HOST}:${HTTP_PORT}/stub-universe-ethereum.json || true

install:
	dcos package install --yes ethereum

deploy: uninstall build rsync repo install
