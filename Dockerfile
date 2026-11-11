# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# AD Pentest toolbox — Ubuntu base with all the tools used in the
# "mykalis.dojo" lab (and the common AD pentest workflow around it).
# -----------------------------------------------------------------------------
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        # build deps (for any source-built python wheels)
        build-essential \
        libssl-dev \
        libffi-dev \
        libkrb5-dev \
        # base tooling
        ca-certificates \
        curl \
        wget \
        git \
        unzip \
        jq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        # recon / scanning
        nmap \
        netcat-openbsd \
        dnsutils \
        ldap-utils \
        # SMB / RPC / kerberos
        smbclient \
        samba-common-bin \
        krb5-user \
        # web fuzzing (OWA / vhost discovery)
        ffuf \
        gobuster \
        # pivoting / tunneling
        socat \
        proxychains4 \
        openssh-client \
        sshpass \
        # RDP clients (jump boxes / GUI access)
        freerdp2-x11 \
        rdesktop \
        # misc
        openssl \
        iproute2 \
        iputils-ping \
        vim \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Python-based AD tooling (each in its own isolated venv via pipx, so their
# pinned dependencies can't conflict with one another)
# -----------------------------------------------------------------------------
ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN python3 -m pip install --no-cache-dir pipx \
    && pipx install --pip-args="--no-cache-dir" bloodhound-ce \
    && pipx install --pip-args="--no-cache-dir" bloodyAD \
    && pipx install --pip-args="--no-cache-dir" certipy-ad \
    && pipx install --pip-args="--no-cache-dir" impacket \
    # NetExec (nxc) is not published on PyPI — install from the official repo
    && pipx install --pip-args="--no-cache-dir" git+https://github.com/Pennyw0rth/NetExec

# -----------------------------------------------------------------------------
# kerbrute (Go binary — faster kerberos brute-forcing)
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/ropnop/kerbrute/releases/download/v1.0.3/kerbrute_linux_amd64" \
        -O /usr/local/bin/kerbrute \
    && chmod +x /usr/local/bin/kerbrute

WORKDIR /data

# The container is used interactively via `docker compose exec pentest bash`.
# `sleep infinity` keeps it alive in detached mode.
CMD ["sleep", "infinity"]
