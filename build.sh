#!/usr/bin/env bash

mkdir -p iso

TAG="${EDITION}-${ALPINE_VERSION}"

source "edition/${EDITION}"

docker run -it --rm \
       -v "${PWD}/iso:/iso" \
       -v "${PWD}/mkimg.lima.sh:/home/build/aports/scripts/mkimg.lima.sh:ro" \
       -v "${PWD}/genapkovl-lima.sh:/home/build/aports/scripts/genapkovl-lima.sh:ro" \
       $(env | grep ^LIMA_ | xargs -n 1 printf -- '-e %s ') \
       -e "LIMA_REPO_VERSION=${REPO_VERSION}" \
       "mkimage:${ALPINE_VERSION}" \
       --tag "${TAG}" \
       --outdir /iso \
       --arch x86_64 \
       --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/main" \
       --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/community" \
       --profile lima
