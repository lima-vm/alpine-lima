#!/bin/sh
exec >>/var/log/lima-init.log 2>&1
set -eux

export LIMA_CIDATA_MNT="/mnt/lima-cidata"

if [ "${1:-}" != "--local" ]; then
    exec "${LIMA_CIDATA_MNT}"/boot.sh
fi

ln -s /var/log/lima-init.log /var/log/cloud-init-output.log

LIMA_CIDATA_DEV="/dev/disk/by-label/cidata"
mkdir -p -m 700 "${LIMA_CIDATA_MNT}"
mount -o ro,mode=0700,dmode=0700,overriderockperm,exec,uid=0 "${LIMA_CIDATA_DEV}" "${LIMA_CIDATA_MNT}"

# We can't just source lima.env because values might have spaces in them
while read -r line; do export "$line"; done <"${LIMA_CIDATA_MNT}"/lima.env

# Set hostname
LIMA_CIDATA_HOSTNAME="$(awk '/^local-hostname:/ {print $2}' "${LIMA_CIDATA_MNT}"/meta-data)"
hostname "${LIMA_CIDATA_HOSTNAME}"

# Set timezone
LIMA_CIDATA_TIMEZONE="$(awk '/^timezone:/ {print $2}' "${LIMA_CIDATA_MNT}"/user-data)"
if [ -n "${LIMA_CIDATA_TIMEZONE}" ]; then
    if setup-timezone "${LIMA_CIDATA_TIMEZONE}"; then
        echo "${LIMA_CIDATA_TIMEZONE}" >/etc/timezone
    fi
fi

# Create user
LIMA_CIDATA_HOMEDIR="/home/${LIMA_CIDATA_USER}.linux"
useradd --home-dir "${LIMA_CIDATA_HOMEDIR}" --create-home --uid "${LIMA_CIDATA_UID}" "${LIMA_CIDATA_USER}"

# Add user to sudoers
echo "${LIMA_CIDATA_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-lima-users

# Create authorized_keys
LIMA_CIDATA_SSHDIR="${LIMA_CIDATA_HOMEDIR}"/.ssh
mkdir -p -m 700 "${LIMA_CIDATA_SSHDIR}"
# Lima currently uses "ssh-authorized-keys", which is invalid and should be "ssh_authorized_keys"
awk '/ssh[-_]authorized[-_]keys/ {flag=1; next} /^ *$/ {flag=0} flag {sub(/^ +- /, ""); gsub(/^"|"$/,""); gsub("\\\\\"", "\""); print $0}' \
	"${LIMA_CIDATA_MNT}"/user-data >"${LIMA_CIDATA_SSHDIR}"/authorized_keys
LIMA_CIDATA_GID=$(id -g "${LIMA_CIDATA_USER}")
chown -R "${LIMA_CIDATA_UID}:${LIMA_CIDATA_GID}" "${LIMA_CIDATA_SSHDIR}"
chmod 600 "${LIMA_CIDATA_SSHDIR}"/authorized_keys

# Process mounts
MOUNT_SCRIPT=/etc/lima-mounts
echo "#!/bin/sh -eux" >"${MOUNT_SCRIPT}"
awk -f- "${LIMA_CIDATA_MNT}"/user-data <<'EOF' >>"${MOUNT_SCRIPT}"
/^mounts:/ {
    flag = 1
    next
}
/^- / && flag {
    # Use a pattern unlikely to appear in a filename. "\0" unfortunately doesn't work.
    FS = "<;><><;>"
    sub(/^ *- \[/, "")
    sub(/"?\] *$/, "")
    gsub("\"?, \"?", FS)
    printf "mkdir -p \"%s\"\n", $2
    printf "mount -t %s -o \"%s\" %s \"%s\"\n", $3, $4, $1, $2
    next
}
{
    flag = 0
}
EOF
chmod +x "${MOUNT_SCRIPT}"
"${MOUNT_SCRIPT}"

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

# Add static nameservers to /etc/resolv.conf
DNS=$(awk '/nameservers:/{flag=1; next} /^[^ ]/{flag=0} flag {gsub("^ +- +", ""); print}' \
          "${LIMA_CIDATA_MNT}"/user-data | tr "\n" " ")

if [ -n "${DNS}" ]; then
    sed -i "/export dns/a dns=\"${DNS}\"" /usr/share/udhcpc/default.script
fi

# Remove default CA certs
if grep -q "^  remove_defaults: true" "${LIMA_CIDATA_MNT}"/user-data >/dev/null; then
    rm /etc/ca-certificates.conf
    rm -rf /usr/share/ca-certificates/*
    update-ca-certificates
fi

# Add user-data CA certs to system certs
LIMA_CA_CERTS=/usr/share/ca-certificates/lima-init-ca-certs.crt
awk -f- "${LIMA_CIDATA_MNT}"/user-data <<'EOF' > ${LIMA_CA_CERTS}
# Lima currently uses "ca-certs", which is deprecated and should be "ca_certs"
/^ca[-_]certs:/ {
    cacerts = 1
    next
}
/^  trusted:/ && cacerts {
    trusted = 1
    next
}
/^  -/ {
    next
}
/^  / && trusted {
    sub(/^ +/, "")
    print
    next
}
# As long as the line is indented we may still be in the ca_certs block, looking for "trusted"
/^  / {
    next
}
{
    cacerts = 0
    trusted = 0
}
EOF
if [ -s ${LIMA_CA_CERTS} ]; then
    echo lima-init-ca-certs.crt >> /etc/ca-certificates.conf
    update-ca-certificates
fi
