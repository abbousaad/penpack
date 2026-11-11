#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# engage.sh — start a named engagement with its own isolated data volume and
# BloodHound database.
#
#   ./engage.sh <engagement-name> [bloodhound-port]
#
# Creates engagements/<name>/data (mounted at /data inside the container) and
# runs the stack with `docker compose -p <name>`, so the BloodHound Postgres +
# Neo4j volumes are also isolated per engagement.
#
# Stop the engagement with:   docker compose -p <name> down
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME="${1:?Usage: ./engage.sh <engagement-name> [bloodhound-port]}"
PORT="${2:-8080}"

# Docker project names must be lowercase [a-z0-9_-]
if [[ ! "$NAME" =~ ^[a-z0-9_-]+$ ]]; then
    echo "[-] Engagement name must be lowercase alphanumeric (use only [a-z0-9_-])." >&2
    exit 1
fi

ENG_DIR="$ROOT/engagements/$NAME"
DATA_DIR="$ENG_DIR/data"
mkdir -p "$DATA_DIR"

if ss -tln 2>/dev/null | grep -q ":$PORT "; then
    echo "[!] Port $PORT is already in use — pass a different port as the 2nd argument." >&2
    exit 1
fi

echo "[*] Starting engagement '$NAME' (BloodHound on :$PORT)"
DATA_DIR="$DATA_DIR" BLOODHOUND_PORT="$PORT" \
    docker compose -p "$NAME" up -d --build

echo
echo "Engagement '$NAME' is running."
echo "  Pentest shell : docker compose -p $NAME exec pentest bash"
echo "  One-off tool  : docker compose -p $NAME run --rm pentest <tool> [args]"
echo "  BloodHound UI : http://localhost:$PORT/ui/login"
echo "  Data (mounted): $DATA_DIR"
echo "  Stop          : docker compose -p $NAME down"
