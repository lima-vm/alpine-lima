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

# cloud-init requires udev instead
if [ "${LIMA_INSTALL_CLOUD_INIT}" != "true" ]; then
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

rc_add local default

rc_add networking default

rc_add sshd default

mkdir -p "${tmp}/etc/local.d/"
makefile root:root 0755 "$tmp/etc/local.d/lima.start" << EOF
sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
rc-service sshd reload
EOF

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
network: { config: disabled }
EOF
fi

if [ "${LIMA_INSTALL_K3S}" == "true" ]; then
    echo "k3s" >> "$tmp"/etc/apk/world
    rc_add k3s default
fi

if [ "${LIMA_INSTALL_SSHFS}" == "true" ]; then
    echo "sshfs" >> "$tmp"/etc/apk/world
    echo "modprobe fuse" >> "$tmp/etc/local.d/lima.start"
fi

# Can't be a symlink because ash is a busybox symlink itself
mkdir -p "${tmp}/bin"
makefile root:root 0755 "$tmp/bin/bash" << 'EOF'
#!/bin/ash
exec /bin/ash "$@"
EOF

# adapted from scripts/genrootfs.sh
makefile root:root 0755 "$tmp/etc/local.d/apkrepos.start" << 'EOF'
branch=edge
VERSION_ID=$(awk -F= '$1=="VERSION_ID" {print $2}'  "$tmp"/etc/os-release)
case $VERSION_ID in
*_alpha*|*_beta*) branch=edge;;
*.*.*) branch=v${VERSION_ID%.*};;
esac

for repo in main community; do
  url="https://dl-cdn.alpinelinux.org/alpine/${branch}/${repo}"
  if ! grep -q "^${url}$" /etc/apk/repositories; then
    echo "${url}" >> /etc/apk/repositories
  fi
done
EOF

tar -c -C "$tmp" bin etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
