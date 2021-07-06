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
adduser -h "${LIMA_CIDATA_HOMEDIR}" -u "${LIMA_CIDATA_UID}" -D "${LIMA_CIDATA_USER}"

# Add user to sudoers
echo "${LIMA_CIDATA_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-lima-users

# Create authorized_keys
LIMA_CIDATA_SSHDIR="${LIMA_CIDATA_HOMEDIR}"/.ssh
mkdir -p -m 700 "${LIMA_CIDATA_SSHDIR}"
awk '/ssh-authorized-keys/ {flag=1; next} /^ *$/ {flag=0} flag {sub(/^ +- /, ""); print $0}' \
	"${LIMA_CIDATA_MNT}"/user-data >"${LIMA_CIDATA_SSHDIR}"/authorized_keys
chown -R "${LIMA_CIDATA_USER}:${LIMA_CIDATA_USER}" "${LIMA_CIDATA_SSHDIR}"
chmod 600 "${LIMA_CIDATA_SSHDIR}"/authorized_keys

exec "${LIMA_CIDATA_MNT}"/boot.sh
