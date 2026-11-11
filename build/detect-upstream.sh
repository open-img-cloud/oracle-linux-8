#!/usr/bin/env bash
# Prints the latest upstream Oracle Linux 8 KVM template version on stdout.
#
# Oracle's CDN is Akamai-fronted and returns 404 on directory listings,
# so we can't scrape `templates/OracleLinux/OL8/`. Instead we parse the
# canonical `oracle-linux-templates.html` page which lists every
# published artifact across OL7..OL10.
#
# Filename pattern for OL8 KVM images:
#   OL8U<U>_x86_64-kvm-b<B>.qcow2
# We extract (U, B) for the highest U then highest B, and emit
# `8.<U>-b<B>` (e.g. 8.10-b287) as the VERSION string. The reusable
# release workflow rebuilds the upstream URL by parsing this back.
#
# Runs in the upstream-watch reusable workflow (no KVM needed): keep
# it portable bash + curl + sed + sort only.

set -euo pipefail

URL='https://yum.oracle.com/oracle-linux-templates.html'

html=$(curl -fsL "$URL")
if [[ -z "$html" ]]; then
  echo "::error::could not fetch $URL" >&2
  exit 1
fi

# Extract every OL8U<U>_x86_64-kvm-b<B>.qcow2 from hrefs, then sort by
# (update, build) numerically and pick the highest. -V handles dotted
# numeric ordering correctly even though our format is plain integers.
latest=$(printf '%s\n' "$html" \
  | grep -oE 'OL8U[0-9]+_x86_64-kvm-b[0-9]+\.qcow2' \
  | sort -uV \
  | tail -n1)

if [[ -z "$latest" ]]; then
  echo "::error::no OL8 KVM artifact found in $URL" >&2
  exit 1
fi

# OL8U<U>_x86_64-kvm-b<B>.qcow2 → 8.<U>-b<B>
version=$(printf '%s' "$latest" | sed -E 's/^OL8U([0-9]+)_x86_64-kvm-b([0-9]+)\.qcow2$/8.\1-b\2/')
if [[ -z "$version" || "$version" == "$latest" ]]; then
  echo "::error::could not extract version from $latest" >&2
  exit 1
fi

printf '%s\n' "$version"
