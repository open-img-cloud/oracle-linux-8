<div id="top"></div>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![GPL-2.0 License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">

<h3 align="center">Oracle Linux 8 Cloud Images</h3>

  <p align="center">
    Cloud-init-ready, signed Oracle Linux 8 images for OpenStack and Proxmox
    <br />
    <br />
    <a href="https://github.com/open-img-cloud/oracle-linux-8/issues">Report a bug</a>
    ·
    <a href="https://github.com/open-img-cloud/oracle-linux-8/issues">Request a feature</a>
  </p>
</div>

## About

This repo builds [Oracle Linux 8][ol8] cloud images on top of the
upstream `OL8U<U>_x86_64-kvm-b<B>.qcow2` KVM templates published at
[yum.oracle.com/oracle-linux-templates.html][upstream] and republishes
them through the openimages.cloud signed-release pipeline.

OL8 is in Oracle's premier support until **July 2029** (extended
support to July 2032). It is published for existing OL8 / RHEL 8
workloads; for new deployments prefer
[open-img-cloud/oracle-linux-9][ol9-repo] or
[open-img-cloud/oracle-linux-10][ol10-repo].

The build pipeline is shared with the rest of [`open-img-cloud`][org]:
this repo only ships the `VERSION`, `customize.sh`, `detect-upstream.sh`,
and two thin caller workflows that delegate to the reusable workflows
in [`open-img-cloud/.github`][shared] (`@main`).

This pipeline is the openimages.cloud-aligned successor of the legacy
[`linitio/openstack-oracle-linux-image`][legacy] (2022-2024 vintage),
rebuilt around cosign-signed releases, R2/Garage object storage, and
the shared cloud-init policy drop-in.

Customisations applied to the upstream rootfs:

- **Org-wide cloud-init policy drop-in** (`99_oic-policy.cfg`) injected
  by the reusable workflow into `/etc/cloud/cloud.cfg.d/`, pinning
  `datasource_list: [OpenStack, ConfigDrive, NoCloud, None]` and
  `disable_root: true` / `ssh_pwauth: false`
- **`virt-sysprep`** to clean transient state, then `virt-sparsify --compress`

The upstream OL8 KVM template already ships cloud-init, openssh-server,
GRUB2 with serial console wired (`console=tty0 console=ttyS0,115200`),
and a default user (`oracle` or `cloud-user` depending on build): we
don't override any of that.

Each release publishes:

- `oracle-linux-8-<version>-x86_64.qcow2`
- `*.sha256`, `*.sha1`, `*.md5` per-file
- `*.bundle` cosign sigstore-bundle (signature + cert + Rekor proof)
- `MANIFEST.json` (build metadata, including the builder image digest)
- `index.html` directory listing

`<version>` is `8.<update>-b<build>` (e.g. `8.10-b287`), mirroring
Oracle's own OL{R}U{U}-b{B} naming.

## Where to download

Public CDN, served via Cloudflare in front of an R2 bucket (mirror of
the source-of-truth Garage):

| URL pattern                                                                          | Cache policy                  |
|--------------------------------------------------------------------------------------|-------------------------------|
| `https://images.openimages.cloud/oracle-linux-8/<version>/<filename>`                | `max-age=31536000, immutable` |
| `https://images.openimages.cloud/oracle-linux-8/latest/<filename>`                   | `max-age=300`                 |

Browse: [images.openimages.cloud/oracle-linux-8/latest/][latest]

## Verify before deploy

cosign 3.x:

```sh
sha256sum -c <filename>.sha256                    # integrity
cosign verify-blob \
    --bundle <filename>.bundle \
    --new-bundle-format \
    --certificate-identity-regexp '^https://github.com/open-img-cloud/\.github/\.github/workflows/build-libguestfs-image\.yml@' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    <filename>                                     # provenance
```

The certificate identity points at the **reusable** build workflow in
`open-img-cloud/.github`: that's where GitHub's OIDC binds the SAN for
keyless signing. To tie the artifact back to *this* repo's commit, also
check `MANIFEST.json` (commit, build_url, builder digest).

## How to use

### OpenStack

