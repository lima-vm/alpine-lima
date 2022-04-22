ARG ALPINE_VERSION=latest
ARG BINFMT_IMAGE=tonistiigi/binfmt:latest

FROM ${BINFMT_IMAGE} as binfmt

FROM alpine:${ALPINE_VERSION}
RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi

# syslinux is missing for aarch64
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then apk add syslinux; fi

COPY --from=binfmt /usr/bin /binfmt

RUN addgroup root abuild
RUN abuild-keygen -i -a -n
RUN apk update

ADD src/aports /home/build/aports

RUN if [ "${TARGETARCH}" = "arm64" ]; then pkg_arch=aarch64; else pkg_arch=x86_64; fi && \
   mkdir -p /home/build/packages/lima/${pkg_arch} && \
   cd /home/build/packages/lima/${pkg_arch} && \
   apk fetch cni-plugins --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community && \
   apk fetch cni-plugin-flannel --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community && \
   apk index -o APKINDEX.tar.gz *.apk && \
   abuild-sign APKINDEX.tar.gz

WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
