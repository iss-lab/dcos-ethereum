#!/usr/bin/env python3
#
# Creates local artifacts to be added to a remote HTTP server.
# Produces a universe, and puts it in a host dir.
#
# Env:
#   HTTP_DIR (default: /tmp/dcos-http-<pkgname>/)
#   HTTP_HOST (default: 172.17.0.1, which is the ip of the VM when running dcos-docker)
#   HTTP_PORT (default: 0, for an ephemeral port)

import json
import logging
import os
import os.path
import shutil
import socket
import subprocess
import sys

import universe

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG, format="%(message)s")


class FilesPublisher(object):

    def __init__(
            self,
            package_name,
            package_version,
            input_dir_path,
            artifact_paths):
        self._pkg_name = package_name
        self._pkg_version = package_version
        self._input_dir_path = input_dir_path

        self._http_dir = os.environ.get('HTTP_DIR', '/tmp/dcos-http-{}/'.format(package_name))
        self._http_host = os.environ.get('HTTP_HOST', '172.17.0.1')
        self._http_port = int(os.environ.get('HTTP_PORT', '0'))
        self._http_url_root = os.environ.get('HTTP_URL_ROOT', 'http://{}:{}'.format(self._http_host, self._http_port))

        if not os.path.isdir(input_dir_path):
            raise Exception('Provided package path is not a directory: {}'.format(input_dir_path))

        self._artifact_paths = []
        for artifact_path in artifact_paths:
            if not os.path.isfile(artifact_path):
                err = 'Provided package path is not a file: {} (full list: {})'.format(artifact_path, artifact_paths)
                raise Exception(err)
            self._artifact_paths.append(artifact_path)


    def _copy_artifact(self, http_url_root, filepath):
        filename = os.path.basename(filepath)
        destpath = os.path.join(self._http_dir, filename)
        logger.info('- {}'.format(destpath))
        shutil.copyfile(filepath, destpath)
        return '{}/{}'.format(http_url_root, filename)


    def build(self, http_url_root):
        '''copies artifacts and a new stub universe into the http root directory'''
        universe_path = self._package_builder.build_package()

        # wipe files in dir
        if not os.path.isdir(self._http_dir):
            os.makedirs(self._http_dir)
        for filename in os.listdir(self._http_dir):
            path = os.path.join(self._http_dir, filename)
            logger.info('Deleting preexisting file in artifact dir: {}'.format(path))
            os.remove(path)

        # print universe url early
        universe_url = self._copy_artifact(http_url_root, universe_path)
        logger.info('---')
        logger.info('Built and copied stub universe:')
        logger.info(universe_url)
        logger.info('---')
        logger.info('Copying {} artifacts into {}:'.format(len(self._artifact_paths), self._http_dir))

        for path in self._artifact_paths:
            self._copy_artifact(http_url_root, path)

        # print to stdout, while the rest is all stderr:
        print(universe_url)

        return universe_url


def print_help(argv):
    logger.info('Syntax: {} <package-name> <template-package-dir> [artifact files ...]'.format(argv[0]))
    logger.info('  Example: $ {} kafka /path/to/universe/jsons/ /path/to/artifact1.zip /path/to/artifact2.zip /path/to/artifact3.zip'.format(argv[0]))
    logger.info('In addition, environment variables named \'TEMPLATE_SOME_PARAMETER\' will be inserted against the provided package template (with params of the form \'{{some-parameter}}\')')


def main(argv):
    if len(argv) < 3:
        print_help(argv)
        return 1
    # the package name:
    package_name = argv[1]
    # the package version:
    package_version = argv[2]
    # local path where the package template is located:
    package_dir_path = argv[3].rstrip('/')
    # artifact paths (to copy along with stub universe)
    artifact_paths = argv[4:]
    logger.info('''###
Package:         {}
Version:         {}
Template path:   {}
Artifacts:
{}
###'''.format(package_name, package_version, package_dir_path, '\n'.join(['- {}'.format(path) for path in artifact_paths])))

    publisher = FilesPublisher(package_name, package_version, package_dir_path, artifact_paths)
    package_info = universe.Package(publisher._pkg_name, publisher._pkg_version)
    package_manager = universe.PackageManager()
    publisher._package_builder = universe.UniversePackageBuilder(
        package_info, package_manager,
        publisher._input_dir_path, publisher._http_url_root, publisher._artifact_paths)
    universe_url = publisher.build(publisher._http_url_root)

    logger.info('---')
    logger.info('(Re)install your package using the following commands:')
    logger.info('dcos package uninstall {}'.format(package_name))
    logger.info('\n- - - -\nFor 1.9 or older clusters only')
    logger.info('dcos node ssh --master-proxy --leader ' +
                '"docker run mesosphere/janitor /janitor.py -r {0}-role -p {0}-principal -z dcos-service-{0}"'.format(package_name))
    logger.info('- - - -\n')

    logger.info('dcos package repo remove {}-local'.format(package_name))
    logger.info('dcos package repo add --index=0 {}-local {}'.format(package_name, universe_url))

    logger.info('dcos package install --yes {}'.format(package_name))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