```sh
# Pull the qcow2 (replace <V> with the desired version, e.g. 8.10-b287)
curl -fLO https://images.openimages.cloud/oracle-linux-8/<V>/oracle-linux-8-<V>-x86_64.qcow2

openstack image create \
    --disk-format qcow2 --container-format bare \
    --min-disk 40 \
    --file oracle-linux-8-<V>-x86_64.qcow2 \
    'Oracle Linux 8 <V>'
```

### Proxmox VE

```sh
scp oracle-linux-8-<V>-x86_64.qcow2 root@proxmox:/var/lib/vz/template/iso/

qm create <VMID> --name ol8-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk <VMID> oracle-linux-8-<V>-x86_64.qcow2 <STORAGE>
qm set <VMID> --scsihw virtio-scsi-pci --scsi0 <STORAGE>:vm-<VMID>-disk-0
qm set <VMID> --boot c --bootdisk scsi0
qm set <VMID> --ide2 <STORAGE>:cloudinit
qm set <VMID> --serial0 socket --vga serial0
qm set <VMID> --ciuser cloud-user --sshkeys ~/.ssh/authorized_keys --ipconfig0 ip=dhcp
```

## Release flow

1. **`watch.yml`** runs daily 06:41 UTC, calls `build/detect-upstream.sh`
   which parses `oracle-linux-templates.html` for OL8 KVM artifacts and
   emits `8.<U>-b<B>` for the highest (U, B) pair.
2. If the version differs from the current `VERSION`, the workflow opens
   (or updates) a PR `auto/upstream-bump`.
3. Merging the PR + pushing a `v<VERSION>` tag fires `release.yml`,
   which calls the shared `build-libguestfs-image.yml@main` reusable
   workflow.
4. Each build downloads the upstream qcow2, runs `customize.sh`,
   sysprep, sparsify, signs, and uploads to Garage + R2 under
   `s3://oracle-linux-8/<version>/`.

## Repository layout

```
VERSION                          single line, e.g. "8.10-b287"
build/
  customize.sh                   virt-customize hook (qcow2 path as $1)
  detect-upstream.sh             parses oracle-linux-templates.html
.github/workflows/
  release.yml                    calls build-libguestfs-image.yml on tag push
  watch.yml                      daily cron, calls upstream-watch.yml
.gitignore                       repo-local override for global build/ exclusion
LICENSE                          GPL-2.0
```

## Contributing

Fork, branch, PR. Keep changes focused; the customize hook in particular
is consumed by the shared pipeline so backward-compatible tweaks are
preferred over rewrites.

## License

Distributed under the GPL-2.0 License. See `LICENSE`.

## Contact

Kevin Allioli · kevin@stackops.ch · [@stackopshq](https://twitter.com/stackopshq)

Project: [open-img-cloud/oracle-linux-8](https://github.com/open-img-cloud/oracle-linux-8)

[ol8]: https://www.oracle.com/linux/
[ol9-repo]: https://github.com/open-img-cloud/oracle-linux-9
[ol10-repo]: https://github.com/open-img-cloud/oracle-linux-10
[upstream]: https://yum.oracle.com/oracle-linux-templates.html
[legacy]: https://github.com/linitio/openstack-oracle-linux-image
[org]: https://github.com/open-img-cloud
[shared]: https://github.com/open-img-cloud/.github
[latest]: https://images.openimages.cloud/oracle-linux-8/latest/

<!-- shields -->
[contributors-shield]: https://img.shields.io/github/contributors/open-img-cloud/oracle-linux-8.svg?style=for-the-badge
[contributors-url]: https://github.com/open-img-cloud/oracle-linux-8/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/open-img-cloud/oracle-linux-8.svg?style=for-the-badge
[forks-url]: https://github.com/open-img-cloud/oracle-linux-8/network/members
[stars-shield]: https://img.shields.io/github/stars/open-img-cloud/oracle-linux-8.svg?style=for-the-badge
[stars-url]: https://github.com/open-img-cloud/oracle-linux-8/stargazers
[issues-shield]: https://img.shields.io/github/issues/open-img-cloud/oracle-linux-8.svg?style=for-the-badge
[issues-url]: https://github.com/open-img-cloud/oracle-linux-8/issues
[license-shield]: https://img.shields.io/github/license/open-img-cloud/oracle-linux-8.svg?style=for-the-badge
[license-url]: https://github.com/open-img-cloud/oracle-linux-8/blob/main/LICENSE
