#!/usr/bin/env bash
set -euo pipefail

symbols_dir="${1:?Usage: archive-obfuscation-symbols.sh <symbols-directory> <archive-name>}"
archive_name="${2:?Usage: archive-obfuscation-symbols.sh <symbols-directory> <archive-name>}"
passphrase="${DEBUG_SYMBOLS_PASSPHRASE:-}"
runner_temp="${RUNNER_TEMP:-/tmp}"

if [[ ! "$archive_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "::error::Invalid encrypted symbols archive name."
  exit 1
fi
if [[ -z "$passphrase" ]]; then
  echo "::error::Missing DEBUG_SYMBOLS_PASSPHRASE Actions secret."
  exit 1
fi
if [[ ! -d "$symbols_dir" ]]; then
  echo "::error::Symbols directory does not exist: $symbols_dir"
  exit 1
fi

symbol_file="$(find "$symbols_dir" -type f -name '*.symbols' -size +0c -print -quit)"
if [[ -z "$symbol_file" ]]; then
  echo "::error::No non-empty Dart .symbols file found in $symbols_dir"
  exit 1
fi

umask 077
mkdir -p "$runner_temp"
work_dir="$(mktemp -d "$runner_temp/novyn-symbols.XXXXXX")"
archive="$work_dir/$archive_name.tar.gz"
encrypted="$runner_temp/$archive_name.tar.gz.gpg"
trap 'rm -rf "$work_dir" "$symbols_dir"' EXIT

tar -czf "$archive" -C "$symbols_dir" .
printf '%s' "$passphrase" | gpg \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase-fd 0 \
  --symmetric \
  --cipher-algo AES256 \
  --output "$work_dir/archive.tar.gz.gpg" \
  "$archive"

test -s "$work_dir/archive.tar.gz.gpg"
mv "$work_dir/archive.tar.gz.gpg" "$encrypted"
sha256="$(sha256sum "$encrypted" | awk '{ print $1 }')"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "encrypted_file=$encrypted"
    echo "sha256=$sha256"
  } >> "$GITHUB_OUTPUT"
fi

echo "Encrypted Dart symbols archive created: $(basename "$encrypted")"
echo "SHA-256: $sha256"
