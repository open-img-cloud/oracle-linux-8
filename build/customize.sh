#!/usr/bin/env bash
# Customize hook called by the build-libguestfs-image reusable workflow.
# Receives the qcow2 path as $1.
#
# Oracle Linux 8 KVM templates ship with cloud-init, openssh-server,
# GRUB2 with serial console wired, and an `oracle` (or `cloud-user`
# depending on build) default user pre-configured. The org-wide
# cloud-init policy drop-in (datasource_list, disable_root,
# ssh_pwauth=false, mount_default_fields) is injected by the reusable
# workflow AFTER this script runs. Customisation reduces to a dnf
# cache cleanup so the published qcow2 stays small.
#
# Note: like AL2/AL2023 we don't try to install qemu-guest-agent here
# Oracle's pinned dnf snapshot can return "No match for argument" on
# packages we expect to be there. Add it back as a follow-up once the
# right repo is identified.

set -euo pipefail

QCOW2="${1:?usage: customize.sh <path-to-qcow2>}"

if [[ ! -f "$QCOW2" ]]; then
  echo "::error::qcow2 not found: $QCOW2" >&2
  exit 1
fi

echo "[customize] target: $QCOW2"

virt-customize -a "$QCOW2" \
  --run-command 'rm -rf /var/cache/dnf /var/cache/yum /tmp/* /var/tmp/*'

echo "[customize] done"
