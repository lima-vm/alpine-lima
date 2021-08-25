#!/bin/sh
exec >/var/log/lima-init.log 2>&1
set -eux

ln -s /var/log/lima-init.log /var/log/cloud-init-output.log

LIMA_CIDATA_MNT="/mnt/lima-cidata"
LIMA_CIDATA_DEV="/dev/disk/by-label/cidata"
mkdir -p -m 700 "${LIMA_CIDATA_MNT}"
mount -o ro,mode=0700,dmode=0700,overriderockperm,exec,uid=0 "${LIMA_CIDATA_DEV}" "${LIMA_CIDATA_MNT}"
export LIMA_CIDATA_MNT

. "${LIMA_CIDATA_MNT}"/lima.env

# Set hostname
LIMA_CIDATA_HOSTNAME="$(awk '/^local-hostname:/ {print $2}' "${LIMA_CIDATA_MNT}"/meta-data)"
hostname "${LIMA_CIDATA_HOSTNAME}"

# Create user
LIMA_CIDATA_HOMEDIR="/home/${LIMA_CIDATA_USER}.linux"
useradd --home-dir "${LIMA_CIDATA_HOMEDIR}" --create-home --uid "${LIMA_CIDATA_UID}" "${LIMA_CIDATA_USER}"

# Add user to sudoers
echo "${LIMA_CIDATA_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-lima-users

# Create authorized_keys
LIMA_CIDATA_SSHDIR="${LIMA_CIDATA_HOMEDIR}"/.ssh
mkdir -p -m 700 "${LIMA_CIDATA_SSHDIR}"
awk '/ssh-authorized-keys/ {flag=1; next} /^ *$/ {flag=0} flag {sub(/^ +- /, ""); print $0}' \
	"${LIMA_CIDATA_MNT}"/user-data >"${LIMA_CIDATA_SSHDIR}"/authorized_keys
chown -R "${LIMA_CIDATA_USER}:${LIMA_CIDATA_USER}" "${LIMA_CIDATA_SSHDIR}"
chmod 600 "${LIMA_CIDATA_SSHDIR}"/authorized_keys

# Rename network interfaces according to network-config setting
mkdir -p /var/lib/lima-init
IP_RENAME=/var/lib/lima-init/ip-rename
ip -o link > /var/lib/lima-init/ip-link
awk -f /usr/bin/lima-network.awk \
    /var/lib/lima-init/ip-link \
    "${LIMA_CIDATA_MNT}"/network-config \
    > ${IP_RENAME}
chmod +x ${IP_RENAME}
ip link
${IP_RENAME}
ip link

# Create /etc/network/interfaces
awk -f- "${LIMA_CIDATA_MNT}"/network-config <<'EOF' > /etc/network/interfaces
BEGIN {
    print "auto lo"
    print "iface lo inet loopback\n"
}
/set-name/ {
    print "auto", $2
    print "iface", $2, "inet dhcp\n"
}
EOF

# Assign interface names by MAC address
# TODO: this should automatically assign the right interface names when the instance is
# restarted; alas it doesn't seem to have any effect.
awk -f- "${LIMA_CIDATA_MNT}"/network-config <<'EOF' > /etc/udev/rules.d/70-persistent-net.rules
/macaddress/ {
    gsub("'", "")
    mac = $2
}
/set-name/ {
    printf "SUBSYSTEM==\"NET\", ACTION==\"ADD\", DRIVERS==\"?*\", ATTR{address}==\"%s\", NAME=\"%s\"\n", mac, $2
}
EOF

exec "${LIMA_CIDATA_MNT}"/boot.sh
