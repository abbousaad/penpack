#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# encrypt.sh — encrypt an engagement's data directory for archiving.
#
#   ./encrypt.sh <engagement-name> [output-file]
#
# Produces a tar.gz.gpg (AES-256, symmetric). You will be prompted for a
# passphrase — keep it safe, it is required to decrypt.
#
# For asymmetric encryption (encrypt to a GPG key instead of a passphrase),
# set GPG_RECIPIENT:   GPG_RECIPIENT=me@example.com ./encrypt.sh <name>
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME="${1:?Usage: ./encrypt.sh <engagement-name> [output-file]}"
OUT="${2:-$ROOT/engagements/$NAME.tar.gz.gpg}"

ENG_DIR="$ROOT/engagements/$NAME"
DATA_DIR="$ENG_DIR/data"
[[ -d "$DATA_DIR" ]] || { echo "[-] No data directory: $DATA_DIR" >&2; exit 1; }

GPG_ARGS=(--cipher-algo AES256)
if [[ -n "${GPG_RECIPIENT:-}" ]]; then
    GPG_ARGS=(--encrypt --recipient "$GPG_RECIPIENT")
    echo "[*] Encrypting to recipient $GPG_RECIPIENT"
else
    if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
        GPG_ARGS+=(--symmetric --batch --passphrase "$GPG_PASSPHRASE")
        echo "[*] Encrypting with passphrase from GPG_PASSPHRASE (non-interactive)"
    else
        GPG_ARGS+=(--symmetric)
        echo "[*] Encrypting with a passphrase (you will be prompted twice)"
    fi
fi

tar -C "$ENG_DIR" -czf - data | gpg "${GPG_ARGS[@]}" -o "$OUT"

echo "[+] Encrypted archive written to: $OUT"
echo "    Keep your passphrase/key safe — it is required to decrypt."
