<p align="center">
  <a href="https://openimages.cloud/images/oracle-linux-8/">
    <img src="https://openimages.cloud/img/og/oracle-linux-8.png" alt="Oracle Linux 8 cloud image for OpenStack and Proxmox" width="720">
  </a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/oracle-linux-8/"><img alt="Latest version" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fimages.openimages.cloud%2Foracle-linux-8%2Flatest%2FMANIFEST.json&query=%24.version&label=latest&color=2459c4&cacheSeconds=3600"></a>
  <a href="https://github.com/open-img-cloud/oracle-linux-8/actions/workflows/release.yml"><img alt="Release" src="https://github.com/open-img-cloud/oracle-linux-8/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://openimages.cloud/verify/"><img alt="Signed with Sigstore cosign" src="https://img.shields.io/badge/signed-Sigstore%20cosign-2459c4"></a>
  <a href="https://openimages.cloud/quality/"><img alt="Boot-tested on OpenStack" src="https://img.shields.io/badge/boot--tested-OpenStack-2459c4"></a>
  <a href="LICENSE"><img alt="License GPL-2.0" src="https://img.shields.io/badge/license-GPL--2.0-555"></a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/oracle-linux-8/"><b>Catalog page</b></a> ·
  <a href="https://images.openimages.cloud/oracle-linux-8/latest/">Download</a> ·
  <a href="https://openimages.cloud/verify/">Verify</a> ·
  <a href="https://github.com/open-img-cloud/docs">Documentation</a> ·
  <a href="https://github.com/open-img-cloud/oracle-linux-8/issues">Report an issue</a>
</p>

Oracle Linux 8 cloud image (qcow2) for **OpenStack** and **Proxmox**: Oracle's official
KVM template, verified, made ready for both clouds with the same rules as every
[openimages.cloud](https://openimages.cloud) image, signed with Sigstore cosign and boot-tested
on a real OpenStack before it is published.
For new deployments, prefer [Oracle Linux 9](https://github.com/open-img-cloud/oracle-linux-9)
or [Oracle Linux 10](https://github.com/open-img-cloud/oracle-linux-10).

## At a glance

| | |
|---|---|
| **Upstream** | [Oracle Linux](https://www.oracle.com/linux/) KVM template `OL8U<update>_x86_64-kvm-b<build>.qcow2` from [yum.oracle.com](https://yum.oracle.com/oracle-linux-templates.html), checked against the SHA-256 Oracle publishes on that page |
| **Default user** | `cloud-user`, SSH key only, passwordless `sudo` |
| **Firmware** | BIOS |
| **Format** | qcow2, x86_64, LVM root grown to the disk at every boot |
| **Version** | `8.<update>-b<build>`, mirroring Oracle's template naming, e.g. `8.10-b287` ([all versions](https://images.openimages.cloud/oracle-linux-8/versions.json)) |
| **Support** | Oracle premier support until July 2029 (extended support to July 2032) |

## Quick start

```sh
# Latest version and its file name, from the signed manifest
M=https://images.openimages.cloud/oracle-linux-8/latest/MANIFEST.json
V=$(curl -fsS $M | jq -r .version); F=$(curl -fsS $M | jq -r .filename)
curl -fLO https://images.openimages.cloud/oracle-linux-8/$V/$F
```

<details>
<summary><b>OpenStack</b></summary>

```sh
openstack image create --disk-format qcow2 --container-format bare \
  --min-disk 40 \
  --property os_distro=ol --property os_version=8 \
  --property os_admin_user=cloud-user \
  --file "$F" "Oracle Linux 8"
```

The full property set (SCSI disk, multiqueue, quiesced snapshots) is on the
[catalog page](https://openimages.cloud/images/oracle-linux-8/) and in
[`index.json`](https://images.openimages.cloud/index.json). To keep images up to date
automatically, use [oic-sync](https://github.com/open-img-cloud/oic-sync).

</details>

<details>
<summary><b>Proxmox VE</b></summary>

The commands to create a cloud-init template from this image are on the
[catalog page](https://openimages.cloud/images/oracle-linux-8/).

</details>

<details>
<summary><b>Verify the signature</b></summary>

```sh
curl -fLO https://images.openimages.cloud/oracle-linux-8/$V/$F.bundle
cosign verify-blob "$F" --bundle "$F.bundle" \
  --certificate-identity-regexp '^https://github.com/open-img-cloud/\.github/\.github/workflows/build-(libguestfs|dib|nix-flake|freebsd)-image\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

</details>

## What this image changes

On top of the official image, and nothing else:

- adds a cloud-init per-boot script that grows the LVM root (partition, physical volume,
  root logical volume and its filesystem) to the whole disk: cloud-init's own `growpart`
  skips an unencrypted LVM root, so the flavor disk beyond the image size stayed unused;
- works around Oracle's cloud-init 23.4 package, whose backport calls
  `util.load_text_file()` (a cloud-init 24.1 name) and crashed the network configuration
  at boot: the calls are renamed only while `util.py` lacks that function, so a fixed Oracle
  package is left untouched;
- adds the openimages.cloud cloud-init policy: config drive read first, then the metadata
  service; no root login, no SSH password;
- cleans package caches and machine identity so every instance starts fresh.

Every release must pass the same [runtime contract](https://openimages.cloud/quality/) on
OpenStack: SSH with the injected key, cloud-init finished, DNS, hostname, root filesystem grown,
passwordless `sudo`, IPv6 address and egress.

## Notes

- The image declares a 37 GB virtual disk: use a flavor with at least a 40 GB root disk.
- `qemu-guest-agent` is not added: Oracle's pinned package snapshot does not reliably
  provide it, so it is left out until the right repository is identified.

## How releases happen

1. Every day at 06:11 UTC a watcher looks for a new upstream image and opens a pull request
   that bumps [`VERSION`](VERSION).
2. Merging it is all it takes: the release is tagged, built, signed, boot-tested and
   published, then `latest/` and the [catalog](https://openimages.cloud/images/) move to it.

This repository only holds what is specific to Oracle Linux 8: [`VERSION`](VERSION),
[`build/customize.sh`](build/customize.sh), [`build/config/oic-grow-lvm-root.sh`](build/config/oic-grow-lvm-root.sh),
[`build/detect-upstream.sh`](build/detect-upstream.sh), [`build/upstream-sha256.sh`](build/upstream-sha256.sh)
and thin workflows calling the shared pipeline in
[`open-img-cloud/.github`](https://github.com/open-img-cloud/.github).

## License

The build tooling in this repository is under [GPL-2.0](LICENSE). The image keeps the licensing
terms of Oracle Linux (free software under the license of each package). Oracle Linux is a trademark of its owner; this project is not affiliated with Oracle.
