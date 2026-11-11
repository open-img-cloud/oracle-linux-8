#!/usr/bin/env bash
# Prints the SHA-256 that Oracle publishes for one template file.
#
# Usage: build/upstream-sha256.sh <filename> [page-url-or-file]
#   e.g. build/upstream-sha256.sh OL8U10_x86_64-kvm-b287.qcow2
#
# Oracle publishes no checksum file next to the templates (no .sha256,
# no SHA256SUMS, nothing signed): the only official source is the
# "SHA256 Checksum" column of oracle-linux-templates.html, the same page
# detect-upstream.sh reads. Each table row holds the image links
# (<a class="kvm-image" ...>) and, in another cell, the hashes in the
# same order (<tt class="kvm-sha256">...</tt>). We pair them by row and
# by class, and require exactly one 64-hex match: anything else (file
# not listed, layout change, duplicates) is a hard error so the build
# never runs without a verified base.
#
# Note: the page only lists the latest template of each release, so a
# rebuild of an older VERSION fails here once Oracle has moved on.

set -euo pipefail

file=${1:?usage: $0 <filename> [page-url-or-file]}
src=${2:-https://yum.oracle.com/oracle-linux-templates.html}

if [[ ! "$file" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "::error::unexpected filename: $file" >&2
  exit 1
fi

if [[ -f "$src" ]]; then
  html=$(cat "$src")
else
  html=$(curl -fsSL --retry 3 --retry-delay 5 "$src")
fi

# One table row per line, so the image link and its hash share a line.
rows=$(printf '%s' "$html" | tr '\r\n' '  ' | sed 's#</tr>#&\n#g')
file_re=${file//./\\.}
row=$(printf '%s\n' "$rows" | grep -E "href=\"[^\"]*/${file_re}\"" || true)
if [[ $(printf '%s' "$row" | grep -c '^') -ne 1 ]]; then
  echo "::error::expected exactly one row listing $file in $src" >&2
  exit 1
fi

# Class of the link to this file (e.g. kvm-image), wherever the
# attribute sits inside the <a> tag.
cls=$(printf '%s\n' "$row" \
  | grep -oE "<a [^>]*href=\"[^\"]*/${file_re}\"[^>]*>" \
  | grep -oE 'class="[a-z0-9-]+-image"' \
  | sed -E 's/^class="(.*)-image"$/\1/' || true)
if [[ -z "$cls" || $(printf '%s' "$cls" | grep -c '^') -ne 1 ]]; then
  echo "::error::could not identify the image class of $file in $src" >&2
  exit 1
fi

hashes=$(printf '%s\n' "$row" \
  | grep -oE "<tt [^>]*class=\"${cls}-sha256\"[^>]*>[[:space:]]*[0-9A-Fa-f]{64}[[:space:]]*</tt>" \
  | grep -oE '[0-9A-Fa-f]{64}' | tr 'A-F' 'a-f' || true)
if [[ -z "$hashes" || $(printf '%s' "$hashes" | grep -c '^') -ne 1 ]]; then
  echo "::error::expected exactly one ${cls}-sha256 checksum for $file in $src" >&2
  exit 1
fi

printf '%s\n' "$hashes"
