#!/usr/bin/env bash
set -eu

cat <<EOF >"${EDITION}.yaml"
images:
- location: "${PWD}/iso/alpine-lima-${EDITION}-${ALPINE_VERSION}-x86_64.iso"
  arch: "x86_64"
mounts:
- location: "~"
  writable: false
ssh:
  localPort: 40022
firmware:
  legacyBIOS: true
video:
  display: cocoa
containerd:
  system: false
  user: false
EOF

limactl delete -f "${EDITION}"
limactl start --tty=false "${EDITION}.yaml"
