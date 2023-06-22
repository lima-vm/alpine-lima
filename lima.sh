#!/usr/bin/env bash
set -eu

case "$(uname)" in
  Darwin) display=cocoa;;
  Linux) display=gtk;;
esac
case "${ARCH}" in
  x86_64) bios=true;;
  *) bios=false;;
esac
cat <<EOF >"${EDITION}.yaml"
arch: "${ARCH}"
images:
- location: "${PWD}/iso/alpine-lima-${EDITION}-${ALPINE_VERSION}-${ALPINE_ARCH}.iso"
  arch: "${ARCH}"
mounts:
- location: "~"
  writable: false
- location: "/tmp/lima"
  writable: true
ssh:
  localPort: 40022
firmware:
  legacyBIOS: $bios
video:
  display: $display
containerd:
  system: false
  user: false
EOF

limactl delete -f "${EDITION}"
limactl start --tty=false "${EDITION}.yaml"
