ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}
RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi

# syslinux is missing for aarch64
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then apk add syslinux; fi

RUN addgroup root abuild
RUN abuild-keygen -i -a -n
RUN apk update

ADD src/aports /home/build/aports
WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
