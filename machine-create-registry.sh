#!/bin/sh
#
# Laurent Malvert <laurent.malvert@gmail.com>
#
# quick-n-dirty local registry proxy cache to speed up image retrieval
# from disposable docker machines on a Mac OS X system.
#

DIR="${0%/*}"

REGISTRY_MACHINE_NAME="${1:-registry-proxy-cache}"


docker-machine rm "${REGISTRY_MACHINE_NAME}"

docker-machine create                              \
  --driver "xhyve"                                 \
  --xhyve-experimental-nfs-share                   \
  --engine-insecure-registry "localhost:5000"      \
  --engine-registry-mirror "http://localhost:5000" \
  "${REGISTRY_MACHINE_NAME}"

eval "$(docker-machine env ${REGISTRY_MACHINE_NAME})"

docker-compose -f "${DIR}/docker-compose.yml" up -d
