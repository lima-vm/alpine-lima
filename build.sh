#!/usr/bin/env bash
set -eu

DOCKER=${DOCKER:-docker}

mkdir -p iso

TAG="${EDITION}-${ALPINE_VERSION}"

source "edition/${EDITION}"

${DOCKER} run --rm \
    --platform "linux/${ARCH_ALIAS}" \
    -v "${PWD}/iso:/iso" \
    -v "${PWD}/mkimg.lima.sh:/home/build/aports/scripts/mkimg.lima.sh:ro" \
    -v "${PWD}/genapkovl-lima.sh:/home/build/aports/scripts/genapkovl-lima.sh:ro" \
    -v "${PWD}/lima-init.sh:/home/build/lima-init.sh:ro" \
    -v "${PWD}/lima-init.openrc:/home/build/lima-init.openrc:ro" \
    -v "${PWD}/lima-init-local.openrc:/home/build/lima-init-local.openrc:ro" \
    -v "${PWD}/lima-network.awk:/home/build/lima-network.awk:ro" \
    -v "${PWD}/nerdctl-full-${NERDCTL_VERSION}-${ARCH}:/home/build/nerdctl-full.tar.gz:ro" \
    -v "${PWD}/qemu-${QEMU_VERSION}-copying:/home/build/qemu-copying:ro" \
    -v "${PWD}/cri-dockerd-${CRI_DOCKERD_VERSION}-${ARCH}:/home/build/cri-dockerd.tar.gz:ro" \
    -v "${PWD}/cri-dockerd-${CRI_DOCKERD_VERSION}-${ARCH}.LICENSE:/home/build/cri-dockerd.license:ro" \
    -v "${PWD}/sshd.pam:/home/build/sshd.pam:ro" \
    $(env | grep ^LIMA_ | xargs -n 1 printf -- '-e %s ') \
    -e "LIMA_REPO_VERSION=${REPO_VERSION}" \
    -e "LIMA_BUILD_ID=${BUILD_ID}" \
    -e "LIMA_VARIANT_ID=${EDITION}" \
    "mkimage:${ALPINE_VERSION}-${ARCH}" \
    --tag "${TAG}" \
    --outdir /iso \
    --arch "${ARCH}" \
    --repository "/home/build/packages/lima" \
    --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/main" \
    --repository "http://dl-cdn.alpinelinux.org/alpine/${REPO_VERSION}/community" \
    --profile lima

ISO="alpine-lima-${EDITION}-${ALPINE_VERSION}-${ARCH}.iso"
cd iso && sha512sum "${ISO}" > "${ISO}.sha512sum"
