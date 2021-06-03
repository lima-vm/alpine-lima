ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}
RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot syslinux xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi
RUN adduser -h /home/build -D build -G abuild
ADD src/aports /home/build/aports
RUN echo "%abuild ALL=(ALL) ALL" > /etc/sudoers.d/abuild
WORKDIR /home/build/aports/scripts
ENTRYPOINT ["sh", "./mkimage.sh"]
RUN apk update
USER build
RUN abuild-keygen -i -a
