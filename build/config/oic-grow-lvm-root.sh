#!/bin/sh
# cloud-init per-boot script: grow an LVM root to the whole disk.
#
# cloud-init's growpart skips a root on LVM unless it is encrypted
# ("Resizing mapped device ... skipped as it is not encrypted"), so the
# flavor disk beyond the image size stayed unused. Extend, in order: the
# partition of each physical volume of the root volume group, the PV,
# then the root LV with its filesystem (lvextend -r). Idempotent: does
# nothing when the root is not on LVM or when everything is already full.
set -u
src=$(findmnt -no SOURCE /) || exit 0
lvs "$src" >/dev/null 2>&1 || exit 0
vg=$(lvs --noheadings -o vg_name "$src" | tr -d ' ')
for pv in $(pvs --noheadings -o pv_name -S vg_name="$vg" | tr -d ' '); do
  name=$(basename "$pv")
  [ -r "/sys/class/block/$name/partition" ] || continue
  part=$(cat "/sys/class/block/$name/partition")
  disk=/dev/$(lsblk -no PKNAME "$pv" | head -n1)
  growpart "$disk" "$part" >/dev/null 2>&1 || true
  pvresize "$pv" >/dev/null 2>&1 || true
done
lvextend -r -l +100%FREE "$src" >/dev/null 2>&1 || true
