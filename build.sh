#!/usr/bin/env bash

mkdir -p iso

# Strip patch level from Alpine version
REPO_VERSION="v${ALPINE_VERSION%.[0-9]*}"

TAG="${EDITION}-${ALPINE_VERSION}"

docker run -it --rm \
       -v "${PWD}/iso:/iso" \
       -v "${PWD}/mkimg.lima.sh:/home/build/aports/scripts/mkimg.lima.sh:ro" \
       -v "${PWD}/genapkovl-lima.sh:/home/build/aports/scripts/genapkovl-lima.sh:ro" \
       "mkimage:${ALPINE_VERSION}" \
       --tag "${TAG}" \
       --outdir /iso \
       --arch x86_64 \
       --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/main" \
       --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/community" \
       --profile lima
