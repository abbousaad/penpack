#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# check-tools.sh — verify every tool in the AD pentest image is installed and
# print a short status/version for each.
#
#   docker compose exec pentest check-tools
# -----------------------------------------------------------------------------
set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MISSING=0

# check <binary> [version-command]
#   - prints OK (with a version line when a version-command is given) or MISS
#   - the version-command is run through `bash -c`, so pipes are allowed
check() {
    local name="$1"
    local vercmd="${2:-}"
    if ! command -v "$name" >/dev/null 2>&1; then
        printf "  ${RED}[MISS]${NC} %-24s not found\n" "$name"
        MISSING=1
        return
    fi
    if [[ -n "$vercmd" ]]; then
        local ver
        ver=$(timeout 5 bash -c "$vercmd" 2>&1 | grep -vE '^\s*$' | head -n 1 | cut -c1-62)
        printf "  ${GREEN}[ OK ]${NC} %-24s %s\n" "$name" "$ver"
    else
        printf "  ${GREEN}[ OK ]${NC} %-24s installed\n" "$name"
    fi
}

echo
echo "AD Pentest toolbox — tool status"
echo "=================================================="

echo
echo "[ AD execution & auth ]"
check netexec   "netexec --version 2>&1 | grep -m1 -E '[0-9]+\.[0-9]+\.[0-9]+'"
check nxc       "netexec --version 2>&1 | grep -m1 -E '[0-9]+\.[0-9]+\.[0-9]+'"
check certipy   "certipy --version"
check bloodyAD
check kerbrute  "kerbrute version 2>&1 | grep -ioE 'v[0-9]+[0-9.]*' | head -1"

echo
echo "[ BloodHound ]"
check bloodhound-ce-python

echo
echo "[ Impacket scripts ]"
check secretsdump.py
check GetNPUsers.py
check mssqlclient.py
check psexec.py
check smbclient.py
check wmiexec.py

echo
echo "[ SMB / RPC / LDAP ]"
check rpcclient  "rpcclient --version 2>&1"
check smbclient  "smbclient --version 2>&1"
check ldapsearch "ldapsearch -VV 2>&1"

echo
echo "[ Recon / web fuzzing ]"
check nmap      "nmap --version 2>&1"
check ffuf      "ffuf -V 2>&1"
check gobuster  "gobuster version 2>&1"

echo
echo "[ RDP / pivoting / misc ]"
check rdesktop    "rdesktop 2>&1 | grep -i version | head -1"
check xfreerdp
check socat       "socat -V 2>&1"
check proxychains4
check openssl     "openssl version"
check sshpass     "sshpass -V 2>&1"

echo
echo "=================================================="
if [[ $MISSING -ne 0 ]]; then
    echo -e "${RED}One or more tools are missing.${NC}"
    exit 1
fi
echo -e "${GREEN}All tools are installed.${NC}"
