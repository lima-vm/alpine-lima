ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}
RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi

# syslinux is missing for aarch64
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then apk add syslinux; fi

RUN adduser -h /home/build -D build -G abuild
RUN echo "%abuild ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/abuild
ADD src/aports /home/build/aports
WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
RUN apk update
USER build
RUN abuild-keygen -i -a -n
