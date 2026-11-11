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

# Oracle's cloud-init 23.4 for OL8 (23.4-7.0.4.el8_10.12) ships a backport
# that calls util.load_text_file(), a name that only exists from cloud-init
# 24.1 (it is util.load_file() in 23.4). It crashes the init-local stage in
# net/sysconfig.py while rendering DNS, so the network config from the
# OpenStack metadata is not applied and cloud-init reports an error.
# Rename the calls only while util.py lacks load_text_file, so a fixed
# Oracle package is left untouched.
CI_FIX='d=$(ls -d /usr/lib/python3*/site-packages/cloudinit 2>/dev/null | head -n1); \
if [ -n "$d" ] && ! grep -q "def load_text_file" "$d/util.py"; then \
  grep -rl "util\.load_text_file(" "$d" --include=*.py | xargs -r sed -i "s/util\.load_text_file(/util.load_file(/g"; \
  find "$d" -name "*.pyc" -delete; \
  echo "cloud-init: load_text_file calls renamed"; \
fi'

virt-customize -a "$QCOW2" \
  --run-command "$CI_FIX" \
  --run-command 'rm -rf /var/cache/dnf /var/cache/yum /tmp/* /var/tmp/*'

echo "[customize] done"
