#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
openssh
EOF

rc_add devfs sysinit
rc_add dmesg sysinit

# cloud-init / lima-init require udev instead (for /dev/disk/...)
if [ "${LIMA_INSTALL_CLOUD_INIT}" != "true" -a "${LIMA_INSTALL_LIMA_INIT}" != "true" ]; then
    rc_add mdev sysinit
    rc_add hwdrivers sysinit
fi

rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

rc_add networking default

rc_add sshd default

if [ "${LIMA_INSTALL_LIMA_INIT}" == "true" ]; then
    rc_add lima-init default

    mkdir -p "${tmp}/etc/init.d/"
    cp /home/build/lima-init.openrc "${tmp}/etc/init.d/lima-init"

    mkdir -p "${tmp}/usr/bin/"
    cp /home/build/lima-init.sh "${tmp}/usr/bin/lima-init"
    cp /home/build/lima-network.awk "${tmp}/usr/bin/lima-network.awk"

    echo e2fsprogs >> "$tmp"/etc/apk/world
    echo lsblk >> "$tmp"/etc/apk/world
    echo sfdisk >> "$tmp"/etc/apk/world
    echo shadow >> "$tmp"/etc/apk/world
    echo sudo >> "$tmp"/etc/apk/world
    echo udev >> "$tmp"/etc/apk/world

    rc_add udev sysinit
    rc_add udev-postmount default
    rc_add udev-trigger sysinit

    rc_add machine-id sysinit
fi

if [ "${LIMA_INSTALL_CLOUD_INIT}" == "true" ]; then
    echo cloud-init >> "$tmp"/etc/apk/world

    rc_add cloud-init-local boot
    rc_add cloud-config default
    rc_add cloud-final default
    rc_add cloud-init default

    rc_add udev sysinit
    rc_add udev-postmount default
    rc_add udev-trigger sysinit

    mkdir -p "${tmp}/etc/cloud/cloud.cfg.d/"
    makefile root:root 0644 "$tmp/etc/cloud/cloud.cfg.d/10_lima.cfg" << EOF
datasource_list: [ NoCloud, None ]
EOF
fi

if [ "${LIMA_INSTALL_BINFMT_MISC}" == "true" ]; then
    echo "qemu-aarch64" >> "$tmp"/etc/apk/world

    mkdir -p "${tmp}/etc/init.d/"
    APKBUILD=/home/build/aports/community/qemu-openrc/APKBUILD
    PKGVER=$(awk '/^pkgver=/ {split($1, a, "="); print a[2]}' ${APKBUILD})
    URL=$(awk '/^url=/ {split($1, a, "="); print a[2]}' ${APKBUILD} | tr -d '"' | sed 's/github/raw.githubusercontent/')
    wget "${URL}/v${PKGVER}/qemu-binfmt.initd" -O "${tmp}/etc/init.d/qemu-binfmt"
    chmod +x "${tmp}/etc/init.d/qemu-binfmt"

    rc_add qemu-binfmt default
fi

if [ "${LIMA_INSTALL_CA_CERTIFICATES}" == "true" ]; then
    echo "ca-certificates" >> "$tmp"/etc/apk/world
fi

if [ "${LIMA_INSTALL_K3S}" == "true" ]; then
    echo "k3s" >> "$tmp"/etc/apk/world
    rc_add k3s default
fi

if [ "${LIMA_INSTALL_SSHFS}" == "true" ]; then
    echo "sshfs" >> "$tmp"/etc/apk/world
fi

mkdir -p "${tmp}/etc"
mkdir -p "${tmp}/usr"

tar -c -C "$tmp" etc usr | gzip -9n > $HOSTNAME.apkovl.tar.gz
