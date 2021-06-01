FROM alpine:3.13
RUN apk add alpine-sdk build-base apk-tools alpine-conf busybox \
  fakeroot syslinux xorriso squashfs-tools sudo \
  mtools dosfstools grub-efi
RUN adduser -h /home/build -D build -G abuild
ADD src/aports /home/build/aports
RUN echo "%abuild ALL=(ALL) ALL" > /etc/sudoers.d/abuild
WORKDIR /home/build/aports/scripts
RUN apk update
USER build
RUN abuild-keygen -i -a
