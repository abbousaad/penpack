#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# decrypt.sh — decrypt an engagement archive created by encrypt.sh.
#
#   ./decrypt.sh <archive.tar.gz.gpg> [destination-dir]
#
# Extracts the archive's data/ directory into the destination (default: cwd).
# -----------------------------------------------------------------------------
set -euo pipefail

ARCHIVE="${1:?Usage: ./decrypt.sh <archive.tar.gz.gpg> [destination-dir]}"
DEST="${2:-.}"

[[ -f "$ARCHIVE" ]] || { echo "[-] Archive not found: $ARCHIVE" >&2; exit 1; }
mkdir -p "$DEST"

if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
    gpg --batch --passphrase "$GPG_PASSPHRASE" -d "$ARCHIVE" | tar -xzf - -C "$DEST"
else
    gpg -d "$ARCHIVE" | tar -xzf - -C "$DEST"
fi

echo "[+] Decrypted into $DEST"
